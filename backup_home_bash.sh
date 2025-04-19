#!/bin/bash

#############################################################################################################################
# Name: backup_home_bash.sh
# Author: ASAN
# Date: 19.04.2025
# Version: 001.001.002
# Dependencies: rsync, bash, coreutils


# This script is ment to help creating backups of specific folders and files in your ${HOME}.
# It can also restore the folders and files in your ${HOME} from a previously created backup.
# Simply define the folders and files in the array paths_to_backup=() at the beginning of the script.
# Then execute the script with the following commands:
# bash backup_home_bash.sh --backup 'path/to/the/backup/dir'
# bash backup_home_bash.sh --restore 'path/to/the/backup/dir'
# Get more information about the script with the commmand
# bash backup_home_bash.sh -h
# If you want to compress your backup, use 7z or similar archivers.
#
# Examples:
# nice -n 10 bash backup_home_bash.sh --backup "path/to/the/backup/dir"
# nice -n 10 bash backup_home_bash.sh --restore "path/to/the/backup/dir"
# path_backup="path/to/the/backup/dir"; \
# nice -n 10 bash backup_home_bash.sh --backup "${path_backup}" && \
# nice -n 10 7z a -mx9 "${path_backup}.7z" "${path_backup}" && \
# rm -dr "${path_backup}"
#
# Dependencies:
# bash, coreutils, rsync

#############################################################################################################################


# Script options. Change them as needed.
script_options() {
    declare -ga paths_to_backup=(
        '.aegisub'
        '.audacity-data'
        '.mozilla'
        '.ssh'
        '.thunderbird'
        '.var/app'
        '.wine'
        'wine-prefixes'
        '.config/BraveSoftware'
        '.config/Code'
        '.config/Element'
        '.config/ghb'
        '.config/GIMP'
        '.config/inkscape'
        '.config/kate'
        '.config/kdeconnect'
        '.config/libreoffice'
        '.config/micro'
        '.config/mpv'
        '.config/peazip'
        '.config/vlc'
        '.config/kwinrc'
        '.config/kwinrulesrc'
        '.config/kscreenlockerrc'
        'Pictures'
        'Documents'
        'Programme'
        'Music'
        'Videos'
        'Downloads'
        '.local/bin'
        '.local/share/applications'
        '.local/share/desktop-directories'
        '.config/menus'
        '.local/share/fonts'
        '.local/share/icons'
        '.local/share/user-places.xbel'
        #'i/dont/need/this'
        )
    declare -gra option_rsync_options_backup=(
        '-lptD'                 # l:links p:permissions t:times D:devices and specials.
        '--info=progress2'      # show progress info
        #'--info=name2'
        '--delete'              # delete extraneous files from dest dirs
        #'-og'                  # preserve owner and group
        #'-rR'                  # hard coded in the function exec_rsync(), r:recursive R:relative
        )
    declare -gra option_rsync_options_restore=(
        '-lptD'                 # l:links p:permissions t:times D:devices and specials.
        '--info=progress2'      # show progress info
        #'--info=name2'
        #'-og'                  # preserve owner and group
        #'-rR'                  # hard coded in the function exec_rsync(), r:recursive R:relative
        )
    declare -g path_home="${HOME}"
}

# Script vars. Don't change
script_vars() {
    declare -gr script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
    declare -gra script_dependencies=( "rsync" )
    declare -g option_backup=false
    declare -g option_restore=false
    declare -g option_verbose=false
    declare -g option_dry_run=false
    declare -g path_backup=""
    declare -gr script_name="backup_home_bash.sh"
}

# help page for this script
usage() {
  cat <<EOF

Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS] [PATH_TO_BACKUP]

Create a backup of specific folders and files in your \${HOME}
or restore the folders and files from previously created backup.
Define the folders and files in the array paths_to_backup
before executing this script.

PATH_TO_BACKUP: The location where the backup will be saved or
                the location of the backup that will be restored.

Available options:

-h, --help              Print this help and exit.
-v, --verbose           Show more info.
--no-color              Output without colors.
--dry-run               Perform a trial run with no changes made.
--backup                Create a backup of the home dir.
--restore               Restore the home dir from the backup.
--home                  Set a home other than the current user's one.


