// SPDX-License-Identifier: GNU-3
pragma solidity ^0.8.13;

contract Mockcontract {
    bool has;
    bytes32 val;

    function peek() public view returns (bytes32, bool) {
        return (val, has);
    }

    function void() public {
        // unset the value
        has = false;
    }
}
