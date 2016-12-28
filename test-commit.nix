{ inherit (import <rethinkdb-nix/all.nix>)
  fetchDependencies sourcePrep unitTests checkStyle
  testPython35 testRuby22 otherTests; }



