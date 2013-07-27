###############################################################################
##                                                                           ##
## Build a 32/64 bits Mono runtime                                           ##
##                                                                           ##
## This script is in the public domain.                                      ##
## Creator     : Laurent Etiemble                                            ##
## Contributors: Dimitar Dobrev                                              ##
##                                                                           ##
###############################################################################

VERSION?=3.2.0
RELEASE?=0
KIND?=MDK
BUILDER?=monobjc
CERTIFICATE?=Developer ID Installer: Laurent Etiemble

## --------------------
## Variables
## --------------------

# Directory variables
PACKAGE_DIR=package
FILES_DIR=files
WORK_DIR=work
SCRIPT_DIR=$(PACKAGE_DIR)/scripts
BINARIES_DIR=$(WORK_DIR)/binaries
CONTENT_DIR=$(WORK_DIR)/content
MERGE_DIR=$(WORK_DIR)/merge
EXPAND_DIR=$(WORK_DIR)/temp
WORK_DIRS=$(SCRIPT_DIR) $(BINARIES_DIR) $(MERGE_DIR)
ALL_DIRS=$(FILES_DIR) $(WORK_DIRS)

# Build Markers
MARKER_CONFIGURE=$(WORK_DIR)/.configure
MARKER_MAKE=$(WORK_DIR)/.make
MARKER_INSTALL=$(WORK_DIR)/.install

