#!/bin/bash

set -o pipefail # The whole pipeline fails when any command fails
set -u; # Exit when uninitialised variable is used
set -e; # Exit when any command fails

# It is more like a collection of copy/paste commands


# Make all startup applications visible for configuration
sudo sed --in-place "s/NoDisplay=false/NoDisplay=true/g" /etc/xdg/autostart/*.desktop;


# Add contrib and non-free components to sources list in Debian 10 Buster
# Based on: https://wiki.debian.org/SourcesList#Example_sources.list
# Only lines with the word 'main' at the end of a line will be changed
sudo sed --in-place --regexp-extended "s/ (buster)([-/]updates)? (main)$/\1\2 \3 contrib non-free/g" /etc/apt/sources.list.d/official-package-repositories.list;


# Set up a git alias for showing commit logs
git config --global alias.logg "log --decorate=short --all --pretty=oneline --abbrev-commit --date=relative --graph --name-only";
