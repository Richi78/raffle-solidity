// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LinkToken is ERC20 {
    constructor() ERC20("Chainlink", "LINK") {
        _mint(msg.sender, 1_000_000 ether);
    }

    function transferAndCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bool success) {
        transfer(to, value);
        if (to.code.length > 0) {
            (success, ) = to.call(
                abi.encodeWithSignature(
                    "onTokenTransfer(address,uint256,bytes)",
                    msg.sender,
                    value,
                    data
                )
            );
        } else {
            success = true;
        }
    }
}
