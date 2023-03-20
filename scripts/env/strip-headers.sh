#!/bin/sh

SCRIPT_DIR=`dirname $0`

# For each text file in current directory (recursively)
for f in `grep -rIl . | grep -v .git`; do

    # Execute awk script to strip known copyright headers
    awk -f $SCRIPT_DIR/strip-header.awk $f > $f.noheaders

    # Check whether modification is required
    if cmp --silent $f $f.noheaders; then
        # If not, delete temporary file
        rm $f.noheaders
    else
        # If so, copy temporary file to original file, preserving permissions
        chmod --reference=$f $f.noheaders
        mv $f.noheaders $f
        echo "Deleted header for $f..."
    fi
done
