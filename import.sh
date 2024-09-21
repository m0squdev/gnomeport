#!/bin/bash

# Global variables
user_theme_extension_id="user-theme@gnome-shell-extensions.gcampax.github.com"
themes_dir="$HOME/.themes"
icons_dir="$HOME/.local/share/icons"
sounds_dir="$HOME/.local/share/sounds"
extensions_dir="$HOME/.local/share/gnome-shell/extensions"
wallpapers_dir="$HOME/.local/share/backgrounds"
import_gtk=false
import_icon=false
import_cursor=false
import_sound=false
import_extensions=false
import_shell=false
import_wallpapers=false
force_overwrite=false
help=$(cat << EOF
Usage: $0 [FLAGS] INPUT_DIRECTORY
FLAGS:
    -a    import anything
    -c    import current cursor theme files
    -e    import extensions' files and dconf configurations
    -f    force overwriting the directory of a theme. If not specified, the copying for that theme will be skipped
    -g    import current gtk theme files. You will be able to apply the theme only if $user_theme_extension_id extension is enabled
    -h    view help
    -i    import current icon theme files, excluding the files related to the cursor
    -s    import current sound theme files
    -S    import current shell theme files. You will be able to apply the theme only if $user_theme_extension_id extension is enabled
    -v    view program version
    -w    import current wallpapers
Notice: trying to import inexisting parts of the configuration will result in skipping that part of the import.
EOF
)

# Retrieve flags
while getopts 'acdefghisSvw' OPTION; do
    case "$OPTION" in
        a) import_cursor=true; import_extensions=true; import_shell=true; import_gtk=true; import_icon=true; import_sound=true; import_wallpapers=true ;;
        c) import_cursor=true ;;
        e) import_extensions=true ;;
        f) force_overwrite=true;;
        g) import_gtk=true ;;
        h) echo "$help"; exit 0 ;;
        i) import_icon=true ;;
        s) import_sound=true ;;
        S) import_shell=true ;;
        v) echo "$0 v0.0.0"; exit 0 ;;
        w) import_wallpapers=true ;;
        ?) echo "$help"; exit 2 ;;
    esac
done
shift "$(($OPTIND - 1))"

# Configure cp command
shopt -s extglob

# check_and_copy <source path> <destination path (including the name of the new dir)>
check_and_copy() {
    source_path="$1"
    destination_path="$2"
    if [ ! -d "$source_path" ]; then
        echo "cp: skipping $source_path => $destination_path because source doesn't exist"
    elif [ $force_overwrite == false ] && [ -d "$destination_path" ]; then
        echo "cp: skipping $source_path => $destination_path because destination already exists"
    else
        echo "cp: copying $source_path => $destination_path"
        cp -r "$source_path" "$destination_path"
    fi
}

# import_dir <parent source path> <prefix of the basename of the source dir> <parent destination path>
import_dir() {
    parent_source_path="$1"
    prefix="$2"
    parent_destination_path="$3"
    source_path=$(find "$parent_source_path" -maxdepth 1 -type d -name "$prefix-*" | head -n 1)
    if [ -n "$source_path" ]; then
        source_basename=$(basename "$source_path")
        destination_path="$parent_destination_path/$source_basename"
        check_and_copy "$source_path" "$destination_path"
    else
        echo "Warning: skipping copying of $parent_source_path/$prefix-* because source doesn't exist"
    fi
}

# Retrieve input directory
if [ $# -eq 0 ]; then
    echo "Error: no directory specified"
    echo "$help"
    exit 5
elif [ ! -d "$*" ]; then
    echo "Error: directory doesn't exist"
    echo "$help"
    exit 1
fi

# Gtk theme
if [ $import_gtk == true ]; then
    echo "=== GTK THEME ==="
    import_dir "$*" "gtk" "$themes_dir"
fi

# Icon theme
if [ $import_icon == true ]; then
    echo "=== ICON THEME ==="
    import_dir "$*" "icon" "$icons_dir"
fi

# Cursor theme
if [  $import_cursor == true ]; then
    echo "=== CURSOR THEME ==="
    import_dir "$*" "cursor" "$icons_dir"
fi

# Sound theme
if [ $import_sound == true ]; then
    echo "=== SOUND THEME ==="
    import_dir "$*" "sound" "$sounds_dir"
fi

# Extensions
if [ $import_extensions == true ]; then
    echo "=== EXTENSIONS ==="
    if [ -d "$*/extensions" ]; then
        for item_path in "$*/extensions"/*; do
            item_basename=$(basename "$item_path")
            if [ -d "$item_path" ]; then
                check_and_copy "$item_path" "$extensions_dir/$item_basename"
            else
                dconf_path="/org/gnome/shell/extensions/${item_basename%.ini}/"
                if [ $force_overwrite == false ] && [ "$(dconf dump "$dconf_path")" != "\n" ]; then
                    echo "dconf load: skipping $item_path => $dconf_path"
                else
                    echo "dconf load: loading $item_path => $dconf_path"
                    dconf load "$dconf_path" < "$item_path"
                fi
            fi
        done
    else
        echo "Warning: skipping import of extensions because sources don't exist"
    fi
fi

# Shell theme
if [ $import_shell == true ]; then
    echo "=== SHELL THEME ==="
    import_dir "$*" "shell" "$themes_dir"
fi

# Wallpapers
if [ $import_wallpapers == true ]; then
    echo "=== WALLPAPERS ==="
    if ls "$*"/light.* "$*"/dark.* 1> /dev/null 2>&1; then
        for item_path in "$*"/light.* "$*"/dark.*; do
            if [ -f "$item_path" ]; then
                item_basename=$(basename "$item_path")
                destination_path="$wallpapers_dir/$item_basename"
                if [ $force_overwrite == false ] && [ -f "$destination_path" ]; then
                    echo "cp: skipping $item_path => $destination_path/$item_basename because destination already exists"
                else
                    echo "cp: copying $item_path => $destination_path/$item_basename"
                    cp "$item_path" "$destination_path"
                fi
            fi
        done
    else
        echo "Warning: skipping import of wallpapers as sources don't exist"
    fi
fi