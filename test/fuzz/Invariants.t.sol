// SPDX-License-Identifier: MIT
// Have our invariant aka properties

// What are our invariants? Properties that should always hold

// 1. The total supply of DSC should be less than the total value of collateral

// 2. Getter view functions should never revert <- evergreen invariant

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";
pragma solidity ^0.8.18;

contract InvariantTest is StdInvariant, Test{
    DeployDSC deployer;
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        console.log("Weth: ", weth);
        console.log("Wbtc: ", wbtc);
        console.log("Engine: ",address(engine));
        // targetContract(address(engine));
        handler = new Handler(engine, dsc);
        targetContract(address(handler));
        // hey, don't call redeemcollateral, unless there is a collatreral to redeem
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // get the value of all the collateral in the protocol
        // compare it to all the debt (dsc)
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(engine));
        
        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = engine.getUsdValue(wbtc, totalBtcDeposited);

        console.log ("Total wethValue: ", wethValue);
        console.log ("Total wbtcValue: ", wbtcValue);

        console.log("Final check | Total WETH Supply: ", totalWethDeposited);
        console.log("Final check | Total WBTC Supply: ", totalBtcDeposited);
        console.log ("totalSupply: ", totalSupply);
        console.log("Times mint called: ", handler.timesMintIsCalled());

        assert(wethValue + wbtcValue >= totalSupply);
        // assert(totalWethDeposited >= totalSupply);
        // assert(totalBtcDeposited >= totalSupply);
    }

    // We should always use a given invariant <- for all the getters
    function invariant_gettersShouldNotRevert() public view {
        engine.getCollateralTokens();
        engine.getHealthFactor();
        engine.getAccountCollateralValue(msg.sender);
    }
}