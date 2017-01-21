{ debug ? false }:
let lib = import lib/prelude.nix {}; in
with lib;

let
  inputs.rethinkdb = <rethinkdb>;

  source = loadModule lib/source.nix inputs;
  build = loadModule lib/build.nix (inputs // source);
  package = loadModule lib/package.nix source;
  test = loadModule lib/test.nix (inputs // source // build);
in

package.debs // package.rpms // build.matrixBuilds // test.reqlTests // {
  inherit (source) sourcePrep fetchDependencies sourceTgz;
  inherit (test) unitTests checkStyle unitTestsBroken integrationTests;
  inherit (build) buildDeps debugBuild;
} // (if !debug then {} else {
  inherit source build package test;
})
