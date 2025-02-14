# Build GRASS GIS with Anaconda

This is a script package for nearly automated build of GRASS GIS as a macOS
application bundle (GRASS-x.x.app).

The building script `build-grass.sh` will do all the steps – creating App
bundle, installing Conda dependencies (using the package manager Mambaforge),
to patching, compiling and installing GRASS GIS – to end up with an
installed GRASS.app in `/Applications`. It can also create a compressed dmg
file if so wished.


Usage:
```
./build-grass.sh [arguments]

Arguments:
  -g
  --grassdir    [path]  GRASS GIS source directory, spaces in path not allowed.
  -s
  --sdk         [path]  MacOS SDK - full path, spaces in path not allowed.
  -t
  --target    [target]  Set deployment target version (MACOSX_DEPLOYMENT_TARGET),
                        e.g. "10.14", optional, default is set from SDK.
  -o
  --dmg-out-dir [path]  Output directory path for DMG file creation
                        This is a requirement for creating .dmg files.
  -c
  --conda-file  [path]  Conda package requirement file, optional.
  --with-liblas         Include libLAS support, optional, default is no support.
  -u
  --update-conda-stable Update the stable explicit conda requirement file. This
                        is only allowed if conda-requirements-dev-[arm64|x86_64].txt
                        is used (with --conda-file), to keep the two files in sync.
  -r
  --repackage           Recreate dmg file from previously built app,
                        setting [-o | --dmg-out-dir] is a requirement.
  -h
  --help                Usage information.

```


## Requirements

- Apple's Command Line Tools
- GRASS GIS source code repository (preferably a git repo)
- This (grass-conda) script package

You need to install Apple's Command Line Tools (CLT), with or without Xcode.
Installing CLT is possible with following terminal command:
```
xcode-select --install
```
Xcode is available for download at Apple's App Store.

CLT will typically install SDKs in `/Library/Developer/CommandLineTools/SDKs/`,
while finding Xcode's default SDK can be achieved with e.g.
`xcrun --show-sdk-path`. (See `man xcrun` for more functions.)

**Note**: Compiling GRASS (c/c++ based) addon extensions with the resulting
GRASS.app requires CLT installation too.

## Instructions

Fork or download this grass-conda repository to local disk and make sure you
have the GRASS GIS source directory on local disk too.

If GRASS source directory is a git repo, you can checkout the branch/release
you want to build. At present the `master` and `releasebranch_7_8` branches, and
the `7.8.5` release is supported, e.g.:

```
cd [grass-source-dir]

# for 8.0.dev
git checkout master

# for 7.8.6dev
git checkout releasebranch_7_8

# for 7.8.5 release
git checkout 7.8.5
```

There are currently two required variables needed to be set either through
editing the `$HOME/.config/grass/configure-build-[arm64|x86_64].sh` file,
or by giving them as arguments to the main script: `./build-grass.sh`.

Argument given to `./build-grass.sh` will override settings in
`configure-build-[arm64|x86_64].sh`. You can also do
`./build-grass.sh --help` for info on possible configurations.

Required settings:

- SDK full path to the SDK that will be set to -isysroot (path may **not**
  contain spaces)
- GRASSDIR full path to the GRASS GIS source directory (path may **not**
  contain spaces)

Example with using settings in `$HOME/.config/grass/configure-build-[arm64|x86_64].sh`:
```
./build-grass.sh
```


Example with executing with arguments:
```
./build-grass.sh \
  --grassdir /Volumes/dev/grass \
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX10.14.sdk \
  --target 10.14
```

Example of building and creating dmg with executing with arguments:
```
~/scripts/grass-conda/build-grass.sh \
  --grassdir /Volumes/dev/grass \
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX10.14.sdk \
  --conda-file ./Desktop/requirement.txt \
  --dmg-out-dir ~/Desktop
```

## Build Target Architecture

Building GRASS on a x86_64 (Intel) machine can create a binary *only* for the
x86_64 architecture. On a Apple silicon based machine a binary can be created
for *either* x86_64 or arm64 (creating Universal Binary is at the moment *not*
possible).

The building target architecture depends ultimately on the result of `uname -m`
in the Terminal running the `build-grass.sh` script. Building on Apple silicon
machines, opening the Terminal in Rosetta mode, creates a x86_64 binary.

## Settings

By default a conda environment will be created by an explicit conda requirement
file (`default/conda-requirements-dev-[arm64|x86_64].txt`). It was created by
executing `conda list --explicit` on an environment created by the file
`default/conda-requirements-dev-[arm64|x86_64].txt`. This enables reproducibility
and stability. It is also possible to use a customized conda requirement file,
set as an argument (or in `configure-build.sh`).

To be able to bump dependency versions and/or add/remove dependencies for the
`default/conda-requirements-stable.txt` file the command flag
`--update-conda-stable` can be added. A requirement for this is that
`default/conda-requirements-dev.txt` is used for `--conda-file`. This function is
primarily intended to be used for updating this git repo.

GRASS configure settings are set in `default/configure-grass.sh`. Changes to that
file should reflect settings of conda environment.

GRASS build configure settings can be set in configure files located in
`$HOME/.config/grass` (or `$XDG_CONFIG_HOME/grass` if set), e.g.:

```sh
mkdir -p $HOME/.config/grass
cp default/configure-build.sh $HOME/.config/grass/configure-build-arm64.sh
cp default/configure-build.sh $HOME/.config/grass/configure-build-x86_64.sh
```

Edit the configure files to your needs.
