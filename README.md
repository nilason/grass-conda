# Build GRASS GIS with Anaconda

This is a script package for nearly automated build of GRASS GIS as an macOS ".app".

## Prerequisites

Installation of Anaconda for macOS https://www.anaconda.com/

Create conda environment, e.g.:
```
conda create -n anaconda_p37 python==3.7.8 anaconda
```

## Instructions

Fork or download this grass-conda repository to local disk. In terminal `cd` to
the grass-conda directory. Make sure you have the GRASS GIS source directory on 
local disk. Edit the `configure-build.sh` file. Start compiling with
`./build-grass.sh`.

You can also do `./build-grass.sh --help` for info on possible configurations,
that overrides the configure-build.sh.

If GRASS GIS source directory is a git repository, the patches can be reset with:
```
cd grass-source-dir
git reset --hard
git clean -f -d
```
