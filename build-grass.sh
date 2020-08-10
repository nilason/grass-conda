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
#               on work by Eric Hutton with contribution by Michael Barton.
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
GRASS_VER_MAJ=""
GRASS_VER_MIN=""
GRASS_APP_NAME=""
CONDA_ENV=
CONDA_REQ_FILE="conda-requirements.txt"

# read in configurations
. configure-build.sh

function display_usage () { cat <<- _EOF_
GRASS GIS build script for Anaconda.

Description...

Usage:  $THIS_SCRIPT [arguments]
Arguments:
  -g
  --grassdir  GRASS GIS source directory
  -s
  --sdk       MacOS SDK
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
    cp -p "$GRASSDIR/macosx/app/build_gui_user_menu.sh" "$macos_dir/build_gui_user_menu.sh"
    cp -p "$GRASSDIR/macosx/app/build_html_user_index.sh" "$macos_dir/build_html_user_index.sh"
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
    local patches_dir="$THIS_SCRIPT_DIR/patches"
    patch -p0 < "$patches_dir/aclocal.m4.patch"
    patch -p0 < "$patches_dir/configure.patch"
    patch -p0 < "$patches_dir/install.make.patch"
    patch -p0 < "$patches_dir/loader.py.patch"
    patch -p0 < "$patches_dir/module.make.patch"
    patch -p0 < "$patches_dir/platform.make.in.patch"
    patch -p0 < "$patches_dir/rules.make.patch"
    patch -p0 < "$patches_dir/shlib.make.patch"
    cd "$THIS_SCRIPT_DIR"
}

while [ "$1" != "" ]; do
    case $1 in
        -s | --sdk ) shift
        SDK=$1
        ;;
        -g | --grassdir ) shift
        GRASSDIR=$1
        ;;
        -h | --help )
        display_usage
		exit 0
        ;;
        -c | --conda-env ) shift
        CONDA_ENV=$1
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

# check if conda is available
if ! type conda &>/dev/null ; then
    echo "Error, conda() not found, make sure to activate conda environment"
    exit_nice 1
fi

if [ `conda env list | grep -o "^$CONDA_ENV " | wc -l` -eq 0 ]; then
    echo "Error, could not find conda environment \"$CONDA_ENV\""
    exit_nice 1 
fi

read_grass_version

if [ -d  "/Applications/$GRASS_APP_NAME" ]; then
    echo "Warning, \"/Applications/$GRASS_APP_NAME\" already exists."
    while true; do
        read -p "Do you wish to delete it (y|n)? " yn
        case $yn in
            [Yy]* ) rm -rf "/Applications/$GRASS_APP_NAME"; break;;
            [Nn]* ) exit_nice 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

make_app_bundle_dir

patch_grass

if [ ! -f "$THIS_SCRIPT_DIR/miniconda3.sh" ]; then
    curl https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh \
        --output miniconda3.sh
fi

# Conda stuff
. ~/opt/anaconda3/etc/profile.d/conda.sh
conda activate $CONDA_ENV
if [ $? -ne 0 ]; then
    exit_nice $?
fi

$BASH miniconda3.sh -b -f -p "/Applications/$GRASS_APP_NAME/Contents/Resources"
export PATH=/Applications/$GRASS_APP_NAME/Contents/Resources/bin:$PATH
conda install --yes -p "/Applications/$GRASS_APP_NAME/Contents/Resources" \
    --file=$CONDA_REQ_FILE -c conda-forge

ln -sf /Applications/$GRASS_APP_NAME/Contents/Resources/python.app/pythonapp/Contents/* \
    /Applications/$GRASS_APP_NAME/Contents/Resources/python.app/Contents

# GRASS stuff
cd "$GRASSDIR"
make distclean &>/dev/null
export BUILD_SDK=$SDK
. "$THIS_SCRIPT_DIR/configure-grass.sh"
make -j4  GDAL_DYNAMIC=
echo "Start installation:"
sudo make -j4 install

sudo rm -r /Applications/$GRASS_APP_NAME/Contents/Resources/pkgs
sudo chown -R root:wheel /Applications/$GRASS_APP_NAME

exit 0
