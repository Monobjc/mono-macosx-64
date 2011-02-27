#!/bin/bash

#
# Build a Universal 32/64 bist Mono runtime
#
# Copyright (C) 2011 Laurent Etiemble
# This script is put in the public domain.
#

COMMAND=$1
VERSION=2.10.1
RELEASE=3
PACKAGE="$VERSION"_"$RELEASE"

BASE_DIR=`pwd`
MONO_DIR=mono-$VERSION

FILES_DIR="files"
SOURCES_DIR="sources"
BINARIES_DIR="binaries"
MERGE_DIR="merge"

MONO_PREFIX=/Library/Frameworks/Mono.framework/Versions/$VERSION

mkdir -p "$FILES_DIR"
mkdir -p "$SOURCES_DIR"
mkdir -p "$BINARIES_DIR"
mkdir -p "$MERGE_DIR"

# Clean any prior Mono installation
# --------------------------------------------------------------------------------
function clean {
	echo "Cleaning existant Mono installation..."
	sudo rm -Rf "$MONO_PREFIX"
	echo "Done"
}

# Fetch the required files
# --------------------------------------------------------------------------------
function fetch {
	echo "Fetching files..."
	cd "$FILES_DIR"
	
	file="mono-$VERSION.tar.bz2"
	if [ ! -f $file ]; then
		curl "http://ftp.novell.com/pub/mono/sources/mono/$file" > $file
	fi
	file="MonoFramework-$PACKAGE.macos10.novell.universal.dmg"
	if [ ! -f $file ]; then
		curl "http://ftp.novell.com/pub/mono/archive/$VERSION/macos-10-universal/$RELEASE/$file" > $file
	fi
	file="MonoFramework-CSDK-$PACKAGE.macos10.novell.universal.dmg"
	if [ ! -f $file ]; then
		curl "http://ftp.novell.com/pub/mono/archive/$VERSION/macos-10-universal/$RELEASE/$file" > $file
	fi
	
	cd "$BASE_DIR"
	echo "Done"
}

# Uncompress the sources
# --------------------------------------------------------------------------------
function unarchive {
	echo "Unarchiving..."
	cd "$SOURCES_DIR"
	if [ ! -d "$MONO_DIR" ]; then
		tar -jxf "../$FILES_DIR/$MONO_DIR.tar.bz2"
	fi
	cd "$BASE_DIR"
	echo "Done"
}

# Build Mono runtime and install it in a temporary location
# --------------------------------------------------------------------------------
function build {
	echo "Building..."
	cd "$SOURCES_DIR/$MONO_DIR"
	./configure --prefix "$MONO_PREFIX" --with-glib=embedded --disable-nls --disable-mcs-build --host=x86_64-apple-darwin10
	make
	sudo make install
	cd "$BASE_DIR"
}

# Copy only the Mach-O binaries
# --------------------------------------------------------------------------------
function copy {
	rm -Rf "$BINARIES_DIR"
	FILES=`find "$MONO_PREFIX" -type f`
	for file in $FILES; do
		macho=`file $file | grep -l "Mach-O"`
		if [ "x$macho" != "x" ]; then
			echo "Copying $file"
			dir=`dirname $file | sed -e "s|$MONO_PREFIX/||"`
			name=`basename $file`
			mkdir -p "$BINARIES_DIR/$dir"
			cp "$file" "$BINARIES_DIR/$dir/$name"
		fi
	done
}

# Install the runtime and the CSDK
# --------------------------------------------------------------------------------
function install {
	cd "$FILES_DIR"
	volume="/Volumes/MonoFramework-$VERSION"
	hdiutil detach "$volume"
	file="MonoFramework-$PACKAGE.macos10.novell.universal"
	hdiutil attach "$file.dmg"
	sudo installer -pkg "$volume/$file.pkg" -target "/"
	hdiutil detach "$volume"
	
	volume="/Volumes/MonoFramework-CSDK-$VERSION"
	hdiutil detach "$volume"
	file="MonoFramework-CSDK-$PACKAGE.macos10.novell.universal"
	hdiutil attach "$file.dmg"
	sudo installer -pkg "$volume/$file.pkg" -target "/"
	hdiutil detach "$volume"
	cd "$BASE_DIR"
}

# Merge the Mach-O binaries and replace the original
# --------------------------------------------------------------------------------
function merge {
	rm -Rf "$MERGE_DIR"
	FILES=`find "$BINARIES_DIR" -type f`
	for file in $FILES; do
		echo "Merging $file"
		dir=`dirname $file | sed -e "s|$BINARIES_DIR/||"`
		name=`basename $file`
		mkdir -p "$MERGE_DIR/$dir"
		lipo -create "$MONO_PREFIX/$dir/$name" "$BINARIES_DIR/$dir/$name" -output "$MERGE_DIR/$dir/$name"
		sudo cp "$MERGE_DIR/$dir/$name" "$MONO_PREFIX/$dir/$name"
	done
}

# Main entry point
# --------------------------------------------------------------------------------
case "$COMMAND" in

	clean)
		clean
		;;
    fetch)
        fetch
        ;;
    unarchive)
        unarchive
        ;;
    build)
        build
        ;;
	copy)
		copy
		;;
	install)
		install
		;;
	merge)
		merge
		;;

    *)
		echo "usage: $0 (clean|fetch|unarchive|build|copy|install|merge)"
        exit 1
        ;;

esac
