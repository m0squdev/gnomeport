#!/bin/bash

# Global variables
user_theme_extension_id="user-theme@gnome-shell-extensions.gcampax.github.com"
themes_dir="$HOME/.local/share/themes"  # Use $HOME/.themes for legacy applications if you have issues with this directory
icons_dir="$HOME/.local/share/icons"
sounds_dir="$HOME/.local/share/sounds"
extensions_dir="$HOME/.local/share/gnome-shell/extensions"
glib_dir="$HOME/.local/share/glib-2.0"
schemas_dir="$glib_dir/schemas"
wallpapers_dir="$HOME/.local/share/backgrounds"
import_gtk=false
import_icon=false
import_cursor=false
import_sound=false
import_extensions=false
import_shell=false
import_wallpapers=false
import_shortcuts=false
import_accent_color=false
import_color_scheme=false
force_overwrite=false
help=$(cat << EOF
Usage: $0 [FLAGS] INPUT_DIRECTORY
FLAGS:
    -a    import anything
    -A    import accent color (the effect will be visible only on GNOME 47+)
    -c    import current cursor theme files
    -C    export color scheme
    -e    import extensions' files and dconf configurations
    -f    force overwriting existing directories and extensions' dconf configurations. If not specified and a directory already exists, the copying will be skipped. Doesn't apply to keyboard shortcuts because the dconf paths to edit aren't empty by default
    -g    import current GTK theme files
    -h    view help
    -i    import current icon theme files, excluding the files related to the cursor
    -k    import current keyboard shortcuts to dconf. Edits will be applied to desktop, mutter, settings-daemon and shell configurations
    -s    import current sound theme files
    -S    import current shell theme files. You will be able to apply the theme only if $user_theme_extension_id extension is enabled
    -v    view program version
    -w    import current wallpapers
Notice: trying to import inexisting parts of the configuration will result in skipping that part of the import.
EOF
)

# Retrieve flags
while getopts 'aAcCdefghiksSvw' OPTION; do
    case "$OPTION" in
        a) import_accent_color=true; import_cursor=true; import_color_scheme=true; import_extensions=true; import_gtk=true; import_icon=true; import_shortcuts=true; import_sound=true; import_shell=true; import_wallpapers=true ;;
        A) import_accent_color=true ;;
        c) import_cursor=true ;;
        C) import_color_scheme=true ;;
        e) import_extensions=true ;;
        f) force_overwrite=true;;
        g) import_gtk=true ;;
        h) echo "$help"; exit 0 ;;
        i) import_icon=true ;;
        k) import_shortcuts=true ;;
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

