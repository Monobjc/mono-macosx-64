#!/bin/bash

#
# Build a 32/64 bits Mono runtime
#
# Copyright (C) 2011 Laurent Etiemble
# This script is in the public domain.
#

COMMAND=$1
VERSION=$2
RELEASE=$3

if [ "x$VERSION" == "x" ]; then
    VERSION=2.11
fi
if [ "x$RELEASE" == "x" ]; then
    RELEASE=0
fi

if [ "x$RELEASE" == "x0" ]; then
	PACKAGE="$VERSION"
	FULLVERSION="$VERSION.0"
else
	PACKAGE="$VERSION"_"$RELEASE"
	FULLVERSION="$VERSION"
fi

BASE_DIR=`pwd`
MONO_DIR="mono-$VERSION"

BINARIES_DIR="binaries"
CONTENT_DIR="content"
DMG_DIR="dmg"
FILES_DIR="files"
MERGE_DIR="merge"
PACKAGE_DIR="package"
SOURCES_DIR="sources"

MONO_FRAMEWORK="/Library/Frameworks/Mono.framework"
MONO_PREFIX="$MONO_FRAMEWORK/Versions/$VERSION"

mkdir -p "$BINARIES_DIR"
mkdir -p "$FILES_DIR"
mkdir -p "$MERGE_DIR"
mkdir -p "$SOURCES_DIR"

# Clobber all uneeded folder
# --------------------------------------------------------------------------------
function clobber {
	rm -Rf binaries
	rm -Rf content
	rm -Rf dmg
	rm -Rf merge
	echo "Done"
}

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
	
	file="mono-$FULLVERSION.tar.bz2"
	url="http://download.mono-project.com/sources/mono/$file"
	echo "Probing $file ($url)"
	if [ ! -f $file ]; then
		curl "$url" > $file
	fi
	
	file="MonoFramework-MDK-$PACKAGE.macos10.xamarin.x86.dmg"
	if [ "x$RELEASE" == "x0" ]; then
		url="http://download.mono-project.com/archive/$FULLVERSION/macos-10-x86/$file"
	else
		url="http://download.mono-project.com/archive/$FULLVERSION/macos-10-x86/$RELEASE/$file"
	fi
	
	echo "Probing $file ($url)"
	if [ ! -f $file ]; then
		curl "$url" > $file
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
		tar -zxf "../$FILES_DIR/mono-$FULLVERSION.tar.bz2"
	fi
	cd "$BASE_DIR"
	echo "Done"
}

