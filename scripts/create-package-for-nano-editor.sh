#!/bin/bash

set -u; # Exit when uninitialised variable is used
set -e; # Exit when any command fails - http://mywiki.wooledge.org/BashFAQ/105

# Official GNU nano documentation: https://www.nano-editor.org/docs.php

# Disclaimer:
# Package created by this script does not meet all requirements of a sensible
# debian package and thus should not be distributed. CheckInstall keeps track
# of all the files created or modified by the installation script. However,
# it does not list or track its dependencies.

# Clarification of strip and stripso options in checkinstall:
# Stripping binaries/executables means that debug sections are not included.
# Debug section helps with eventual debugging that may be needed. Modern dynamic
# loaders typically ensure that debug code is not loaded during normal execution.

readonly URL='https://www.nano-editor.org/dist/v5/nano-5.4.tar.gz';
FILE_NAME=${URL##*/}; # nano-x.y.z.tar.gz
readonly DIR_NAME=${FILE_NAME%.tar.*}; # nano-x.y.z
readonly VERSION=${DIR_NAME##*-}; # x.y.z


function check_continue_permission
{
    read -r -p 'Do you want to continue (y/n)? ' answer;

    # Trim whitespaces
    answer=$(xargs <<< $answer);

    # Convert character(s) to lowercase
    answer=${answer,,};

    # Proceed only when the input is y(es)
    [[ ! $answer =~ ^y(es)?$ ]] && exit 0;

    unset answer;
}


function check_prerequisites
{
    local -i status=0;

    if [[ ! $FILE_NAME =~ ^nano[-_]([[:digit:]]+\.){2,3}tar\.[gx]z$ ]]
    then
        echo 'File with nano source must be either .tar.gz or .tar.xz archive';
        ((++status));
    fi

    for cmd in checkinstall gcc
    do
        if [ -z "$(which $cmd)" ]
        then
            echo "-- Missing requirement: $cmd";
            ((++status));
        fi
    done

    # Proceed only when all requirements are met
    [ $status -ne 0 ] && exit 0;

    unset status cmd;
}


function clean_files
{
    [ -f ./Makefile ] && make --quiet clean;
    [ "$(basename $PWD)" == "$DIR_NAME" ] && cd ..;
    [ -f $FILE_NAME ] && rm --force --verbose $FILE_NAME;
    [ -d $DIR_NAME ] && rm --force --recursive $DIR_NAME && echo "Removed $DIR_NAME directory";
}


echo "Running $(basename $0) with pid $$ in cwd $(pwd)/";
echo "This script will create a package from source for GNU nano text editor version $VERSION";
check_continue_permission;
check_prerequisites;

# Download the source code
if [ -f $FILE_NAME -a -s $FILE_NAME ]
then
    echo "File already downloaded: $FILE_NAME";
    if [ ! -r $FILE_NAME ]
    then
        echo 'No read permission';
        ls -lh | grep --color $FILE_NAME;
        exit 0;
    fi
elif [ -n "$(which wget)" ]
then
    wget --no-verbose --tries=6 --output-document=$FILE_NAME --show-progress --timeout=16 $URL;
else
    curl --silent --show-error --retry 6 --output $FILE_NAME --connect-timeout 16 $URL;
fi

# Unpack the source, do not show the list of extracted files
if [[ ${FILE_NAME: -3} == '.gz' ]]
then
    tar -zxf $FILE_NAME || gzip --decompress --stdout $FILE_NAME | tar --extract --file -;
else
    tar -Jxf $FILE_NAME || unxz --decompress $FILE_NAME | tar --extract --file -;
fi

# Descriptions are taken from the official documentation. For more information:
# - visit https://www.nano-editor.org/dist/v5/nano.html#Building-and-Configure-Options
# - type "./configure --help"
readonly CONFIGURE_ARG_LIST=(
#   --no-create            # Only check dependencies
    --quiet                # Show only errors and warnings
    --disable-dependency-tracking # Speed up one-time build by rejecting slow dependency extractors
    --prefix='/usr/local'  # Installation location for architecture-independent files, default is /usr/local/
    --disable-largefile    # Omit support for large files
#   --disable-threads      # Build without multithread safety
#   --disable-rpath        # Do not hardcode runtime library paths
    --disable-browser      # Disable the built-in file browser
#   --disable-color        # Disable color and syntax highlighting
#   --disable-comment      # Disable the comment/uncomment function
    --disable-extra        # Disable the Easter egg
    --disable-help         # Disable the built-in help texts
    --disable-histories    # Disable search and position histories
#   --disable-justify      # Disable the justify/unjustify functions
#   --disable-libmagic     # Disable detection of file types via libmagic
#   --disable-linenumbers  # Disable line numbering
    --disable-mouse        # Disable mouse support
    --disable-multibuffer  # Disable multiple file buffers
#   --disable-nanorc       # Disable the use of .nanorc files
    --disable-operatingdir # Disable the setting of an operating directory
    --disable-speller      # Disable the spell-checker functions
    --disable-tabcomp      # Disable the tab-completion functions
    --disable-wordcomp     # Disable the word-completion function
    --disable-wrapping     # Disable all hard-wrapping of text
    --disable-nls          # Disable internationalization, do not use Native Language Support
);

if [ -n "$(which git)" ]
then
    USER="$(git config user.email)";
fi

# Assign the current user name if git is not installed or email address is not configured
USER=${USER:-"$(whoami)"};

# Descriptions are taken from the manual
# Default config file: /etc/checkinstallrc
readonly CHECKINSTALL_ARG_LIST=(
    --type='debian'       # Create a Debian package
    --install=no          # Toggle installation of the created package
    --default             # Accept default answers to all questions
    --pkgname='nano'      # Set the package name
    --pkgversion=$VERSION # Set the package version
    --pakdir='../'        # Where to save the new package
    --maintainer=$USER    # Set the package maintainer
    --pkglicense='GPLv3'  # Set the package license
#   --nodoc               # Do not include documentation files
    --showinstall=no      # Toggle interactive install command
    --autodoinst=no       # Toggle creation of a "doinst.sh" script
    --strip=yes           # Toggle stripping any ELF binaries found inside the package
    --stripso=yes         # Toggle stripping any ELF libraries (.so) found inside the package
#   --inspect             # Inspect the package's file list
#   --review-control      # Review the control file before creating a debian package (.deb)
    --deldoc=yes          # Toggle deletion of doc-pak upon termination
    --deldesc=yes         # Toggle deletion of description-pak upon termination
    --delspec=yes         # Toggle deletion of spec file upon termination
);

cd $DIR_NAME;

# Ensure that configure file has execute permission
[ ! -x ./configure ] && chmod --changes u+x ./configure;

# Configure and build the package
sudo ./configure ${CONFIGURE_ARG_LIST[@]};
[ ! -f ./Makefile ] && exit 0;
make --quiet CFLAGS='-march=native -g0 -O3 -Wall';
sudo checkinstall ${CHECKINSTALL_ARG_LIST[@]};

clean_files;

USER="$(whoami)";
FILE_NAME="nano[_-]$VERSION*.deb";
FILE_NAME="$(ls | grep $FILE_NAME)";

sudo chown --changes $USER:$USER $FILE_NAME;
chmod --changes 644 $FILE_NAME;

echo "Package created successfully in $(pwd)";
ls -lh | grep --color $FILE_NAME;
