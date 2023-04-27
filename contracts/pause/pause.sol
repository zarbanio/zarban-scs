// SPDX-License-Identifier: GNU-3
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

pragma solidity ^0.8.13;

interface Authority {
    function canCall(address src, address dst, bytes4 sig) external view returns (bool);
}

contract AuthEvents {
    event LogSetAuthority(address indexed authority);
    event LogSetOwner(address indexed owner);
}

contract Auth is AuthEvents {
    address public authority;
    address public owner;

    modifier auth() {
        require(isAuthorized(msg.sender, msg.sig), "auth-unauthorized");
        _;
    }

    function isAuthorized(address src, bytes4 sig) internal view returns (bool) {
        if (src == address(this)) {
            return true;
        } else if (src == owner) {
            return true;
        } else if (authority == address(0)) {
            return false;
        } else {
            return Authority(authority).canCall(src, address(this), sig);
        }
    }
}

contract Pause is Auth {
    // --- admin ---

    modifier wait() {
        require(msg.sender == address(proxy), "pause-undelayed-call");
        _;
    }

    function setOwner(address owner_) public wait {
        owner = owner_;
        emit LogSetOwner(owner);
    }

    function setAuthority(address authority_) public wait {
        authority = authority_;
        emit LogSetAuthority(authority);
    }

    function setDelay(uint256 delay_) public wait {
        delay = delay_;
    }

    // --- data ---

    mapping(bytes32 => bool) public plans;
    PauseProxy public proxy;
    uint256 public delay;

    // --- init ---

    constructor(uint256 delay_, address owner_, address authority_) public {
        delay = delay_;
        owner = owner_;
        authority = authority_;
        proxy = new PauseProxy();
    }

    // --- util ---

    function hash(address usr, bytes32 tag, bytes memory fax, uint256 eta) internal pure returns (bytes32) {
        return keccak256(abi.encode(usr, tag, fax, eta));
    }

    function soul(address usr) internal view returns (bytes32 tag) {
        assembly {
            tag := extcodehash(usr)
        }
    }

    // --- operations ---

    function plot(address usr, bytes32 tag, bytes memory fax, uint256 eta) public auth {
        require(eta >= block.timestamp + delay, "pause-delay-not-respected");
        plans[hash(usr, tag, fax, eta)] = true;
    }

    function drop(address usr, bytes32 tag, bytes memory fax, uint256 eta) public auth {
        plans[hash(usr, tag, fax, eta)] = false;
    }

    function exec(address usr, bytes32 tag, bytes memory fax, uint256 eta) public returns (bytes memory out) {
        require(plans[hash(usr, tag, fax, eta)], "pause-unplotted-plan");
        require(soul(usr) == tag, "pause-wrong-codehash");
        require(block.timestamp >= eta, "pause-premature-exec");

        plans[hash(usr, tag, fax, eta)] = false;

        out = proxy.exec(usr, fax);
        require(proxy.owner() == address(this), "pause-illegal-storage-change");
    }
}

// plans are executed in an isolated storage context to protect the pause from
// malicious storage modification during plan execution
contract PauseProxy {
    address public owner;

    modifier auth() {
        require(msg.sender == owner, "pause-proxy-unauthorized");
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    function exec(address usr, bytes memory fax) public auth returns (bytes memory out) {
        bool ok;
        (ok, out) = usr.delegatecall(fax);
        require(ok, "pause-delegatecall-error");
    }
}
