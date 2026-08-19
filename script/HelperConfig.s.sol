// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
contract HelperConfig is Script{
    struct NetworkConfig{
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    NetworkConfig public activeNetworkConfig;

    constructor(){
        if(block.chainid == 1){ // mainnet

        } else if(block.chainid == 11155111){ // sepolia
            activeNetworkConfig = getSepoliaEthConfig();
        } else { // local anvil
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }

    }

    function getSepoliaEthConfig() private pure returns (NetworkConfig memory){
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, // seconds
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0, // update thiw with out subId
            callbackGasLimit: 500000, // 500,000 gas!
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory){
        if(activeNetworkConfig.vrfCoordinator != address(0)){
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        uint96 baseFee = 0.25 ether; // 0.25LINK
        uint96 gasPrice = 1e9; // 1 gwei LINK
        int256 weiPerUintLink = 1e18;
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock({
            _baseFee: baseFee,
            _gasPrice: gasPrice,
            _weiPerUnitLink: weiPerUintLink
        });
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, // seconds
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // this doesn't matter
            subscriptionId: 0, // our script will add this
            callbackGasLimit: 500000, // 500,000 gas!
            link: address(link) 
        });
    }
}