with { inherit (import lib/package.nix) debs rpms; };
with { inherit (import lib/build.nix) matrixBuilds; };
with { inherit (import lib/test.nix) reqlTests; };
debs // rpms // matrixBuilds // reqlTests // {
  inherit (import lib/source.nix) sourcePrep fetchDependencies sourceTgz;
  inherit (import lib/test.nix) unitTests checkStyle unitTestsBroken integrationTests;
  inherit (import lib/build.nix) buildDeps debugBuild;
}