Examples:
nice -n 10 bash backup_home_bash.sh --backup "path/to/the/backup/dir"
nice -n 10 bash backup_home_bash.sh --restore "path/to/the/backup/dir"
path_backup="path/to/the/backup/dir"; \\
nice -n 10 bash backup_home_bash.sh --backup "\${path_backup}" && \\
nice -n 10 7z a -mx9 "\${path_backup}.7z" "\${path_backup}" && \\
rm -dr "\${path_backup}"

EOF
  exit 0
}

# instead of echo
# usage: msg "This is a ${RED}very important${NOFORMAT} message, but not a script output value!"
msg() {
  echo >&2 -e "${1-}"
}

# cleanup function
cleanup() {
  # script cleanup here
  local dummy
}

# kill the script
die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

# @ 1: true: no colors will be set.
setup_colors() {
  if [[ -t 2 ]] && [[ -z "${1-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

# Verfiy that the dependencies defined in the array 'script_dependencies' are available on this system.
check_dependencies() {
    local missing_dependencies=""
    local entry=""
    for entry in "${script_dependencies[@]}"
    do
        if ! command -v ${entry} &> /dev/null; then
            missing_dependencies="${missing_dependencies}${entry}\n"
        fi
    done
    if [[ ! ${missing_dependencies} == "" ]]; then
        die "The following dependencies are not met:$\n${missing_dependencies}Please install all dependencies before using this script."
    fi
    return 0
}

# parse the parameters of this script
parse_params() {
    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) option_verbose=true;;
        --no-color) setup_colors 1;;
        --dry-run) option_dry_run=true;;
        --backup) option_backup=true;;
        --restore) option_restore=true;;
        --home)
            path_home="${2-}"
            shift
            ;;
        -?*) die "${RED}Unknown option: $1${NOFORMAT}" ;;
        *) break ;;
        esac
        shift
    done

    # check if options are valid
    [[ $option_backup == $option_restore ]] && die "${RED}Set either the backup or the restore option.${NOFORMAT}"

    # check if backup path was given
    [[ -z "${1:-}" ]] && die "${RED}No backup path provided.${NOFORMAT}"
    path_backup="$1"
    return 0
}


# Run rsync. Do the sync recursively and preserve the relative paths in the param 'path_src_relative'.
# @1:  bool:    verbose:            Echo the command if true.
# @2:  string:  path_src_root
# @3:  string:  path_src_relative
# @4:  string:  path_dest_root
# @exec_rsync_options:  Array that contains the rsync options being used.
#                       Set the options before executing the function.
exec_rsync() {
    [[ $1 == true ]] && msg "rsync ${exec_rsync_options[*]} -rR \"${2}/./${3}\" \"${4}/\""
    rsync "${exec_rsync_options[@]}" -rR "${2}/./${3}" "${4}/"
}
declare -ga exec_rsync_options


# Check if the paths in $paths_to_backup exist and check for write permissions.
# @return: 0 if everything is ok, > 0 if not.
check_paths() {
    local path=""
    local i=0
    local res=0
    local error=0

    # Set the rsync options
    if $option_backup; then
        local -r src_root="$path_home"
        local -r dst_root="$path_backup"
        exec_rsync_options=(
            "${option_rsync_options_backup[@]}"
            "--info=none"
            "--dry-run"
            )
    else if $option_restore; then
        local -r src_root="$path_backup"
        local -r dst_root="$path_home"
        exec_rsync_options=(
            "${option_rsync_options_restore[@]}"
            "--info=none"
            "--dry-run"
            )
    else
        die "${RED}Function check_paths(): \$option_backup not valid.${NOFORMAT}"
    fi fi

    # trim paths, remove trailing /
    path_home=$(echo "$path_home" | sed 's:/*$::')
    path_backup=$(echo "$path_backup" | sed 's:/*$::')
    for ((i = 0; i < "${#paths_to_backup[@]}"; i++)); do
        paths_to_backup[$i]=$(echo "${paths_to_backup[$i]}" | sed 's:/*$::')
    done

    # dry run rsync to check file permissions
    if [[ true ]]; then
        for path in "${paths_to_backup[@]}"; do
            msg "${BLUE}${path}${NOFORMAT}"
            # execute rsync and filter the stdout and stderr of rsync to help the user better understand the issues encountered.
            res=0; exec_rsync false "$src_root" "$path" "$dst_root" 2>&1 | sed '/^rsync error:.*$/d' | sed 's/^rsync:[^"]*"/"/' || res=${PIPESTATUS[0]}
            [ $res -ne 0 ] && error=1
        done
    fi
    return $error
}


