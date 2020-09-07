# Build GRASS GIS with Anaconda

This is a script package for nearly automated build of GRASS GIS as a macOS
application bundle (GRASS-x.x.app).

The building script `build-grass.sh` will do all the steps – creating App
bundle, installing miniconda and dependencies, to patching, compiling and
installing GRASS GIS – to end up with an installed GRASS.app in `/Applications`.
It can also create a compressed dmg file if so wished.


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
  --conda-file  [path]  Conda package requirement file, optional, full path to
                        file.
  -u
  --update-conda-stable Update the stable explicit conda requirement file. This
						is only allowed if conda-requirements-dev.txt is used
					    (with --conda-file), to keep the two files in sync.
  -r
  --repackage           Recreate dmg file from previously built app,
                        setting [-o | --dmg-out-dir] is a requirement.
  -h
  --help                Usage information.

```


## Requirements

- Apple's Command Line Tools
- GRASS GIS source code repository (preferable a git repo)
- This (grass-conda) script package

You need to install Apple's Command Line Tools (CLT), with or without Xcode.
Installing CLT is possible with following terminal command:
```
xcode-select —install
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

There are currently two required variables needed to be set either through
editing the `configure-build.sh` file, or by giving them as arguments to the
main script: `./build-grass.sh`.

Argument given to `./build-grass.sh` will override settings in `configure-build.sh`.
You can also do `./build-grass.sh --help` for info on possible configurations.

Required settings:

- SDK full path to the SDK that will be set to -isysroot (path may **not**
  contain spaces)
- GRASSDIR full path to the GRASS GIS source directory (path may **not**
  contain spaces)

Example with using settings in `configure-build.sh`:
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
  --dmg-out-dir ~/Desktop
```


## Settings

By default a conda environment will be created by an explicit conda requirement
file (`default/conda-requirements-stable.txt`). It was created by executing
`conda list --explicit` on an environment created by the file
`default/conda-requirements-dev.txt`. This enables reproducibility and stability.
It is also possible to use a customized conda requirement file, set as an argument
(or in `configure-build.sh`).

To be able to bump dependency versions and/or add/remove dependencies for the
`default/conda-requirements-stable.txt` file the command flag
`--update-conda-stable` can be added. A requirement for this is that
`default/conda-requirements-dev.txt` is used for `--conda-file`. This function is
primarily intended to be used for updating this git repo.

GRASS configure settings are set in `default/configure-grass.sh`. Changes to that
file should reflect settings of conda environment.
