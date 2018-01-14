{ lib, sourcePrep, alwaysFetch, fetchDependencies, debugBuild, rethinkdbBuildInputs, rawSource }:
with lib;

rec {

  # TODO: add job to run known failures
  known_failures = [
    # known failures (TODO: fix upstream)
    "unit.UtilsTest"
    "unit.TimerTest"
    
    # Heavy tests that may sometimes fail
    "unit.RDBProtocol" # .SindexFuzzCreateDrop
    "unit.RDBBtree" # .SindexPostConstruct
    "unit.RDBInterrupt"
    "unit.ClusteringRaft"
  ];
  skipTests = tests:
      concatStringsSep " " (map (t: "'!" + t + "'") tests);

  runTests = { testName, testsPattern, neverFail ? false, setup ? "", additionalInputs ? [], jobs ? null, verbose ? false }: mkSimpleDerivation rec {
    name = "rethinkdb-${testName}-results-${env.rethinkdb.version}";
    env = {
      rethinkdb = sourcePrep;
      inherit debugBuild;
    };
    buildInputs = rethinkdbBuildInputs ++ [ pkgs.git ] ++ additionalInputs;
    buildCommand = ''
      cp -r $rethinkdb/* .
      cp -r $debugBuild/* .
      chmod -R u+w .
      patchShebangs .

      ${setup}
      
      # TODO upstream remove dependency on git
      git init
      git config user.email joe@example.com
      git config user.name Joe
      git commit --allow-empty -m "empty"
      
      mkdir -p $out/nix-support
      test/run -H -j ${if jobs == null then "$((NIX_BUILD_CORES / 2))" else toString jobs} ${testsPattern}  ${if verbose then "-v" else ""} || ${if neverFail then "true" else "touch $out/nix-support/failed"}
      test -e test/results/*/test_results.html
      cp -r test/results/* $out
      echo report html $out/*/test_results.html > $out/nix-support/hydra-build-products
    '';
  };

  unitTests = runTests {
    testName = "unit";
    testsPattern = "unit ${skipTests known_failures}";
  };

  unitTestsBroken = runTests {
    testName = "unit-broken";
    testsPattern = concatStringsSep " " known_failures;
    neverFail = true;
  };

  checkStyle = mkSimpleDerivation {
    name = "check-style";
    buildInputs = with pkgs; [ python ];
    env.rethinkdb = rawSource;
    buildCommand = ''
      sed 's|^DIR=.*|DIR=$rethinkdb/scripts|; s|"$DIR"/cpplint|python "$DIR"/cpplint|' \
        $rethinkdb/scripts/check_style.sh > check_style.sh
      bash check_style.sh | tee $out
    '';
  };

  integrationTests = runTests {
    testName = "integration";
    testsPattern = "all '!unit' '!cpplint' ${skipTests known_failures}";
    additionalInputs = [ reCC pkgs.procps ] ++ rethinkdbBuildInputs;
    setup = ''
      ./configure --allow-fetch
      make py-driver
    '';
  };

  testLang = { args, python ? pkgs.python, ruby ? pkgs.ruby, javascript ? pkgs.nodejs }: let
      hasGevent = builtins.elem python.pythonVersion [ "2.7" ]; # TODO: python 3
    in mkSimpleDerivation rec {
    name = "test-reql";
    buildInputs = rethinkdbBuildInputs ++ [ reCC env.python env.ruby env.javascript ] ++ (with pkgs; [ procps utillinux iproute ]);
    env = {
      rethinkdb = sourcePrep;
      inherit debugBuild fetchDependencies;
      python = python.withPackages (p: with p; [ tornado twisted pyopenssl ] ++ (if hasGevent then [ gevent ] else []));
      inherit ruby javascript;
      runTests = toFile "run-reql-tests.sh" ''
        ip link set dev lo up
        ./resunder.py start
        trap "./resunder.py stop" EXIT
        test/rql_test/test-runner -j 1 ${args}
      '';
    };
    buildCommand = ''
      cp -r $rethinkdb/* .
      cp -r $debugBuild/* .
      chmod u+w build external
      cp -r $fetchDependencies/* .
      chmod -R u+w .
      patchShebangs . > /dev/null

      # TODO: running tests shouldn't require building more than necessary
      ./configure ${alwaysFetch}
      ${make} build-coffee-script build-browserify
      patchShebangs build/external > /dev/null
      ${make} drivers
      
      mkdir -p $out/nix-support
      sed 's|/var/log/resunder.log|resunder.log|' test/common/resunder.py > resunder.py
      chmod u+x resunder.py
      unshare --net --map-root-user bash $runTests
    ''; 
  };

  reqlTests = mapAttrs (k: v: testLang v) rec {
    # TODO: test more interpreters
    testPython27 = { args = "-i py2.7 polyglot"; python = pkgs.python27Full; };
    testPython35 = { args = "-i py3.5 polyglot"; python = pkgs.python35; };
    # testJavascript = { args = "-i js polyglot"; javascript = pkgs.nodejs; };
    testRuby22 = { args = "-i rb2.2 polyglot"; ruby = pkgs.ruby_2_2; };
    otherTests = { args = "-i rb2.2 -i py backup changefeeds connections interface stream"; ruby = pkgs.ruby_2_2; }; # TODO: js
  };
}
