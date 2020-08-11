#!/bin/bash

############################################################################
#
# TOOL:         build-grass.sh
# AUTHOR(s):    Nicklas Larsson
# PURPOSE:
# COPYRIGHT:    (c) 2020 Nicklas Larsson
#               (c) 2020 Michael Barton
#               (c) 2018 Eric Hutton, Community Surface Dynamics Modeling
#                   System
#               This package is written by Nicklas Larsson and is heavily based
#               on work by Eric Hutton with contributions by Michael Barton.
#               This package is free software under the GNU General Public
#               License (>=v2).
#
#############################################################################
#
#
#


BASH=/bin/bash
THIS_SCRIPT=`basename $0`
THIS_SCRIPT_DIR=`pwd`
SDK=
GRASSDIR=
DEPLOYMENT_TARGET=
GRASS_VER_MAJ=""
GRASS_VER_MIN=""
GRASS_VER_PATCH=
PATCH_DIR=
GRASS_APP_NAME=""
CONDA_ENV=
CONDA_REQ_FILE="conda-requirements.txt"

# read in configurations
. configure-build.sh

#############################################################################
# Functions
#############################################################################

function display_usage () { cat <<- _EOF_
GRASS GIS build script for Anaconda.

Description...

Usage:  $THIS_SCRIPT [arguments]
Arguments:
  -g
  --grassdir  GRASS GIS source directory
  -s
  --sdk       MacOS SDK - full path
  -t
  --target    Set deployment target version (MACOSX_DEPLOYMENT_TARGET), e.g. "10.14"
  -c
  --conda-env Conda environment name
  -h
  --help      Usage information
Example:
  ./$THIS_SCRIPT
  ./$THIS_SCRIPT -s /Library/Developer/CommandLineTools/SDKs/MacOSX10.14.sdk \
      -g /Volumes/dev/grass
_EOF_
}

function exit_nice () {
    error_code=$1
    if [[ "$#" -eq 2 && $2 == 'cleanup' ]]; then
        reset_grass_patches
    fi
    exit $error_code
}

function read_grass_version () {
    local versionfile="$GRASSDIR/include/VERSION"
    local arr=()
    while read line; do
        arr+=("$line")
    done < $versionfile
    GRASS_VER_MAJ=${arr[0]}
    GRASS_VER_MIN=${arr[1]}
    GRASS_VER_PATCH=${arr[2]}
    PATCH_DIR=$GRASS_VER_MAJ.$GRASS_VER_MIN.$GRASS_VER_PATCH
    echo PATCH_DIR:$PATCH_DIR
    if [ ! -d  "$THIS_SCRIPT_DIR/patches/$PATCH_DIR" ]; then
        echo "Error, no patch directory \"$THIS_SCRIPT_DIR/patches/$PATCH_DIR\" found"
        exit_nice 1
    fi
    GRASS_APP_NAME="GRASS-$GRASS_VER_MAJ.$GRASS_VER_MIN.app"
}

function make_app_bundle_dir () {
    local contents_dir="/Applications/$GRASS_APP_NAME/Contents"
    local resources_dir="/Applications/$GRASS_APP_NAME/Contents/Resources"
    local macos_dir="/Applications/$GRASS_APP_NAME/Contents/MacOS"
    mkdir -p -m 0755 $contents_dir
    mkdir -m 0755 $resources_dir
    mkdir -m 0755 $macos_dir

    sed "s|@@GRASSVERSION@@|$GRASS_VER_MAJ.$GRASS_VER_MIN|g" \
        ./files/Info.plist > "$contents_dir/Info.plist"
    sed "s|@@GRASSBIN@@|grass$GRASS_VER_MAJ$GRASS_VER_MIN|g" \
        ./files/Grass.sh > "$macos_dir/Grass.sh"
    cp -p "$GRASSDIR/macosx/app/build_gui_user_menu.sh" \
        "$macos_dir/build_gui_user_menu.sh"
    cp -p "$GRASSDIR/macosx/app/build_html_user_index.sh" \
        "$macos_dir/build_html_user_index.sh"
    cp -p ./files/Grass "$macos_dir/Grass"
    cp -p "$GRASSDIR/macosx/app/app.icns" "$resources_dir/app.icns"

    chmod 0644 "$contents_dir/Info.plist"
    chmod 0755 "$macos_dir/build_gui_user_menu.sh"
    chmod 0755 "$macos_dir/build_html_user_index.sh"
    chmod 0755 "$macos_dir/Grass"
    chmod 0755 "$macos_dir/Grass.sh"
    chmod 0644 "$resources_dir/app.icns"
}

