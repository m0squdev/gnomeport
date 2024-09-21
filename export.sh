#!/bin/bash

# Global variables
user_theme_extension_id="user-theme@gnome-shell-extensions.gcampax.github.com"
export_gtk=false
export_icon=false
export_cursor=false
export_sound=false
export_enabled_extensions=false
export_disabled_extensions=false
export_shell=false
export_wallpaper=false
help=$(cat << EOF
Usage: $0 [FLAGS] OUTPUT_DIRECTORY
FLAGS:
    -a    export anything but disabled extensions' files
    -c    export current cursor theme files
    -d    export disabled extensions' files and dconf configurations
    -e    export enabled extensions' files and dconf configurations
    -g    export current gtk theme files
    -h    view help
    -i    export current icon theme files, excluding the files related to the cursor
    -s    export current sound theme files
    -S    export current shell theme files. Only works with $user_theme_extension_id extension installed
    -v    view program version
    -w    export current wallpapers and their dconf configuration
Shorthand: to export anything use the -ad flags.
EOF
)

# Retrieve flags
while getopts 'acdeghisSvw' OPTION; do
    case "$OPTION" in
        a) export_cursor=true; export_enabled_extensions=true; export_shell=true; export_gtk=true; export_icon=true; export_sound=true; export_wallpaper=true ;;
        c) export_cursor=true ;;
        d) export_disabled_extensions=true ;;
        e) export_enabled_extensions=true ;;
        g) export_gtk=true ;;
        h) echo "$help"; exit 0 ;;
        i) export_icon=true ;;
        s) export_sound=true ;;
        S) export_shell=true ;;
        v) echo "$0 v0.0.0"; exit 0 ;;
        w) export_wallpaper=true ;;
        ?) echo "$help"; exit 2 ;;
    esac
done
shift "$(($OPTIND - 1))"

# Configure cp command
shopt -s extglob