# Build Mono runtime and install it in a temporary location
# --------------------------------------------------------------------------------
function build {
	echo "Building..."
	cd "$SOURCES_DIR/$MONO_DIR"
	
	#
	# Uncomment the following if you want to override flags
	#
	# DARWIN_FLAGS="-arch x86_64 -D_XOPEN_SOURCE -mmacosx-version-min=10.5"
	# DARWIN_FLAGS="-arch x86_64 -mmacosx-version-min=10.6"
	# DARWIN_FLAGS="-arch x86_64 -mmacosx-version-min=10.5"
	#
	# CPPFLAGS="$CPPFLAGS $DARWIN_FLAGS" \
	# CFLAGS="$CFLAGS $DARWIN_FLAGS" \
	# CXXFLAGS="$CXXFLAGS $DARWIN_FLAGS" \
	# CCASFLAGS="$CCASFLAGS $DARWIN_FLAGS" \
	# CPPFLAGS_FOR_LIBGC="$CPPFLAGS_FOR_LIBGC $DARWIN_FLAGS" \
	# CFLAGS_FOR_LIBGC="$CFLAGS_FOR_LIBGC $DARWIN_FLAGS" \
	# CPPFLAGS_FOR_EGLIB="$CPPFLAGS_FOR_EGLIB $DARWIN_FLAGS" \
	# CFLAGS_FOR_EGLIB="$CFLAGS_FOR_EGLIB $DARWIN_FLAGS" \
	#	
	./configure --prefix "$MONO_PREFIX" --disable-nls --disable-mcs-build --host=x86_64-apple-darwin
	
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

# Install the MDK
# --------------------------------------------------------------------------------
function install {
	cd "$FILES_DIR"

    volume="/Volumes/MonoFramework-MDK-$VERSION"
    if [ ! -d "$volume" ]; then
        volume="/Volumes/MonoFramework MDK $VERSION"
    fi
    if [ ! -d "$volume" ]; then
        volume="/Volumes/Mono Framework MDK $VERSION"
    fi

    hdiutil detach "$volume"

    file="MonoFramework-MDK-$PACKAGE.macos10.xamarin.x86"
    hdiutil attach "$file.dmg"

    volume="/Volumes/MonoFramework-MDK-$VERSION"
    if [ ! -d "$volume" ]; then
        volume="/Volumes/MonoFramework MDK $VERSION"
    fi
    if [ ! -d "$volume" ]; then
        volume="/Volumes/Mono Framework MDK $VERSION"
    fi

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

# Package the Mono framework
# --------------------------------------------------------------------------------
function package {
    rm -Rf "$CONTENT_DIR"
    mkdir -p "$CONTENT_DIR/Versions/$VERSION"
    cp -R "$MONO_PREFIX/" "$CONTENT_DIR/Versions/$VERSION/"

    # Create the symlinks
    cd "$CONTENT_DIR"
    ln -s "Versions/Current/bin" "Commands"
    ln -s "Versions/Current/include" "Headers"
    ln -s "Versions/Current" "Home"
    ln -s "Versions/Current/lib" "Libraries"
    ln -s "Libraries/libmono-2.0.dylib" "Mono"
    ln -s "Versions/Current/Resources" "Resources"
    cd -
    cd "$CONTENT_DIR/Versions"
    ln -s "$VERSION" "Current"
    cd -

    # Create the installer
    cd "$PACKAGE_DIR"
    PMDOC="MonoMDK-$PACKAGE.pmdoc"
    mkdir -p "$PMDOC"
    cat "ReadMe.rtf" | sed -e "s/@@MONO_VERSION_RELEASE@@/$PACKAGE/g" > "ReadMe-$PACKAGE.rtf"
    cat "Welcome.rtf" | sed -e "s/@@MONO_VERSION_RELEASE@@/$PACKAGE/g" > "Welcome-$PACKAGE.rtf"
    FILES=`ls MonoMDK.pmdoc`;
    for file in $FILES; do
        cat "MonoMDK.pmdoc/$file" | sed \
        -e "s/@@MONO_VERSION_RELEASE@@/$PACKAGE/g" \
        -e "s/>ReadMe.rtf</>ReadMe-$PACKAGE.rtf</g" \
        -e "s/>Welcome.rtf</>Welcome-$PACKAGE.rtf</g" \
        > "$PMDOC/$file"
    done
    cd -

    rm -Rf "$DMG_DIR"
    mkdir -p "$DMG_DIR"
    file="MonoFramework-MDK-$PACKAGE.macos10.monobjc.universal"

    # Create the installer package
    /Developer/usr/bin/packagemaker --verbose --doc "$PACKAGE_DIR/$PMDOC" -o "$DMG_DIR/$file.pkg"

    # Create the disk image
    rm -Rf "$FILES_DIR/$file.dmg"
    hdiutil create "$FILES_DIR/$file.dmg" -volname "MonoFramework-MDK-$VERSION" -fs HFS+ -srcfolder "$DMG_DIR"
}

# Main entry point
# --------------------------------------------------------------------------------
case "$COMMAND" in

	clobber)
		clobber
		;;
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

    package)
        package
        ;;

    all)
        clean
        fetch
        unarchive
        build
        copy
        install
        merge
        package
        ;;

    *)
		echo "usage: $0 (all|clobber|clean|fetch|unarchive|build|copy|install|merge|package) [version] [build]"
        exit 1
        ;;

esac
