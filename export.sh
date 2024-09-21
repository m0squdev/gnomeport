#!/bin/bash

# Global variables
user_theme_extension_id="user-theme@gnome-shell-extensions.gcampax.github.com"
export_user_shell=false
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

# dconf dump output files
shell_file="$*/shell.ini"
bg_file="$*/bg.ini"

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
        echo "Error: both $user_dir and $dir directories don't exist" 1>&2
        exit 3
    fi
}

# Create output directory
if [ $# -eq 0 ]; then
    echo "Error: no directory specified"
    echo "$help"
    exit 5
else
    echo "Creating $* directory"
    mkdir -p "$*"
fi

# Gtk theme
if [ $export_gtk == true ]; then
    theme_dconf_name="$(rm_single_quotes "$(dconf read /org/gnome/desktop/interface/gtk-theme)")"
    echo "Copying $theme_dconf_name gtk theme"
    gtk=$(find_path "$theme_dconf_name" "$HOME/.themes" "/usr/share/themes")
    cp -r "$gtk" "$*/gtk-$theme_dconf_name"
fi

# Icon theme
if [ $export_icon == true ]; then
    icon_dconf_name="$(rm_single_quotes "$(dconf read /org/gnome/desktop/interface/icon-theme)")"
    echo "Copying $icon_dconf_name icon theme"
    icon=$(find_path "$icon_dconf_name" "$HOME/.local/share/icons" "/usr/share/icons")
    mkdir -p "$*/icon-$icon_dconf_name"
    cp -r "$icon"/!(cursor.theme|cursors) "$*/icon-$icon_dconf_name/"  # Copies all the files in the icon theme directory except for the cursor.theme file and cursors directory, which are the cursor theme files instead
fi

# Cursor theme
if [ $export_cursor == true ]; then
    cursor_dconf_name="$(rm_single_quotes "$(dconf read /org/gnome/desktop/interface/cursor-theme)")"
    cursor_dconf_name=${cursor_dconf_name#\'}
    cursor_dconf_name=${cursor_dconf_name%\'}
    echo "Copying $cursor_dconf_name cursor theme"
    user_dirs=$(find "$HOME/.local/share/icons" -mindepth 1 -maxdepth 1 -type d)
    dirs=$(find "/usr/share/icons" -mindepth 1 -maxdepth 1 -type d)
    mkdir -p "$*/cursor-$cursor_dconf_name"
    found=false
    if [ ${#user_dirs[@]} -gt 0 ]; then
        find "$HOME/.local/share/icons" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r user_dir; do
            basename=$(basename "$user_dir")
            if [ "$basename" == "$cursor_dconf_name" ]; then
                found=true
                if ! cp "$user_dir/cursor.theme" "$*/cursor-$cursor_dconf_name" 2>/dev/null; then
                    echo "Warning: $user_dir/cursor.theme file not found"
                fi
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
                if ! cp "$dir/cursor.theme" "$*/cursor-$cursor_dconf_name" 2>/dev/null; then
                    echo "Warning: $dir/cursor.theme file not found"
                fi
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
    sound_dconf_name="$(rm_single_quotes "$(dconf read /org/gnome/desktop/sound/theme-name)")"
    echo "Copying $sound_dconf_name sound theme"
    sound=$(find_path "$sound_dconf_name" "$HOME/.local/share/sounds" "/usr/share/sounds")
    cp -r "$sound" "$*/sound-$sound_dconf_name"
fi

# Extensions
extensions_user_path="$HOME/.local/share/gnome-shell/extensions"
extensions_path="/usr/share/gnome-shell/extensions"
extensions_list=""
if [ $export_enabled_extensions == true ]; then
    echo "Marked enabled extensions as to be copied"
    extensions_list+="$(gnome-extensions list --enabled)"
    extensions_list+=$'\n'
fi
if [ $export_disabled_extensions == true ]; then
    echo "Marked disabled extensions as to be copied"
    extensions_list+="$(gnome-extensions list --disabled)"
    extensions_list+=$'\n'
fi
mkdir -p "$*/extensions"
while IFS= read -r extension; do
    if [ -n "${extension[*]}" ]; then  # Because there's normally a \n at the end of the file
        if [ "${extension[*]}" == $user_theme_extension_id ]; then
            echo "Copying extension ${extension[*]}, current shell theme will be copied if flagged"
            export_user_shell=true
        else
            echo "Copying extension ${extension[*]}"
        fi
        if [ -d "$extensions_user_path/${extension[*]}" ]; then
            cp -r "$extensions_user_path/${extension[*]}" "$*/extensions/${extension[*]}"
        elif [ -d "$extensions_path/${extension[*]}" ]; then
            cp -r "$extensions_path/${extension[*]}" "$*/extensions/${extension[*]}"
        else
            echo "Error: extension ${extension[*]} couldn't be found both in $extensions_user_path and $extensions_path"
            exit 6
        fi
        extension_dump_name="${extension[*]%%@*}"
        extension_dump=$(dconf dump /org/gnome/shell/extensions/"$extension_dump_name"/)
        echo "$extension_dump" > "$*/extensions/$extension_dump_name.ini"
    fi
done <<< "$extensions_list"

# Shell theme
if [ $export_shell == true ]; then
    if [ $export_user_shell == true ]; then
        shell_dconf_name="$(rm_single_quotes "$(dconf read /org/gnome/shell/extensions/user-theme/name)")"
        shell=""
        if [ "$shell_dconf_name" == "" ]; then
            shell_dconf_name="Adwaita"
            shell="/usr/share/themes/$shell_dconf_name"
            echo "Warning: reading current shell theme name from $user_theme_extension_id resulted in empty string, defaulting to $shell"
        else
            shell=$(find_path "$shell_dconf_name" "$HOME/.themes" "/usr/share/themes")
        fi
        echo "Copying $shell_dconf_name shell theme"
        cp -r "$shell" "$*/shell-$shell_dconf_name"
    else
        echo "Warning: extension $user_theme_extension_id not found, current shell theme won't be exported (shell dconf configuration will be exported anyway)"
    fi

    # The following snippet is to copy the configuration of /org/gnome/shell/ without its subfolders
    # It works fine but it is useless so I didn't implement it in import.sh
    # echo "Copying shell configuration"
    # shell_dump="$(echo "$(dconf dump /org/gnome/shell/)" | sed '/^$/q')"
    # echo "$shell_dump" > "$shell_file"
fi

# Wallpapers
if [ $export_wallpaper == true ]; then
    # The following snippet is to copy the configuration of /org/gnome/desktop/background
    # It works fine but it is useless so I didn't implement it in import.sh
    # echo "Copying wallpaper configuration"
    # echo "$(dconf dump /org/gnome/desktop/background/)" > "$bg_file"

    bg_path=$(dconf read /org/gnome/desktop/background/picture-uri)
    bg_path=${bg_path#\'file://}
    bg_path=${bg_path%\'}
    echo "Copying light wallpaper $bg_path"
    cp "$bg_path" "$*/light.${bg_path##*.}"
    bg_path_dark=$(dconf read /org/gnome/desktop/background/picture-uri-dark)
    bg_path_dark=${bg_path_dark#\'file://}
    bg_path_dark=${bg_path_dark%\'}
    echo "Copying dark wallpaper $bg_path_dark"
    cp "$bg_path_dark" "$*/dark.${bg_path_dark##*.}"
fi