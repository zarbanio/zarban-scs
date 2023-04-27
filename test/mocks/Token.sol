// SPDX-License-Identifier: GPL-3.0-or-later

/// token.sol -- ERC20 implementation with minting and burning

// Copyright (C) 2015, 2016, 2017  DappHub, LLC

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.13;

contract MockToken {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    string public symbol;
    uint8 public decimals = 18; // standard token precision. override to customize

    constructor(string memory symbol_) {
        symbol = symbol_;
    }

    function approve(address guy) external returns (bool) {
        return approve(guy, type(uint256).max);
    }

    function approve(address guy, uint256 wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;

        return true;
    }

    function transfer(address dst, uint256 wad) external returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint256 wad) public returns (bool) {
        if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad, "token-insufficient-approval");
            allowance[src][msg.sender] = allowance[src][msg.sender] - wad;
        }

        require(balanceOf[src] >= wad, "token-insufficient-balance");
        balanceOf[src] = balanceOf[src] - wad;
        balanceOf[dst] = balanceOf[dst] + wad;

        return true;
    }

    function push(address dst, uint wad) external {
        transferFrom(msg.sender, dst, wad);
    }

    function pull(address src, uint wad) external {
        transferFrom(src, msg.sender, wad);
    }

    function move(address src, address dst, uint wad) external {
        transferFrom(src, dst, wad);
    }

    function mint(uint256 wad) external {
        mint(msg.sender, wad);
    }

    function burn(uint256 wad) external {
        burn(msg.sender, wad);
    }

    function mint(address guy, uint256 wad) public {
        balanceOf[guy] = balanceOf[guy] + wad;
        totalSupply = totalSupply + wad;
    }

    function burn(address guy, uint256 wad) public {
        if (guy != msg.sender && allowance[guy][msg.sender] != type(uint256).max) {
            require(allowance[guy][msg.sender] >= wad, "token-insufficient-approval");
            allowance[guy][msg.sender] = allowance[guy][msg.sender] - wad;
        }

        require(balanceOf[guy] >= wad, "token-insufficient-balance");
        balanceOf[guy] = balanceOf[guy] - wad;
        totalSupply = totalSupply - wad;
    }
}
