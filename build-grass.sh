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
THIS_SCRIPT_DIR=$(cd $(dirname "$0"); pwd)
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
CONDA_ENV=
CONDA_REQ_FILE="${THIS_SCRIPT_DIR}/conda-requirements.txt"
DMG_TITLE=
DMG_NAME=
DMG_OUT_DIR=
BUNDLE_VERSION=
REPACKAGE=0
MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh"

# read in configurations
. "${THIS_SCRIPT_DIR}/configure-build.sh"

#############################################################################
# Functions
#############################################################################

function display_usage () { cat <<- _EOF_

GRASS GIS build script for Anaconda.

Description...

Usage:  $THIS_SCRIPT [arguments]
Arguments:
  -g
  --grassdir    [path] GRASS GIS source directory, required, spaces in path not
                       allowed
  -s
  --sdk         [path] MacOS SDK - full path to the SDK, which will be set as
                       -isysroot, required, spaces in path not allowed
  -t
  --target             Set deployment target version (MACOSX_DEPLOYMENT_TARGET),
                       e.g. "10.14", optional, default is set from SDK
  -c
  --conda-env          Conda environment name, required
  -o
  --dmg-out-dir [path] Output directory path for DMG file creation
                       This is a requirement for creating .dmg files.
  -r
  --repackage          Recreate dmg file from previously built app,
                       setting [-o | --dmg-out-dir] is a requirement.
  -h
  --help               Usage information

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
    DMG_NAME="grass-${GRASS_VERSION}.dmg"
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
    mkdir -p -m 0755 "$contents_dir"
    mkdir -m 0755 "$resources_dir"
    mkdir -m 0755 "$macos_dir"

    sed "s|@GRASS_VERSION_DATE@|$GRASS_VERSION_DATE|g" \
        "$THIS_SCRIPT_DIR/files/Info.plist.in" | \
        sed "s|@GRASS_VERSION_MAJOR@|$GRASS_VERSION_MAJOR|g" | \
        sed "s|@GRASS_VERSION_MINOR@|$GRASS_VERSION_MINOR|g" | \
        sed "s|@GRASS_VERSION_RELEASE@|$GRASS_VERSION_RELEASE|g" | \
        sed "s|@BUNDLE_VERSION@|$BUNDLE_VERSION|g" | \
        sed "s|@DEPLOYMENT_TARGET@|$DEPLOYMENT_TARGET|g" \
            > "$contents_dir/Info.plist"

    sed "s|@GRASSBIN@|grass$GRASS_VERSION_MAJOR$GRASS_VERSION_MINOR|g" \
        "$THIS_SCRIPT_DIR/files/Grass.sh.in" > "$macos_dir/Grass.sh"
    cp -p "$GRASSDIR/macosx/app/build_gui_user_menu.sh" \
        "$macos_dir/build_gui_user_menu.sh"
    cp -p "$GRASSDIR/macosx/app/build_html_user_index.sh" \
        "$macos_dir/build_html_user_index.sh"
    cp -p "$THIS_SCRIPT_DIR/files/Grass" "$macos_dir/Grass"
    if [ "$GRASS_VERSION" = "7.8.3" ]; then
        cp -p "$THIS_SCRIPT_DIR/files/AppIcon.icns" "$resources_dir/AppIcon.icns"
    else
        cp -p "$GRASSDIR/macosx/app/app.icns" "$resources_dir/AppIcon.icns"
    fi
    cp -p "$THIS_SCRIPT_DIR/files/GRASSDocument_gxw.icns" \
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
    # download miniconda if not already existing
    local miniconda="$THIS_SCRIPT_DIR/miniconda3.sh"
    if [ ! -f "$miniconda" ]; then
        curl "$MINICONDA_URL" --output "$miniconda"
        [ $? -ne 0 ] && exit_nice $? cleanup
    fi

    if [ ! -f "$(conda info --base)/etc/profile.d/conda.sh" ]; then
        echo "Error: failed to locate the file \"/etc/profile.d/conda.sh\" in conda base \"$(conda info --base)\""
        exit_nice 1 cleanup
    fi

    # a hack, this is needed to enable `conda activate` in bash script
    # see https://github.com/conda/conda/issues/7980
    . $(conda info --base)/etc/profile.d/conda.sh
    conda activate $CONDA_ENV
    [ $? -ne 0 ] && exit_nice $? cleanup

    $BASH "$miniconda" -b -f -p "$GRASS_APP_BUNDLE/Contents/Resources"
    export PATH="$GRASS_APP_BUNDLE/Contents/Resources/bin:$PATH"
    conda install --yes -p "$GRASS_APP_BUNDLE/Contents/Resources" \
        --file=$CONDA_REQ_FILE -c conda-forge
    [ $? -ne 0 ] && exit_nice $? cleanup
}

