// SPDX-License-Identifier: AGPL-3.0-or-later

// vow.t.sol -- tests for vow.sol

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

import "ds-test/test.sol";
import "dss-test/DssTest.sol";

import {Vow} from "contracts/system/vow.sol";
import {Vat} from "contracts/system/vat.sol";

interface Hevm {
    function warp(uint256) external;
}

contract Gem {
    mapping(address => uint256) public balanceOf;

    function mint(address usr, uint256 rad) public {
        balanceOf[usr] += rad;
    }
}

contract Collector {}

contract VowTest is DSTest, DssTest {
    Hevm hevm;

    Vat vat;
    Vow vow;
    Gem gov;
    Collector collector;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        collector = new Collector();
        vat = new Vat();
        gov = new Gem();
        vow = new Vow(address(vat));

        vow.file("bump", rad(100 ether));
        vow.file("sump", rad(100 ether));
        vow.file("collector", address(collector));

        vat.hope(address(vow));
    }

    function try_flog(uint256 era) internal returns (bool ok) {
        string memory sig = "flog(uint256)";
        (ok,) = address(vow).call(abi.encodeWithSignature(sig, era));
    }

    function try_call(address addr, bytes calldata data) external returns (bool) {
        bytes memory _data = data;
        assembly {
            let ok := call(gas(), addr, 0, add(_data, 0x20), mload(_data), 0, 0)
            let free := mload(0x40)
            mstore(free, ok)
            mstore(0x40, add(free, 32))
            revert(free, 32)
        }
    }

    function can_flap() public returns (bool) {
        string memory sig = "flap()";
        bytes memory data = abi.encodeWithSignature(sig);

        bytes memory can_call = abi.encodeWithSignature("try_call(address,bytes)", vow, data);
        (bool ok, bytes memory success) = address(this).call(can_call);

        ok = abi.decode(success, (bool));
        if (ok) return true;
    }

    function can_flop(uint256 rad) public returns (bool) {
        string memory sig = "flop(uint256)";
        bytes memory data = abi.encodeWithSignature(sig, rad);

        bytes memory can_call = abi.encodeWithSignature("try_call(address,bytes)", vow, data);
        (bool ok, bytes memory success) = address(this).call(can_call);

        ok = abi.decode(success, (bool));
        if (ok) return true;
    }

    uint256 constant ONE = 10 ** 27;

    function rad(uint256 wad) internal pure returns (uint256) {
        return wad * ONE;
    }

    function suck(address who, uint256 wad) internal {
        vow.fess(rad(wad));
        vat.init("");
        vat.suck(address(vow), who, rad(wad));
    }

    function flog(uint256 wad) internal {
        suck(address(0), wad); // suck dai into the zero address
        vow.flog(block.timestamp);
    }

    function heal(uint256 wad) internal {
        vow.heal(rad(wad));
    }

    function test_fail_auth() public {
        vow.deny(address(this));
        vm.expectRevert("Vow/not-authorized");
        vow.file("wait", uint256(100 seconds));
    }

    function test_fail_file() public {
        vm.expectRevert("Vow/file-unrecognized-param");
        vow.file("invalidName", uint256(1 ether));
        vm.expectRevert("Vow/file-unrecognized-param");
        vow.file("invalidName2", address(this));
    }

    function test_fail_rely_after_cage() public {
        vow.cage();
        vm.expectRevert("Vow/not-live");
        vow.rely(address(1));
    }

    function test_rely() public {
        vow.rely(address(1));
        vm.prank(address(1));
        vow.rely(address(2));
    }

    function test_deny() public {
        vow.deny(address(this));
        vm.expectRevert("Vow/not-authorized");
        vow.rely(address(this));
    }

    function test_cage_twice() public {
        vow.cage();
        vm.expectRevert("Vow/not-live");
        vow.cage();
    }

    function test_file_multiple() public {
        vow.file("bump", rad(100 ether));
        vow.file("collector", address(this));
    }

    function test_flog_wait() public {
        assertEq(vow.wait(), 0);
        vow.file("wait", uint256(100 seconds));
        assertEq(vow.wait(), 100 seconds);

        uint256 tic = block.timestamp;
        vow.fess(100 ether);
        hevm.warp(tic + 99 seconds);
        assertTrue(!try_flog(tic));
        hevm.warp(tic + 100 seconds);
        assertTrue(try_flog(tic));
    }

    function test_flap() public {
        vat.suck(address(0), address(vow), rad(100 ether));
        assertTrue(can_flap());
    }

    function test_no_reflop() public {
        uint256 mad = rad(100 ether);
        flog(100 ether);
        vat.suck(address(0), address(this), mad);

        assertTrue(can_flop(mad));
        vow.flop(mad);
        assertTrue(!can_flop(mad));
    }

    function test_no_flop_pending_surplus() public {
        flog(200 ether);

        vat.suck(address(0), address(vow), (rad(100 ether)));
        assertTrue(!can_flop(rad(100 ether)));

        heal(100 ether);
        vat.suck(address(0), address(this), (rad(100 ether)));

        assertTrue(can_flop(rad(100 ether)));
    }

    function test_no_flop_min_insufficient_flop_rad() public {
        assertTrue(!can_flop(rad(99 ether)));
    }

    function test_no_flap_pending_sin() public {
        vow.file("bump", uint256(0 ether));
        flog(100 ether);

        vat.suck(address(vow), address(this), (rad(50 ether)));
        assertTrue(!can_flap());
    }

    function test_no_flap_nonzero_surplus() public {
        vow.file("bump", uint256(0 ether));
        flog(100 ether);
        vat.suck(address(0), address(vow), (rad(50 ether)));
        assertTrue(!can_flap());
    }

    function test_no_flap_nonzero_surplus2() public {
        vow.file("bump", uint256(0 ether));
        vow.file("hump", uint256(50 ether));
        flog(100 ether);
        vat.suck(address(0), address(vow), (rad(151 ether)));
        assertTrue(!can_flap());
    }

    function test_no_flap_nonzero_debt() public {
        vow.file("bump", uint256(0 ether));
        vow.file("hump", uint256(50 ether));
        flog(100 ether);
        vat.suck(address(0), address(vow), (rad(150 ether)));
        assertTrue(!can_flap());
    }

    function test_no_flap_insufficient_rad() public {
        vat.suck(address(0), address(vow), (rad(50 ether)));
        assertTrue(!can_flop(50 ether));
    }

    function test_no_flap_insufficient_debt() public {
        vow.file("sump", uint256(10 ether));
        flog(100 ether);
        vow.fess(rad(10 ether));
        vat.suck(address(0), address(vow), (rad(100 ether)));
        assertTrue(!can_flop(rad(91 ether)));
    }

    function test_cage() public {
        flog(50 ether);
        vat.suck(address(0), address(vow), (rad(100 ether)));
        vow.cage();
        assertTrue(vat.zar(address(vow)) == rad(50 ether));
    }

    function test_cage2() public {
        flog(100 ether);
        vat.suck(address(0), address(vow), (rad(50 ether)));
        vow.cage();
        assertTrue(vat.sin(address(vow)) == rad(50 ether));
    }

    function test_cage3() public {
        flog(100 ether);
        vat.suck(address(0), address(vow), rad(100 ether));
        vow.cage();
        assertTrue(vat.sin(address(vow)) == 0);
        assertTrue(vat.zar(address(vow)) == 0);
    }

    function test_heal_insufficient_surplus() public {
        vat.suck(address(0), address(vow), (rad(100 ether)));
        assertEq(vat.zar(address(vow)), rad(100 ether));
        vm.expectRevert("Vow/insufficient-surplus");
        heal(101 ether);
    }

    function test_heal_insufficient_debt() public {
        flog(100 ether);
        vow.fess(rad(50 ether));
        vat.suck(address(0), address(vow), (rad(100 ether)));

        assertEq(vat.zar(address(vow)), rad(100 ether));
        assertEq(vow.Sin(), rad(50 ether));
        vm.expectRevert("Vow/insufficient-debt");
        heal(51 ether);

        heal(50 ether);
    }

    function test_heal_insufficient_debt2() public {
        flog(100 ether);
        vat.suck(address(0), address(vow), (rad(200 ether)));

        assertEq(vat.zar(address(vow)), rad(200 ether));
        assertEq(vow.Sin(), 0);
        vm.expectRevert("Vow/insufficient-debt");
        heal(101 ether);
    }
}
