with import ./prelude.nix;
with { inherit (import ./source.nix) sourcePrep; };
with { inherit (import ./build.nix) debugBuild rethinkdbBuildInputs; };
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

  fastTests = mkSimpleDerivation rec {
    name = "rethinkdb-fast-tests-results-${env.rethinkdb.version}";
    env = {
      rethinkdb = sourcePrep;
      inherit debugBuild;
    };
    buildInputs = rethinkdbBuildInputs ++ [ pkgs.git ];
    buildCommand = ''
      cp -r $rethinkdb/* .
      cp -r $debugBuild/* .
      chmod -R u+w .
      patchShebangs .

      # TODO upstream remove dependency on git
      git init
      git config user.email joe@example.com
      git config user.name Joe
      git commit --allow-empty -m "empty"
      
      mkdir -p $out/nix-support
      test/run -H -j $((NIX_BUILD_CORES / 2)) unit cpplint ${skip_tests_filter} || touch $out/nix-support/failed
      test -e test/results/*/test_results.html
      cp -r test/results/* $out
      echo report html $out/*/test_results.html > $out/nix-support/hydra-build-products
    '';
  };

}
