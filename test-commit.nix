{ inherit (import ./all.nix {})
  fetchDependencies sourcePrep unitTests checkStyle
  # TODO: re-enable PR tests when they pass reliably 
  # testPython35 testRuby22 otherTests
  ; }



