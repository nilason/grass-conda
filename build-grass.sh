#!/bin/bash

############################################################################
#
# TOOL:         build-grass.sh
# AUTHOR(s):    Nicklas Larsson
# PURPOSE:
# COPYRIGHT:    (c) 2020-2021 Nicklas Larsson
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
export CONDA_ARCH=$(uname -m)
export THIS_SCRIPT_DIR=$(cd $(dirname "$0"); pwd)
export EXTERNAL_DIR="${THIS_SCRIPT_DIR}/external"
SDK=
GRASSDIR=
DEPLOYMENT_TARGET=
GRASS_VERSION=""
GRASS_VERSION_MAJOR=""
GRASS_VERSION_MINOR=""
GRASS_VERSION_RELEASE=
GRASS_VERSION_DATE=
PATCH_DIR=
GRASS_APP_NAME=""
GRASS_APP_BUNDLE=""
CONDA_STABLE_FILE="${THIS_SCRIPT_DIR}/default/conda-requirements-stable-${CONDA_ARCH}.txt"
CONDA_DEV_FILE="${THIS_SCRIPT_DIR}/default/conda-requirements-dev-${CONDA_ARCH}.txt"
CONDA_REQ_FILE="$CONDA_STABLE_FILE"
CONDA_BIN=
CONDA_TEMP_DIR=$(mktemp -d -t GRASS)
DMG_TITLE=
DMG_NAME=
DMG_OUT_DIR=
BUNDLE_VERSION=
REPACKAGE=0
CONDA_UPDATE_STABLE=0
WITH_LIBLAS=0
MINICONDA_URL="https://github.com/conda-forge/miniforge/releases/latest/download/\
Mambaforge-MacOSX-${CONDA_ARCH}.sh"

# read in configurations
source "${THIS_SCRIPT_DIR}/configure-build.sh"

#############################################################################
# Functions
#############################################################################

function display_usage () { cat <<- _EOF_

GRASS GIS build script for Anaconda.

Description...

Usage:  $THIS_SCRIPT [arguments]
Arguments:
  -g
  --grassdir    [path]  GRASS GIS source directory, required, spaces in path not
                        allowed
  -s
  --sdk         [path]  MacOS SDK - full path to the SDK, which will be set as
                        -isysroot, required, spaces in path not allowed
  -t
  --target    [target]  Set deployment target version (MACOSX_DEPLOYMENT_TARGET),
                        e.g. "10.14", optional, default is set from SDK
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
  --help                Usage information

Example:
  ./$THIS_SCRIPT
  ./$THIS_SCRIPT -s /Library/Developer/CommandLineTools/SDKs/MacOSX10.14.sdk \\
      -g /Volumes/dev/grass

_EOF_
}

function exit_nice () {
    error_code=$1
    if [[ "$#" -eq 2 && $2 = "cleanup" ]]; then
        reset_grass_patches
        rm -rf "$CONDA_TEMP_DIR"
    fi
    exit $error_code
}

function read_grass_version () {
    local versionfile="${GRASSDIR}/include/VERSION"
    local arr=()
    while read line; do
        arr+=("$line")
    done < "$versionfile"
    GRASS_VERSION_MAJOR=${arr[0]}
    GRASS_VERSION_MINOR=${arr[1]}
    GRASS_VERSION_RELEASE=${arr[2]}
    GRASS_VERSION_DATE=${arr[3]}
    GRASS_VERSION="${GRASS_VERSION_MAJOR}.${GRASS_VERSION_MINOR}.${GRASS_VERSION_RELEASE}"
    PATCH_DIR="$THIS_SCRIPT_DIR/patches/$GRASS_VERSION"
    GRASS_APP_NAME="GRASS-$GRASS_VERSION_MAJOR.$GRASS_VERSION_MINOR.app"
    GRASS_APP_BUNDLE="/Applications/$GRASS_APP_NAME"
    DMG_TITLE="GRASS-GIS-${GRASS_VERSION}"
    DMG_NAME="grass-${GRASS_VERSION}-${CONDA_ARCH}.dmg"
}

# This set the build version for CFBundleVersion, in case of dev version the
# git short commit hash number is added.
function set_bundle_version () {
    pushd "$GRASSDIR" > /dev/null
    BUNDLE_VERSION=$GRASS_VERSION

    local is_git_repo=`git rev-parse --is-inside-work-tree 2> /dev/null`
    if [[ ! $? -eq 0 && ! "$is_git_repo" = "true" ]]; then
        popd > /dev/null
        return
    fi

    if [[ "$GRASS_VERSION_RELEASE" = *"dev"* ]]; then
        local git_commit=`git rev-parse --short HEAD`
        BUNDLE_VERSION="${BUNDLE_VERSION} \(${git_commit}\)"
    fi
    popd > /dev/null
}

