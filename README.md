# GNOMEport

GNOMEport is a set of bash scripts designed to export and import GNOME desktop environment themes and configurations. This tool allows you to easily backup and restore your GNOME customizations, including GTK themes, icon themes, cursor themes, sound themes, shell themes, wallpapers, and extension configurations.

## Scripts

This repository contains two main scripts:

1. `export.sh`: Exports your current GNOME theme and configurations.
2. `import.sh`: Imports previously exported GNOME theme and configurations.

## Usage

### Exporting Themes

To export your current GNOME themes and configurations:

```bash
./export.sh [FLAGS] OUTPUT_DIRECTORY
```

Flags:
- `-a`: Export everything except disabled extensions
- `-c`: Export current cursor theme files
- `-d`: Export disabled extensions' files and dconf configurations
- `-e`: Export enabled extensions' files and dconf configurations
- `-g`: Export current GTK theme files
- `-h`: View help
- `-i`: Export current icon theme files (excluding cursor files)
- `-s`: Export current sound theme files
- `-S`: Export current shell theme files (requires user-theme extension)
- `-v`: View program version
- `-w`: Export current wallpapers and their dconf configuration

To export everything, use: `./export.sh -ad OUTPUT_DIRECTORY`

### Importing Themes

To import previously exported GNOME themes and configurations:

```bash
./import.sh [FLAGS] INPUT_DIRECTORY
```

Flags:
- `-a`: Import everything
- `-c`: Import cursor theme files
- `-e`: Import extensions' files and dconf configurations
- `-f`: Force overwrite existing theme directories
- `-g`: Import GTK theme files
- `-h`: View help
- `-i`: Import icon theme files (excluding cursor files)
- `-s`: Import sound theme files
- `-S`: Import shell theme files
- `-v`: View program version
- `-w`: Import wallpapers

Notice: the script doesn't automatically apply the themes and the extensions, it just moves them to the locations where GNOME loads them from! Use tools like `gnome-tweaks` and `gnome-extensions` to do this after you run the script.

## Requirements

- GNOME desktop environment
- Bash shell
- `dconf` command-line tool

## Notes

- The user-theme extension (`user-theme@gnome-shell-extensions.gcampax.github.com`) is required for exporting and importing shell themes.
- When importing, use the `-f` flag to force overwrite existing theme directories and dconf configurations. Without this flag, the script will skip copying if a directory already exists or a dconf path is not empty.
- The export script will attempt to find themes in both user and system directories.
- The import script will place themes in the appropriate user directories.

## Disclaimer

Always backup your data before using these scripts. While they are designed to be safe, unexpected issues may occur.
