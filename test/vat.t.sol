// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.13;

import "dss-test/DssTest.sol";

import {Vat} from "contracts/system/vat.sol";
import {Jug} from "contracts/system/jug.sol";
import {ZarJoin, GemJoin} from "contracts/system/join.sol";

import {MockToken} from "test/mocks/Token.sol";

contract User {
    Vat public vat;

    constructor(Vat vat_) {
        vat = vat_;
    }

    function flux(bytes32 ilk, address src, address dst, uint256 wad) public {
        vat.flux(ilk, src, dst, wad);
    }

    function move(address src, address dst, uint256 rad) public {
        vat.move(src, dst, rad);
    }

    function frob(bytes32 ilk, address u, address v, address w, int256 dink, int256 dart) public {
        vat.frob(ilk, u, v, w, dink, dart);
    }

    function fork(bytes32 ilk, address src, address dst, int256 dink, int256 dart) public {
        vat.fork(ilk, src, dst, dink, dart);
    }

    function heal(uint256 rad) public {
        vat.heal(rad);
    }

    function hope(address usr) public {
        vat.hope(usr);
    }

    function zar() public view returns (uint256) {
        return vat.zar(address(this));
    }

    function sin() public view returns (uint256) {
        return vat.sin(address(this));
    }

    function gems(bytes32 ilk) public view returns (uint256) {
        return vat.gem(ilk, address(this));
    }

    function ink(bytes32 ilk) public view returns (uint256 _ink) {
        (_ink,) = vat.urns(ilk, address(this));
    }

    function art(bytes32 ilk) public view returns (uint256 _art) {
        (, _art) = vat.urns(ilk, address(this));
    }
}