function make_app_bundle_dir () {
    local contents_dir="$GRASS_APP_BUNDLE/Contents"
    local resources_dir="$GRASS_APP_BUNDLE/Contents/Resources"
    local macos_dir="$GRASS_APP_BUNDLE/Contents/MacOS"
    local grass_bin_in="Grass.sh.in"
    mkdir -p -m 0755 "$contents_dir"
    mkdir -m 0755 "$resources_dir"
    mkdir -m 0755 "$macos_dir"

    local info_plist_in="$GRASSDIR/macosx/app/Info.plist.in"

    sed "s|@GRASS_VERSION_DATE@|$GRASS_VERSION_DATE|g" "$info_plist_in" | \
        sed "s|@GRASS_VERSION_MAJOR@|$GRASS_VERSION_MAJOR|g" | \
        sed "s|@GRASS_VERSION_MINOR@|$GRASS_VERSION_MINOR|g" | \
        sed "s|@GRASS_VERSION_RELEASE@|$GRASS_VERSION_RELEASE|g" | \
        sed "s|@BUNDLE_VERSION@|$BUNDLE_VERSION|g" | \
        sed "s|@DEPLOYMENT_TARGET@|$DEPLOYMENT_TARGET|g" \
            > "$contents_dir/Info.plist"

    local grassbin="grass$GRASS_VERSION_MAJOR$GRASS_VERSION_MINOR"
    if [ "$GRASS_VERSION_MAJOR" -ge 8 ]; then
            grassbin="grass"
            grass_bin_in="Grass8.sh.in"
    fi
    sed "s|@GRASSBIN@|$grassbin|g" \
        "$THIS_SCRIPT_DIR/files/$grass_bin_in" > "$macos_dir/Grass.sh"
    cp -p "$GRASSDIR/macosx/app/build_gui_user_menu.sh" \
        "$macos_dir/build_gui_user_menu.sh"
    cp -p "$GRASSDIR/macosx/app/build_html_user_index.sh" \
        "$macos_dir/build_html_user_index.sh"
    cp -p "$THIS_SCRIPT_DIR/files/Grass" "$macos_dir/GRASS"
    cp -p "$GRASSDIR/macosx/app/AppIcon.icns" "$resources_dir/AppIcon.icns"
    cp -p "$GRASSDIR/macosx/app/GRASSDocument_gxw.icns" \
        "$resources_dir/GRASSDocument_gxw.icns"

    chmod 0644 "$contents_dir/Info.plist"
    chmod 0755 "$macos_dir/build_gui_user_menu.sh"
    chmod 0755 "$macos_dir/build_html_user_index.sh"
    chmod 0755 "$macos_dir/Grass"
    chmod 0755 "$macos_dir/Grass.sh"
    chmod 0644 "$resources_dir/AppIcon.icns"
    chmod 0644 "$resources_dir/GRASSDocument_gxw.icns"
}

function patch_grass () {
    for patchfile in "$PATCH_DIR/"*.patch; do
        patch -d "$GRASSDIR" -p0 < "$patchfile"
    done
}

function reset_grass_patches () {
    echo "Reverting patches..."
    for patchfile in "$PATCH_DIR/"*.patch; do
        patch -d "$GRASSDIR" -R -p0 < "$patchfile"
    done
    echo "Reverting patches done."
}

function set_up_conda () {
    # move existing miniconda script to new external directory
    if [ -f "${THIS_SCRIPT_DIR}/miniconda3.sh" ]; then
        mv "${THIS_SCRIPT_DIR}/miniconda3.sh" "${EXTERNAL_DIR}/miniconda3.sh"
    fi

    # download miniconda if not already existing
    local miniconda="${EXTERNAL_DIR}/miniconda3-${CONDA_ARCH}.sh"
    if [ ! -f "$miniconda" ]; then
        curl -L "$MINICONDA_URL" --output "$miniconda"
        [ $? -ne 0 ] && exit_nice $? cleanup
    fi

    $BASH "$miniconda" -b -f -p "$CONDA_TEMP_DIR"
    CONDA_BIN="$CONDA_TEMP_DIR/bin/mamba"
    if [ ! -f "$CONDA_BIN" ]; then
        echo "Error, could not find conda binary file at ${CONDA_BIN}"
        exit_nice 1 cleanup
    fi

    $CONDA_BIN create --yes -p "$GRASS_APP_BUNDLE/Contents/Resources" \
        --file="${CONDA_REQ_FILE}" -c conda-forge    
    [ $? -ne 0 ] && exit_nice $? cleanup

    export PATH="$GRASS_APP_BUNDLE/Contents/Resources/bin:$PATH"
}

