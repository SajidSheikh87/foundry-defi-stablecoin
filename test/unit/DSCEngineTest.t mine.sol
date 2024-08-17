// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    address public USER2 = makeAddr("user2");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant HALF_COLLATERAL = AMOUNT_COLLATERAL / 2;
    uint256 public constant MINT_DSC = 1 ether;
    
    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, ,) = config.activeNetworkConfig();
        
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
        ERC20Mock(weth).mint(USER2, STARTING_ERC20_BALANCE);

        // console.log("engine: ", address(engine));
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
        
    function testRervertsIfTokenLengthDoesntMatchPriceFeed() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.
        DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));

    }
    

    /////////////////
    // Price Tests //
    /////////////////

    function testGetUsdValue() public view{
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/ETH = 30,000e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);

        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        // $2,000 / ETH, $100
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT COLLATERAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testRevertsIfCollateralZero()public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        engine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral(address user) {
        
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        // depositCollateral();
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);        
        console.log("AMOUNT_COLLATERAL", AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
        // engine.s_collateralDeposited[USER]["WETH"]
    }
    

    modifier mintDscTokens(uint256 dscToBeMinted){
        // uint256 dscToBeMinted = 100 ether;
        vm.startPrank(USER);
        engine.mintDsc(dscToBeMinted);
        vm.stopPrank();
        _;
    }

    // 10.000000000000000000

    function testCanDepositCollateralAndMintDsc() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, MINT_DSC);
        (uint256 totalDscMinted, ) = engine.getAccountInformation(USER);
        uint256 amountCollateralNonUsd = engine.getAmountCollateral(USER, weth);
        vm.stopPrank();
        assertEq(totalDscMinted, MINT_DSC);
        assertEq(amountCollateralNonUsd, AMOUNT_COLLATERAL);
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral(USER) {
      
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = 0;
        
        uint256 expectedDepositAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        console.log("totalDscMinted", totalDscMinted);
        console.log("collateralValueInUsd", collateralValueInUsd);
        console.log("expectedDepositAmount", expectedDepositAmount);

        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);

    }

    /*//////////////////////////////////////////////////////////////
                        REDEEM COLLATERAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testRedeemCollateral() public depositedCollateral(USER) {
        
        (/* uint256 totalDscMinted */, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        vm.startPrank(USER);
        engine.redeemCollateral(weth, HALF_COLLATERAL);
        vm.stopPrank();
        (/* uint256 totalDscMinted */, uint256 collateralValueInUsd2) = engine.getAccountInformation(USER);
        assertEq(collateralValueInUsd2, collateralValueInUsd / 2);

    }

    // function testRedeemCollateralForDsc() public {}

        // 10000.000000000000000000
        //20000.000000000000000000 <- 10 eth
        //10000.000000000000000000

    /* function testRedeemCollateralForDsc() public depositedCollateral mintDscTokens(MINT_DSC) {
        // Before calling the redeem function
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        console.log("totalDscMinted[before]: ", totalDscMinted); // 1.000000000000000000
        console.log("collateralValueInUsd[Before]: ", collateralValueInUsd);

        vm.startPrank(USER);

        // Ensure the amount is properly approved
        // ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

    // Approve the DSCEngine to spend the tokens
        bool success = ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        if(success) {
            console.log("Amount approved");
        }

       

        // Verify approval was set
        uint256 allowance = ERC20Mock(weth).allowance(USER, address(engine));
        console.log("Allowance after approval:", allowance); // 10.000000000000000000
        console.log("HALF_COLLATERAL: ", HALF_COLLATERAL); // 5.000000000000000000
        console.log("DSCEngine Address: ", address(engine));
        console.log("WETH Address: ", weth);
        console.log("USER Address: ", address(USER));
        console.log("Transaction initiator: ", msg.sender); 

        // 100.000000000000000000

        vm.stopPrank();

        vm.startPrank(address(engine));

        // Ensure you're redeeming an amount less than or equal to the approved amount
        engine.redeemCollateralForDsc(weth, HALF_COLLATERAL, MINT_DSC);
        vm.stopPrank();

        // After calling the redeem function
        (uint256 totalDscMinted2, ) = engine.getAccountInformation(USER);
        (uint256 remainingCollateral) = engine.getAmountCollateral(USER, weth);
        console.log("totalDscMinted[after]: ", totalDscMinted2);
        console.log("remainingCollateral[after]: ", remainingCollateral);
        

        // Verify changes, e.g., DSC minted and collateral value
        assertEq(totalDscMinted2, totalDscMinted - MINT_DSC);
        assertEq(remainingCollateral, AMOUNT_COLLATERAL - HALF_COLLATERAL);

        
    }

//     totalDscMinted[before]:      1.000000000000000000 (when 100 ether value used)
//   collateralValueInUsd[Before]:  20000.000000000000000000 / 2000 == 10 ether
    // max dsc 1000 => 10 ether

    // Allowance after approval: 10.000000000000000000 */

    /*//////////////////////////////////////////////////////////////
                              TEST MINTING
    //////////////////////////////////////////////////////////////*/

    function testMintDsc() public depositedCollateral(USER) mintDscTokens(MINT_DSC){

        (uint256 totalDscMinted, ) = engine.getAccountInformation(USER);
        console.log("Total DSC Minted: ", totalDscMinted);

        assertEq(MINT_DSC, totalDscMinted); 

    }

    function testMintDscRevertsIfTryingToMintMoreThanTheAllowedHealthFactor() public depositedCollateral(USER) {
        uint256 dscToBeMinted = 100000 ether;
        uint256 userHealthFactor = 0.1 ether;
        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, userHealthFactor)
            );
        engine.mintDsc(dscToBeMinted);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            LIQUIDATE TESTS
    //////////////////////////////////////////////////////////////*/

    // function testLiquidationFailsIfHealthFactorIsGood() public depositedCollateral(USER) depositedCollateral(USER2) mintDscTokens(MINT_DSC){
        
    //     (, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);

    //     vm.startPrank(USER2);
    //     engine.liquidate(DSCEngine.USER(weth), USER, collateralValueInUsd);

    // }

    
}

