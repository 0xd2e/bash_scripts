#!/bin/sh

set -o pipefail # The whole pipeline fails when any command fails
set -u; # Exit when uninitialised variable is used
set -e; # Exit when any command fails - http://mywiki.wooledge.org/BashFAQ/105

# Based on:
# https://community.linuxmint.com/tutorial/view/373
# https://easylinuxtipsproject.blogspot.com/p/clean-mint.html

function show_estimated_disk_space_usage
{
    echo "Space used by system logs    : $(sudo du --human-readable --summarize /var/log/)";
    echo "Space used by APT cache      : $(sudo du --human-readable --summarize /var/cache/apt)";
    echo "Space used by thumbnail cache: $(du --human-readable --summarize ~/.cache/thumbnails)";
    journalctl --disk-usage; # Show total disk usage of all journal files
}

show_estimated_disk_space_usage;

echo 'Removing unwanted software dependencies...';
sudo apt-get -y autoremove;
echo 'Done';

echo 'Removing packages that failed to install completely...';
sudo apt-get -y autoclean;
echo 'Done';

echo 'Removing old config files...';
sudo aptitude -y purge $(dpkg --list | grep '^rc' | awk '{print $2}');
echo 'Done';

echo -n 'Removing APT cache...';
sudo apt-get -y clean;
echo ' Done';

echo 'Removing archived systemd journal logs (active journal files will not be deleted)...';
sudo journalctl --vacuum-time=2d --vacuum-size=50M;
echo 'Done';

echo -n 'Deleting system logs...';
sudo rm /var/log/*log*;
echo ' Done';

echo -n 'Clearing the thumbnail cache...';
rm --force --recursive ~/.cache/thumbnails/**/*;
rm --force ~/.cache/mintinstall/screenshots/*;
echo ' Done';

echo -n 'Emptying the trash...';
rm --force --recursive ~/.local/share/Trash/*/** &> /dev/null;
echo ' Done';
