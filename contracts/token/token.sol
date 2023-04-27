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

pragma solidity ^0.8.13;

import "./math.sol";

contract Token is Math {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    string public symbol;
    uint8 public decimals = 18; // standard token precision. override to customize
    string public name = "Tes Col"; // Optional token name

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Mint(address indexed guy, uint256 wad);
    event Burn(address indexed guy, uint256 wad);

    constructor(string memory symbol_) public {
        symbol = symbol_;
    }

    function approve(address guy) external returns (bool) {
        return approve(guy, type(uint256).max);
    }

    function approve(address guy, uint256 wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;

        emit Approval(msg.sender, guy, wad);

        return true;
    }

    function transfer(address dst, uint256 wad) external returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint256 wad) public returns (bool) {
        uint256 allowed = allowance[src][msg.sender];
        if (src != msg.sender && allowed != type(uint256).max) {
            require(allowed >= wad, "ds-token-insufficient-approval");

            unchecked {
                allowance[src][msg.sender] = allowed - wad;
            }
        }

        require(balanceOf[src] >= wad, "ds-token-insufficient-balance");

        unchecked {
            balanceOf[src] = balanceOf[src] - wad;
            balanceOf[dst] = balanceOf[dst] + wad;
        }

        emit Transfer(src, dst, wad);

        return true;
    }

    function mint(uint256 wad) external {
        mint(msg.sender, wad);
    }

    function burn(uint256 wad) external {
        burn(msg.sender, wad);
    }

    function mint(address guy, uint256 wad) public {
        unchecked {
            balanceOf[guy] = balanceOf[guy] + wad;
        }
        totalSupply = totalSupply + wad;
        emit Mint(guy, wad);
    }

    function burn(address guy, uint256 wad) public {
        uint256 allowed = allowance[guy][msg.sender];
        if (guy != msg.sender && allowed != type(uint256).max) {
            require(allowed >= wad, "token-insufficient-approval");

            unchecked {
                allowance[guy][msg.sender] = allowed - wad;
            }
        }

        require(balanceOf[guy] >= wad, "token-insufficient-balance");

        unchecked {
            balanceOf[guy] = balanceOf[guy] - wad;
            totalSupply = totalSupply - wad;
        }

        emit Burn(guy, wad);
    }

    function setName(string memory name_) public {
        name = name_;
    }
}
