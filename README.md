
##backup_home_bash.sh

This script is ment to help creating backups of specific folders and files in your **${HOME}**.  
It can also restore the folders and files in your **${HOME}** from a previously created backup.  
Simply define the folders and files in the array **paths_to_backup=()** at the beginning of the script.  
Then execute the script with the following commands:

```
bash backup_home_bash.sh --backup 'path/to/the/backup/dir'
bash backup_home_bash.sh --restore 'path/to/the/backup/dir'
```
Get more information about the script with the commmand

```
bash backup_home_bash.sh -h
```
If you want to compress your backup, use 7z or similar archivers.

Available options:

```
-h, --help              Print this help and exit.  
-v, --verbose           Show more info.  
--no-color              Output without colors.  
--dry-run               Perform a trial run with no changes made.  
--backup                Create a backup of the home dir.  
--restore               Restore the home dir from the backup.  
--home                  Set a home other than the current user's one.  
```
Dependencies:

```
bash, coreutils, rsync
```
Examples:

```
nice -n 10 bash backup_home_bash.sh --backup "path/to/the/backup/dir"

nice -n 10 bash backup_home_bash.sh --restore "path/to/the/backup/dir"

path_backup="path/to/the/backup/dir"; \
nice -n 10 bash backup_home_bash.sh --backup "${path_backup}" && \
nice -n 10 7z a -mx9 "${path_backup}.7z" "${path_backup}" && \
rm -dr "${path_backup}"
```

