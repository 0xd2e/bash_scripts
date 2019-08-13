#!/bin/bash

set -o pipefail # The whole pipeline fails when any command fails
set -u; # Exit when uninitialised variable is used
set -e; # Exit when any command fails

# Change the swap use - modify vm.swappiness setting in /etc/sysctl.conf file


GOAL='10';
CURR="$(cat /proc/sys/vm/swappiness)";
readonly FILE_PATH='/etc/sysctl.conf';
readonly SETTING='vm.swappiness';

if [[ $CURR = $GOAL ]]
then
    echo "Swappiness is already set to $GOAL";
    exit 0;
fi

echo "Current swappiness setting: $CURR";
read -r -p "Do you want to change it to $GOAL? (y/n) " ANSWER;

# Convert character(s) to lowercase
ANSWER=${ANSWER,,};

# Proceed only when the input is y[es]
[[ ! $ANSWER =~ ^y(es)?$ ]] && exit 0;

unset ANSWER CURR;

# If 'vm.swappiness' is in the file, capture the last occurrence
readonly LINE=$(grep $SETTING $FILE_PATH | tail --lines=1);

GOAL="$SETTING=$GOAL";

if [ -z $LINE ]
then
    # If nothing was found, append to the end of the file
    GOAL="# Reduce the swap tendency\n$GOAL\n";
    if [ $(tail --lines=1 $FILE_PATH | wc --chars) -gt 1 ]
    then
        # If the file does not have an empty line at the end, add a new line
        GOAL="\n$GOAL";
    fi
    echo -e $GOAL | sudo tee -a $FILE_PATH > /dev/null;
else
    # Replace the entire line
    sudo sed --in-place "s/$LINE/$GOAL/1" $FILE_PATH > /dev/null;
fi

if [ $? -eq 0 ]
then
    # If the file was chenged successfully, restart computer
    echo 'Restart is required. Press any key to continue...';
    read -n1 -s -r && sudo reboot;
fi
