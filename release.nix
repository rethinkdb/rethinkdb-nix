let pkgs = import <nixpkgs> {}; in rec {
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
    version = builtins.readFile versionFile;
    builder = builtins.toFile "builder.sh" ''
      source $stdenv/setup
      # TODO: https://github.com/NixOS/nixpkgs/issues/13744
      export SSL_CERT_FILE=$cacert/etc/ssl/certs/ca-bundle.crt
      cp -r $src rethinkdb
      chmod -R u+w rethinkdb
      cd rethinkdb
      # TODO: use original shebangs in tarball
      patchShebangs configure
      patchShebangs drivers/convert_protofile
      patchShebangs scripts/gen-version.sh
      patchShebangs mk/support/pkg/pkg.sh
      ./configure --fetch jemalloc
      make dist -j $NIX_BUILD_CORES
      cp build/packages/rethinkdb-${version}.tgz $out
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

  unitTests = pkgs.stdenv.mkDerivation rec {
    name = "rethinkdb-unit-test-results-${src.version}.html";
    src = sourceTarball;
    buildInputs = with pkgs; [
      protobuf
      python
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
      make -j $NIX_BUILD_CORES DEBUG=1 build/debug/rethinkdb-unittest
      test/run -j $NIX_BUILD_CORES unit
      cp test/results/*/test_results.html $out
    '';
  };
}

# # pkgs.stdenv.mkDerivation {
#   name = "rethinkdb-dev";
#   buildInputs = with pkgs; [
#    gcc6
#    protobuf
#    python
#    nodejs
#    nodePackages.coffee-script
#    nodePackages.browserify
#    zlib
#    openssl
#    curl
#    jemalloc
#    boost
#    git
#   ];
#   shellHook = ''
#     export LIBRARY_PATH=${pkgs.jemalloc}/lib
#   '';
# }
