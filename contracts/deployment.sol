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

import {Auth, Authority} from "./auth/auth.sol";

import {Vat} from "./system/vat.sol";
import {Jug} from "./system/jug.sol";
import {Vow} from "./system/vow.sol";
import {Dog} from "./system/dog.sol";

import {ZarJoin} from "./system/join.sol";
import {Clipper} from "./system/clip.sol";
import {LinearDecrease, StairstepExponentialDecrease, ExponentialDecrease} from "./system/abaci.sol";
import {Zar} from "./system/zar.sol";
import {End} from "./system/end.sol";
import {Spotter} from "./system/spot.sol";

contract VatFab {
    function newVat(address owner) public returns (Vat vat) {
        vat = new Vat();
        vat.rely(owner);
        vat.deny(address(this));
    }
}

contract JugFab {
    function newJug(address owner, address vat) public returns (Jug jug) {
        jug = new Jug(vat);
        jug.rely(owner);
        jug.deny(address(this));
    }
}

contract VowFab {
    function newVow(address owner, address vat) public returns (Vow vow) {
        vow = new Vow(vat);
        vow.rely(owner);
        vow.deny(address(this));
    }
}

contract DogFab {
    function newDog(address owner, address vat) public returns (Dog dog) {
        dog = new Dog(vat);
        dog.rely(owner);
        dog.deny(address(this));
    }
}

contract ZarFab {
    function newZar(address owner) public returns (Zar zar) {
        zar = new Zar();
        zar.rely(owner);
        zar.deny(address(this));
    }
}

contract ZarJoinFab {
    function newZarJoin(address vat, address zar) public returns (ZarJoin zarJoin) {
        zarJoin = new ZarJoin(vat, zar);
    }
}

contract ClipFab {
    function newClip(address owner, address vat, address spotter, address dog, bytes32 ilk)
        public
        returns (Clipper clip)
    {
        clip = new Clipper(vat, spotter, dog, ilk);
        clip.rely(owner);
        clip.deny(address(this));
    }
}

contract CalcFab {
    function newLinearDecrease(address owner) public returns (LinearDecrease calc) {
        calc = new LinearDecrease();
        calc.rely(owner);
        calc.deny(address(this));
    }

    function newStairstepExponentialDecrease(address owner) public returns (StairstepExponentialDecrease calc) {
        calc = new StairstepExponentialDecrease();
        calc.rely(owner);
        calc.deny(address(this));
    }

    function newExponentialDecrease(address owner) public returns (ExponentialDecrease calc) {
        calc = new ExponentialDecrease();
        calc.rely(owner);
        calc.deny(address(this));
    }
}

contract SpotFab {
    function newSpotter(address owner, address vat) public returns (Spotter spotter) {
        spotter = new Spotter(vat);
        spotter.rely(owner);
        spotter.deny(address(this));
    }
}


contract EndFab {
    function newEnd(address owner) public returns (End end) {
        end = new End();
        end.rely(owner);
        end.deny(address(this));
    }
}


