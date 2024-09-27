// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "forge-std/StdUtils.sol";
import {InnovativeTWAML} from "../src/TWAML.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TWAMLScript is Script {
    InnovativeTWAML public twAML;
    address public contractOwner;
    IERC20 public stakingToken; 
    uint256 public minLockTime = 1 days; // Example value, adjust as needed
    uint256 public maxLockTime = 30 days; // Example value, adjust as needed
    uint256 public maxWeeklyWeightIncrease = 100; // Example value, adjust as needed

    function setUp() public {
        contractOwner = vm.envAddress("OWNER_ADDRESS");
        stakingToken = IERC20(vm.envAddress("STAKING_TOKEN_ADDRESS"));
    }

    function run() public {
        vm.startBroadcast();

        twAML = new InnovativeTWAML(); 

        twAML.initialize(
            stakingToken,
            minLockTime,
            maxLockTime,
            maxWeeklyWeightIncrease,
            contractOwner
        );

        vm.stopBroadcast();
    }
}