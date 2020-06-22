#!/bin/bash
# This script must be run as root (ex.: sudo sh [script_name])

# exit when any command fails
set -e
# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command failed with exit code $?."' EXIT

function echo_title {
    echo ""
    echo "###############################################################################"
    echo "$1"
    echo "###############################################################################"
}

###############################################################################
echo_title "Starting $0 on $(date)."
###############################################################################

###############################################################################
echo_title "Map input parameters."
###############################################################################
fileShareName="$1"

###############################################################################
echo_title "Recreate moodledata mount point."
###############################################################################
mkdir /mnt/${fileShareName}

###############################################################################
echo_title "Mount all storages."
###############################################################################
mount -a

###############################################################################
echo_title "Finishing $0 on $(date)."
###############################################################################