function install_grass_session () {
    local python_bin="$GRASS_APP_BUNDLE/Contents/Resources/bin/python"
    $python_bin -m pip install --upgrade pip
    $python_bin -m pip install grass-session
}

function create_dmg () {
    echo
    echo "Create dmg file of $GRASS_APP_BUNDLE ..."

    if [ ! -d  "$GRASS_APP_BUNDLE" ]; then
        echo "Error, attempt to create dmg file, but no app could be found"
        exit_nice 1
    fi

    local tmpdir=`mktemp -d /tmp/org.osgeo.grass.XXXXXX`
    local dmg_tmpfile=${tmpdir}/grass-tmp-$$.dmg
    local exact_app_size=`du -ks $GRASS_APP_BUNDLE | cut -f 1`
    local dmg_size=$((exact_app_size*120/100))

    sudo hdiutil create -srcfolder $GRASS_APP_BUNDLE \
        -volname $DMG_TITLE \
        -fs HFS+ \
        -fsargs "-c c=64,a=16,e=16" \
        -format UDRW \
        -size ${dmg_size}k "${dmg_tmpfile}"

    if [ $? -ne 0 ]; then
        rm -rf $tmpdir
        exit_nice $?
    fi

    DEVICE=`sudo hdiutil attach -readwrite -noverify -noautoopen "${dmg_tmpfile}" | egrep '^/dev/' | sed -e "s/^\/dev\///g" -e 1q  | awk '{print $1}'`
    sudo hdiutil attach "${dmg_tmpfile}" || error "Can't attach temp DMG"

    mkdir -p "/Volumes/${DMG_TITLE}/.background"
    cp -p "${THIS_SCRIPT_DIR}/files/dmg-background.png" \
        "/Volumes/${DMG_TITLE}/.background/background.png"

    sudo osascript << EOF
tell application "Finder"
    tell disk "$DMG_TITLE"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 1040, 460}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 100
        set background picture of theViewOptions to file ".background:background.png"
        make new alias file at container window to POSIX file "/Applications" with properties {name:"Applications"}
        set position of item "$GRASS_APP_NAME" of container window to {187, 163}
        set position of item "Applications" of container window to {452, 163}
        update without registering applications
        delay 5
        close
    end tell
end tell
EOF

    sync
    sync
    sleep 3
    hdiutil detach $DEVICE

    hdiutil convert "${dmg_tmpfile}" \
        -format UDZO -imagekey zlib-level=9 -o "${DMG_OUT_DIR}/${DMG_NAME}"

    if [ $? -ne 0 ]; then
        rm -rf $tmpdir
        exit_nice $?
    fi

    rm -rf $tmpdir
    echo
}

function remove_dmg () {
    if [ -d "/Volumes/${DMG_TITLE}" ]; then
        disk=`diskutil list | grep ${DMG_TITLE} | awk -F\  '{print $NF}'`
        diskutil unmount $disk
    fi
    rm -rf "${DMG_OUT_DIR}/${DMG_NAME}"
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
        -t | --target ) shift
        DEPLOYMENT_TARGET=$1
        ;;
        -o | --dmg-out-dir ) shift
        DMG_OUT_DIR=$1
        ;;
        -c | --conda-file ) shift
        CONDA_REQ_FILE=$1
        ;;
        --with-liblas )
        WITH_LIBLAS=1
        ;;
        -r | --repackage )
        REPACKAGE=1
        ;;
        -u | --update-conda-stable )
        CONDA_UPDATE_STABLE=1
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

# make full path of CONDA_REQ_FILE
CONDA_REQ_FILE=$(cd $(dirname "$CONDA_REQ_FILE") && pwd)/$(basename "$CONDA_REQ_FILE")

if [ ! -f  "${SDK}/SDKSettings.plist" ]; then
    echo "Error, could not find valid MacOS SDK at $SDK"
    display_usage
    exit_nice 1
fi

# if DEPLOYMENT_TARGET hasn't been set, extract from SDK
if [ -z "$DEPLOYMENT_TARGET" ]; then
    DEPLOYMENT_TARGET=`plutil -extract DefaultProperties.MACOSX_DEPLOYMENT_TARGET xml1 \
        -o - $SDK/SDKSettings.plist | awk -F '[<>]' '/string/{print $3}'`
fi

if [ ! -d  "$GRASSDIR" ]; then
    echo "Error, --g argument required, could not find GRASS source directory"
    display_usage
    exit_nice 1
fi

read_grass_version
set_bundle_version

