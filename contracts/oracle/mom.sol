// SPDX-License-Identifier: GNU-3
pragma solidity ^0.8.13;

interface OsmLike {
    function stop() external;
}

interface AuthorityLike {
    function canCall(address src, address dst, bytes4 sig) external view returns (bool);
}

interface VatLike {
    function file(bytes32 ilk, bytes32 what, uint256 data) external;
}

interface AutoLineLike {
    function remIlk(bytes32 ilk) external;
}

contract OsmMom {
    address public owner;
    address public authority;
    address public autoLine;

    mapping(bytes32 => address) public osms;

    address public immutable vat;

    event SetOwner(address indexed owner);
    event SetAuthority(address indexed authority);
    event File(bytes32 indexed what, address data);
    event SetOsm(bytes32 indexed ilk, address osm);
    event Stop(bytes32 indexed ilk);

    modifier onlyOwner() {
        require(msg.sender == owner, "OsmMom/only-owner");
        _;
    }

    modifier auth() {
        require(isAuthorized(msg.sender, msg.sig), "OsmMom/not-authorized");
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
            return AuthorityLike(authority).canCall(src, address(this), sig);
        }
    }

    constructor(address vat_) public {
        vat = vat_;
        owner = msg.sender;
        emit SetOwner(msg.sender);
    }

    function setOwner(address owner_) external onlyOwner {
        owner = owner_;
        emit SetOwner(owner_);
    }

    function setAuthority(address authority_) external onlyOwner {
        authority = authority_;
        emit SetAuthority(authority_);
    }

    function file(bytes32 what, address data) external onlyOwner {
        if (what == "autoLine") autoLine = data;
        else revert("OsmMom/file-unrecognized-param");
        emit File(what, data);
    }

    function setOsm(bytes32 ilk, address osm) external onlyOwner {
        osms[ilk] = osm;
        emit SetOsm(ilk, osm);
    }

    function stop(bytes32 ilk) external auth {
        OsmLike(osms[ilk]).stop();
        VatLike(vat).file(ilk, "line", 0);
        AutoLineLike(autoLine).remIlk(ilk);
        emit Stop(ilk);
    }
}
