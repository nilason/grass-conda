# Build GRASS GIS with Anaconda

This is a script package for nearly automated build of GRASS GIS as a macOS
application bundle (GRASS-x.x.app).

## Prerequisites

Installation of Anaconda for macOS https://www.anaconda.com/.

Create conda environment, e.g.:
```
conda create -n anaconda_p37 python==3.7.8 anaconda
```

## Instructions

Fork or download this grass-conda repository to local disk. In terminal `cd` to
the grass-conda directory. Make sure you have the GRASS GIS source directory on
local disk.

There are currently four variables needed to be set either through editing the
`configure-build.sh` file, or by giving them as arguments to the main script:
`./build-grass.sh`.

Argument given to `./build-grass.sh` will override settings in `configure-build.sh`.
You can also do `./build-grass.sh --help` for info on possible configurations.

Settings:

- SDK full path to the SDK that will be set to -isysroot
- DEPLOYMENT_TARGET this will set MACOSX_DEPLOYMENT_TARGET
- GRASSDIR full path to the GRASS GIS source directory
- CONDA_ENV name of conda environment

Example with using settings in `configure-build.sh`:
```
cd [grass-conda-directory]
./build-grass.sh
```


Example with executing with arguments:
```
cd [grass-conda-directory]

./build-grass.sh \
  --grassdir /Volumes/dev/grass \
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX10.14.sdk \
  --target 10.14 \
  --conda-env anaconda_p37
```