if [ ! -d  "$PATCH_DIR" ]; then
    echo "Error, no patch directory \"$PATCH_DIR\" found"
    exit_nice 1
fi

if [[ ! -z "$DMG_OUT_DIR" && ! -d  "$DMG_OUT_DIR" ]]; then
    echo "Error, dmg output directory \"$DMG_OUT_DIR\" does not exist."
    exit_nice 1
fi

if [[ ! -z "$DMG_OUT_DIR" && -f "${DMG_OUT_DIR}/${DMG_NAME}" ]]; then
    echo "Warning, there exists a dmg file \"${DMG_NAME}\" in \"${DMG_OUT_DIR}\"."
    while true; do
        read -p "Do you wish to delete it (y|n)? " yn
        case $yn in
            [Yy]* ) remove_dmg; break;;
            [Nn]* ) exit_nice 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

if [[ "$REPACKAGE" -eq 1 && ! -d  "$GRASS_APP_BUNDLE" ]]; then
    echo "Error, attempt to repackage a non-existing \"$GRASS_APP_BUNDLE\" app bundle."
    exit_nice 1
fi

# check if destination app bundle exists, with option to cancel if true
if [[ -d  "$GRASS_APP_BUNDLE" && "$REPACKAGE" -eq 0 ]]; then
    echo "Warning, \"$GRASS_APP_BUNDLE\" already exists."
    while true; do
        read -p "Do you wish to delete it (y|n)? " yn
        case $yn in
            [Yy]* ) rm -rf "$GRASS_APP_BUNDLE"; break;;
            [Nn]* ) exit_nice 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

#############################################################################
# Start setting up and compiling procedures
#############################################################################

# only create a new dmg file of existing app bundle
if [[ ! -z "$DMG_OUT_DIR" && "$REPACKAGE" -eq 1 ]]; then
    create_dmg
    exit_nice 0
fi

make_app_bundle_dir

patch_grass

mkdir -p $EXTERNAL_DIR

set_up_conda

install_grass_session

export BUILD_SDK=$SDK
export DEPLOYMENT_TARGET=$DEPLOYMENT_TARGET
export WITH_LIBLAS=$WITH_LIBLAS

if [[ "$WITH_LIBLAS" -eq 1 ]]; then
    source "$THIS_SCRIPT_DIR/default/liblas-install.sh"
fi

# configure and compile GRASS GIS
pushd "$GRASSDIR" > /dev/null

echo "Starting \"make distclean\"..."
make distclean &>/dev/null
echo "Finished \"make distclean\""

source "$THIS_SCRIPT_DIR/default/configure-grass.sh"

make -j$(sysctl -n hw.ncpu) GDAL_DYNAMIC=
if [ $? -ne 0 ]; then
    echo "Compilation failed, you may need to reset the GRASS git repository."
    echo "This can be made with: \"cd [grass-source-dir] && git reset --hard\"."
    echo
    popd > /dev/null
    exit_nice $?
fi

echo
echo "Start installation..."
make install
if [ $? -ne 0 ]; then
    echo "Installation failed, you may need to reset the GRASS git repository."
    echo "This can be made with: \"cd [grass-source-dir] && git reset --hard\"."
    echo
    popd > /dev/null
    exit_nice $?
fi
echo "Finished installation."

popd > /dev/null

# replace SDK with a unversioned one of Command Line Tools
FILE=$GRASS_APP_BUNDLE/Contents/Resources/include/Make/Platform.make
sed -i .bak "s|-isysroot $SDK|-isysroot /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk|g" $FILE
if [ $? -eq 0 ]; then
    rm -f $FILE.bak
fi

# update the stable conda explicit requirement file, this is only allowed if
# default/conda-requirements-dev.txt is used, to keep the two files in sync
if [[ "$CONDA_UPDATE_STABLE" -eq 1 && \
    "$CONDA_REQ_FILE" = "$CONDA_DEV_FILE" ]]; then
    $CONDA_BIN list -p "$GRASS_APP_BUNDLE/Contents/Resources" \
        --explicit > "$CONDA_STABLE_FILE"
fi

# print list of installed packages
echo "================================================================="
echo
$CONDA_BIN list -p "$GRASS_APP_BUNDLE/Contents/Resources"
if [[ "$WITH_LIBLAS" -eq 1 ]]; then
    liblas_version=`$GRASS_APP_BUNDLE/Contents/Resources/bin/liblas-config --version`
    echo "libLAS                    ${liblas_version}"
fi
echo
echo "================================================================="

# create dmg file
if [[ ! -z "$DMG_OUT_DIR" ]]; then
    create_dmg
fi

exit_nice 0 cleanup
