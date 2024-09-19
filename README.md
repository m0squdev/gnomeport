# GNOME Backup Tool

This shell script allows you to backup various GNOME theme components and settings to a specified directory.

## Features

The script can backup the following GNOME components:

- GTK theme
- Icon theme
- Cursor theme
- Sound theme
- Shell theme (requires the User Themes extension)
- Enabled and disabled GNOME Shell extensions
- Wallpapers (both light and dark modes)
- GNOME Shell configuration

## Usage

```
./gnome-bak-tool.sh [FLAGS] OUTPUT_DIRECTORY
```

### Flags

- `-a`: Backup everything except disabled extensions
- `-c`: Backup current cursor theme files
- `-e`: Backup enabled extensions' files
- `-d`: Backup disabled extensions' files
- `-g`: Backup current GTK theme files
- `-h`: View help
- `-i`: Backup current icon theme files (excluding cursor-related files)
- `-s`: Backup current sound theme files
- `-S`: Backup current shell theme files and shell's dconf configuration (requires User Themes extension)
- `-v`: View program version
- `-w`: Backup current wallpapers and their dconf configuration

Shorthand: To backup everything, use the `-ad` flags.

## Output

The script creates a directory structure in the specified output directory, containing the backed up theme components and configuration files.

## Requirements

- GNOME desktop environment
- Bash shell
- User Themes extension (for shell theme backup)

## Notes

- The script searches for themes in both user-specific and system-wide directories.
- If a theme component is not found, the script will display an error message.
- The User Themes extension (`user-theme@gnome-shell-extensions.gcampax.github.com`) is required to backup the current shell theme.

## Examples

Backup everything to a directory named "my_gnome_backup":

```
./gnome-bak-tool.sh -ad my_gnome_backup
```

Backup only GTK and icon themes:

```
./gnome-bak-tool.sh -gi my_gnome_backup
```

## Troubleshooting

If you encounter any issues, make sure:

1. You have the necessary permissions to read theme files and write to the output directory.
2. The User Themes extension is installed if you're trying to backup the shell theme.
3. The themes you're trying to backup exist in either the user or system directories.

For more information, run the script with the `-h` flag to view the help message.
