#!/bin/bash

# Global variables
user_theme_extension_id="user-theme@gnome-shell-extensions.gcampax.github.com"
icon_user_dir="$HOME/.local/share/icons"
icon_dir="/usr/share/icons"
cursor_user_dir="$icon_user_dir"
cursor_dir="$icon_dir"
sound_user_dir="$HOME/.local/share/sounds"
sound_dir="/usr/share/sounds"
export_gtk=false
export_icon=false
export_cursor=false
export_sound=false
export_extensions=false
export_shell=false
export_wallpaper=false
export_shortcuts=false
export_accent_color=false
export_color_scheme=false
help=$(cat << EOF
Usage: $0 [FLAGS] OUTPUT_DIRECTORY
FLAGS:
    -a    export anything
    -A    export accent color (GNOME 47+)
    -c    export current cursor theme files
    -C    export color scheme
    -e    [EXPERIMENTAL] export extensions' files and dconf configurations
    -g    export current GTK theme files
    -h    view help
    -i    export current icon theme files. This exports the whole theme, including eventual files related to the cursor
    -k    export current keyboard shortcuts from dconf. Looks inside desktop, mutter, settings-daemon and shell configurations
    -s    export current sound theme files
    -S    export current shell theme files. Only works with $user_theme_extension_id extension installed
    -v    view program version
    -w    export current wallpapers and their dconf configuration
EOF
)

# Retrieve flags
while getopts 'aAcCdeghiksSvw' OPTION; do
    case "$OPTION" in
        a) export_accent_color=true; export_cursor=true; export_color_scheme=true; export_extensions=true; export_gtk=true; export_icon=true; export_shortcuts=true; export_sound=true; export_shell=true; export_wallpaper=true ;;
        A) export_accent_color=true ;;
        c) export_cursor=true ;;
        C) export_color_scheme=true ;;
        e) export_extensions=true ;;
        g) export_gtk=true ;;
        h) echo "$help"; exit 0 ;;
        i) export_icon=true ;;
        k) export_shortcuts=true ;;
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
        echo "Warning: couldn't find theme $name in both $user_dir and $dir" 1>&2
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
        echo "Warning: couldn't find theme $name in $user_dir, $user_dir_local and $dir" 1>&2
    fi
}

