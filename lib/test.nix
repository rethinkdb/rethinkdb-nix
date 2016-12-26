with import ./prelude.nix;
with { inherit (import ./source.nix) sourcePrep; };
with { inherit (import ./build.nix) debugBuild rethinkdbBuildInputs; };
rec {

  # TODO: add job to run known failures
  known_failures = [
    # known failures (TODO: fix upstream)
    "unit.RDBBtree"
    "unit.UtilsTest"
    "unit.RDBProtocol"
    "unit.RDBBtree"
    "unit.RDBInterrupt"
    "unit.ClusteringRaft"
  ];
  skipTests = tests:
      concatStringsSep " " (map (t: "'!" + t + "'") tests);

  runTests = { testName, testsPattern, neverFail ? false }: mkSimpleDerivation rec {
    name = "rethinkdb-${testName}-results-${env.rethinkdb.version}";
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
      test/run -H -j $((NIX_BUILD_CORES / 2)) ${testsPattern} || ${if neverFail then "true" else "touch $out/nix-support/failed"}
      test -e test/results/*/test_results.html
      cp -r test/results/* $out
      echo report html $out/*/test_results.html > $out/nix-support/hydra-build-products
    '';
  };

  unitTests = runTests {
    testName = "unit";
    testsPattern = "unit ${skipTests known_failures}";
  };

  # TODO: untested
  unitTestsBroken = runTests {
    testName = "unit-broken";
    testsPattern = concatStringsSep " " known_failures;
    neverFail = true;
  };

  # TODO: untested
  checkStyle = mkSimpleDerivation {
    name = "check-style";
    buildInputs = with pkgs; [ python ];
    env.rethinkdb = <rethinkdb>;
    buildCommand = ''
      sed 's|^DIR=.*|DIR=$rethinkdb/scripts|; s|"$DIR"/cpplint|python "$DIR"/cpplint|' \
        $rethinkdb/scripts/check_style.sh > check_style.sh
      bash check_style.sh | tee $out
    '';
  };
}
