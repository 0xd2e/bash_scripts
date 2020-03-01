#!/bin/bash

set -u; # Exit when uninitialised variable is used
set -e; # Exit when any command fails

# Disclaimer:
# Package created by this script does not meet all requirements of a sensible
# debian package and thus should not be distributed. CheckInstall keeps track
# of all the files created or modified by the installation script. However,
# it does not list or track its dependencies.

# Clarification of strip and stripso options in checkinstall:
# Stripping binaries/executables means that debug sections are not included.
# Debug section helps with eventual debugging that may be needed. Modern dynamic
# loaders typically ensure that debug code is not loaded during normal execution.

# Official GNU nano documentation: https://www.nano-editor.org/docs.php


readonly URL='https://www.nano-editor.org/dist/v4/nano-4.8.tar.gz';
FILE_NAME=${URL##*/}; # nano-x.y.z.tar.gz
readonly DIR_NAME=${FILE_NAME%.tar.*}; # nano-x.y.z
readonly VERSION=${DIR_NAME##*-}; # x.y.z

STATUS=0;

if [[ ! $FILE_NAME =~ ^nano[-_]([[:digit:]]+\.){2,3}tar\.[gx]z$ ]]
then
    echo 'File must be either .tar.gz or .tar.xz archive with nano source';
    ((++STATUS));
fi

for cmd in auto-apt checkinstall gcc
do
    if [ -z "$(which $cmd)" ]
    then
        echo "-- '$cmd' is required but not found";
        ((++STATUS));
    fi
done

# Proceed only when all requirements are met
[ $STATUS -ne 0 ] && exit 0;

echo "Running $(basename $0) with pid $$ in cwd $(pwd)/";
echo "This script will create a package from source for GNU nano text editor version $VERSION";
read -r -p 'Do you want to continue (y/n)? ' ANSWER;

# Convert character(s) to lowercase
ANSWER=${ANSWER,,};

# Proceed only when the input is y[es]
[[ ! $ANSWER =~ ^y(es)?$ ]] && exit 0;

unset STATUS ANSWER cmd;

# Download the source
if [ -n "$(which wget)" ]
then
    wget --no-verbose --tries=3 --output-document=$FILE_NAME --show-progress --timeout=6 $URL;
else
    curl --silent --show-error --retry 3 --output $FILE_NAME --connect-timeout 6 $URL;
fi

# Unpack the source, do not show the list of extracted files
if [[ ${FILE_NAME: -3} == '.gz' ]]
then
    tar -zxf $FILE_NAME || gzip --decompress --stdout $FILE_NAME | tar --extract --file -;
else
    tar -Jxf $FILE_NAME || unxz --decompress $FILE_NAME | tar --extract --file -;
fi

cd $DIR_NAME;

# Ensure that configure file has execute permission
[ ! -x ./configure ] && chmod --changes u+x ./configure;

# Descriptions are taken from the official documentation
# Type "./configure --help" for more information
readonly CONFIGURE_ARG_LIST=(
    --quiet
    --disable-dependency-tracking # Speed up one-time build by rejecting slow dependency extractors
    --prefix='/usr/local'   # Installation location for architecture-independent files, default is /usr/local/
#   --disable-largefile     # Omit support for large files
#   --disable-threads       # Build without multithread safety
#   --disable-rpath         # Do not hardcode runtime library paths
    --disable-browser       # Disable the built-in file browser
#   --disable-color         # Disable color and syntax highlighting
#   --disable-comment       # Disable the comment/uncomment function
    --disable-extra         # Disable the Easter egg
    --disable-help          # Disable the built-in help texts
    --disable-histories     # Disable search and position histories
#   --disable-justify       # Disable the justify/unjustify functions
#   --disable-libmagic      # Disable detection of file types via libmagic
#   --disable-linenumbers   # Disable line numbering
    --disable-mouse         # Disable mouse support
    --disable-multibuffer   # Disable multiple file buffers
#   --disable-nanorc        # Disable the use of .nanorc files
    --disable-operatingdir  # Disable the setting of an operating directory
    --disable-speller       # Disable the spell-checker functions
    --disable-tabcomp       # Disable the tab-completion functions
    --disable-wordcomp      # Disable the word-completion function
    --disable-wrapping      # Disable all hard-wrapping of text
    --disable-nls           # Disable internationalization, do not use Native Language Support
);

USER='';

if [ -n "$(which git)" ]
then
    USER="$(git config user.email)";
fi

if [ -z $USER ]
then
    USER="$(whoami)";
fi

# Descriptions are taken from the manual
# Default config: /etc/checkinstallrc
readonly CHECKINSTALL_ARG_LIST=(
    --type='debian'         # Create a Debian package
    --install=no            # Toggle installation of the created package
    --default               # Accept default answers to all questions
    --pkgname='nano'        # Set the package name
    --pkgversion=$VERSION   # Set the package version
    --pakdir='../'          # Where to save the new package
    --maintainer=$USER      # Set the package maintainer
    --pkglicense='GPLv3'    # Set the package license
#   --nodoc                 # Do not include documentation files
    --showinstall=no        # Toggle interactive install command
    --autodoinst=no         # Toggle creation of a "doinst.sh" script
    --strip=yes             # Toggle stripping any ELF binaries found inside the package
    --stripso=yes           # Toggle stripping any ELF libraries (.so) found inside the package
#   --inspect               # Inspect the package's file list
#   --review-control        # Review the control file before creating a debian package (.deb)
    --deldoc=yes            # Toggle deletion of doc-pak upon termination
    --deldesc=yes           # Toggle deletion of description-pak upon termination
    --delspec=yes           # Toggle deletion of spec file upon termination
);

# Configure and build the package
auto-apt run ./configure ${CONFIGURE_ARG_LIST[@]};
make --quiet;
sudo checkinstall ${CHECKINSTALL_ARG_LIST[@]};

make --quiet clean;
cd ..;
rm --force --verbose $FILE_NAME;
rm --force --recursive $DIR_NAME;
[ ! -d $DIR_NAME ] && echo "Removed directory '$DIR_NAME'";

USER="$(whoami)";
FILE_NAME="nano[_-]$VERSION*.deb";
FILE_NAME="$(ls | grep $FILE_NAME)";

sudo chown --changes $USER:$USER $FILE_NAME;
chmod --changes 644 $FILE_NAME;

echo "Package created successfully in $(pwd)";
ls -lh | grep --color $FILE_NAME;
