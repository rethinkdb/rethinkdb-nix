with import ./prelude.nix;
with { inherit (import ./source.nix) sourcePrep; };
rec {

  skip_tests = [
    # known failures (TODO: fix upstream)
    "unit.RDBBtree"
    "unit.UtilsTest"
    "unit.RDBProtocol"
    "unit.RDBBtree"
    "unit.RDBInterrupt"
    "unit.ClusteringRaft"
    # Slow tests
    "unit.DiskBackedQueue"
  ];
  skip_tests_filter =
      concatStringsSep " " (map (t: "'!" + t + "'") skip_tests);

  fastTests = pkgs.stdenv.mkDerivation rec {
    name = "rethinkdb-fast-tests-results-${src.version}";
    src = sourcePrep;
    buildInputs = with pkgs; [
      gcc #TODO: just testing
      protobuf
      python27Full
      nodejs
      nodePackages.coffee-script
      nodePackages.browserify
      zlib
      openssl
      boost
      curl
      git # TODO
    ];
    builder = mkStdBuilder ''
      cp -r $src/* .
      chmod -R u+w .
      patchShebangs .

      # TODO upstream remove dependency on git
      git init
      git config user.email joe@example.com
      git config user.name Joe
      git commit --allow-empty -m "empty"
      
      ./configure
      ${make} DEBUG=1 
      mkdir -p $out/nix-support
      test/run -H -j $((NIX_BUILD_CORES / 2)) unit cpplint ${skip_tests_filter} || touch $out/nix-support/failed
      test -e test/results/*/test_results.html
      cp -r test/results/* $out
      echo report html $out/*/test_results.html > $out/nix-support/hydra-build-products
    '';
  };

}