# Create a backup or restore from the backup
# depending on the vars $option_backup and $option_restore
# @return: 0 if everything is ok, > 0 if not.
create_backup() {
    local path=""
    local options=""
    local src_root=""
    local dst_root=""
    local res=0
    local error=0

    # Set the rsync options
    if $option_backup; then
        src_root="$path_home"
        dst_root="$path_backup"
        if ! $option_dry_run; then
            exec_rsync_options=(
                "${option_rsync_options_backup[@]}"
                )
        else
            exec_rsync_options=(
                "${option_rsync_options_backup[@]}"
                "--dry-run"
                )
        fi
    else if $option_restore; then
        src_root="$path_backup"
        dst_root="$path_home"
        if ! $option_dry_run; then
            exec_rsync_options=(
                "${option_rsync_options_restore[@]}"
                )
        else
            exec_rsync_options=(
                "${option_rsync_options_restore[@]}"
                "--dry-run"
                )
        fi
    else
        die "${RED}Function create_backup(): \$option_backup not valid.${NOFORMAT}"
    fi fi

    # Do the backup
    for path in "${paths_to_backup[@]}"; do
        msg "${BLUE}${path}${NOFORMAT}"
        res=0; exec_rsync $option_verbose "$src_root" "$path" "$dst_root" || res=$?
        if [ $res -ne 0 ]; then
            error=1
            msg "${RED}->failed${NOFORMAT}"
        else
            msg "${GREEN}->done${NOFORMAT}"
        fi
    done

    return $error
}


main() {
    local res=0
    local answer=""
    local txt=""


    ## setup the script

    # exit on error, subshells inherit err traps, unset vars are errors, return value of a pipeline is the status of the last command to exit with a non-zero status
    set -o errexit -o errtrace -o nounset -o pipefail

    script_vars
    script_options
    setup_colors

    # execute cleanup on exit, etc
    trap cleanup EXIT
    trap "die 'Exiting $script_name'" SIGINT SIGTERM


    ## Start the script
    check_dependencies
    parse_params "$@"


    ## Check permissions before doing the backup/restoration
    msg "Checking permissions."
    msg "========================================"
    res=0; check_paths || res=$?
    if [ $res -ne 0 ]; then
        echo
        if $option_backup; then
            txt="Problems detected. Create the backup anyway?"
        else
            txt="Problems detected. Restore the backup anyway?"
        fi
        read -rp "$txt (Y/N): " answer
        case $answer in
            [Yy]* ) ;;
            * ) die "Closing.";;
        esac
    fi


    ## Do the backup/restoration
    msg "\n"
    if $option_backup; then
        msg "Creating the backup."
    else
        msg "Restoring the backup."
    fi
    msg "========================================"
    $option_dry_run && msg "Performing a dry run."
    res=0; create_backup || res=$?


    ## Print the result
    msg "\n"
    msg "Result"
    msg "========================================"
    if [ $res -ne 0 ]; then
        if $option_backup; then
            die "${RED}An error occurred while creating the backup.\nPlease check the output of this script.${NOFORMAT}"
        else
            die "${RED}An error occurred while restoring the backup.\nPlease check the output of this script.${NOFORMAT}"
        fi
    else
        if $option_backup; then
            msg "Backup created.\nEverything is fine."
        else
            msg "Backup restore completed.\nEverything is fine."
        fi
    fi
    exit 0
}

main "$@"





























