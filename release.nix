with rec {
  inherit (builtins)
    toFile readFile concatStringsSep unsafeDiscardStringContext
    listToAttrs match head tail toJSON toPath elemAt getAttr length
    trace genList isString fromJSON getEnv concatLists toString;
  foldl = builtins.foldl'; #'
  tracing = x: trace x x;
  for = xs: f: map f xs;
  pkgs = import <nixpkgs> {};
};
let
  mkBuilder = script: toFile "builder.sh" ("source $stdenv/setup\n" + script);

  scripts = concatStringsSep " " [
    "configure" "drivers/convert_protofile" "scripts/gen-version.sh"
    "mk/support/pkg/pkg.sh" "test/run" "external/v8_*/build/gyp/gyp"
  ];
  patchScripts = ''
    for script in ${scripts}; do
      cp $script $script.orig
      patchShebangs $script
    done
  '';
  unpatchScripts = dest: ''
    for script in ${scripts}; do
      test ! -e $script.orig || cp $script.orig ${dest}/$script
    done
    '';

  make = "make -j $NIX_BUILD_CORES -l $NIX_BUILD_CORES";

  skip_tests = [
    # known failures (TODO: fix upstream)
    # "unit.RDBBtree"
    "unit.UtilsTest"
    "unit.RDBProtocol"
    "unit.RDBBtree"
    # Slow tests
    "unit.DiskBackedQueue"
  ];
  skip_tests_filter =
      concatStringsSep " " (map (t: "'!" + t + "'") skip_tests);

  versionFile = pkgs.stdenv.mkDerivation {
    name = "rethinkdb-version";
    src = <rethinkdb>;
    buildInputs = [ pkgs.git ];
    builder = mkBuilder ''
      cd $src
      echo -n $(bash scripts/gen-version.sh) > $out
    '';
  };

  replace = pattern: replacement: string:
    let group = match "(.*)(${pattern})(.*)" string;
    in if group == null then string else
      replace pattern replacement (elemAt group 0)
      + (if isString replacement then replacement
         else replacement (genList (i: elemAt group (i + 2)) (length group - 3)))
      + elemAt group (length group - 1);

  depInfo = dep: let
    source = readFile (toPath "${<rethinkdb>}/mk/support/pkg/${dep}.sh");
    find = var: let go = source: val:
      let group = match "(.*?)\n *${var}=([^\n]*)\n.*" source;
      in if group == null then val else go (head group) (elemAt group 1);
    in go source null;
  in rec {
    version = replace "/-patched.*/" "" (find "version");
    url = replace "\\$\\{?version([^}]*})?" version (find "src_url");
    sha1 = find "src_url_sha1";
  };

  mkFetch = fetch_list: pkgs.stdenv.mkDerivation (rec {
    name = "rethinkdb-dependencies-src";
    builder = mkBuilder ("mkdir $out\n" +
      concatStringsSep "\n"
        (map (dep: "cp -r --no-preserve=all ${"$"}${dep}/* $out/") fetch_list));
    buildInputs = [ <rethinkdb> ];
  } // listToAttrs (map (dep: let info = depInfo dep; in {
    name = dep;
    value = pkgs.stdenv.mkDerivation {
      name = "rethinkdb-fetch-${dep}-${info.version}";
      src = pkgs.fetchurl {
        url = info.url;
        sha1 = info.sha1;
      };
      builder = mkBuilder ''
        mkdir -p $out/external/.cache
        ln -s $src $out/external/.cache/''${src#*-}
      '';
    };
  }) fetch_list));

  fetchList = ["v8" "jemalloc"];

  fetchDependencies = mkFetch fetchList;

  debBuildDeps = [
    "build-essential" "protobuf-compiler" "python"
    "libprotobuf-dev" "libcurl4-openssl-dev"
    "libboost-dev" "libncurses5-dev"
    "libjemalloc-dev" "wget" "m4"
    "libssl-dev"
    "devscripts" "debhelper" "fakeroot"
  ];

  sourcePrep = pkgs.stdenv.mkDerivation rec {
    name = "rethinkdb-${version}";
    version = unsafeDiscardStringContext (readFile versionFile);
    builder = mkBuilder ''

      # TODO: https://github.com/NixOS/nixpkgs/issues/13744
      export SSL_CERT_FILE=$cacert/etc/ssl/certs/ca-bundle.crt

      mkdir rethinkdb
      cp -r $src/* rethinkdb/
      chmod -R u+w rethinkdb
      cd rethinkdb

      # TODO: move upstream
      sed -i 's/reset-dist-dir: FORCE | web-assets/reset-dist-dir: FORCE/' mk/packaging.mk
      sed -i 's/install: build/install:/' packaging/debian/rules

      echo "${version}" > VERSION.OVERRIDE
      cp -r --no-preserve=all $fetchDependencies/* .
      ${patchScripts}
      ./configure --fetch jemalloc
      ${make} dist-dir DIST_DIR=$out
      ${unpatchScripts "$out"}
    '';
    __noChroot = true;
    src = <rethinkdb>;
    inherit fetchDependencies;
    buildInputs = with pkgs; [
      protobuf
      python
      nodejs
      nodePackages.coffee-script
      nodePackages.browserify
      zlib
      openssl
      curl
      boost
      git
      cacert
      nix
    ];
  };

  fastTests = pkgs.stdenv.mkDerivation rec {
    name = "rethinkdb-fast-tests-results-${src.version}";
    src = sourcePrep;
    buildInputs = with pkgs; [
      protobuf
      python27Full
      nodejs
      nodePackages.coffee-script
      nodePackages.browserify
      zlib
      openssl
      boost
      curl
    ];
    builder = mkBuilder ''
      cp -r $src/* .
      chmod -R u+w .
      ${patchScripts}
      ./configure
      ${make} DEBUG=1
      test/run -j $NIX_BUILD_CORES '!long' ${skip_tests_filter} || :
      test -e test/results/*/test_results.html
      cp test/results/* $out
      echo report test_results $out/*/test_results.html > $out/nix-support/hydra-build-products
    '';
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

  debs = with pkgs.vmTools.diskImageFuns;
    listToAttrs (concatLists (for [
      { name = "xenial";
        b64 = ubuntu1604x86_64;
	b32 = ubuntu1604i386; }
      { name = "wily";
	b64 = ubuntu1510x86_64;
	b32 = ubuntu1510i386; }
    ] ({ name, b64, b32, extra ? [] }: let
      dsc = vmBuild {
        name = "rethinkdb-${sourcePrep.version}-${name}-src";
        attrs = { src = sourcePrep; };
        build = ''
          cp -r $src rethinkdb
          cd rethinkdb
          ./configure
          make build-deb-src UBUNTU_RELEASE=${name} SIGN_PACKAGE=0
          cp build/packages/*.{dsc,build,changes,tar.?z} $out
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
        '';
        memSize = 8192;
        diskImage = diskImage {extraPackages = debBuildDeps ++ extra; };
      };
    in [
      { name = "${name}-src"; value = dsc; }
      { name = "${name}-i386"; value = deb "i386" b32; }
      { name = "${name}-amd64"; value = deb "amd64" b64; }
    ])));

in {
  inherit sourcePrep fetchDependencies fastTests;
} // debs # // rpms
