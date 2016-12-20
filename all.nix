with { inherit (import lib/package.nix) debs rpms; };
with { inherit (import lib/build.nix) matrixBuilds; };
debs // rpms // matrixBuilds // {
  inherit (import lib/source.nix) sourcePrep fetchDependencies sourceTgz;
  inherit (import lib/test.nix) fastTests;
  inherit (import lib/build.nix) buildDeps debugBuild;
}