contract Deployment is Auth {
    VatFab public vatFab;
    JugFab public jugFab;
    VowFab public vowFab;
    DogFab public dogFab;
    ZarFab public zarFab;
    ZarJoinFab public zarJoinFab;
    ClipFab public clipFab;
    CalcFab public calcFab;
    SpotFab public spotFab;
    EndFab public endFab;

    Vat public vat;
    Jug public jug;
    Vow public vow;
    Dog public dog;
    Zar public zar;
    ZarJoin public zarJoin;
    Spotter public spotter;
    End public end;

    mapping(bytes32 => Ilk) public ilks;

    uint8 public step = 0;

    uint256 constant ONE = 10 ** 27;

    struct Ilk {
        Clipper clip;
        address join;
    }

    function addFabs1(
        VatFab vatFab_,
        JugFab jugFab_,
        VowFab vowFab_,
        DogFab dogFab_,
        ZarFab zarFab_,
        ZarJoinFab zarJoinFab_
    ) public auth {
        require(address(vatFab) == address(0), "Fabs 1 already saved");
        vatFab = vatFab_;
        jugFab = jugFab_;
        vowFab = vowFab_;
        dogFab = dogFab_;
        zarFab = zarFab_;
        zarJoinFab = zarJoinFab_;
    }

    function addFabs2(
        ClipFab clipFab_,
        CalcFab calcFab_,
        SpotFab spotFab_,
        EndFab endFab_
    ) public auth {
        require(address(clipFab) == address(0), "Fabs 2 already saved");
        clipFab = clipFab_;
        calcFab = calcFab_;
        spotFab = spotFab_;
        endFab = endFab_;
    }

    function rad(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 27;
    }

    function deployVat() public auth {
        require(address(vatFab) != address(0), "Missing Fabs 1");
        require(address(vat) == address(0), "VAT already deployed");
        vat = vatFab.newVat(address(this));
        spotter = spotFab.newSpotter(address(this), address(vat));

        // Internal auth
        vat.rely(address(spotter));
    }

    function deployZar() public auth {
        require(address(vat) != address(0), "Missing previous step");

        zar = zarFab.newZar(address(this));
        zarJoin = zarJoinFab.newZarJoin(address(vat), address(zar));
        zar.rely(address(zarJoin));
    }

    function deployTaxation() public auth {
        require(address(vat) != address(0), "Missing previous step");

        // Deploy
        jug = jugFab.newJug(address(this), address(vat));

        // Internal auth
        vat.rely(address(jug));
    }

    function deployAuctions(address gov) public auth {
        require(gov != address(0), "Missing GOV address");
        require(address(jug) != address(0), "Missing previous step");

        // Deploy
        vow = vowFab.newVow(address(this), address(vat));

        // Internal references set up
        jug.file("vow", address(vow));
    }

    function deployLiquidator() public auth {
        require(address(vow) != address(0), "Missing previous step");

        // Deploy
        dog = dogFab.newDog(address(this), address(vat));

        // Internal references set up
        dog.file("vow", address(vow));

        // Internal auth
        vat.rely(address(dog));
        vow.rely(address(dog));
    }

    function deployEnd() public auth {
        // Deploy
        end = endFab.newEnd(address(this));

        // Internal references set up
        end.file("vat", address(vat));
        end.file("dog", address(dog));
        end.file("vow", address(vow));
        end.file("spot", address(spotter));

        // Internal auth
        vat.rely(address(end));
        dog.rely(address(end));
        vow.rely(address(end));
        spotter.rely(address(end));
    }

    function relyAuthority(address authority) public auth {
        require(address(zar) != address(0), "Missing previous step");
        require(address(end) != address(0), "Missing previous step");

        vat.rely(authority);
        dog.rely(authority);
        vow.rely(authority);
        jug.rely(authority);
        spotter.rely(authority);
        end.rely(authority);
    }

    function deployCollateralClip(bytes32 ilk, address join, address pip, address calc, address authority)
        public
        auth
    {
        require(ilk != bytes32(""), "Missing ilk name");
        require(join != address(0), "Missing join address");
        require(pip != address(0), "Missing pip address");

        // Deploy
        ilks[ilk].clip = clipFab.newClip(address(this), address(vat), address(spotter), address(dog), ilk);
        ilks[ilk].join = join;
        Spotter(spotter).file(ilk, "pip", address(pip)); // Set pip

        // Internal references set up
        dog.file(ilk, "clip", address(ilks[ilk].clip));
        ilks[ilk].clip.file("vow", address(vow));

        // Use calc with safe default if not configured
        if (calc == address(0)) {
            calc = address(calcFab.newLinearDecrease(address(this)));
            LinearDecrease(calc).file(bytes32("tau"), 1 hours);
        }
        ilks[ilk].clip.file("calc", calc);
        vat.init(ilk);
        jug.init(ilk);

        // Internal auth
        vat.rely(join);
        vat.rely(address(ilks[ilk].clip));
        dog.rely(address(ilks[ilk].clip));
        ilks[ilk].clip.rely(address(dog));
        ilks[ilk].clip.rely(address(end));
        ilks[ilk].clip.rely(authority);
    }

    function releaseAuth() public auth {
        vat.deny(address(this));
        dog.deny(address(this));
        vow.deny(address(this));
        jug.deny(address(this));
        zar.deny(address(this));
        spotter.deny(address(this));
        end.deny(address(this));
    }

    function releaseAuthClip(bytes32 ilk) public auth {
        ilks[ilk].clip.deny(address(this));
    }
}
