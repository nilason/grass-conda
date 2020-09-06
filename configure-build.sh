#!/bin/bash

# full path to the SDK to build with
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX10.14.sdk"

# setting DEPLOYMENT_TARGET here is optional (MACOSX_DEPLOYMENT_TARGET
# of the SDK is the default) this will set MACOSX_DEPLOYMENT_TARGET
# DEPLOYMENT_TARGET=10.14

# full path to GRASS GIS source directory
GRASSDIR=""

# setting CONDA_REQ_FILE here is optional (default/conda-requirements-stable.txt
# is used by default)
# CONDA_REQ_FILE="${THIS_SCRIPT_DIR}/default/conda-requirements-dev.txt"
