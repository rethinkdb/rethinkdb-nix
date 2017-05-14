{ lib, sourcePrep, mkFetch }:
with lib;

rec {
  debBuildDeps = [
    "build-essential" "protobuf-compiler" "python"
    "libprotobuf-dev" "libcurl4-openssl-dev"
    "libboost-dev" "libncurses5-dev"
    "libjemalloc-dev" "wget" "m4"
    "libssl-dev"
    "devscripts" "debhelper" "fakeroot"
  ];

  rpmExtraRepos = {
    centos6 = arch: {
      url = "http://linuxsoft.cern.ch/cern/devtoolset/slc6X/${arch}/yum/devtoolset/repodata/primary.xml.gz";
      prefix = "http://linuxsoft.cern.ch/cern/devtoolset/slc6X/${arch}/yum/devtoolset";
      hash = getAttr arch {
	i686 = "0m6wkm96435j4226cgf3x0p7z6gmdjgw3mrd2ybd4s5v3w648sgx";
	x86_64 = "0zp7q8aayjk677d40hxby0lz2zwd2jwifz8jca4pli2k5gv4mbj5";
      };
    };
    centos7 = {
      url = "https://dl.fedoraproject.org/pub/epel/7/x86_64/repodata/8b36e7f48bd4a63b0b5a4be88c0202a35d2092a753ac887035c47aa5769317ad-primary.xml.gz";
      prefix = "https://dl.fedoraproject.org/pub/epel/7/x86_64";
      hash = "1b8pjdvaayn46mq8ib2kly920pd30818rs2bb85kp9nligsffdlb";
    };
  };

  rpmBuildDeps = rec {
    common = [ "tar" "which" "m4" ];
    centos6 = common ++ [ "devtoolset-2" ];
    centos7 = common ++ [
      # centos
      "git" "gcc-c++" "ncurses-devel" "make" "ncurses-static" "zlib-devel" "zlib-static" "boost-static"
      # epel
      "protobuf-devel" "protobuf-static" "jemalloc-devel"
    ];
  };

  vmBuild = { diskImage, name, build, attrs ? {}, ncpu ? 6, memSize ? 4096 }:
    pkgs.vmTools.runInLinuxImage ((derivation (rec {
      inherit name memSize;
      builder = "${pkgs.bash}/bin/bash";
      system = builtins.currentSystem;
      args = [ (toFile "builder.sh" (''
        set -ex
        PATH=/usr/bin:/bin:/usr/sbin:/sbin
        '' + build)) ];
      QEMU_OPTS = "-smp ${toString ncpu}";
    } // attrs)) // {
      inherit diskImage;
    });

  # TODO: remove when accepted upstream: https://github.com/NixOS/nixpkgs/pull/22009
  customDebDistros = with pkgs; with vmTools; with debDistros; debDistros // {
    ubuntu1610i386 = {
      name = "ubuntu-16.10-yakkety-i386";
      fullName = "Ubuntu 16.10 Yakkety (i386)";
      packagesLists = [
	(fetchurl {
	   url = mirror://ubuntu/dists/yakkety/main/binary-i386/Packages.xz;
           sha256 = "13r75sp4slqy8w32y5dnr7pp7p3cfvavyr1g7gwnlkyrq4zx4ahy";
        })
        (fetchurl {
          url = mirror://ubuntu/dists/yakkety/universe/binary-i386/Packages.xz;
          sha256 = "14fid1rqm3sc0wlygcvn0yx5aljf51c2jpd4x0zxij4019316hsh";
        })
      ];
      urlPrefix = mirror://ubuntu;
      packages = commonDebPackages ++ [ "diffutils" "libc-bin" ];
    };
    ubuntu1610x86_64 = {
      name = "ubuntu-16.10-yakkety-amd64";
      fullName = "Ubuntu 16.10 Yakkety (amd64)";
      packagesList = [
        (fetchurl {
          url = mirror://ubuntu/dists/yakkety/main/binary-amd64/Packages.xz;
          sha256 = "1lg3s8fhip14k423k5scn9iqya775sr7ikbkqisppxypn3x4qv1m";
        })
        (fetchurl {
          url = mirror://ubuntu/dists/yakkety/universe/binary-amd64/Packages.xz;
          sha256 = "1rjpa3miq28p9ag05l9k9w5sr1skkcjwca4k7f79gmpzzvw609m7";
        })
      ];
      urlPrefix = mirror://ubuntu;
      packages = commonDebPackages ++ [ "diffutils" "libc-bin" ];
    };
    ubuntu1704i386 = {
          name = "ubuntu-17.04-zesty-i386";
	  fullName = "Ubuntu 17.04 Zesty (i386)";
	  packagesLists =
	  [ (fetchurl {
	      url = mirror://ubuntu/dists/zesty/main/binary-i386/Packages.xz;
 	      sha256 = "1794y32k29p9w6cyg6nvyz7yyxbyd2az31zxxvg1pjn5n244vbhk";
	  })
	    (fetchurl {
		url = mirror://ubuntu/dists/zesty/universe/binary-i386/Packages.xz;
		sha256 = "0lw1rrjfladxxarffmhkqigd126736iw6i4kxkdbxqp0sj5x6gw8";
	    })
	  ];
	  urlPrefix = mirror://ubuntu;
	  packages = commonDebPackages ++ [ "diffutils" "libc-bin" ];
    };
    ubuntu1704x86_64 = {
        name = "ubuntu-17.04-zesty-amd64";
	fullName = "Ubuntu 17.04 Zesty (amd64)";
	packagesList =
	[ (fetchurl {
	    url = mirror://ubuntu/dists/zesty/main/binary-amd64/Packages.xz;
	    sha256 = "1fs0v6w831hlizzcri6dd08dbbrq7nmhzbw0a699ypdyy72cglk6";
	})
	  (fetchurl {
	      url = mirror://ubuntu/dists/zesty/universe/binary-amd64/Packages.xz;
	      sha256 = "10rwysnwpz225xxjkl58maflqgykqi1rlrm0h0w5bis86jwp59ph";
	  })
	];
	urlPrefix = mirror://ubuntu;
	packages = commonDebPackages ++ [ "diffutils" "libc-bin" ];
    };
    debian8i386 = debian8i386 // {
      packagesList = fetchurl {
        url = "mirror://debian/dists/jessie/main/binary-i386/Packages.xz";
        sha256 = "1s1z7dp93lz8gxzfrvc7avczhv43r75mq8gdlmkjxay49n9wpjki";
      };
    };
    debian8x86_64 = debian8x86_64 // {
      packagesList = fetchurl {
        url = "mirror://debian/dists/jessie/main/binary-amd64/Packages.xz";
        sha256 = "1wqp9a44i65434ik04r536lk6vsv7wbhl3yh4qbww18zyfpbmkxl";
      };
    };
    debian9x86_64 = {
      name = "debian-stretch-amd64";
      fullName = "Debian Stretch (amd64)";
      packagesList = fetchurl {
        url = mirror://debian/dists/stretch/main/binary-amd64/Packages.xz;
 	sha256 = "1ihfcrrjz2nwh5wxa8b90m24b5z7q5p1h2ydfg9f1b6pdk81f6ji";
      };
      urlPrefix = mirror://debian;
      packages = commonDebianPackages;
    };
    debian9i386 = {
      name = "debian-stretch-i386";
      fullName = "Debian Stretch (i386)";
      packagesList = fetchurl {
        url = mirror://debian/dists/stretch/main/binary-i386/Packages.xz;
 	sha256 = "08gikw2pfm76fdl14b6sjx07dwp70ycgdj3zir296b7xrwiymima";
      };
      urlPrefix = mirror://debian;
      packages = commonDebianPackages;
    };
  };

  addRPMRepo = repo: distro: distro // {
    packagesLists = (distro.packagesLists or [ distro.packagesList ]) ++ [ (
      pkgs.fetchurl {
	url = repo.url;
	sha256 = repo.hash;
      }
    ) ];
    urlPrefixes = (distro.urlPrefixes or [ distro.urlPrefix ]) ++ [ repo.prefix ];
  };
  customRpmDistros = with pkgs; with vmTools; with rpmDistros; rpmDistros // {
    centos65i386 = addRPMRepo (rpmExtraRepos.centos6 "i686") centos65i386;
    centos65x86_64 = addRPMRepo (rpmExtraRepos.centos6 "x86_64") centos65x86_64;
    centos71x86_64 = addRPMRepo rpmExtraRepos.centos7 centos71x86_64;
  };

  # copied from nixpkgs
  diskImageFuns =
    (pkgs.lib.mapAttrs (name: as: as2: pkgs.vmTools.makeImageFromDebDist (as // as2)) customDebDistros)
    // (pkgs.lib.mapAttrs (name: as: as2: pkgs.vmTools.makeImageFromRPMDist (as // as2)) customRpmDistros);

  debs = with diskImageFuns;
    listToAttrs (concatLists (for [
      { name = "zesty";
        b64 = ubuntu1704x86_64;
	b32 = ubuntu1704i386;
	extra = [ "gcc-5" "g++-5" ]; }
      { name = "yakkety";
        b64 = ubuntu1610x86_64;
	b32 = ubuntu1610i386;
	extra = [ "gcc-5" "g++-5" ]; }
      { name = "xenial";
        b64 = ubuntu1604x86_64;
	b32 = ubuntu1604i386; }
      { name = "wily";
	b64 = ubuntu1510x86_64;
	b32 = ubuntu1510i386; }
      { name = "vivid";
	b64 = ubuntu1504x86_64;
	b32 = ubuntu1504i386; }
      { name = "utopic";
	b64 = ubuntu1410x86_64;
	b32 = ubuntu1410i386; }
      { name = "trusty";
	b64 = ubuntu1404x86_64;
	b32 = ubuntu1404i386; }
      { name = "saucy";
	b64 = ubuntu1310x86_64;
	b32 = ubuntu1310i386; }
      { name = "jessie";
	b64 = debian8x86_64;
	b32 = debian8i386; }
      { name = "stretch";
	b64 = debian9x86_64;
	b32 = debian9i386; }
    ] ({ name, b64, b32, extra ? [] }: let
      dsc = vmBuild {
        name = "rethinkdb-${sourcePrep.version}-${name}-src";
        attrs = { src = sourcePrep; };
        build = ''
          cp -r $src rethinkdb
          cd rethinkdb
          ./configure

          make -j 6 build-deb-src UBUNTU_RELEASE=${name} SIGN_PACKAGE=0
          cp build/packages/*.{dsc,build,changes,tar.?z} $out
          mkdir $out/nix-support
          for p in $out/*.*; do
            echo file deb-source "$p" >> $out/nix-support/hydra-build-products
          done
        '';
        memSize = 4096;
        diskImage = b64 { extraPackages = debBuildDeps ++ extra; };
      };
      deb = arch: diskImage: vmBuild {
        name = replace "-src$" "-${arch}" dsc.name;
        attrs = { src = dsc; };
	build = ''
          PATH=/usr/bin:/bin:/usr/sbin:/sbin
          mkdir /build
          dpkg-source -x $src/*.dsc /build/source
          cd /build/source
          debuild -b -us -uc -j6
          cp ../*.deb $out
          mkdir $out/nix-support
          for deb in $out/*.deb; do
            echo file deb "$deb" >> $out/nix-support/hydra-build-products
          done
        '';
        memSize = 8192;
        diskImage = diskImage {extraPackages = debBuildDeps ++ extra; };
      };
    in [
      { name = "${name}-src"; value = dsc; }
      { name = "${name}-i386"; value = deb "i386" b32; }
      { name = "${name}-amd64"; value = deb "amd64" b64; }
    ])));

  rpms = with diskImageFuns;
    listToAttrs (for [
      { name = "centos7";
	arch = "x86_64";
        image = centos71x86_64; }
      { name = "centos6";
	arch = "x86_64";
        image = centos65x86_64;
	extraFetch = ["protobuf" "jemalloc" "boost"]; }
      # TODO: build fails with "package bzip2 doesn't exist"
      # { name = "centos6";
      # 	arch = "i386";
      #   image = centos65i386; }
    ] ({ name, arch, image, extraFetch ? [] }: let
      fetchList = [ "openssl" "curl" "libidn" "zlib" ] ++ extraFetch;
      rpm = vmBuild {
        name = "rethinkdb-${sourcePrep.version}-${name}-${arch}";
        attrs = {
	  src = sourcePrep;
	  fpm = pkgs.fpm;
          fetched = mkFetch fetchList;
	};
	build = ''
          PATH=$fpm/bin:/usr/bin:/bin:/usr/sbin:/sbin
          ${if name == "centos6" then "source /opt/rh/devtoolset-2/enable" else ""}
	  cp -r $src /build
          cp -r $fetched/* /build/
          cd /build

          # TODO: conditionally `--fetch all' upstream
          # TODO: centos is missing krb5-static: https://bugzilla.redhat.com/show_bug.cgi?id=838782
          ./configure --static all --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
	      ${concatStringsSep " " (map (d: "--fetch ${d}") fetchList)}
	  export NOCONFIGURE=1

          scripts/build-rpm.sh
	  cp build/release/rethinkdb.debug build/packages/rethinkdb*.rpm $out
          mkdir $out/nix-support
          echo file debug-symbols $out/rethinkdb.debug >> $out/nix-support/hydra-build-products
          for rpm in $out/*.rpm; do
            echo file rpm "$rpm" >> $out/nix-support/hydra-build-products
          done
        '';
        memSize = 8192;
        diskImage = image { extraPackages = getAttr name rpmBuildDeps; size = 8192; };
      };
  in { name = "${name}-${arch}"; value = rpm; }));

}
