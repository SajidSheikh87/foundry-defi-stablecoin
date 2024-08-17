// // SPDX-License-Identifier: MIT
// // Have our invariant aka properties

// // What are our invariants? Properties that should always hold

// // 1. The total supply of DSC should be less than the total value of collateral

// // 2. Getter view functions should never revert <- evergreen invariant

// import {Test, console} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DeployDSC} from "../../script/DeployDSC.s.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// pragma solidity ^0.8.18;

// contract OpenInvariantTest is StdInvariant, Test{
//     DeployDSC deployer;
//     DSCEngine engine;
//     DecentralizedStableCoin dsc;
//     HelperConfig config;
//     address weth;
//     address wbtc;

//     function setUp() external {
//         deployer = new DeployDSC();
//         (dsc, engine, config) = deployer.run();
//         (,, weth, wbtc,) = config.activeNetworkConfig();
//         console.log(address(engine));
//         targetContract(address(engine));
//     }

//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//         // get the value of all the collateral in the protocol
//         // compare it to all the debt (dsc)
//         console.log("here");
//         uint256 totalSupply = dsc.totalSupply();
//         uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
//         uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(engine));
        
//         uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
//         uint256 wbtcValue = engine.getUsdValue(wbtc, totalBtcDeposited);

//         console.log ("wethValue: ", wethValue);
//         console.log ("wbtcValue: ", wbtcValue);
//         console.log ("totalSupply: ", totalSupply);


//         assert(wethValue + wbtcValue >= totalSupply);
//     }

// }