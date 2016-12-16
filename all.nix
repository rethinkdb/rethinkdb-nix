with { inherit (import lib/package.nix) debs rpms; };
debs // rpms // {
  inherit (import lib/source.nix) sourcePrep fetchDependencies sourceTgz;
  inherit (import lib/test.nix) fastTests;
}
