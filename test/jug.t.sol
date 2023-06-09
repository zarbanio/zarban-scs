// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.13;

import "ds-test/test.sol";

import {Jug} from "contracts/system/jug.sol";
import {Vat} from "contracts/system/vat.sol";

interface Hevm {
    function warp(uint256) external;
}

interface VatLike {
    function ilks(bytes32)
        external
        view
        returns (uint256 Art, uint256 rate, uint256 spot, uint256 line, uint256 dust);
}

contract Rpow is Jug {
    constructor(address vat_) Jug(vat_) {}

    function pRpow(uint256 x, uint256 n, uint256 b) public pure returns (uint256) {
        return _rpow(x, n, b);
    }
}

contract JugTest is DSTest {
    Hevm hevm;
    Jug jug;
    Vat vat;

    function rad(uint256 wad_) internal pure returns (uint256) {
        return wad_ * 10 ** 27;
    }

    function wad(uint256 rad_) internal pure returns (uint256) {
        return rad_ / 10 ** 27;
    }

    function rho(bytes32 ilk) internal view returns (uint256) {
        (uint256 duty, uint256 rho_) = jug.ilks(ilk);
        duty;
        return rho_;
    }

    function Art(bytes32 ilk) internal view returns (uint256 ArtV) {
        (ArtV,,,,) = VatLike(address(vat)).ilks(ilk);
    }

    function rate(bytes32 ilk) internal view returns (uint256 rateV) {
        (, rateV,,,) = VatLike(address(vat)).ilks(ilk);
    }

    function line(bytes32 ilk) internal view returns (uint256 lineV) {
        (,,, lineV,) = VatLike(address(vat)).ilks(ilk);
    }

    address ali = address(bytes20("ali"));

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        vat = new Vat();
        jug = new Jug(address(vat));
        vat.rely(address(jug));
        vat.init("i");

        draw("i", 100 ether);
    }

    function draw(bytes32 ilk, uint256 zar) internal {
        vat.file("Line", vat.Line() + rad(zar));
        vat.file(ilk, "line", line(ilk) + rad(zar));
        vat.file(ilk, "spot", 10 ** 27 * 10000 ether);
        address self = address(this);
        vat.slip(ilk, self, 10 ** 27 * 1 ether);
        vat.frob(ilk, self, self, self, int256(1 ether), int256(zar));
    }

    function test_drip_setup() public {
        hevm.warp(0);
        assertEq(uint256(block.timestamp), 0);
        hevm.warp(1);
        assertEq(uint256(block.timestamp), 1);
        hevm.warp(2);
        assertEq(uint256(block.timestamp), 2);
        assertEq(Art("i"), 100 ether);
    }

    function test_drip_updates_rho() public {
        jug.init("i");
        assertEq(rho("i"), block.timestamp);

        jug.file("i", "duty", 10 ** 27);
        jug.drip("i");
        assertEq(rho("i"), block.timestamp);
        hevm.warp(block.timestamp + 1);
        assertEq(rho("i"), block.timestamp - 1);
        jug.drip("i");
        assertEq(rho("i"), block.timestamp);
        hevm.warp(block.timestamp + 1 days);
        jug.drip("i");
        assertEq(rho("i"), block.timestamp);
    }

    function test_drip_file() public {
        jug.init("i");
        jug.file("i", "duty", 10 ** 27);
        jug.drip("i");
        jug.file("i", "duty", 1000000564701133626865910626); // 5% / day
    }

    function test_drip_0d() public {
        jug.init("i");
        jug.file("i", "duty", 1000000564701133626865910626); // 5% / day
        assertEq(vat.zar(ali), rad(0 ether));
        jug.drip("i");
        assertEq(vat.zar(ali), rad(0 ether));
    }

    function test_drip_1d() public {
        jug.init("i");
        jug.file("vow", ali);

        jug.file("i", "duty", 1000000564701133626865910626); // 5% / day
        hevm.warp(block.timestamp + 1 days);
        assertEq(wad(vat.zar(ali)), 0 ether);
        jug.drip("i");
        assertEq(wad(vat.zar(ali)), 5 ether);
    }

    function test_drip_2d() public {
        jug.init("i");
        jug.file("vow", ali);
        jug.file("i", "duty", 1000000564701133626865910626); // 5% / day

        hevm.warp(block.timestamp + 2 days);
        assertEq(wad(vat.zar(ali)), 0 ether);
        jug.drip("i");
        assertEq(wad(vat.zar(ali)), 10.25 ether);
    }

    function test_drip_3d() public {
        jug.init("i");
        jug.file("vow", ali);

        jug.file("i", "duty", 1000000564701133626865910626); // 5% / day
        hevm.warp(block.timestamp + 3 days);
        assertEq(wad(vat.zar(ali)), 0 ether);
        jug.drip("i");
        assertEq(wad(vat.zar(ali)), 15.7625 ether);
    }

    function test_drip_negative_3d() public {
        jug.init("i");
        jug.file("vow", ali);

        jug.file("i", "duty", 999999706969857929985428567); // -2.5% / day
        hevm.warp(block.timestamp + 3 days);
        assertEq(wad(vat.zar(address(this))), 100 ether);
        vat.move(address(this), ali, rad(100 ether));
        assertEq(wad(vat.zar(ali)), 100 ether);
        jug.drip("i");
        assertEq(wad(vat.zar(ali)), 92.6859375 ether);
    }

    function test_drip_multi() public {
        jug.init("i");
        jug.file("vow", ali);

        jug.file("i", "duty", 1000000564701133626865910626); // 5% / day
        hevm.warp(block.timestamp + 1 days);
        jug.drip("i");
        assertEq(wad(vat.zar(ali)), 5 ether);
        jug.file("i", "duty", 1000001103127689513476993127); // 10% / day
        hevm.warp(block.timestamp + 1 days);
        jug.drip("i");
        assertEq(wad(vat.zar(ali)), 15.5 ether);
        assertEq(wad(vat.debt()), 115.5 ether);
        assertEq(rate("i") / 10 ** 9, 1.155 ether);
    }

    function test_drip_base() public {
        vat.init("j");
        draw("j", 100 ether);

        jug.init("i");
        jug.init("j");
        jug.file("vow", ali);

        jug.file("i", "duty", 1050000000000000000000000000); // 5% / second
        jug.file("j", "duty", 1000000000000000000000000000); // 0% / second
        jug.file("base", uint256(50000000000000000000000000)); // 5% / second
        hevm.warp(block.timestamp + 1);
        jug.drip("i");
        assertEq(wad(vat.zar(ali)), 10 ether);
    }

    function test_file_duty() public {
        jug.init("i");
        hevm.warp(block.timestamp + 1);
        jug.drip("i");
        jug.file("i", "duty", 1);
    }

    function testFail_file_duty() public {
        jug.init("i");
        hevm.warp(block.timestamp + 1);
        jug.file("i", "duty", 1);
    }

    function test_rpow() public {
        Rpow r = new Rpow(address(vat));
        uint256 result = r.pRpow(uint256(1000234891009084238901289093), uint256(3724), uint256(1e27));
        // python calc = 2.397991232255757e27 = 2397991232255757e12
        // expect 10 decimal precision
        assertEq(result / uint256(1e17), uint256(2397991232255757e12) / 1e17);
    }
}