#rm_single_quotes <string with single quotes> => string without single quotes
rm_single_quotes() {
    local tmp_str=${1#\'}
    echo "${tmp_str%\'}"
    return
}

# find_path <theme name> <user directory> <system directory> => path
find_path() {
    local name=$1
    local user_dir=$2
    local dir=$3
    local found=""
    if [ -d "$user_dir" ]; then
        if [ -d "$user_dir/$name" ]; then
            found="$user_dir/$name"
        fi
    fi
    if [ -d "$dir" ]; then
        if [ -d "$dir/$name" ]; then
            found="$dir/$name"
        fi
    fi
    if [ -n "$found" ]; then
        echo "$found"
        return
    else
        echo "Error: couldn't find theme $name in both $user_dir and $dir" 1>&2
        exit 3
    fi
}

# find_theme_path <theme name> => path
find_theme_path() {
    local name=$1
    local user_dir="$HOME/.themes"
    local user_dir_local="$HOME/.local/share/themes"
    local dir="/usr/share/themes"
    local found=""
    if [ -d "$user_dir" ]; then
        if [ -d "$user_dir/$name" ]; then
            found="$user_dir/$name"
        fi
    fi
    if [ -d "$user_dir_local" ]; then
        if [ -d "$user_dir_local/$name" ]; then
            found="$user_dir_local/$name"
        fi
    fi
    if [ -d "$dir" ]; then
        if [ -d "$dir/$name" ]; then
            found="$dir/$name"
        fi
    fi
    if [ -n "$found" ]; then
        echo "$found"
        return
    else
        echo "Error: couldn't find theme $name in $user_dir, $user_dir_local and $dir" 1>&2
        exit 3
    fi
}


# Create output directory
if [ $# -eq 0 ]; then
    echo "Error: no directory specified"
    echo "$help"
    exit 5
else
    mkdir -p "$*"
fi

# Gtk theme
if [ $export_gtk == true ]; then
    echo "=== GTK THEME ==="
    theme_dconf_name="$(rm_single_quotes "$(dconf read /org/gnome/desktop/interface/gtk-theme)")"
    gtk=$(find_theme_path "$theme_dconf_name")
    echo "cp: copying $gtk => $*/gtk-$theme_dconf_name"
    cp -r "$gtk" "$*/gtk-$theme_dconf_name"
fi

# Icon theme
if [ $export_icon == true ]; then
    echo "=== ICON THEME ==="
    icon_dconf_name="$(rm_single_quotes "$(dconf read /org/gnome/desktop/interface/icon-theme)")"
    icon=$(find_path "$icon_dconf_name" "$HOME/.local/share/icons" "/usr/share/icons")
    echo "cp: copying $icon/* except cursor.theme and cursors => $*/icon-$icon_dconf_name"
    mkdir -p "$*/icon-$icon_dconf_name"
    cp -r "$icon"/!(cursor.theme|cursors) "$*/icon-$icon_dconf_name/"  # Copies all the files in the icon theme directory except for the cursor.theme file and cursors directory, which are the cursor theme files instead
fi

# Cursor theme
if [ $export_cursor == true ]; then
    echo "=== CURSOR THEME ==="
    cursor_dconf_name="$(rm_single_quotes "$(dconf read /org/gnome/desktop/interface/cursor-theme)")"
    cursor_dconf_name=${cursor_dconf_name#\'}
    cursor_dconf_name=${cursor_dconf_name%\'}
    user_dirs=$(find "$HOME/.local/share/icons" -mindepth 1 -maxdepth 1 -type d)
    dirs=$(find "/usr/share/icons" -mindepth 1 -maxdepth 1 -type d)
    mkdir -p "$*/cursor-$cursor_dconf_name"
    found=false
    if [ ${#user_dirs[@]} -gt 0 ]; then
        find "$HOME/.local/share/icons" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r user_dir; do
            basename=$(basename "$user_dir")
            if [ "$basename" == "$cursor_dconf_name" ]; then
                found=true
                if cp "$user_dir/cursor.theme" "$*/cursor-$cursor_dconf_name" 2>/dev/null; then
                    echo "cp: copying $user_dir/cursor.theme => $*/cursor-$cursor_dconf_name"
                else
                    echo "Warning: couldn't copy $user_dir/cursor.theme (don't panic: not all cursor themes have this file)"
                fi
                echo "cp: copying $user_dir/cursors => $*/cursor-$cursor_dconf_name"
                cp -r "$user_dir/cursors" "$*/cursor-$cursor_dconf_name"
                break
            fi
        done
    fi
    if [ ${#dirs[@]} -gt 0 ]; then
        find "/usr/share/icons" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r dir; do
            basename=$(basename "$dir")
            if [ "$basename" == "$cursor_dconf_name" ]; then
                found=true
                if cp "$dir/cursor.theme" "$*/cursor-$cursor_dconf_name" 2>/dev/null; then
                    echo "cp: copying $dir/cursor.theme => $*/cursor-$cursor_dconf_name"
                else
                    echo "Warning: couldn't copy $dir/cursor.theme (don't panic: not all cursor themes have this file)"
                fi
                echo "cp: copying $dir/cursors => $*/cursor-$cursor_dconf_name"
                cp -r "$dir/cursors" "$*/cursor-$cursor_dconf_name"
                break
            fi
        done
    fi
    if [ ! $found ]; then
        echo "Error: the currently set cursor theme ($cursor_dconf_name) couldn't be found"
        exit 4
    fi
fi

# Sound theme
if [ $export_sound == true ]; then
    echo "=== SOUND THEME ==="
    sound_dconf_name="$(rm_single_quotes "$(dconf read /org/gnome/desktop/sound/theme-name)")"
    sound=$(find_path "$sound_dconf_name" "$HOME/.local/share/sounds" "/usr/share/sounds")
    echo "cp: copying $sound => $*/sound-$sound_dconf_name"
    cp -r "$sound" "$*/sound-$sound_dconf_name"
fi

# Extensions
extensions_user_path="$HOME/.local/share/gnome-shell/extensions"
extensions_path="/usr/share/gnome-shell/extensions"
extensions_list=""
if [ $export_enabled_extensions == true ]; then
    extensions_list+="$(gnome-extensions list --enabled)"
    extensions_list+=$'\n'
fi
if [ $export_disabled_extensions == true ]; then
    extensions_list+="$(gnome-extensions list --disabled)"
    extensions_list+=$'\n'
fi
if [ -n "$extensions_list" ]; then
    echo "=== EXTENSIONS ==="
    mkdir -p "$*/extensions"
    while IFS= read -r extension; do
        if [ -n "${extension[*]}" ]; then  # Because there's normally a \n at the end of the file
            if [ -d "$extensions_user_path/${extension[*]}" ]; then
                echo "cp: copying $extensions_user_path/${extension[*]} => $*/extensions/${extension[*]}"
                cp -r "$extensions_user_path/${extension[*]}" "$*/extensions/${extension[*]}"
            elif [ -d "$extensions_path/${extension[*]}" ]; then
                echo "cp: copying $extensions_path/${extension[*]} => $*/extensions/${extension[*]}"
                cp -r "$extensions_path/${extension[*]}" "$*/extensions/${extension[*]}"
            else
                echo "Error: extension ${extension[*]} couldn't be found both in $extensions_user_path and $extensions_path"
                exit 6
            fi
            extension_dump_name="${extension[*]%%@*}"
            echo "dconf dump: dumping /org/gnome/shell/extensions/$extension_dump_name/ => $*/extensions/$extension_dump_name.ini"
            extension_dump=$(dconf dump /org/gnome/shell/extensions/"$extension_dump_name"/)
            echo "$extension_dump" > "$*/extensions/$extension_dump_name.ini"
        fi
    done <<< "$extensions_list"
fi

# Shell theme
if [ $export_shell == true ]; then
    echo "=== SHELL THEME ==="
    shell_dconf_name="$(rm_single_quotes "$(dconf read /org/gnome/shell/extensions/user-theme/name)")"
    shell=""
    if [ "$shell_dconf_name" == "" ]; then
        shell_dconf_name="Adwaita"
        shell="/usr/share/themes/$shell_dconf_name"
        echo "Warning: reading current shell theme name from $user_theme_extension_id resulted in empty string, defaulting to $shell"
    else
        shell=$(find_path "$shell_dconf_name")
    fi
    echo "cp: copying $shell => $*/shell-$shell_dconf_name"
    cp -r "$shell" "$*/shell-$shell_dconf_name"

    # The following lines are to copy the configuration of /org/gnome/shell/ without its subfolders
    # It works fine but it is useless so I didn't implement it in import.sh
    # shell_dump="$(echo "$(dconf dump /org/gnome/shell/)" | sed '/^$/q')"
    # echo "$shell_dump" > "$shell_file"
fi

# Wallpapers
if [ $export_wallpaper == true ]; then
    echo "=== WALLPAPERS ==="

    # The following line is to copy the configuration of /org/gnome/desktop/background/
    # It works fine but it is useless so I didn't implement it in import.sh
    # echo "$(dconf dump /org/gnome/desktop/background/)" > "$bg_file"

    bg_path=$(dconf read /org/gnome/desktop/background/picture-uri)
    bg_path=${bg_path#\'file://}
    bg_path=${bg_path%\'}
    echo "cp: copying $bg_path => $*/light.${bg_path##*.}"
    cp "$bg_path" "$*/light.${bg_path##*.}"
    bg_path_dark=$(dconf read /org/gnome/desktop/background/picture-uri-dark)
    bg_path_dark=${bg_path_dark#\'file://}
    bg_path_dark=${bg_path_dark%\'}
    echo "cp: copying $bg_path_dark => $*/dark.${bg_path_dark##*.}"
    cp "$bg_path_dark" "$*/dark.${bg_path_dark##*.}"
fi