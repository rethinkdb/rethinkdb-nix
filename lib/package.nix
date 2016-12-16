with import ./prelude.nix;
with { inherit (import ./source.nix) sourcePrep mkFetch; };
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
    common = [ "boost-static" "tar" "which" "m4" ];
    centos6 = common ++ [ "devtoolset-2" ];
    centos7 = common ++ [
      # centos
      "git" "gcc-c++" "ncurses-devel" "make" "ncurses-static" "zlib-devel" "zlib-static"
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

  # TODO: move missing distros upstream
  customDebDistros = with pkgs; with vmTools; with debDistros; debDistros // {
    ubuntu1610i386 = {
      name = "ubuntu-16.10-yakkety-i386";
      fullName = "Ubuntu 16.10 Yakkety (i386)";
      packagesLists = [
	(fetchurl {
	   url = mirror://ubuntu/dists/yakkety/main/binary-i386/Packages.xz;
           sha256 = "13r75sp4slqy8w32y5dnr7pp7p3cfvavyr1g7gwnlkyrq4zx4ahy"; # TODO
        })
        (fetchurl {
          url = mirror://ubuntu/dists/yakkety/universe/binary-i386/Packages.xz;
          sha256 = "14fid1rqm3sc0wlygcvn0yx5aljf51c2jpd4x0zxij4019316hsh"; # TODO
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
      { name = "yakkety";
        b64 = ubuntu1610x86_64;
	b32 = ubuntu1610i386; }
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
    ] ({ name, b64, b32, extra ? [] }: let
      dsc = vmBuild {
        name = "rethinkdb-${sourcePrep.version}-${name}-src";
        attrs = { src = sourcePrep; };
        build = ''
          cp -r $src rethinkdb
          cd rethinkdb
          ./configure

          # TODO: upstream add -w to *.pb.cc build rule
          ${if name == "yakkety" then "sed -i 's/^ALLOW_WARNINGS.*/ALLOW_WARNINGS = 1/' mk/defaults.mk" else ""}

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
        image = centos65x86_64; }
      # TODO: build fails with "package bzip2 doesn't exist"
      # { name = "centos6";
      # 	arch = "i386";
      #   image = centos65i386; }
    ] ({ name, arch, image, extra ? [] }: let
      rpm = vmBuild {
        name = "rethinkdb-${sourcePrep.version}-${name}-${arch}";
        attrs = {
	  src = sourcePrep;
	  fpm = pkgs.fpm;
          extraFetched = mkFetch [ "openssl" "curl" "libidn" "zlib" ];
	};
	build = ''
          PATH=$fpm/bin:/usr/bin:/bin:/usr/sbin:/sbin
	  cp -r $src /build
          cp -r $extraFetched/* /build/
          cd /build

          # TODO: conditionally `--fetch all' upstream
          # TODO: centos is missing krb5-static: https://bugzilla.redhat.com/show_bug.cgi?id=838782
          ./configure --static all --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
              --fetch openssl --fetch crypto --fetch curl --fetch zlib --fetch libidn
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
        diskImage = image { extraPackages = getAttr name rpmBuildDeps; };
      };
  in { name = "${name}-${arch}"; value = rpm; }));

}
