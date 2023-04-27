// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

interface JugLike {
    function file(bytes32 ilk, bytes32 what, uint256 data) external;

    function drip(bytes32 ilk) external returns (uint256 rate);
}

contract FileDuty {
    // --- Auth ---
    mapping(address => uint256) public wards;

    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    modifier auth() {
        require(wards[msg.sender] == 1, "FileDuty/not-authorized");
        _;
    }

    JugLike jug;

    event Rely(address indexed usr);
    event Deny(address indexed usr);

    constructor(address jug_) {
        wards[msg.sender] = 1;
        jug = JugLike(jug_);
    }

    function fileDuty(bytes32 ilk, bytes32 what, uint256 data) auth external {
        jug.drip(ilk);
        jug.file(ilk, what, data);
    }
}