function patch_grass () {
    cd "$GRASSDIR"
    local patches_dir="$THIS_SCRIPT_DIR/patches/$PATCH_DIR"
    for patchfile in $patches_dir/*.patch; do
        patch -p0 < $patchfile
    done
    cd "$THIS_SCRIPT_DIR"
}

function reset_grass_patches () {
    echo "Reverting patches..."
    cd "$GRASSDIR"
    local patches_dir="$THIS_SCRIPT_DIR/patches/$PATCH_DIR"
    for patchfile in $patches_dir/*.patch; do
        patch  -R -p0 < $patchfile
    done
    echo "Reverting patches done."
    cd "$THIS_SCRIPT_DIR"
}

function set_up_conda () {
    # download miniconda if not already existing
    if [ ! -f "$THIS_SCRIPT_DIR/miniconda3.sh" ]; then
        curl https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh \
            --output miniconda3.sh
    fi

    if [ ! -f "$(conda info --base)/etc/profile.d/conda.sh" ]; then
        echo "Error: failed to locate the file \"/etc/profile.d/conda.sh\" in conda base \"$(conda info --base)\""
        exit_nice 1 cleanup
    fi

    # a hack, this is needed to enable `conda activate` in bash script
    # see https://github.com/conda/conda/issues/7980
    . $(conda info --base)/etc/profile.d/conda.sh
    # . ~/opt/anaconda3/etc/profile.d/conda.sh
    conda activate $CONDA_ENV
    if [ $? -ne 0 ]; then
        exit_nice $? cleanup
    fi

    $BASH miniconda3.sh -b -f -p "/Applications/$GRASS_APP_NAME/Contents/Resources"
    export PATH=/Applications/$GRASS_APP_NAME/Contents/Resources/bin:$PATH
    conda install --yes -p "/Applications/$GRASS_APP_NAME/Contents/Resources" \
        --file=$CONDA_REQ_FILE -c conda-forge
    if [ $? -ne 0 ]; then
        exit_nice $? cleanup
    fi
}

#############################################################################
# Read script arguments
#############################################################################

while [ "$1" != "" ]; do
    case $1 in
        -s | --sdk ) shift
        SDK=$1
        ;;
        -g | --grassdir ) shift
        GRASSDIR=$1
        ;;
        -c | --conda-env ) shift
        CONDA_ENV=$1
        ;;
        -t | --target ) shift
        DEPLOYMENT_TARGET=$1
        ;;
        -h | --help )
        display_usage
        exit 0
        ;;
        *)
         # unknown option
         echo "ERROR"
         display_usage
         exit 1
        ;;
    esac
    shift
done

#############################################################################
# Check arguments and files
#############################################################################

# make sure this script is run from script directory
if [ ! -f "$THIS_SCRIPT_DIR/$THIS_SCRIPT" ]; then
    echo "Error, you need to cd to grass-conda directory"
    exit_nice 1
fi

if [ ! -d  "$SDK" ]; then
    echo "Error, could not find MacOS SDK"
    display_usage
    exit_nice 1
fi

if [ ! -d  "$GRASSDIR" ]; then
    echo "Error, --g argument required, could not find GRASS source directory"
    display_usage
    exit_nice 1
fi

read_grass_version

# check if conda is available
if ! type conda &>/dev/null ; then
    echo "Error, conda() not found, make sure to activate conda environment"
    exit_nice 1
fi

# check for existence of conda environment
if [ `conda env list | grep -o "^$CONDA_ENV " | wc -l` -eq 0 ]; then
    echo "Error, could not find conda environment \"$CONDA_ENV\""
    exit_nice 1
fi

# check if destination app bundle exists, with option to cancel if true
if [ -d  "/Applications/$GRASS_APP_NAME" ]; then
    echo "Warning, \"/Applications/$GRASS_APP_NAME\" already exists."
    while true; do
        read -p "Do you wish to delete it (y|n)? " yn
        case $yn in
            [Yy]* ) sudo rm -rf "/Applications/$GRASS_APP_NAME"; break;;
            [Nn]* ) exit_nice 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

#############################################################################
# Start setting up and compiling procedures
#############################################################################

make_app_bundle_dir

patch_grass

set_up_conda

ln -sf /Applications/$GRASS_APP_NAME/Contents/Resources/python.app/pythonapp/Contents/* \
    /Applications/$GRASS_APP_NAME/Contents/Resources/python.app/Contents

# configure and compile GRASS GIS
cd "$GRASSDIR"

echo "Starting \"make distclean\"..."
make distclean &>/dev/null
echo "Finished \"make distclean\""

export BUILD_SDK=$SDK
export DEPLOYMENT_TARGET=$DEPLOYMENT_TARGET
. "$THIS_SCRIPT_DIR/configure-grass.sh"

make -j$(sysctl -n hw.ncpu) GDAL_DYNAMIC=

echo
echo "Start installation:"
sudo make install

# replace SDK with a unversioned one of Command Line Tools
FILE=/Applications/$GRASS_APP_NAME/Contents/Resources/include/Make/Platform.make
sudo sed -i .bak "s|-isysroot $SDK|-isysroot /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk|g" $FILE
if [ $? -eq 0 ]; then
    sudo rm -f $FILE.bak
fi

# save some disk space
sudo rm -r /Applications/$GRASS_APP_NAME/Contents/Resources/pkgs

# set app owner
sudo chown -R root:wheel /Applications/$GRASS_APP_NAME

exit_nice 0 cleanup