contract VatTest is DssTest {
    Vat vat;
    User usr1;
    User usr2;
    address ausr1;
    address ausr2;

    bytes32 constant ILK = "SOME-ILK-A";

    // --- Events ---
    event Init(bytes32 indexed ilk);
    event File(bytes32 indexed ilk, bytes32 indexed what, uint256 indexed data);
    event Cage();
    event Hope(address indexed usr);
    event Nope(address indexed usr);
    event Slip(bytes32 indexed ilk, address indexed usr, int256 indexed wad);
    event Flux(bytes32 indexed ilk, address indexed src, address indexed dst, uint256 wad);
    event Move(address indexed src, address indexed dst, uint256 rad);
    event Frob(bytes32 i, address indexed u, address indexed v, address indexed w, int256 dink, int256 dart);
    event Fork(bytes32 indexed ilk, address indexed src, address indexed dst, int256 dink, int256 dart);
    event Grab(bytes32 i, address indexed u, address indexed v, address indexed w, int256 dink, int256 dart);
    event Heal(uint256 indexed rad);
    event Suck(address indexed u, address indexed v, uint256 indexed rad);
    event Fold(bytes32 indexed i, address indexed u, int256 indexed rate);

    function setUp() public {
        vat = new Vat();
        usr1 = new User(vat);
        usr2 = new User(vat);
        ausr1 = address(usr1);
        ausr2 = address(usr2);
    }

    modifier setupCdpOps() {
        vat.init(ILK);
        vat.file("Line", 1000 * RAD);
        vat.file(ILK, "spot", RAY); // Collateral price = $1 and 100% CR for simplicity
        vat.file(ILK, "line", 1000 * RAD);
        vat.file(ILK, "dust", 10 * RAD);

        // Give some gems to the users
        vat.slip(ILK, ausr1, int256(100 * WAD));
        vat.slip(ILK, ausr2, int256(100 * WAD));

        _;
    }

    function testConstructor() public {
        assertEq(vat.live(), 1);
        assertEq(vat.wards(address(this)), 1);
    }

    function testAuth() public {
        checkAuth(address(vat), "Vat");
    }

    function testFile() public {
        checkFileUint(address(vat), "Vat", ["Line"]);
    }

    function testFileIlk() public {
        vm.expectEmit(true, true, true, true);
        emit File(ILK, "spot", 1);
        vat.file(ILK, "spot", 1);
        (,, uint256 spot,,) = vat.ilks(ILK);
        assertEq(spot, 1);
        vat.file(ILK, "line", 1);
        (,,, uint256 line,) = vat.ilks(ILK);
        assertEq(line, 1);
        vat.file(ILK, "dust", 1);
        (,,,, uint256 dust) = vat.ilks(ILK);
        assertEq(dust, 1);

        // Invalid name
        vm.expectRevert("Vat/file-unrecognized-param");
        vat.file(ILK, "badWhat", 1);

        // Not authed
        vat.deny(address(this));
        vm.expectRevert("Vat/not-authorized");
        vat.file(ILK, "spot", 1);
    }

    function testAuthModifier() public {
        vat.deny(address(this));

        bytes[] memory funcs = new bytes[](6);
        funcs[0] = abi.encodeWithSelector(Vat.init.selector, ILK);
        funcs[1] = abi.encodeWithSelector(Vat.cage.selector);
        funcs[2] = abi.encodeWithSelector(Vat.slip.selector, ILK, address(0), 0);
        funcs[3] = abi.encodeWithSelector(Vat.grab.selector, ILK, address(0), address(0), address(0), 0, 0);
        funcs[4] = abi.encodeWithSelector(Vat.suck.selector, address(0), address(0), 0);
        funcs[5] = abi.encodeWithSelector(Vat.fold.selector, ILK, address(0), 0);

        for (uint256 i = 0; i < funcs.length; i++) {
            assertRevert(address(vat), funcs[i], "Vat/not-authorized");
        }
    }

    function testLive() public {
        vat.cage();

        bytes[] memory funcs = new bytes[](6);
        funcs[0] = abi.encodeWithSelector(Vat.rely.selector, address(0));
        funcs[1] = abi.encodeWithSelector(Vat.deny.selector, address(0));
        funcs[2] = abi.encodeWithSignature("file(bytes32,uint256)", bytes32("Line"), 0);
        funcs[3] = abi.encodeWithSignature("file(bytes32,bytes32,uint256)", ILK, bytes32("Line"), 0);
        funcs[4] = abi.encodeWithSelector(Vat.frob.selector, ILK, address(0), address(0), address(0), 0, 0);
        funcs[5] = abi.encodeWithSelector(Vat.fold.selector, ILK, address(0), 0);

        for (uint256 i = 0; i < funcs.length; i++) {
            assertRevert(address(vat), funcs[i], "Vat/not-live");
        }
    }

    function testInit() public {
        (, uint256 rate,,,) = vat.ilks(ILK);
        assertEq(rate, 0);

        vm.expectEmit(true, true, true, true);
        emit Init(ILK);
        vat.init(ILK);

        (, rate,,,) = vat.ilks(ILK);
        assertEq(rate, RAY);
    }

    function testInitCantSetTwice() public {
        vat.init(ILK);
        vm.expectRevert("Vat/ilk-already-init");
        vat.init(ILK);
    }

    function testCage() public {
        assertEq(vat.live(), 1);

        vm.expectEmit(true, true, true, true);
        emit Cage();
        vat.cage();

        assertEq(vat.live(), 0);
    }

    function testHope() public {
        assertEq(vat.can(address(this), TEST_ADDRESS), 0);

        vm.expectEmit(true, true, true, true);
        emit Hope(TEST_ADDRESS);
        vat.hope(TEST_ADDRESS);

        assertEq(vat.can(address(this), TEST_ADDRESS), 1);
    }

    function testNope() public {
        vat.hope(TEST_ADDRESS);

        assertEq(vat.can(address(this), TEST_ADDRESS), 1);

        vm.expectEmit(true, true, true, true);
        emit Nope(TEST_ADDRESS);
        vat.nope(TEST_ADDRESS);

        assertEq(vat.can(address(this), TEST_ADDRESS), 0);
    }

    function testSlipPositive() public {
        assertEq(vat.gem(ILK, TEST_ADDRESS), 0);

        vm.expectEmit(true, true, true, true);
        emit Slip(ILK, TEST_ADDRESS, int256(100 * WAD));
        vat.slip(ILK, TEST_ADDRESS, int256(100 * WAD));

        assertEq(vat.gem(ILK, TEST_ADDRESS), 100 * WAD);
    }

    function testSlipNegative() public {
        vat.slip(ILK, TEST_ADDRESS, int256(100 * WAD));

        assertEq(vat.gem(ILK, TEST_ADDRESS), 100 * WAD);

        vm.expectEmit(true, true, true, true);
        emit Slip(ILK, TEST_ADDRESS, -int256(50 * WAD));
        vat.slip(ILK, TEST_ADDRESS, -int256(50 * WAD));

        assertEq(vat.gem(ILK, TEST_ADDRESS), 50 * WAD);
    }

    function testSlipNegativeUnderflow() public {
        assertEq(vat.gem(ILK, TEST_ADDRESS), 0);

        vm.expectRevert();
        vat.slip(ILK, TEST_ADDRESS, -int256(50 * WAD));
    }

    function testFluxSelfOther() public {
        vat.slip(ILK, ausr1, int256(100 * WAD));

        assertEq(vat.gem(ILK, ausr1), 100 * WAD);
        assertEq(vat.gem(ILK, ausr2), 0);

        vm.expectEmit(true, true, true, true);
        emit Flux(ILK, ausr1, ausr2, 100 * WAD);
        usr1.flux(ILK, ausr1, ausr2, 100 * WAD);

        assertEq(vat.gem(ILK, ausr1), 0);
        assertEq(vat.gem(ILK, ausr2), 100 * WAD);
    }

    function testFluxOtherSelf() public {
        vat.slip(ILK, ausr1, int256(100 * WAD));

        assertEq(vat.gem(ILK, ausr1), 100 * WAD);
        assertEq(vat.gem(ILK, ausr2), 0);

        usr1.hope(ausr2);
        usr2.flux(ILK, ausr1, ausr2, 100 * WAD);

        assertEq(vat.gem(ILK, ausr1), 0);
        assertEq(vat.gem(ILK, ausr2), 100 * WAD);
    }

    function testFluxOtherSelfNoPermission() public {
        vat.slip(ILK, ausr1, int256(100 * WAD));

        assertEq(vat.gem(ILK, ausr1), 100 * WAD);
        assertEq(vat.gem(ILK, ausr2), 0);

        vm.expectRevert("Vat/not-allowed1");
        usr2.flux(ILK, ausr1, ausr2, 100 * WAD);
    }

    function testFluxSelfSelf() public {
        vat.slip(ILK, ausr1, int256(100 * WAD));

        assertEq(vat.gem(ILK, ausr1), 100 * WAD);

        usr1.flux(ILK, ausr1, ausr1, 100 * WAD);

        assertEq(vat.gem(ILK, ausr1), 100 * WAD);
    }

    function testFluxUnderflow() public {
        vm.expectRevert(stdError.arithmeticError);
        usr1.flux(ILK, ausr1, ausr2, 100 * WAD);
    }

    function testMoveSelfOther() public {
        vat.suck(TEST_ADDRESS, ausr1, 100 * RAD);

        assertEq(vat.zar(ausr1), 100 * RAD);
        assertEq(vat.zar(ausr2), 0);

        vm.expectEmit(true, true, true, true);
        emit Move(ausr1, ausr2, 100 * RAD);
        usr1.move(ausr1, ausr2, 100 * RAD);

        assertEq(vat.zar(ausr1), 0);
        assertEq(vat.zar(ausr2), 100 * RAD);
    }

    function testMoveOtherSelf() public {
        vat.suck(TEST_ADDRESS, ausr1, 100 * RAD);

        assertEq(vat.zar(ausr1), 100 * RAD);
        assertEq(vat.zar(ausr2), 0);

        usr1.hope(ausr2);
        usr2.move(ausr1, ausr2, 100 * RAD);

        assertEq(vat.zar(ausr1), 0);
        assertEq(vat.zar(ausr2), 100 * RAD);
    }

    function testMoveOtherSelfNoPermission() public {
        vat.suck(TEST_ADDRESS, ausr1, 100 * RAD);

        assertEq(vat.zar(ausr1), 100 * RAD);
        assertEq(vat.zar(ausr2), 0);

        vm.expectRevert("Vat/not-allowed2");
        usr2.move(ausr1, ausr2, 100 * RAD);
    }

    function testMoveSelfSelf() public {
        vat.suck(TEST_ADDRESS, ausr1, 100 * RAD);

        assertEq(vat.zar(ausr1), 100 * RAD);

        usr1.move(ausr1, ausr1, 100 * RAD);

        assertEq(vat.zar(ausr1), 100 * RAD);
    }

    function testMoveUnderflow() public {
        vm.expectRevert(stdError.arithmeticError);
        usr1.move(ausr1, ausr2, 100 * RAD);
    }

    function testFrobNotInit() public {
        vm.expectRevert("Vat/ilk-not-init");
        usr1.frob(ILK, ausr1, ausr1, ausr1, 0, 0);
    }

    function testFrobMint() public setupCdpOps {
        assertEq(usr1.zar(), 0);
        assertEq(usr1.ink(ILK), 0);
        assertEq(usr1.art(ILK), 0);
        assertEq(usr1.gems(ILK), 100 * WAD);
        (uint256 Art,,,,) = vat.ilks(ILK);
        assertEq(Art, 0);

        vm.expectEmit(true, true, true, true);
        emit Frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));

        assertEq(usr1.zar(), 100 * RAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.gems(ILK), 0);
        (Art,,,,) = vat.ilks(ILK);
        assertEq(Art, 100 * WAD);
    }

    function testFrobRepay() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));

        assertEq(usr1.zar(), 100 * RAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.gems(ILK), 0);
        (uint256 Art,,,,) = vat.ilks(ILK);
        assertEq(Art, 100 * WAD);

        vm.expectEmit(true, true, true, true);
        emit Frob(ILK, ausr1, ausr1, ausr1, -int256(50 * WAD), -int256(50 * WAD));
        usr1.frob(ILK, ausr1, ausr1, ausr1, -int256(50 * WAD), -int256(50 * WAD));

        assertEq(usr1.zar(), 50 * RAD);
        assertEq(usr1.ink(ILK), 50 * WAD);
        assertEq(usr1.art(ILK), 50 * WAD);
        assertEq(usr1.gems(ILK), 50 * WAD);
        (Art,,,,) = vat.ilks(ILK);
        assertEq(Art, 50 * WAD);
    }

    function testFrobCannotExceedIlkCeiling() public setupCdpOps {
        vat.file(ILK, "line", 10 * RAD);

        vm.expectRevert("Vat/ceiling-exceeded");
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
    }

    function testFrobCannotExceedGlobalCeiling() public setupCdpOps {
        vat.file("Line", 10 * RAD);

        vm.expectRevert("Vat/ceiling-exceeded");
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
    }

    function testFrobNotSafe() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));

        assertEq(usr1.zar(), 100 * RAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.gems(ILK), 0);

        // Cannot mint one more ZAR it's undercollateralized
        vm.expectRevert("Vat/not-safe");
        usr1.frob(ILK, ausr1, ausr1, ausr1, 0, int256(1 * WAD));

        // Cannot remove even one ink or it's undercollateralized
        vm.expectRevert("Vat/not-safe");
        usr1.frob(ILK, ausr1, ausr1, ausr1, -int256(1 * WAD), 0);
    }

    function testFrobNotSafeLessRisky() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(50 * WAD), int256(50 * WAD));

        assertEq(usr1.zar(), 50 * RAD);
        assertEq(usr1.ink(ILK), 50 * WAD);
        assertEq(usr1.art(ILK), 50 * WAD);
        assertEq(usr1.gems(ILK), 50 * WAD);

        vat.file(ILK, "spot", RAY / 2); // Vault is underwater

        // Can repay debt even if it's undercollateralized
        usr1.frob(ILK, ausr1, ausr1, ausr1, 0, -int256(1 * WAD));

        assertEq(usr1.zar(), 49 * RAD);
        assertEq(usr1.ink(ILK), 50 * WAD);
        assertEq(usr1.art(ILK), 49 * WAD);
        assertEq(usr1.gems(ILK), 50 * WAD);

        // Can add gems even if it's undercollateralized
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(1 * WAD), 0);

        assertEq(usr1.zar(), 49 * RAD);
        assertEq(usr1.ink(ILK), 51 * WAD);
        assertEq(usr1.art(ILK), 49 * WAD);
        assertEq(usr1.gems(ILK), 49 * WAD);
    }

    function testFrobPermissionlessAddCollateral() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));

        assertEq(usr1.zar(), 100 * RAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.gems(ILK), 0);
        assertEq(usr2.gems(ILK), 100 * WAD);

        vm.expectEmit(true, true, true, true);
        emit Frob(ILK, ausr1, ausr2, TEST_ADDRESS, int256(100 * WAD), 0);
        usr2.frob(ILK, ausr1, ausr2, TEST_ADDRESS, int256(100 * WAD), 0);

        assertEq(usr1.zar(), 100 * RAD);
        assertEq(usr1.ink(ILK), 200 * WAD);
        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.gems(ILK), 0);
        assertEq(usr2.gems(ILK), 0);
    }

    function testFrobPermissionlessRepay() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
        vat.suck(TEST_ADDRESS, ausr2, 100 * RAD);

        assertEq(usr1.zar(), 100 * RAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.gems(ILK), 0);
        assertEq(usr2.zar(), 100 * RAD);

        vm.expectEmit(true, true, true, true);
        emit Frob(ILK, ausr1, TEST_ADDRESS, ausr2, 0, -int256(100 * WAD));
        usr2.frob(ILK, ausr1, TEST_ADDRESS, ausr2, 0, -int256(100 * WAD));

        assertEq(usr1.zar(), 100 * RAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr1.art(ILK), 0);
        assertEq(usr1.gems(ILK), 0);
        assertEq(usr2.zar(), 0);
    }

    function testFrobDusty() public setupCdpOps {
        vm.expectRevert("Vat/dust");
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(9 * WAD), int256(9 * WAD));
    }

    function testFrobOther() public setupCdpOps {
        // usr2 can completely manipulate usr1's vault with permission
        usr1.hope(ausr2);
        usr2.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
        usr2.frob(ILK, ausr1, ausr1, ausr1, -int256(50 * WAD), -int256(50 * WAD));
    }

    function testFrobNonOneRate() public setupCdpOps {
        vat.fold(ILK, TEST_ADDRESS, int256(1 * RAY / 10)); // 10% interest collected

        assertEq(usr1.zar(), 0);
        assertEq(usr1.ink(ILK), 0);
        assertEq(usr1.art(ILK), 0);
        assertEq(usr1.gems(ILK), 100 * WAD);
        (uint256 Art,,,,) = vat.ilks(ILK);
        assertEq(Art, 0);

        vm.expectEmit(true, true, true, true);
        emit Frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(90 * WAD));
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(90 * WAD));

        assertEq(usr1.zar(), 99 * RAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr1.art(ILK), 90 * WAD);
        assertEq(usr1.gems(ILK), 0);
        (Art,,,,) = vat.ilks(ILK);
        assertEq(Art, 90 * WAD);
    }

    function testForkSelfOther() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
        usr2.hope(ausr1);

        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr2.art(ILK), 0);
        assertEq(usr2.ink(ILK), 0);

        vm.expectEmit(true, true, true, true);
        emit Fork(ILK, ausr1, ausr2, int256(100 * WAD), int256(100 * WAD));
        usr1.fork(ILK, ausr1, ausr2, int256(100 * WAD), int256(100 * WAD));

        assertEq(usr1.art(ILK), 0);
        assertEq(usr1.ink(ILK), 0);
        assertEq(usr2.art(ILK), 100 * WAD);
        assertEq(usr2.ink(ILK), 100 * WAD);
    }

    function testForkSelfOtherNegative() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
        usr2.frob(ILK, ausr2, ausr2, ausr2, int256(100 * WAD), int256(100 * WAD));
        usr2.hope(ausr1);

        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr2.art(ILK), 100 * WAD);
        assertEq(usr2.ink(ILK), 100 * WAD);

        vm.expectEmit(true, true, true, true);
        emit Fork(ILK, ausr1, ausr2, -int256(100 * WAD), -int256(100 * WAD));
        usr1.fork(ILK, ausr1, ausr2, -int256(100 * WAD), -int256(100 * WAD));

        assertEq(usr1.art(ILK), 200 * WAD);
        assertEq(usr1.ink(ILK), 200 * WAD);
        assertEq(usr2.art(ILK), 0);
        assertEq(usr2.ink(ILK), 0);
    }

    function testForkSelfOtherNoPermission() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));

        vm.expectRevert("Vat/not-allowed3");
        usr1.fork(ILK, ausr1, ausr2, int256(100 * WAD), int256(100 * WAD));
    }

    function testForkOtherSelf() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
        usr1.hope(ausr2);

        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr2.art(ILK), 0);
        assertEq(usr2.ink(ILK), 0);

        vm.expectEmit(true, true, true, true);
        emit Fork(ILK, ausr1, ausr2, int256(100 * WAD), int256(100 * WAD));
        usr2.fork(ILK, ausr1, ausr2, int256(100 * WAD), int256(100 * WAD));

        assertEq(usr1.art(ILK), 0);
        assertEq(usr1.ink(ILK), 0);
        assertEq(usr2.art(ILK), 100 * WAD);
        assertEq(usr2.ink(ILK), 100 * WAD);
    }

    function testForkOtherSelfNegative() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
        usr2.frob(ILK, ausr2, ausr2, ausr2, int256(100 * WAD), int256(100 * WAD));
        usr1.hope(ausr2);

        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr2.art(ILK), 100 * WAD);
        assertEq(usr2.ink(ILK), 100 * WAD);

        vm.expectEmit(true, true, true, true);
        emit Fork(ILK, ausr1, ausr2, -int256(100 * WAD), -int256(100 * WAD));
        usr2.fork(ILK, ausr1, ausr2, -int256(100 * WAD), -int256(100 * WAD));

        assertEq(usr1.art(ILK), 200 * WAD);
        assertEq(usr1.ink(ILK), 200 * WAD);
        assertEq(usr2.art(ILK), 0);
        assertEq(usr2.ink(ILK), 0);
    }

    function testForkOtherSelfNoPermission() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));

        vm.expectRevert("Vat/not-allowed3");
        usr2.fork(ILK, ausr1, ausr2, int256(100 * WAD), int256(100 * WAD));
    }

    function testForkSelfSelf() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));

        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr2.art(ILK), 0);
        assertEq(usr2.ink(ILK), 0);

        vm.expectEmit(true, true, true, true);
        emit Fork(ILK, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
        usr1.fork(ILK, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));

        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        assertEq(usr2.art(ILK), 0);
        assertEq(usr2.ink(ILK), 0);
    }

    function testForkNotSafeSrc() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
        usr2.frob(ILK, ausr2, ausr2, ausr2, int256(100 * WAD), int256(100 * WAD));
        usr2.hope(ausr1);

        vat.file(ILK, "spot", RAY / 2); // Vaults are underwater

        vm.expectRevert("Vat/not-safe-src");
        usr1.fork(ILK, ausr1, ausr2, int256(20 * WAD), int256(20 * WAD));
    }

    function testForkNotSafeDst() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(50 * WAD));
        usr2.frob(ILK, ausr2, ausr2, ausr2, int256(100 * WAD), int256(100 * WAD));
        usr2.hope(ausr1);

        vat.file(ILK, "spot", RAY / 2); // usr2 vault is underwater

        vm.expectRevert("Vat/not-safe-dst");
        usr1.fork(ILK, ausr1, ausr2, int256(20 * WAD), int256(10 * WAD));
    }

    function testForkDustSrc() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
        usr2.frob(ILK, ausr2, ausr2, ausr2, int256(100 * WAD), int256(100 * WAD));
        usr2.hope(ausr1);

        vm.expectRevert("Vat/dust-src");
        usr1.fork(ILK, ausr1, ausr2, int256(95 * WAD), int256(95 * WAD));
    }

    function testForkDustDst() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
        usr2.frob(ILK, ausr2, ausr2, ausr2, int256(100 * WAD), int256(100 * WAD));
        usr2.hope(ausr1);

        vm.expectRevert("Vat/dust-dst");
        usr1.fork(ILK, ausr1, ausr2, -int256(95 * WAD), -int256(95 * WAD));
    }

    function testGrab() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));

        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        (uint256 Art,,,,) = vat.ilks(ILK);
        assertEq(Art, 100 * WAD);
        assertEq(usr2.gems(ILK), 100 * WAD);
        assertEq(vat.sin(TEST_ADDRESS), 0);
        assertEq(vat.vice(), 0);

        vm.expectEmit(true, true, true, true);
        emit Grab(ILK, ausr1, ausr2, TEST_ADDRESS, -int256(100 * WAD), -int256(100 * WAD));
        vat.grab(ILK, ausr1, ausr2, TEST_ADDRESS, -int256(100 * WAD), -int256(100 * WAD));

        assertEq(usr1.art(ILK), 0);
        assertEq(usr1.ink(ILK), 0);
        (Art,,,,) = vat.ilks(ILK);
        assertEq(Art, 0);
        assertEq(usr2.gems(ILK), 200 * WAD);
        assertEq(vat.sin(TEST_ADDRESS), 100 * RAD);
        assertEq(vat.vice(), 100 * RAD);
    }

    function testGrabPartial() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));

        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        (uint256 Art,,,,) = vat.ilks(ILK);
        assertEq(Art, 100 * WAD);
        assertEq(usr2.gems(ILK), 100 * WAD);
        assertEq(vat.sin(TEST_ADDRESS), 0);
        assertEq(vat.vice(), 0);

        vm.expectEmit(true, true, true, true);
        emit Grab(ILK, ausr1, ausr2, TEST_ADDRESS, -int256(50 * WAD), -int256(50 * WAD));
        vat.grab(ILK, ausr1, ausr2, TEST_ADDRESS, -int256(50 * WAD), -int256(50 * WAD));

        assertEq(usr1.art(ILK), 50 * WAD);
        assertEq(usr1.ink(ILK), 50 * WAD);
        (Art,,,,) = vat.ilks(ILK);
        assertEq(Art, 50 * WAD);
        assertEq(usr2.gems(ILK), 150 * WAD);
        assertEq(vat.sin(TEST_ADDRESS), 50 * RAD);
        assertEq(vat.vice(), 50 * RAD);
    }

    function testGrabPositive() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
        vat.suck(TEST_ADDRESS, TEST_ADDRESS, 100 * RAD);

        assertEq(usr1.art(ILK), 100 * WAD);
        assertEq(usr1.ink(ILK), 100 * WAD);
        (uint256 Art,,,,) = vat.ilks(ILK);
        assertEq(Art, 100 * WAD);
        assertEq(usr2.gems(ILK), 100 * WAD);
        assertEq(vat.sin(TEST_ADDRESS), 100 * RAD);
        assertEq(vat.vice(), 100 * RAD);

        vm.expectEmit(true, true, true, true);
        emit Grab(ILK, ausr1, ausr2, TEST_ADDRESS, int256(100 * WAD), int256(100 * WAD));
        vat.grab(ILK, ausr1, ausr2, TEST_ADDRESS, int256(100 * WAD), int256(100 * WAD));

        assertEq(usr1.art(ILK), 200 * WAD);
        assertEq(usr1.ink(ILK), 200 * WAD);
        (Art,,,,) = vat.ilks(ILK);
        assertEq(Art, 200 * WAD);
        assertEq(usr2.gems(ILK), 0);
        assertEq(vat.sin(TEST_ADDRESS), 0);
        assertEq(vat.vice(), 0);
    }

    function testHeal() public {
        vat.suck(ausr1, ausr1, 100 * RAD);

        assertEq(usr1.sin(), 100 * RAD);
        assertEq(usr1.zar(), 100 * RAD);
        assertEq(vat.vice(), 100 * RAD);
        assertEq(vat.debt(), 100 * RAD);

        vm.expectEmit(true, true, true, true);
        emit Heal(100 * RAD);
        usr1.heal(100 * RAD);

        assertEq(usr1.sin(), 0);
        assertEq(usr1.zar(), 0);
        assertEq(vat.vice(), 0);
        assertEq(vat.debt(), 0);
    }

    function testSuck() public {
        assertEq(usr1.sin(), 0);
        assertEq(usr2.zar(), 0);
        assertEq(vat.vice(), 0);
        assertEq(vat.debt(), 0);

        vm.expectEmit(true, true, true, true);
        emit Suck(ausr1, ausr2, 100 * RAD);
        vat.suck(ausr1, ausr2, 100 * RAD);

        assertEq(usr1.sin(), 100 * RAD);
        assertEq(usr2.zar(), 100 * RAD);
        assertEq(vat.vice(), 100 * RAD);
        assertEq(vat.debt(), 100 * RAD);
    }

    function testFold() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));

        (uint256 Art, uint256 rate,,,) = vat.ilks(ILK);
        assertEq(Art, 100 * WAD);
        assertEq(rate, RAY);
        assertEq(vat.zar(TEST_ADDRESS), 0);
        assertEq(vat.debt(), 100 * RAD);

        vm.expectEmit(true, true, true, true);
        emit Fold(ILK, TEST_ADDRESS, int256(1 * RAY / 10));
        vat.fold(ILK, TEST_ADDRESS, int256(1 * RAY / 10)); // 10% interest collected

        (Art, rate,,,) = vat.ilks(ILK);
        assertEq(Art, 100 * WAD);
        assertEq(rate, 11 * RAY / 10);
        assertEq(vat.zar(TEST_ADDRESS), 10 * RAD);
        assertEq(vat.debt(), 110 * RAD);
    }

    function testFoldNegative() public setupCdpOps {
        usr1.frob(ILK, ausr1, ausr1, ausr1, int256(100 * WAD), int256(100 * WAD));
        vat.fold(ILK, TEST_ADDRESS, int256(1 * RAY / 10));

        (uint256 Art, uint256 rate,,,) = vat.ilks(ILK);
        assertEq(Art, 100 * WAD);
        assertEq(rate, 11 * RAY / 10);
        assertEq(vat.zar(TEST_ADDRESS), 10 * RAD);
        assertEq(vat.debt(), 110 * RAD);

        vm.expectEmit(true, true, true, true);
        emit Fold(ILK, TEST_ADDRESS, -int256(1 * RAY / 20));
        vat.fold(ILK, TEST_ADDRESS, -int256(1 * RAY / 20)); // -5% interest collected

        (Art, rate,,,) = vat.ilks(ILK);
        assertEq(Art, 100 * WAD);
        assertEq(rate, 21 * RAY / 20);
        assertEq(vat.zar(TEST_ADDRESS), 5 * RAD);
        assertEq(vat.debt(), 105 * RAD);
    }
}
