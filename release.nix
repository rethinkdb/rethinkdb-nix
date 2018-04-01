{ inherit (import ./all.nix {})

  # source
  fetchDependencies sourcePrep sourceTgz

  # tests
  unitTests checkStyle
  testPython35 testRuby22 otherTests integrationTests

  # packages
  jessie-amd64 jessie-i386 jessie-src
  stretch-amd64 stretch-i386 stretch-src
  trusty-amd64 trusty-i386 trusty-src
  xenial-amd64 xenial-i386 xenial-src
  artful-amd64 artful-i386 artful-src
  centos6-x86_64 centos7-x86_64
  ;
}
