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
  --grassdir    [path] GRASS GIS source directory, spaces in path not allowed
  -s
  --sdk         [path] MacOS SDK - full path, spaces in path not allowed
  -t
  --target             Set deployment target version (MACOSX_DEPLOYMENT_TARGET),
                       e.g. "10.14", optional, default is set from SDK
  -o
  --dmg-out-dir [path] Output directory path for DMG file creation
                       This is a requirement for creating .dmg files.
  -r
  --repackage          Recreate dmg file from previously built app,
                       setting [-o | --dmg-out-dir] is a requirement.
  -h
  --help               Usage information

```


## Instructions

Fork or download this grass-conda repository to local disk. Make sure you have
the GRASS GIS source directory on local disk.

There are currently two variables needed to be set either through editing the
`configure-build.sh` file, or by giving them as arguments to the main script:
`./build-grass.sh`.

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


