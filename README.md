# Mono Sixty-Four

This project contains a tool to build a Universal 32/64 bits Mono runtime for Mac OS X.

## How it works

This tool builds a full Universal 32/64 bits Mono runtime in a smart way:

- it builds a minimal 64 bits Mono runtime
- it install a full Universal 32 bits Mono runtime
- it merges the minimal 64 bits Mono runtime into the Universal 32 bits one

<img src="https://github.com/letiemble/Mono-Sixty-Four/raw/master/overview.png" alt="How it works" title="How it works" align="center" />

The result is a usable Universal 32/64 bits Mono runtime where all the Mono binaries 
supports three architecture.

## Requirements

In order to use this tool, here are the requirements:

- XCode tools (3.2+)
- A ton of patience

## How to use

> Beware that the scripts needs to wipe the installed Mono runtime.
> This MEANS that if you have installed a Mono runtime, it has to be wiped
> in order for the tool to work. You can of course re-install it later.

The use is pretty rougth, as the purpose is to be efficient. The script can be called
by steps, in order to be fine-grained.

The usage is:

	$ build.sh <step>

The steps to run in order are:

1. **clean** : This step wipes the existing installation of Mono.
2. **fetch** : This step dowloads the required files from the Mono server.
3. **unarchive** : This step uncompress the Mono sources.
4. **build** : This step build the 64 bits minimal Mono runtime and install it in place.
5. **copy** : This step copies the Mach-O binaries from the 64 bits minimal Mono runtime.
6. **install** : This step installs the Universal 32 bits Mono runtime
7. **merge** : This step takes the 64 bits binaries and merge them into the Mono runtime.