# Mono.framework variables
MONO_FRAMEWORK=/Library/Frameworks/Mono.framework
MONO_PREFIX=$(MONO_FRAMEWORK)/Versions/$(VERSION)
MONO_BINARIES= \
	$(subst $(MONO_PREFIX)/,, \
		$(wildcard $(MONO_PREFIX)/bin/*) \
		$(wildcard $(MONO_PREFIX)/lib/*) \
	)

# Mono sources and package
MONO_URL=http://download.mono-project.com
MONO_ARCHIVE_FILE=mono-$(VERSION).tar.bz2
MONO_ARCHIVE_URL=$(MONO_URL)/sources/mono/$(MONO_ARCHIVE_FILE)
MONO_ARCHIVE_PATH=$(FILES_DIR)/$(MONO_ARCHIVE_FILE)
ifeq ($(RELEASE),0)
	MONO_PACKAGE_FILE=MonoFramework-$(KIND)-$(VERSION).macos10.xamarin.x86.pkg
	MONO_PACKAGE_URL=$(MONO_URL)/archive/$(VERSION)/macos-10-x86/$(MONO_PACKAGE_FILE)
else
	MONO_PACKAGE_FILE=MonoFramework-$(KIND)-$(VERSION)_$(RELEASE).macos10.xamarin.x86.pkg
	MONO_PACKAGE_URL=$(MONO_URL)/archive/$(VERSION)/macos-10-x86/$(MONO_PACKAGE_FILE)
endif
MONO_SOURCE_DIR=$(FILES_DIR)/mono-$(VERSION)

# Mono installer
MONO_PACKAGE_PATH=$(FILES_DIR)/$(MONO_PACKAGE_FILE)
MONO_PACKAGE_RESOURCES=License.rtf postinstall ReadMe.rtf Welcome.rtf whitelist.txt

# Universal content, installer and package
UNIVERSAL_PACKAGE_TEMPLATE=$(PACKAGE_DIR)/MonoMDK.pmdoc
UNIVERSAL_PACKAGE_TEMPLATE_FILES=$(wildcard $(UNIVERSAL_PACKAGE_TEMPLATE)/*.xml)
UNIVERSAL_PACKAGE_DESCRIPTOR=$(PACKAGE_DIR)/MonoMDK-$(VERSION).pmdoc
UNIVERSAL_PACKAGE_FILE=$(subst xamarin.x86,$(BUILDER).universal,$(MONO_PACKAGE_FILE))
UNIVERSAL_PACKAGE_PATH=$(FILES_DIR)/$(UNIVERSAL_PACKAGE_FILE)

## --------------------
## Targets
## --------------------

# Perform all the construction process
all: \
	prepare \
	fetch-files \
	wipe-mono \
	build-sources \
	copy-binaries \
	install-mono \
	merge-binaries \
	build-package \
	finish

# Remove the directories
clean:
	rm -Rf $(WORK_DIR)

# Prepare the directories
prepare: $(ALL_DIRS)

$(ALL_DIRS):
	mkdir -p "$@"

# Fetch the Mono files (sources and installer)
fetch-files: prepare $(MONO_ARCHIVE_PATH) $(MONO_PACKAGE_PATH)

$(MONO_ARCHIVE_PATH):
	curl "$(MONO_ARCHIVE_URL)" > "$(MONO_ARCHIVE_PATH)"

$(MONO_PACKAGE_PATH):
	curl "$(MONO_PACKAGE_URL)" > "$(MONO_PACKAGE_PATH)"

# Extract the Mono sources
unarchive-sources: fetch-files $(MONO_SOURCE_DIR)

$(MONO_SOURCE_DIR):
	(cd "$(FILES_DIR)"; tar -jxf "../$(MONO_ARCHIVE_PATH)");

# Remove the Mono framework
wipe-mono:
	sudo rm -Rf "$(MONO_FRAMEWORK)"

# Build the Mono runtime targeting x86_64 architecture
build-sources: unarchive-sources $(MARKER_CONFIGURE) $(MARKER_MAKE) $(MARKER_INSTALL)

$(MARKER_CONFIGURE):
	(cd "$(MONO_SOURCE_DIR)"; ./configure --prefix "$(MONO_PREFIX)" --host=x86_64-apple-darwin --disable-nls --disable-mcs-build);
	touch "$(MARKER_CONFIGURE)"

$(MARKER_MAKE):
	(cd "$(MONO_SOURCE_DIR)"; make);
	touch "$(MARKER_MAKE)"

$(MARKER_INSTALL):
	(cd "$(MONO_SOURCE_DIR)"; sudo make install);
	touch "$(MARKER_INSTALL)"

# Copy only the x86_64 Mach-O binaries
copy-binaries:
	for i in $(MONO_BINARIES); do \
		check=`file -h "$(MONO_PREFIX)/$$i"`; \
		if [[ "$$check" =~ .*(Mach-O|random library).* ]]; then \
			mkdir -p "$(BINARIES_DIR)/`dirname $$i`"; \
			cp "$(MONO_PREFIX)/$$i" "$(BINARIES_DIR)/$$i"; \
		fi; \
	done;

# Install the Mono framework
install-mono:
	sudo installer -pkg "$(MONO_PACKAGE_PATH)" -target "/"

# Merge the x86_64 Mach-O binaries with their i386 counterpart and copy the result back in place
merge-binaries:
	files=`cd "$(BINARIES_DIR)" && find . -type f`; \
	for i in $$files; do \
		echo "$$i"; \
		mkdir -p "$(MERGE_DIR)/`dirname $$i`"; \
		lipo -create "$(MONO_PREFIX)/$$i" "$(BINARIES_DIR)/$$i" -output "$(MERGE_DIR)/$$i"; \
		sudo cp -f "$(MERGE_DIR)/$$i" "$(MONO_PREFIX)/$$i"; \
	done;

# Build the universal installer
build-package:
	# Expand package to retrieve support files
	rm -Rf "$(EXPAND_DIR)"
	pkgutil --expand "$(MONO_PACKAGE_PATH)" "$(EXPAND_DIR)"
	
	# Copy package resources
	for i in $(MONO_PACKAGE_RESOURCES); do \
		cp -f "$(EXPAND_DIR)/mono.pkg/Scripts/$$i" "$(PACKAGE_DIR)/$$i"; \
	done;
	mkdir -p "$(SCRIPT_DIR)"
	cp -f "$(PACKAGE_DIR)/postinstall" "$(SCRIPT_DIR)/"
	cp -f "$(PACKAGE_DIR)/whitelist.txt" "$(SCRIPT_DIR)/"
	
	# Link to the framework content
	rm -Rf "$(CONTENT_DIR)"
	ln -sF "$(MONO_FRAMEWORK)" "$(CONTENT_DIR)"
	
	# Create the package descriptor
	mkdir -p "$(UNIVERSAL_PACKAGE_DESCRIPTOR)"
	for i in $(UNIVERSAL_PACKAGE_TEMPLATE_FILES); do \
		echo $$i; cat "$$i" | sed \
			-e 's/@@CERTIFICATE@@/$(CERTIFICATE)/g' \
			-e 's/@@MONO_VERSION_RELEASE@@/$(VERSION)/g' \
			> "$(UNIVERSAL_PACKAGE_DESCRIPTOR)/`basename $$i`"; \
	done;
	
	# Build the installer
	"/Developer/Applications/Utilities/PackageMaker.app/Contents/MacOS/PackageMaker" --verbose --doc "$(UNIVERSAL_PACKAGE_DESCRIPTOR)" -o "$(UNIVERSAL_PACKAGE_PATH)"

# Finish the construction
finish:

## --------------------
## Phony Targets
## --------------------

.PHONY: \
	all \
	clean \
	prepare \
	fetch-files \
	wipe-mono \
	build-sources \
	copy-binaries \
	install-mono \
	merge-binaries \
	build-package \
	finish
