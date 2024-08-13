#!/bin/bash

# When building the site DO NOT copy the archived files, as this can take a LOT of space.

echo "Building site"
# Removing any old build files
rm -rf ../build
mkdir ../build
# Copying the site files into the build directory
echo "Copying site files"
cp -rf ./site/* ../build
echo "Copied site files"
# Generating the XML (usually 200KB)
echo "Generating Archive XML"
bash ./build-xml.sh
echo "Generated Archive XML"
echo "Built site"