# check_and_copy <source path> <destination path (without the name of the new dir)>
check_and_copy() {
    source_path="$1"
    destination_dir="$2"
    source_basename=$(basename "$source_path")
    source_basename_without_prefix="${source_basename#*-}"
    destination_path="$destination_dir/$source_basename_without_prefix"
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
    find "$parent_source_path" -maxdepth 1 -type d -name "${prefix}parent-*" | while read -r source_path; do
        if [ -n "$source_path" ]; then
            check_and_copy "$source_path" "$parent_destination_path"
        else
            echo "Warning: skipping copying of $parent_source_path/$prefix-* because source doesn't exist"
        fi
    done
    find "$parent_source_path" -maxdepth 1 -type d -name "$prefix-*" | while read -r source_path; do
        if [ -n "$source_path" ]; then
            check_and_copy "$source_path" "$parent_destination_path"
        else
            echo "Warning: skipping copying of $parent_source_path/$prefix-* because source doesn't exist"
        fi
    done
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
    mkdir -p "$themes_dir"
    import_dir "$*" "gtk" "$themes_dir"
fi

# Icon theme
if [ $import_icon == true ]; then
    echo "=== ICON THEME ==="
    mkdir -p "$icons_dir"
    import_dir "$*" "icon" "$icons_dir"
fi

# Cursor theme
if [  $import_cursor == true ]; then
    echo "=== CURSOR THEME ==="
    mkdir -p "$icons_dir"
    import_dir "$*" "cursor" "$icons_dir"
fi

# Sound theme
if [ $import_sound == true ]; then
    echo "=== SOUND THEME ==="
    mkdir -p "$sounds_dir"
    import_dir "$*" "sound" "$sounds_dir"
fi

# Extensions
if [ $import_extensions == true ]; then
    echo "=== EXTENSIONS ==="
    if [ -d "$*/extensions" ]; then
        mkdir -p "$extensions_dir"
        mkdir -p "$glib_dir"
        mkdir -p "$schemas_dir"
        for item_path in "$*/extensions"/*; do
            item_basename=$(basename "$item_path")
            if [ -d "$item_path" ]; then
                if [[ "$force_overwrite" == false && -d "/usr/share/gnome-shell/extensions/$item_basename" ]] || [[ "$force_overwrite" == false && -d "$extensions_dir/$item_basename" ]]; then
                    echo "cp: skipping $item_path => $extensions_dir because the extension is already installed"
                else
                    check_and_copy "$item_path" "$extensions_dir"
                fi
            else
                if [[ $item_basename == *.ini ]]; then
                    dconf_path="/org/gnome/shell/extensions/${item_basename::-4}/"
                    if [ $force_overwrite == false ] && [ "$(dconf dump "$dconf_path")" != "\n" ]; then
                        echo "dconf load: skipping $item_path => $dconf_path because directory is not empty"
                    else
                        echo "dconf load: loading $item_path => $dconf_path"
                        dconf load "$dconf_path" < "$item_path"
                    fi
                elif [[ $item_basename == *.gschema.xml ]]; then
                    schema_destination="$schemas_dir/$item_basename"
                    if [ $force_overwrite == false ] && [ -f "$schema_destination" ]; then
                        echo "cp: skipping $item_path => $schema_destination because destination already exists"
                    else
                        echo "cp: copying $item_path => $schema_destination"
                        cp "$item_path" "$schema_destination"
                    fi
                else
                    echo "Warning: skipping unexpected file $item_path"
                fi
            fi
        done
        glib-compile-schemas "$schemas_dir"
    else
        echo "Warning: skipping import of extensions because sources don't exist"
    fi
fi

# Shell theme
if [ $import_shell == true ]; then
    echo "=== SHELL THEME ==="
    mkdir -p "$themes_dir"
    import_dir "$*" "shell" "$themes_dir"
fi

# Wallpapers
if [ $import_wallpapers == true ]; then
    echo "=== WALLPAPERS ==="
    if ls "$*"/light.* "$*"/dark.* 1> /dev/null 2>&1; then
        mkdir -p "$wallpapers_dir"
        for item_path in "$*"/light.* "$*"/dark.*; do
            if [ -f "$item_path" ]; then
                item_basename=$(basename "$item_path")
                destination_path="$wallpapers_dir/$item_basename"
                if [ $force_overwrite == false ] && [ -f "$destination_path" ]; then
                    echo "cp: skipping $item_path => $wallpapers_dir because destination already exists"
                else
                    echo "cp: copying $item_path => $wallpapers_dir"
                    cp "$item_path" "$destination_path"
                fi
            fi
        done
    else
        echo "Warning: skipping import of wallpapers as sources don't exist"
    fi
fi

# Shortcuts
if [ $import_shortcuts == true ]; then
    echo "=== KEYBOARD SHORTCUTS ==="
    if [ -d "$*/extensions" ]; then
        for item_path in "$*/shortcuts"/*; do
            item_basename=$(basename "$item_path")
            if [ -f "$item_path" ]; then
                dconf_path=""
                case "$item_basename" in
                    desktop.ini) dconf_path="/org/gnome/desktop/wm/keybindings/" ;;
                    mutter.ini) dconf_path="/org/gnome/mutter/keybindings/" ;;
                    mutter-wayland.ini) dconf_path="/org/gnome/mutter/wayland/keybindings/" ;;
                    settings-daemon.ini) dconf_path="/org/gnome/settings-daemon/plugins/media-keys/" ;;
                    shell.ini) dconf_path="/org/gnome/shell/keybindings/" ;;
                    *) echo "Warning: skipping import of unexpected file $item_path" ;;
                esac
                if [ -n "$dconf_path" ]; then
                    echo "dconf load: loading $item_path => $dconf_path"
                    dconf load "$dconf_path" < "$item_path"
                fi
            else
                echo "Warning: skipping import of unexpected directory $item_path"
            fi
        done
    else
        echo "Warning: skipping import of keyboard shortcuts because sources don't exist"
    fi
fi

# Accent color
if [ $import_accent_color == true ];then
    echo "=== ACCENT COLOR ==="
    echo "dconf write: $*/accent-color.txt => /org/gnome/desktop/interface/accent-color"
    if [ -f "$*/accent-color.txt" ]; then
        while IFS= read -r accent_color; do
            if [ -n "${accent_color[*]}" ]; then
                dconf write /org/gnome/desktop/interface/accent-color "${accent_color[*]}"
            else
                echo "Warning: skipping dconf write of accent-color because source file is empty"
            fi
        done < "$*/accent-color.txt"
    else
        echo "Warning: skipping dconf write of accent-color because source file doesn't exist"
    fi
fi

# Color scheme
if [ $import_color_scheme == true ];then
    echo "=== COLOR SCHEME ==="
    echo "dconf write: $*/color-scheme.txt => /org/gnome/desktop/interface/color-scheme"
    if [ -f "$*/color-scheme.txt" ]; then
        while IFS= read -r color_scheme; do
            if [ -n "${color_scheme[*]}" ]; then
                dconf write /org/gnome/desktop/interface/color-scheme "${color_scheme[*]}"
            else
                echo "Warning: skipping dconf write of color-scheme because an source file is empty"
            fi
        done < "$*/color-scheme.txt"
    else
        echo "Warning: skipping dconf write of color-scheme because source file doesn't exist"
    fi
fi