#!/bin/bash

# CLIX: A Plex Terminal Media Player
# Browse and play Plex media from the command line
#
# Developed by Jereme Hancock
# https://github.com/jeremehancock/CLIX
#
# MIT License
#
# Copyright (c) 2024 Jereme Hancock
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

###################
# Server Settings #
###################

PLEX_URL="http://localhost:32400"
PLEX_TOKEN=""

########################################################################################################
################################### DO NOT EDIT ANYTHING BELOW #########################################
########################################################################################################

# Version information
VERSION="1.0.1"

# Show version
show_version() {
    echo "Plex Terminal Player v${VERSION}"
    check_version
}

# Check for updates
check_version() {
    if ! command -v curl &> /dev/null; then
        echo -e "Error: curl is required for version checking"
        return 1
    fi

    local remote_version
    remote_version=$(curl -s https://raw.githubusercontent.com/jeremehancock/CLIX/refs/heads/main/clix.sh | grep "^VERSION=" | cut -d'"' -f2)
    
    if [[ -z "$remote_version" ]]; then
        echo -e "Error: Could not fetch remote version"
        return 1
    fi

    # Compare versions (assuming semantic versioning x.y.z format)
    if [[ "$remote_version" != "$VERSION" ]]; then
        echo -e "Update available: v$VERSION → v$remote_version"
        echo -e "Use the Update option in the main menu or run with -u to update to the latest version"
        return 0
    fi
}

# Update script
update_script() {
    if ! command -v curl &> /dev/null; then
        echo -e "Error: curl is required for updating"
        return 1
    fi

    echo -e "Updating script..."
    
    # Create backups directory if it doesn't exist
    local backup_dir="backups"
    mkdir -p "$backup_dir"

    # Create backup of current script with version number
    local script_name=$(basename "$0")
    local backup_file="${backup_dir}/${script_name}.v${VERSION}.backup"
    cp "$0" "$backup_file"
    
    echo -n "Do you want to proceed with the update? [y/N] "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Update cancelled."
        return 0
    fi
    
    # Download new version
    if curl -o "$script_name" -L https://raw.githubusercontent.com/jeremehancock/CLIX/main/clix.sh; then
        # Preserve Plex URL and Token from the last backup
        local last_backup=$(ls -t "$backup_dir"/*.backup | head -n 1)
        
        if [[ -n "$last_backup" ]]; then
            # Extract Plex URL and Token from the last backup
            local old_plex_url=$(grep "^PLEX_URL=" "$last_backup" | cut -d'"' -f2)
            local old_plex_token=$(grep "^PLEX_TOKEN=" "$last_backup" | cut -d'"' -f2)
            
            # Update new script with preserved credentials
            if [[ -n "$old_plex_url" ]]; then
                sed -i "s|^PLEX_URL=.*|PLEX_URL=\"$old_plex_url\"|" "$script_name"
            fi
            
            if [[ -n "$old_plex_token" ]]; then
                sed -i "s|^PLEX_TOKEN=.*|PLEX_TOKEN=\"$old_plex_token\"|" "$script_name"
            fi
        fi
        
        chmod +x "$script_name"
        echo -e "Successfully updated script"
        echo -e "Previous version backed up to $backup_file"
        
        # Exit after successful update to ensure credentials are used
        exit 0
    else
        echo -e "Update failed"
        # Restore backup
        mv "$backup_file" "$script_name"
        return 1
    fi
}


# Show help menu
show_help() {
    cat << EOF
Plex Terminal Player v${VERSION} - Navigation Guide

OPTIONS:
    -h          Show this help message
    -v          Show version information
    -u          Update to the latest version

NAVIGATION:
    ↑/↓     Move up/down in menus
    Enter   Select current item
    ESC     Go back to previous menu
    Ctrl+C  Exit the program

MENU STRUCTURE:
    1. Main Menu
        - Movies
        - TV Shows
        - Music
        - Update
        - Help
        - Quit
    
    2. Library Selection
        → Select your preferred library
    
    3. Media Selection
        Movies: Select movie from list
        TV Shows: Select show → season → episode
        Music: Select artist → album → track

NOTE: 
    - Use fuzzy search by typing to quickly find items
    - Updates can be performed via -u option or Update menu item

DEPENDENCIES:
    Required: curl, xmlstarlet, fzf, mpv
EOF
}

# Dependencies check
check_dependencies() {
    local deps=("curl" "xmlstarlet" "fzf" "mpv")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo "Missing required dependencies: ${missing[*]}"
        echo "Please install them and try again."
        exit 1
    fi
}

# Get Plex libraries
get_libraries() {
    local response
    response=$(curl -s -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/sections")

    if [[ -z "$response" ]]; then
        echo "Error: No response from Plex server."
        exit 1
    fi

    # List all libraries in the format: <key>|<title>|<type>
    echo "$response" | xmlstarlet sel -t -m "//Directory" -v "concat(@key, '|', @title, '|', @type)" -n
}

# Get library contents
get_library_contents() {
    local library_key="$1"
    local response
    response=$(curl -s -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/sections/${library_key}/all")

    if [[ -z "$response" ]]; then
        echo "Error: No response from Plex server."
        exit 1
    fi

    local first_item_type
    first_item_type=$(echo "$response" | xmlstarlet sel -t -m "//Video | //Directory" -v "name()" -n | head -n 1)

    if [[ "$first_item_type" == "Video" ]]; then
        # Modified to put ID at the end for movies
        echo "$response" | xmlstarlet sel -t -m "//Video" -v "concat(@title, ' (', @year, ')|', @ratingKey)" -n
    elif [[ "$first_item_type" == "Directory" ]]; then
        # Modified to put ID at the end for shows/artists
        echo "$response" | xmlstarlet sel -t -m "//Directory" -v "concat(@title, '|', @ratingKey)" -n
    else
        echo "Error: Could not determine media type."
        exit 1
    fi
}

# Get Plex streaming URL
get_stream_url() {
    local media_key="$1"
    local media_type="$2"

    local response
    response=$(curl -s -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/metadata/${media_key}")

    if [[ -z "$response" ]]; then
        echo "Error: No response from Plex server."
        return 1
    fi

    local stream_url
    stream_url=$(echo "$response" | xmlstarlet sel -t -m "//Part" -v "@key" -n)

    if [[ -n "$stream_url" ]]; then
        echo "${PLEX_URL}${stream_url}?X-Plex-Token=${PLEX_TOKEN}"
    else
        echo "Error: Could not retrieve stream URL."
        return 1
    fi
}

# Get albums for an artist
get_albums() {
    local artist_key="$1"
    local response

    response=$(curl -s -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/metadata/${artist_key}/children")

    if [[ -z "$response" ]]; then
        echo "Error: No response from Plex server."
        exit 1
    fi

    # Modified to put ID at the end
    echo "$response" | xmlstarlet sel -t -m "//Directory" -v "concat(@title, '|', @ratingKey)" -n
}

# Get tracks for an album
get_tracks() {
    local album_key="$1"
    local response

    response=$(curl -s -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/metadata/${album_key}/children")

    if [[ -z "$response" ]]; then
        echo "Error: No response from Plex server."
        exit 1
    fi

    # Modified to put ID at the end and format track numbers properly
    echo "$response" | xmlstarlet sel -t -m "//Track" -v "concat(@index, '. ', @title, '|', @ratingKey)" -n
}

# Get seasons for a TV show
get_seasons() {
    local show_key="$1"
    local response

    response=$(curl -s -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/metadata/${show_key}/children")

    if [[ -z "$response" ]]; then
        echo "Error: No response from Plex server."
        exit 1
    fi
    
    # Extract seasons but filter out "all episodes"
    echo "$response" | xmlstarlet sel -t -m "//Directory[@type='season']" -v "@title" -o "|" -v "@ratingKey" -n | \
    grep -v "^All episodes|" | sort -V
}

# Get episodes for a season
get_episodes() {
    local season_key="$1"
    local response

    response=$(curl -s -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/metadata/${season_key}/children")

    if [[ -z "$response" ]]; then
        echo "Error: No response from Plex server."
        exit 1
    fi

    # Modified to put ID at the end and show episode info
    echo "$response" | xmlstarlet sel -t -m "//Video" -v "concat(@index, '. ', @title, '|', @ratingKey)" -n
}

# Play media using mpv
play_media() {
    local media_key="$1"
    local media_type="$2"

    local media_url
    media_url=$(get_stream_url "$media_key" "$media_type")

    if [[ -n "$media_url" ]]; then
        echo "Playing $media_type..."
        mpv "$media_url"
    else
        echo "Error: Could not retrieve stream URL."
        read -p "Press Enter to continue..." 
    fi
}

# Display help in pager
display_help() {
    clear
    show_help
    echo -e "\nPress q to return to main menu..."
    read -n 1 key
    while [[ $key != "q" ]]; do
        read -n 1 key
    done
    clear
}

# Select media with error handling
select_media() {
    local library_type="$1"

    case "$library_type" in 
        movie)
            local libraries
            libraries=$(get_libraries | grep "movie")
            
            if [[ -z "$libraries" ]]; then
                echo "No movie libraries found."
                return 1
            fi

            local chosen_library
            chosen_library=$(echo "$libraries" | cut -d'|' -f2 | fzf --reverse --header="Select Movie Library" --prompt="Select a Movie Library > ")
            
            if [[ -z "$chosen_library" ]]; then
                return 1
            fi

            local lib_key
            lib_key=$(echo "$libraries" | grep "|${chosen_library}|" | cut -d'|' -f1)
            
            local movies
            movies=$(get_library_contents "$lib_key")
            
            local chosen_movie
            chosen_movie=$(echo "$movies" | cut -d'|' -f1 | fzf --reverse --header="Select Movie" --prompt="Select a Movie > ")
            
            if [[ -z "$chosen_movie" ]]; then
                return 1
            fi

            local movie_key
            movie_key=$(echo "$movies" | grep "^${chosen_movie}|" | cut -d'|' -f2)
            
            play_media "$movie_key" "movie"
            ;;
        
        show)
            local libraries
            libraries=$(get_libraries | grep "show")
            
            if [[ -z "$libraries" ]]; then
                echo "No TV show libraries found."
                return 1
            fi

            local chosen_library
            chosen_library=$(echo "$libraries" | cut -d'|' -f2 | fzf --reverse --header="Select TV Show Library" --prompt="Select a TV Show Library > ")
            
            if [[ -z "$chosen_library" ]]; then
                return 1
            fi

            local lib_key
            lib_key=$(echo "$libraries" | grep "|${chosen_library}|" | cut -d'|' -f1)
            
            local shows
            shows=$(get_library_contents "$lib_key")
            
            local chosen_show
            chosen_show=$(echo "$shows" | cut -d'|' -f1 | fzf --reverse --header="Select TV Show" --prompt="Select a TV Show > ")
            
            if [[ -z "$chosen_show" ]]; then
                return 1
            fi

            local show_key
            show_key=$(echo "$shows" | grep "^${chosen_show}|" | cut -d'|' -f2)
            
            local seasons
            seasons=$(get_seasons "$show_key")
            
            local chosen_season
            chosen_season=$(echo "$seasons" | cut -d'|' -f1 | fzf --reverse --header="Select Season" --prompt="Select a Season > ")
            
            if [[ -z "$chosen_season" ]]; then
                return 1
            fi

            local season_key
            season_key=$(echo "$seasons" | grep "^${chosen_season}|" | cut -d'|' -f2)

            local episodes
            episodes=$(get_episodes "$season_key")
            
            local chosen_episode
            chosen_episode=$(echo "$episodes" | cut -d'|' -f1 | fzf --reverse --header="Select Episode" --prompt="Select an Episode > ")
            
            if [[ -z "$chosen_episode" ]]; then
                return 1
            fi

            local episode_key
            episode_key=$(echo "$episodes" | grep "^${chosen_episode}|" | cut -d'|' -f2)
            
            play_media "$episode_key" "episode"
            ;;
        
        music)
            local libraries
            libraries=$(get_libraries | grep "artist")
            
            if [[ -z "$libraries" ]]; then
                echo "No music libraries found."
                return 1
            fi

            local chosen_library
            chosen_library=$(echo "$libraries" | cut -d'|' -f2 | fzf --reverse --header="Select Music Library" --prompt="Select a Music Library > ")
            
            if [[ -z "$chosen_library" ]]; then
                return 1
            fi

            local lib_key
            lib_key=$(echo "$libraries" | grep "|${chosen_library}|" | cut -d'|' -f1)
            
            local artists
            artists=$(get_library_contents "$lib_key")
            
            local chosen_artist
            chosen_artist=$(echo "$artists" | cut -d'|' -f1 | fzf --reverse --header="Select Artist" --prompt="Select an Artist > ")
            
            if [[ -z "$chosen_artist" ]]; then
                return 1
            fi

            local artist_key
            artist_key=$(echo "$artists" | grep "^${chosen_artist}|" | cut -d'|' -f2)
            
            local albums
            albums=$(get_albums "$artist_key")
            
            local chosen_album
            chosen_album=$(echo "$albums" | cut -d'|' -f1 | fzf --reverse --header="Select Album" --prompt="Select an Album > ")
            
            if [[ -z "$chosen_album" ]]; then
                return 1
            fi

            local album_key
            album_key=$(echo "$albums" | grep "^${chosen_album}|" | cut -d'|' -f2)
            
            local tracks
            tracks=$(get_tracks "$album_key")
            
            local chosen_track
            chosen_track=$(echo "$tracks" | cut -d'|' -f1 | fzf --reverse --header="Select Track" --prompt="Select a Track > ")
            
            if [[ -z "$chosen_track" ]]; then
                return 1
            fi

            local track_key
            track_key=$(echo "$tracks" | grep "^${chosen_track}|" | cut -d'|' -f2)
            
            play_media "$track_key" "music"
            ;;
        
        *)
            echo "Unsupported media type"
            return 1
            ;;
    esac
}

# Main menu
main_menu() {
    local choice
    choice=$(echo -e "Movies\nTV Shows\nMusic\nUpdate\nHelp\nQuit" | fzf --reverse --header="Select Media Type" --prompt="Select a Media Type > ")
    
    case "$choice" in
        Movies) select_media "movie" ;;
        "TV Shows") select_media "show" ;;
        Music) select_media "music" ;;
        Update) 
            echo "Checking for updates..."
            update_script
            echo "Press Enter to continue..."
            read
            clear
            ;;
        Help) display_help ;;
        Quit) exit 0 ;;
        *) echo "Invalid selection" ;;
    esac
}

# Main program
main() {
    # Parse command line arguments
    while getopts "hvu" opt; do
        case ${opt} in
            h )
                show_help
                exit 0
                ;;
            v )
                show_version
                exit 0
                ;;
            u )
                update_script
                exit 0
                ;;
            \? )
                echo "Invalid Option: -$OPTARG" 1>&2
                show_help
                exit 1
                ;;
        esac
    done
    shift $((OPTIND -1))
    
    check_dependencies
    
    if [ -z "$PLEX_TOKEN" ]; then
        echo "Error: Plex token not set"
        echo "Please edit this script and add your Plex token"
        exit 1
    fi
    
    # Show quick tip at startup
    clear
    echo "-------------------------------------------------------------------------"
    echo "Plex Terminal Player v${VERSION}"
    echo "Tip: Press ESC to go back to previous menu, or select Help for more info"
    echo "-------------------------------------------------------------------------"
    sleep 2
    clear
    
    while true; do
        main_menu
    done
}

# Run the program
main "$@"
