# Continuous integration for RethinkDB

These scripts run on my [Thanos](https://thanos.atnnn.com:3443) build
server, allowing us to build [RethinkDB](http://github.com/rethinkdb/rethinkdb), run the tests and build
packages.

To add your own server to the build farm contact me at
etienne@atnnn.com. I need macOS, Windows and Linux (PC and ARM)
machines to extend the test coverage and add packages for Windows, for
macOS and for other Linux distributions. I would also like to run the
performance tests.

## Download Packages

Thanos currently builds packages for Ubuntu and Centos. I will try to
add more packages if there is any demand.

Build artifacts and packages haven't been organised yet, but most of
them are available.

* Open the RethinkDB project page at
  https://thanos.atnnn.com:3443/project/rethinkdb

* Click on the branch you want to download, and locate the *Jobs*
  tab. For example, the `next` branch:
  https://thanos.atnnn.com:3443/jobset/rethinkdb/next#tabs-jobs

* Click the green checkbox next to the package you want to open the
  build page

* Locate the download links in the Build Products section

# Contributing

## Local Setup

Running these scripts locally requires [Nix](http://nixos.org/nix/).

Checkout RethinkDB and RethinkDB-Nix side-by-side:

```
git clone https://github.com/rethinkdb/rethinkdb
git clone https://github.com/atnnn/rethinkdb-nix
```

Syntax-check the scripts:

```
cd rethinkdb-nix
nix-instantiate -I .. release.nix
```

Build a RethinkDB source tarball:

```
nix-build -I .. release.nix -A sourceTgz
```

`nix-build` parameters that can help debug errors are:

* `-K` - keep the build folder on failure
* `-v`, `-vv`, ... - be more verbose
* `--show-trace` - stack traces for nix errors

