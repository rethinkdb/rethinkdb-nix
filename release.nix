{ inherit (import ./all.nix {})

  # source
  fetchDependencies sourcePrep sourceTgz

  # tests
  unitTests checkStyle
  testPython35 testRuby22 otherTests integrationTests

  # packages
  jessie-amd64 jessie-i386 jessie-src
  saucy-amd64 saucy-i386 saucy-src
  stretch-amd64 stretch-i386 stretch-src
  trusty-amd64 trusty-i386 trusty-src
  utopic-amd64 utopic-i386 utopic-src
  vivid-amd64 vivid-i386 vivid-src
  wily-amd64 wily-i386 wily-src
  xenial-amd64 xenial-i386 xenial-src
  yakkety-amd64 yakkety-i386 yakkety-src
  zesty-amd64 zesty-i386 zesty-src
  centos6-x86_64 centos7-x86_64
  ;
}