function create_dmg () {
    echo
    echo "Create dmg file of $GRASS_APP_BUNDLE ..."

    if [ ! -d  "$GRASS_APP_BUNDLE" ]; then
        echo "Error, attempt to create dmg file, but no app could be found"
        exit_nice 1
    fi

    local tmpdir=`mktemp -d /tmp/org.osgeo.grass.XXXXXX`
    local dmg_tmpfile=grass-tmp-$$.dmg
    local exact_app_size=`du -ks $GRASS_APP_BUNDLE | cut -f 1`
    local dmg_size=$((exact_app_size*115/100))

    sudo hdiutil create -srcfolder $GRASS_APP_BUNDLE \
        -volname $DMG_TITLE \
        -fs HFS+ \
        -fsargs "-c c=64,a=16,e=16" \
        -format UDRW \
        -size ${dmg_size}k "${tmpdir}/${dmg_tmpfile}"

    if [ $? -ne 0 ]; then
        rm -rf $tmpdir
        exit_nice $?
    fi

    DEVICE=`sudo hdiutil attach -readwrite -noverify -noautoopen "${tmpdir}/${dmg_tmpfile}" | egrep '^/dev/' | sed -e "s/^\/dev\///g" -e 1q  | awk '{print $1}'`
    sudo hdiutil attach "${tmpdir}/${dmg_tmpfile}" || error "Can't attach temp DMG"

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

    hdiutil convert "${tmpdir}/${dmg_tmpfile}" \
        -format UDZO -imagekey zlib-level=9 -o "${DMG_OUT_DIR}/${DMG_NAME}"

    if [ $? -ne 0 ]; then
        rm -rf $tmpdir
        exit_nice $?
    fi

    rm -rf $tmpdir
    echo
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
        -o | --dmg-out-dir ) shift
        DMG_OUT_DIR=$1
        ;;
        -r | --repackage )
        REPACKAGE=1
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
            [Yy]* ) rm -rf "${DMG_OUT_DIR}/${DMG_NAME}"; break;;
            [Nn]* ) exit_nice 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

if [[ "$REPACKAGE" -eq 1 && ! -d  "$GRASS_APP_BUNDLE" ]]; then
    echo "Error, attempt to repackage a non-existing \"$GRASS_APP_BUNDLE\" app bundle."
    exit_nice 1
fi

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

set_up_conda

# fix for miniconda python.app installer bug
if [[ -d $GRASS_APP_BUNDLE/Contents/Resources/python.app/pythonapp/Contents ]]; then
    mv $GRASS_APP_BUNDLE/Contents/Resources/python.app/pythonapp/Contents/* \
        $GRASS_APP_BUNDLE/Contents/Resources/python.app/Contents
    rm -rf $GRASS_APP_BUNDLE/Contents/Resources/python.app/pythonapp
fi

# configure and compile GRASS GIS
pushd "$GRASSDIR" > /dev/null

echo "Starting \"make distclean\"..."
make distclean &>/dev/null
echo "Finished \"make distclean\""

export BUILD_SDK=$SDK
export DEPLOYMENT_TARGET=$DEPLOYMENT_TARGET
. "$THIS_SCRIPT_DIR/configure-grass.sh"

make -j$(sysctl -n hw.ncpu) GDAL_DYNAMIC=

echo
echo "Start installation..."
make install
echo "Finished installation."

popd > /dev/null

# replace SDK with a unversioned one of Command Line Tools
FILE=$GRASS_APP_BUNDLE/Contents/Resources/include/Make/Platform.make
sed -i .bak "s|-isysroot $SDK|-isysroot /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk|g" $FILE
if [ $? -eq 0 ]; then
    rm -f $FILE.bak
fi

# save some disk space
rm -rf $GRASS_APP_BUNDLE/Contents/Resources/build-1
rm -rf $GRASS_APP_BUNDLE/Contents/Resources/conda-meta
rm -rf $GRASS_APP_BUNDLE/Contents/Resources/condabin
rm -rf $GRASS_APP_BUNDLE/Contents/Resources/envs
rm -rf $GRASS_APP_BUNDLE/Contents/Resources/pkgconfig
rm -rf $GRASS_APP_BUNDLE/Contents/Resources/pkgs
rm -rf $GRASS_APP_BUNDLE/Contents/Resources/shell
rm -rf $GRASS_APP_BUNDLE/Contents/Resources/var

# create dmg file
if [[ ! -z "$DMG_OUT_DIR" ]]; then
    create_dmg
fi

exit_nice 0 cleanup