# copy_parents_from_index <theme path> <theme type>
copy_parents_from_index() {
    local theme_path="$1"
    local destination_path="$2"
    local theme_type="$3"
    local index_path="$theme_path/index.theme"
    if [ -f "$index_path" ]; then
        local parents_line=$(grep -i '^Inherits=' "$index_path" | cut -d '=' -f 2)
        local parents=$(echo "$parents_line" | cut -d '=' -f 2 | tr -d ' ')
        IFS=',' read -ra parents_array <<< "$parents"
        for parent in "${parents_array[@]}"; do
            if [ "$theme_type" == "gtk" ] || [ "$theme_type" == "shell" ]; then
                parent_path=$(find_theme_path "$parent")
            else
                eval "parent_user_dir=\${${theme_type}_user_dir}"
                eval "parent_dir=\${${theme_type}_dir}"
                parent_path=$(find_path "$parent" "$parent_user_dir" "$parent_dir")
            fi
            if [ -d "$parent_path" ]; then  # Check if the parent theme exists. Many times it doesn't!
                destination_full_path="$destination_path/${theme_type}parent-$parent"
                if [ -d "$destination_full_path" ]; then
                    echo "cp: skipping $parent_path => $destination_full_path because destination already exists"
                else
                    echo "cp: copying $parent_path => $destination_full_path"
                    cp -r "$parent_path" "$destination_full_path"
                    copy_parents_from_index "$parent_path" "$destination_path" "$theme_type"
                fi
            fi
        done
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
    copy_parents_from_index "$gtk" "$*" "gtk"
fi

# Icon theme
if [ $export_icon == true ]; then
    echo "=== ICON THEME ==="
    icon_dconf_name="$(rm_single_quotes "$(dconf read /org/gnome/desktop/interface/icon-theme)")"
    icon=$(find_path "$icon_dconf_name" "$icon_user_dir" "$icon_dir")
    echo "cp: copying $icon => $*/icon-$icon_dconf_name"
    cp -r "$icon" "$*/icon-$icon_dconf_name/"
    copy_parents_from_index "$icon" "$*" "icon"
fi

# Cursor theme
if [ $export_cursor == true ]; then
    echo "=== CURSOR THEME ==="
    cursor_dconf_name="$(rm_single_quotes "$(dconf read /org/gnome/desktop/interface/cursor-theme)")"
    cursor_dconf_name=${cursor_dconf_name#\'}
    cursor_dconf_name=${cursor_dconf_name%\'}
    cursor=$(find_path "$cursor_dconf_name" "$icon_user_dir" "$icon_dir")
    echo "cp: copying $cursor => $*/cursor-$cursor_dconf_name"
    cp -r "$cursor" "$*/cursor-$cursor_dconf_name"
    copy_parents_from_index "$cursor" "$*" "cursor"
fi

# Sound theme
if [ $export_sound == true ]; then
    echo "=== SOUND THEME ==="
    sound_dconf_name="$(rm_single_quotes "$(dconf read /org/gnome/desktop/sound/theme-name)")"
    sound=$(find_path "$sound_dconf_name" "$sound_user_dir" "$sound_dir")
    echo "cp: copying $sound => $*/sound-$sound_dconf_name"
    cp -r "$sound" "$*/sound-$sound_dconf_name"
    copy_parents_from_index "$sound" "$*" "sound"
fi

# Extensions
extensions_user_path="$HOME/.local/share/gnome-shell/extensions"
extensions_path="/usr/share/gnome-shell/extensions"
extensions_schemas_path="/usr/share/glib-2.0/schemas"
if [ $export_extensions == true ]; then
    echo "=== EXTENSIONS ==="
    extensions_list="$(gnome-extensions list)"
    extensions_list+=$'\n'
    mkdir -p "$*/extensions"
    while IFS= read -r extension; do
        if [ -n "${extension[*]}" ]; then  # Because there's normally a \n at the end of the string
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
        fi
    done <<< "$extensions_list"
    parent_dconf_dir="/org/gnome/shell/extensions/"
    children_dconf_basenames="$(dconf list $parent_dconf_dir)"
    while IFS= read -r child_dconf_basename; do
        if [ -n "${child_dconf_basename[*]}" ]; then  # Because there's normally a \n at the end of the string
            child_dconf_dir="$parent_dconf_dir$child_dconf_basename"
            destination="$*/extensions/$(basename "${child_dconf_basename[*]}").ini"
            echo "dconf dump: dumping ${child_dconf_dir[*]} => $destination"
            dconf dump $child_dconf_dir > "$destination"
        fi
    done <<< "$children_dconf_basenames"
    echo "cp: copying $extensions_schemas_path/org.gnome.shell.extensions.*.gschema.xml => $*/extensions"
    cp "$extensions_schemas_path"/org.gnome.shell.extensions.*.gschema.xml "$*/extensions"
fi

# Shell theme
if [ $export_shell == true ]; then
    echo "=== SHELL THEME ==="
    shell_dconf_name="$(rm_single_quotes "$(dconf read /org/gnome/shell/extensions/user-theme/name)")"
    shell=""
    if [ "$shell_dconf_name" == "" ]; then
        shell_dconf_name="Default"
        shell="/usr/share/themes/$shell_dconf_name"
        echo "Warning: reading current shell theme name from $user_theme_extension_id resulted in empty string, defaulting to $shell"
    else
        shell=$(find_theme_path "$shell_dconf_name")
    fi
    echo "cp: copying $shell => $*/shell-$shell_dconf_name"
    cp -r "$shell" "$*/shell-$shell_dconf_name"
    copy_parents_from_index "$shell" "$*" "shell"

    # The following lines are to copy the configuration of /org/gnome/shell/ without its subfolders
    # It works fine but it is useless so I didn't implement it in import.sh
    # shell_dump="$(echo "$(dconf dump /org/gnome/shell/)" | sed '/^$/q')"
    # echo "$shell_dump" > "$shell_"
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

# Shortcuts
if [ $export_shortcuts == true ]; then
    echo "=== KEYBOARD SHORTCUTS ==="
    mkdir -p "$*/shortcuts"
    echo "dconf dump: dumping /org/gnome/desktop/wm/keybindings/ => $*/shortcuts/desktop.ini"
    dconf dump /org/gnome/desktop/wm/keybindings/ > "$*/shortcuts/desktop.ini"
    echo "dconf dump: dumping /org/gnome/mutter/keybindings/ => $*/shortcuts/mutter.ini"
    dconf dump /org/gnome/mutter/keybindings/ > "$*/shortcuts/mutter.ini"
    echo "dconf dump: dumping /org/gnome/mutter/wayland/keybindings/ => $*/shortcuts/mutter-wayland.ini"
    dconf dump /org/gnome/mutter/wayland/keybindings/ > "$*/shortcuts/mutter-wayland.ini"
    echo "dconf dump: dumping /org/gnome/settings-daemon/plugins/media-keys/ => $*/shortcuts/settings-daemon.ini"
    dconf dump /org/gnome/settings-daemon/plugins/media-keys/ > "$*/shortcuts/settings-daemon.ini"
    echo "dconf dump: dumping /org/gnome/shell/keybindings/ => $*/shortcuts/shell.ini"
    dconf dump /org/gnome/shell/keybindings/ > "$*/shortcuts/shell.ini"
fi

# Accent color
if [ $export_accent_color == true ]; then
    echo "=== ACCENT COLOR ==="
    echo "dconf read: reading /org/gnome/desktop/interface/accent-color => $*/accent-color.txt"
    accent_color=$(dconf read /org/gnome/desktop/interface/accent-color)
    if [ -n "$accent_color" ]; then
        echo "$accent_color" > "$*/accent-color.txt"
    else
        echo "Warning: reading accent-color from dconf failed, skipping. Are you running GNOME 47+?"
    fi
fi

# Color scheme
if [ $export_color_scheme == true ]; then
    echo "=== COLOR SCHEME ==="
    echo "dconf read: reading /org/gnome/desktop/interface/color-scheme => $*/color-scheme.txt"
    dconf read /org/gnome/desktop/interface/color-scheme > "$*/color-scheme.txt"
fi
