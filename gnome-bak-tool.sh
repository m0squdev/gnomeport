#!/bin/bash

# Global variables
help=$(cat << EOF
Usage: $0 [FLAGS] OUTPUT_DIRECTORY
FLAGS:
    -a    shorthand to -cefgisw (export anything but disabled extensions' files)
    -c    export current cursor theme files
    -e    export enabled extensions' files
    -d    export disabled extensions' files
    -f    export current shell theme files and the shell's dconf configuration
    -g    export current gtk theme files
    -h    view help
    -i    export current icon theme files, excluding the files related to the cursor
    -s    export current sound theme files
    -v    view program version
    -w    export current wallpapers and their dconf configuration
EOF
)
export_gtk=false
export_icon=false
export_cursor=false
export_sound=false
export_enabled_extensions=false
export_disabled_extensions=false
export_shell=false
export_wallpaper=false

# Retrieve flags
while getopts 'acdefghisvw' OPTION; do
    case "$OPTION" in
        a) export_cursor=true; export_enabled_extensions=true; export_shell=true; export_gtk=true; export_icon=true; export_sound=true; export_wallpaper=true ;;
        c) export_cursor=true ;;
        d) export_disabled_extensions=true ;;
        e) export_enabled_extensions=true ;;
        f) export_shell=true ;;
        g) export_gtk=true ;;
        h) echo "$help"; exit 0 ;;
        i) export_icon=true ;;
        s) export_sound=true ;;
        v) echo "$0 v0.0.0"; exit 0 ;;
        w) export_wallpaper=true ;;
        ?) echo "$help"; exit 2 ;;
    esac
done
shift "$(($OPTIND - 1))"

shell_file="$*/shell.txt"
bg_file="$*/bg.txt"
export_user_shell=false
user_theme_extension_id="user-theme@gnome-shell-extensions.gcampax.github.com"

# Configure cp command
shopt -s extglob

