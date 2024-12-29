# GNOME Theme Exporter/Importer

This project provides two bash scripts for exporting and importing GNOME theme configurations, including GTK themes, icon themes, cursor themes, sound themes, shell themes, extensions, wallpapers, keyboard shortcuts, accent colors, and color schemes.

## Scripts

1. `export.sh`: Exports the current GNOME theme configuration.
2. `import.sh`: Imports a previously exported GNOME theme configuration.

## Usage

### Exporting

```bash
./export.sh [FLAGS] OUTPUT_DIRECTORY
```

### Importing

```bash
./import.sh [FLAGS] INPUT_DIRECTORY
```

## Flags

Both scripts support the following flags:

- `-a`: Export/import everything
- `-A`: Export/import accent color (GNOME 47+)
- `-c`: Export/import current cursor theme files
- `-C`: Export/import color scheme
- `-e`: Export/import extensions' files and dconf configurations
- `-g`: Export/import current GTK theme files
- `-h`: View help
- `-i`: Export/import current icon theme files
- `-k`: Export/import current keyboard shortcuts
- `-s`: Export/import current sound theme files
- `-S`: Export/import current shell theme files
- `-v`: View program version
- `-w`: Export/import current wallpapers

Additional flag for `import.sh`:
- `-f`: Force overwriting existing directories and extensions' dconf configurations

## Notes

- The export script will create directories and files in the specified output directory.
- The import script will place files in the appropriate locations within the user's home directory.
- Importing may overwrite existing configurations. Use with caution.
- The accent color feature is only visible on GNOME 47+.

## Requirements

If you have GNOME installed you're good to go! To run these scripts you only need the following dependencies:
- GNOME desktop environment
- `dconf` command-line tool

## Limitations

- The scripts do not handle all possible GNOME configurations.
- Some exported configurations may not work correctly when imported on a different system or GNOME version.
