let
  pkgs = import <nixpkgs> {};

  scripts = ''
    configure drivers/convert_protofile scripts/gen-version.sh
    mk/support/pkg/pkg.sh test/run external/v8_*/build/gyp/gyp
  '';
  patchScripts = ''
    for script in ${scripts}; do
      cp $script $script.orig
      patchShebangs $script
    done
  '';
  unpatchScripts = dest: ''
    for script in ${scripts}; do
      cp $script.orig ${dest}/$script
    done
  '';
  make = ''
    make -j $NIX_BUILD_CORES -l $NIX_BUILD_CORES
  '';

  skip_tests = [
    # known failures (TODO: fix upstream)
    # "unit.RDBBtree"
    "unit.UtilsTest"
    "unit.RDBProtocol"
    "unit.RDBBtree"
    # Slow tests
    "unit.DiskBackedQueue"
  '';
  skip_tests_filter =
      builtins.concatStringSep " " (map (t: "'!" + t + "'") skip_tests);

in rec {
  versionFile = pkgs.stdenv.mkDerivation {
    name = "rethinkdb-version";
    src = <rethinkdb>;
    buildInputs = [ pkgs.git ];
    builder = builtins.toFile "builder.sh" ''
      source $stdenv/setup
      cd $src
      echo -n $(bash scripts/gen-version.sh) > $out
    '';
  };

  sourceTarball = pkgs.stdenv.mkDerivation rec {
    name = "rethinkdb-${version}.tgz";
    version = builtins.unsafeDiscardStringContext (builtins.readFile versionFile);
    builder = builtins.toFile "builder.sh" ''
      source $stdenv/setup
      # TODO: https://github.com/NixOS/nixpkgs/issues/13744
      export SSL_CERT_FILE=$cacert/etc/ssl/certs/ca-bundle.crt
      cp -r $src rethinkdb
      chmod -R u+w rethinkdb
      cd rethinkdb
      ${patchScripts}
      ./configure --fetch jemalloc
      ${make} dist-dir
      ${unpatchScripts "build/packages/rethinkdb-${version}"}
      cd build/packages
      tar zcf $out rethinkdb-${version}
    '';
    __noChroot = true;
    src = <rethinkdb>;
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

  fastTests = pkgs.stdenv.mkDerivation {
    name = "rethinkdb-unit-test-results-${src.version}";
    src = sourceTarball;
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
    builder = builtins.toFile "builder.sh" ''
      source $stdenv/setup
      tar xf $src
      cd rethinkdb-*
      ./configure
      ${make} DEBUG=1
      test/run -j $NIX_BUILD_CORES '!long' ${skip_test_filter} || :
      test -e test/results/*/test_results.html
      cp test/results/* $out
      echo report test_results $out/*/test_results.html > $out/nix-support/hydra-build-products
    '';
  };
}
