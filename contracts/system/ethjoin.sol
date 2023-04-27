// SPDX-License-Identifier: GNU-3
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

interface DSTokenLike {
    function mint(address, uint256) external;

    function burn(address, uint256) external;
}

interface VatLike {
    function slip(bytes32, address, int256) external;

    function move(address, address, uint256) external;
}

/*
    Here we provide *adapters* to connect the Vat to arbitrary external
    token implementations, creating a bounded context for the Vat. The
    adapters here are provided as working examples:

      - `GemJoin`: For well behaved ERC20 tokens, with simple transfer
                   semantics.

      - `ETHJoin`: For native Ether.

      - `ZarJoin`: For connecting internal Zar balances to an external
                   `DSToken` implementation.

    In practice, adapter implementations will be varied and specific to
    individual collateral types, accounting for different transfer
    semantics and token standards.

    Adapters need to implement two basic methods:

      - `join`: enter collateral into the system
      - `exit`: remove collateral from the system*/

contract ETHJoin {
    // ---  ---
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
        require(wards[msg.sender] == 1, "Vow/not-authorized");
        _;
    }

    VatLike public vat;
    bytes32 public ilk;
    uint256 public live; // Access Flag

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);

    constructor(address vat_, bytes32 ilk_) public {
        wards[msg.sender] = 1;
        live = 1;
        vat = VatLike(vat_);
        ilk = ilk_;
    }

    function cage() external auth {
        live = 0;
    }

    function join(address usr) external payable {
        require(live == 1, "ETHJoin/not-live");
        require(int256(msg.value) >= 0, "ETHJoin/overflow");
        vat.slip(ilk, usr, int256(msg.value));
    }

    function exit(address payable usr, uint256 wad) external {
        require(int256(wad) >= 0, "ETHJoin/overflow");
        vat.slip(ilk, msg.sender, -int256(wad));
        usr.transfer(wad);
    }
}
