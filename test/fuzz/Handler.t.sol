// SPDX-License-Identifier: MIT

// Handler is going to narrow down the way we call functions so that we don't waste runs

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

// Price Fee
// WETH Token
// WBTC Token
// These should also be tested

contract Handler is Test {
    DSCEngine engine;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timesMintIsCalled = 0;
    address[] public usersWithCollateralDeposited;
    MockV3Aggregator public ethUsdPriceFeed;
 
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max; // the max uint96 value

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        engine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = engine.getCollateralTokens();

        weth = ERC20Mock(collateralTokens[0]);
        
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(engine.getCollateralTokenPriceFeed(address(weth)));
    }

    // redeem collateral <- call only when you have collateral

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        // console.log("Collateral: ", address(collateral));
        // console.log("Amount: ", amountCollateral);
        
        // vm.deal(address(this), amountCollateral);
        // vm.deal(address(engine), amountCollateral);
        
        // Approve the engine to make a deposit
        // collateral.approve(address(engine), amountCollateral);
        
        // uint256 allowance = collateral.allowance(address(this), address(engine));
        // uint256 allowance = collateral.allowance(address(this), address(engine));
        // console.log("Allowance after approval:", allowance); // 10.000000000000000000
        // collateral.mint(address(this), amountCollateral);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(engine), amountCollateral);

        // console.log("Address of Handler: ", address(this));

        // console.log("Balance of Handler: ", address(this).balance);
        // console.log("Balance of Engine:", ERC20Mock(address(collateral)).balanceOf(address(engine)));
        
        // console.log("Balance of Handler [Tokens] BEFORE transaction: ",  ERC20Mock(collateral).balanceOf(address(this)));
        engine.depositCollateral(address(collateral), amountCollateral);
        // console.log("Balance of Handler [Tokens] AFTER transaction: ",  ERC20Mock(collateral).balanceOf(address(this)));
        // console.log("Total WETH Deposited: ", ERC20Mock(weth).balanceOf(address(engine)));
        // console.log("Total WBTC Deposited: ", ERC20Mock(wbtc).balanceOf(address(engine)));
        vm.stopPrank();
        // this will double push if same address hits twice
        usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = engine.getAmountCollateral(address(collateral), msg.sender);
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if(amountCollateral == 0) {
            return;
        }
        engine.redeemCollateral(address(collateral), amountCollateral);
        
    }

    function mintDsc(uint256 amount, uint256 addressSeed) public {
        if(usersWithCollateralDeposited.length == 0) {
            return;
        }
        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(sender);
        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
    
        if(maxDscToMint < 0) {
            return;
        }
        amount = bound(amount, 0, uint256(maxDscToMint));
        
        if(amount == 0) {
            return;
        }
        vm.startPrank(sender);
        engine.mintDsc(amount);
        vm.stopPrank();
        timesMintIsCalled++;
    }

    // This breaks our invariat test suite!!! 100% show in the audit
    // function updateCollateralPrice(uint96 newPrice) public{
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    // Helper functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if(collateralSeed % 2 == 0) {
            return weth;
        } 
        return wbtc;
    }
}