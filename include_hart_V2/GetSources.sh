#!/bin/sh

# sh GetSources.sh <Path to hart-toolbox>

# Note this is not functional for the C-Sources by now.
# Only the interfacing functions can be obtained by
# this Script.

echo "Fetching sources from hart dir" $1

# Get all interfacing functions for the Scicos-Blocks
mkdir macros
cp `find "$1"/macros/palettes -name "*.sci"` macros

# Get all C/C++/h sources
# Need a list of them

# Get all ld-flags and store them into the file LDFLAGS
# ...