# find_path <theme name> <user directory> <system directory> => path
find_path() {
    local name=${1#\'}
    name=${name%\'}
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
    echo "Error: no directory specified."
    echo "$help"
    exit 5
else
    echo "Creating $* directory"
    mkdir -p "$*"
fi

# Gtk theme
if [ $export_gtk == true ]; then
    echo "Copying current gtk theme"
    gtk=$(find_path "$(dconf read /org/gnome/desktop/interface/gtk-theme)" "$HOME/.themes" "/usr/share/themes")
    cp -r "$gtk" "$*/gtk"
fi

# Icon theme
if [ $export_icon == true ]; then
    echo "Copying current icon theme"
    icon=$(find_path "$(dconf read /org/gnome/desktop/interface/icon-theme)" "$HOME/.local/share/icons" "/usr/share/icons")
    mkdir -p "$*/icon"
    cp -r "$icon"/!(cursor.theme|cursors) "$*/icon/"  # Copies all the files in the icon theme directory except for the cursor.theme file and cursors directory, which are the cursor theme files instead
fi

# Cursor theme
if [ $export_cursor == true ]; then
    echo "Copying current cursor theme"
    cursor_dconf_name=$(dconf read /org/gnome/desktop/interface/cursor-theme)
    cursor_dconf_name=${cursor_dconf_name#\'}
    cursor_dconf_name=${cursor_dconf_name%\'}
    user_dirs=$(find "$HOME/.local/share/icons" -mindepth 1 -maxdepth 1 -type d)
    dirs=$(find "/usr/share/icons" -mindepth 1 -maxdepth 1 -type d)
    mkdir -p "$*/cursor"
    found=false
    if [ ${#user_dirs[@]} -gt 0 ]; then
        find "$HOME/.local/share/icons" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r user_dir; do
            basename=$(basename "$user_dir")
            if [ "$basename" == "$cursor_dconf_name" ]; then
                found=true
                #cp -r "$user_cursor" "$*/cursor"
                cp "$user_dir/cursor.theme" "$*/cursor"
                cp -r "$user_dir/cursors" "$*/cursor"
                break
            fi
        done
    fi
    if [ ${#dirs[@]} -gt 0 ]; then
        find "/usr/share/icons" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r dir; do
            basename=$(basename "$dir")
            if [ "$basename" == "$cursor_dconf_name" ]; then
                found=true
                #cp -r "$cursor" "$*/cursor"
                cp "$dir/cursor.theme" "$*/cursor"
                cp -r "$dir/cursors" "$*/cursor"
                break
            fi
        done
    fi
    if [ ! $found ]; then
        echo "Error: the currently set cursor theme ($cursor_dconf_name) couldn't be found"
        exit 4
    fi
fi

# Sounds
if [ $export_sound == true ]; then
    echo "Copying current sound theme"
    sound=$(find_path "$(dconf read /org/gnome/desktop/sound/theme-name)" "$HOME/.local/share/sounds" "/usr/share/sounds")
    cp -r "$sound" "$*/sound"
fi

# Extensions
extensions_user_path="$HOME/.local/share/gnome-shell/extensions"
extensions_path="/usr/share/gnome-shell/extensions"
extensions_list=""
if [ $export_enabled_extensions == true ]; then
    echo "Copying enabled extensions"
    extensions_list+="$(gnome-extensions list --enabled)"
    extensions_list+=$'\n'
fi
if [ $export_disabled_extensions == true ]; then
    echo "Copying disabled extensions"
    extensions_list+="$(gnome-extensions list --disabled)"
    extensions_list+=$'\n'
fi
#$extensions_list | while IFS= read -r extension; do
while IFS= read -r extension; do
    if [ "${extension[*]}" == $user_theme_extension_id ]; then
        echo "Extension ${extension[*]} found, current shell theme will be copied if flagged"
        export_user_shell=true
    fi
    if [ -d "$extensions_user_path/${extension[*]}" ]; then
        cp -r "$extensions_user_path/${extension[*]}" "$*/extensions"
    elif [ -d "$extensions_path/${extension[*]}" ]; then
        cp -r "$extensions_path/${extension[*]}" "$*/extensions"
    else
        echo "Error: enabled extension ${extension[*]} couldn't be found both in $extensions_user_path and $extensions_path"
        exit 6
    fi
done <<< "$extensions_list"

# Shell theme and configuration (includes extensions' settings)
if [ $export_shell == true ]; then
    if [ $export_user_shell == true ]; then
        echo "Copying current shell theme"
        shell_name=$(dconf read /org/gnome/shell/extensions/user-theme/name)
        shell=""
        if [ "$shell_name" == "''" ]; then
            shell="/usr/share/themes/Adwaita"
            echo "Warning: reading current shell theme name from $user_theme_extension_id resulted in empty string, defaulting to $shell"
        else
            shell=$(find_path "$shell_name" "$HOME/.themes" "/usr/share/themes")
        fi
        cp -r "$shell" "$*/shell"
    else
        echo "Warning: extension $user_theme_extension_id not found, current shell theme won't be exported"
    fi

    echo "Copying shell configuration"
    echo "$(dconf dump /org/gnome/shell/)" > "$shell_file"
    # TODO: only copy enabled extensions' settings if not flagged by -d
fi

# Wallpaper configuration and wallpapers
if [ $export_wallpaper == true ]; then
    echo "Copying wallpaper configuration"
    echo "$(dconf dump /org/gnome/desktop/background/)" > "$bg_file"

    echo "Copying current light and dark wallpapers"
    bg_path=$(dconf read /org/gnome/desktop/background/picture-uri)
    bg_path=${bg_path#\'file://}
    bg_path=${bg_path%\'}
    bg_path_dark=$(dconf read /org/gnome/desktop/background/picture-uri-dark)
    bg_path_dark=${bg_path_dark#\'file://}
    bg_path_dark=${bg_path_dark%\'}
    cp "$bg_path" "$*/light.${bg_path##*.}"
    cp "$bg_path_dark" "$*/dark.${bg_path##*.}"
fi