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

VERSION="1.0.8"

show_version() {
    echo "CLIX v${VERSION}"
    check_version
}

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

update_script() {
    if ! command -v curl &> /dev/null; then
        echo -e "Error: curl is required for updating"
        return 1
    fi

    # Check for updates first
    local remote_version
    remote_version=$(curl -s https://raw.githubusercontent.com/jeremehancock/CLIX/refs/heads/main/clix.sh | grep "^VERSION=" | cut -d'"' -f2)
    
    if [[ -z "$remote_version" ]]; then
        echo -e "Error: Could not fetch remote version"
        return 1
    fi

    # Compare versions (assuming semantic versioning x.y.z format)
    if [[ "$remote_version" == "$VERSION" ]]; then
        echo -e "No updates available. You are running the latest version (v${VERSION})."
        return 0
    fi

    echo -e "Update available: v$VERSION → v$remote_version"
    
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

show_help() {
    cat << EOF
CLIX v${VERSION} - Guide

OPTIONS:
    -h		Show this help message
    -v		Show version information
    -u		Update to the latest version

NAVIGATION:
    ↑/↓		Move up/down in menus
    Enter   Select current item
    ESC     Go back to previous menu
    Ctrl+C  Exit the program or Exit from Music track
    Type to search  Fuzzy finding in any menu

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

DEPENDENCIES:
    Required: curl, xmlstarlet, fzf, mpv
EOF
}

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

check_plex_credentials() {
    echo "Checking Plex server connection..."
    
    # Check if PLEX_URL and PLEX_TOKEN are set
    if [ -z "$PLEX_URL" ] || [ -z "$PLEX_TOKEN" ]; then
        echo "Error: Plex URL or token not set"
        echo "Please edit this script and add your Plex credentials"
        exit 1
    fi
    
    # First verify basic connectivity
    local basic_response
    basic_response=$(curl -s -m 10 "${PLEX_URL}/identity")
    
    if [[ -z "$basic_response" ]]; then
        echo "Error: Could not connect to Plex server at ${PLEX_URL}"
        echo "Please check if:"
        echo "1. The Plex server URL is correct"
        echo "2. The Plex server is running"
        echo "3. Your network connection is working"
        exit 1
    fi

    # Now verify token access by attempting to list libraries
    local auth_response
    auth_response=$(curl -s -m 10 -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/sections")
    
    # Check if we can actually access library data
    if ! echo "$auth_response" | xmlstarlet sel -t -v "/MediaContainer" &>/dev/null; then
        echo "Error: Invalid Plex token or unauthorized access"
        echo "The server is reachable, but the provided token does not have proper access permissions"
        echo "Please check your Plex token and try again"
        exit 1
    fi

    # Get server name
    local server_info
    server_info=$(curl -s -m 10 -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/")
    
    local server_name
    server_name=$(echo "$server_info" | xmlstarlet sel -t -v "/MediaContainer/@friendlyName" 2>/dev/null)
    
    if [[ -z "$server_name" ]]; then
        server_name=$(echo "$server_info" | xmlstarlet sel -t -v "/MediaContainer/@title" 2>/dev/null || echo "Unknown")
    fi

    # Count available libraries as additional verification
    local library_count
    library_count=$(echo "$auth_response" | xmlstarlet sel -t -v "count(/MediaContainer/Directory)")
    
    echo "Successfully connected to Plex server: $server_name"
    echo "Found $library_count available libraries"
    sleep 2
}

main() {
    # First check dependencies and credentials before parsing arguments
    check_dependencies
    check_plex_credentials
    
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
    
    # Show quick tip at startup
    clear
    echo "-------------------------------------------------------------------------"
    echo "CLIX v${VERSION}"
    echo "Tip: Press ESC to go back to previous menu, or select Help for more info"
    echo "-------------------------------------------------------------------------"
    sleep 2
    clear
    
    while true; do
        main_menu
    done
}

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

get_library_contents() {
    local library_key="$1"
    local page=1
    local page_size=50
    local all_items=""
    
    # Determine library type and name for progress display
    local libraries
    libraries=$(get_libraries | grep "|${library_key}|")
    local library_name
    library_name=$(echo "$libraries" | cut -d'|' -f2)
    
    # Retrieve total size first
    local total_size
    local first_response
    first_response=$(curl -s -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/sections/${library_key}/all?X-Plex-Container-Start=0&X-Plex-Container-Size=1")
    total_size=$(echo "$first_response" | xmlstarlet sel -t -v "/MediaContainer/@totalSize" -n)
    
    # Check if library is empty
    if [[ "$total_size" -eq 0 ]]; then
        # Instead of returning error, return special "EMPTY_LIBRARY" marker
        echo "EMPTY_LIBRARY"
        return 0
    fi
    
    # Determine item type from first response
    local first_item_type
    first_item_type=$(echo "$first_response" | xmlstarlet sel -t -m "//Video | //Directory" -v "name()" -n | head -n 1)
    if [[ -z "$first_item_type" ]]; then
        echo "EMPTY_LIBRARY"
        return 0
    fi

    # Redirect progress to stderr to keep stdout clean for piping
    {
        clear >&2
        echo "Retrieving contents of library: $library_name" >&2
        echo "Total items: $total_size" >&2
    
        while true; do
            local start_index=$((($page - 1) * $page_size))
            local response
            response=$(curl -s -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/sections/${library_key}/all?X-Plex-Container-Start=${start_index}&X-Plex-Container-Size=${page_size}")
            if [[ -z "$response" ]]; then
                echo "EMPTY_LIBRARY"
                return 0
            fi
            local current_items
            if [[ "$first_item_type" == "Video" ]]; then
                current_items=$(echo "$response" | xmlstarlet sel -t -m "//Video" -v "concat(@title, ' (', @year, ')|', @ratingKey)" -n)
            elif [[ "$first_item_type" == "Directory" ]]; then
                current_items=$(echo "$response" | xmlstarlet sel -t -m "//Directory" -v "concat(@title, '|', @ratingKey)" -n)
            else
                echo "EMPTY_LIBRARY"
                return 0
            fi
            # If no items returned, we've reached the end
            if [[ -z "$current_items" ]]; then
                break
            fi
            # Append current page's items
            all_items+="$current_items"$'\n'
            # Calculate and display progress
            local current_count=$((page * page_size))
            if [[ $current_count -gt "$total_size" ]]; then
                current_count="$total_size"
            fi
            
            # Progress percentage
            local progress_percent=$((current_count * 100 / total_size))
            
            # Progress bar
            printf "\rRetrieving items: [%-50s] %d%% (%d/%d)" \
                "$(printf "#%.0s" $(seq 1 $((progress_percent / 2))))" \
                "$progress_percent" "$current_count" "$total_size" >&2
            # If we've retrieved all items, break the loop
            if [[ $((page * page_size)) -ge "$total_size" ]]; then
                break
            fi
            # Increment page
            ((page++))
        done
        echo "" >&2
        clear >&2
    }
    
    # Return the list to stdout
    echo "$all_items" | sed '/^$/d'
}

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

play_media() {
    local media_key="$1"
    local media_type="$2"
    local title="$3"

    local media_url
    media_url=$(get_stream_url "$media_key" "$media_type")

    if [[ -n "$media_url" ]]; then
        echo "Playing $media_type: $title"
        mpv --title="$title" "$media_url"
        clear  # Clear screen after playback
        return 0  # Return success to indicate playback completed
    else
        echo "Error: Could not retrieve stream URL."
        read -p "Press Enter to continue..." 
        return 1
    fi
}

display_help() {
    clear >&2
    show_help
    echo -e "\nPress q to return to main menu..."
    read -n 1 key
    while [[ $key != "q" ]]; do
        read -n 1 key
    done
    clear >&2
}

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

            # Count number of libraries
            local lib_count
            lib_count=$(echo "$libraries" | wc -l)

            while true; do
                local chosen_library
                local lib_key

                if [[ $lib_count -eq 1 ]]; then
                    chosen_library=$(echo "$libraries" | cut -d'|' -f2)
                    lib_key=$(echo "$libraries" | cut -d'|' -f1)
                else
                    chosen_library=$(echo "$libraries" | cut -d'|' -f2 | fzf --reverse --header="Select Movie Library" --prompt="Search Movie Libraries > ")
                    
                    if [[ -z "$chosen_library" ]]; then
                        return 1
                    fi

                    lib_key=$(echo "$libraries" | grep "|${chosen_library}|" | cut -d'|' -f1)
                fi
                
                while true; do
                    local movies
                    movies=$(get_library_contents "$lib_key")
                    
                    if [[ "$movies" == "EMPTY_LIBRARY" ]]; then
                        echo -e "< Go back\n" | fzf --reverse --header="Library Empty" --disabled
                        clear
                        if [[ $lib_count -eq 1 ]]; then
                            return 1
                        else
                            break
                        fi
                    fi
                    
                    local chosen_movie
                    chosen_movie=$(echo "$movies" | cut -d'|' -f1 | fzf --reverse --header="Select Movie" --prompt="Search Movies > ")
                    
                    if [[ -z "$chosen_movie" ]]; then
                        if [[ $lib_count -eq 1 ]]; then
                            return 1
                        else
                            break
                        fi
                    fi

                    local movie_key
                    movie_key=$(echo "$movies" | grep "^${chosen_movie}|" | cut -d'|' -f2)
                    
                    play_media "$movie_key" "movie" "$chosen_movie"
                done
            done
            ;;
        
        show)
            local libraries
            libraries=$(get_libraries | grep "show")
            
            if [[ -z "$libraries" ]]; then
                echo "No TV show libraries found."
                return 1
            fi

            local lib_count
            lib_count=$(echo "$libraries" | wc -l)

            while true; do
                local chosen_library
                local lib_key

                if [[ $lib_count -eq 1 ]]; then
                    chosen_library=$(echo "$libraries" | cut -d'|' -f2)
                    lib_key=$(echo "$libraries" | cut -d'|' -f1)
                else
                    chosen_library=$(echo "$libraries" | cut -d'|' -f2 | fzf --reverse --header="Select TV Show Library" --prompt="Search TV Show Libraries > ")
                    
                    if [[ -z "$chosen_library" ]]; then
                        return 1
                    fi

                    lib_key=$(echo "$libraries" | grep "|${chosen_library}|" | cut -d'|' -f1)
                fi
                
                while true; do
                    local shows
                    shows=$(get_library_contents "$lib_key")
                    
                    if [[ "$shows" == "EMPTY_LIBRARY" ]]; then
                        echo -e "< Go back\n" | fzf --reverse --header="Library Empty" --disabled
                        clear
                        if [[ $lib_count -eq 1 ]]; then
                            return 1
                        else
                            break
                        fi
                    fi
                    
                    local chosen_show
                    chosen_show=$(echo "$shows" | cut -d'|' -f1 | fzf --reverse --header="Select TV Show" --prompt="Search TV Shows > ")
                    
                    if [[ -z "$chosen_show" ]]; then
                        if [[ $lib_count -eq 1 ]]; then
                            return 1
                        else
                            break
                        fi
                    fi

                    local show_key
                    show_key=$(echo "$shows" | grep "^${chosen_show}|" | cut -d'|' -f2)
                    
                    while true; do
                        local seasons
                        seasons=$(get_seasons "$show_key")
                        
                        local chosen_season
                        chosen_season=$(echo "$seasons" | cut -d'|' -f1 | fzf --reverse --header="TV Show: $chosen_show
Select Season" --prompt="Search Seasons > ")
                        
                        if [[ -z "$chosen_season" ]]; then
                            break  # Go back to show selection
                        fi

                        local season_key
                        season_key=$(echo "$seasons" | grep "^${chosen_season}|" | cut -d'|' -f2)

                        while true; do
                            local episodes
                            episodes=$(get_episodes "$season_key")
                            
                            local chosen_episode
                            chosen_episode=$(echo "$episodes" | cut -d'|' -f1 | fzf --reverse --header="TV Show: $chosen_show
Season: $chosen_season
Select Episode" --prompt="Search Episodes > ")
                            
                            if [[ -z "$chosen_episode" ]]; then
                                break  # Go back to season selection
                            fi

                            local episode_key
                            episode_key=$(echo "$episodes" | grep "^${chosen_episode}|" | cut -d'|' -f2)
                            
                            local episode_title="$chosen_show - $chosen_season - $chosen_episode"
                            play_media "$episode_key" "episode" "$episode_title"
                        done
                    done
                done
            done
            ;;
        
        music)
            local libraries
            libraries=$(get_libraries | grep "artist")
            
            if [[ -z "$libraries" ]]; then
                echo "No music libraries found."
                return 1
            fi

            local lib_count
            lib_count=$(echo "$libraries" | wc -l)

            while true; do
                local chosen_library
                local lib_key

                if [[ $lib_count -eq 1 ]]; then
                    chosen_library=$(echo "$libraries" | cut -d'|' -f2)
                    lib_key=$(echo "$libraries" | cut -d'|' -f1)
                else
                    chosen_library=$(echo "$libraries" | cut -d'|' -f2 | fzf --reverse --header="Select Music Library" --prompt="Search Music Libraries > ")
                    
                    if [[ -z "$chosen_library" ]]; then
                        return 1
                    fi

                    lib_key=$(echo "$libraries" | grep "|${chosen_library}|" | cut -d'|' -f1)
                fi
                
                while true; do
                    local artists
                    artists=$(get_library_contents "$lib_key")
                    
                    if [[ "$artists" == "EMPTY_LIBRARY" ]]; then
                        echo -e "< Go back\n" | fzf --reverse --header="Library Empty" --disabled
                        clear
                        if [[ $lib_count -eq 1 ]]; then
                            return 1
                        else
                            break
                        fi
                    fi
                    
                    local chosen_artist
                    chosen_artist=$(echo "$artists" | cut -d'|' -f1 | fzf --reverse --header="Select Artist" --prompt="Search Artists > ")
                    
                    if [[ -z "$chosen_artist" ]]; then
                        if [[ $lib_count -eq 1 ]]; then
                            return 1
                        else
                            break
                        fi
                    fi

                    local artist_key
                    artist_key=$(echo "$artists" | grep "^${chosen_artist}|" | cut -d'|' -f2)
                    
                    while true; do
                        local albums
                        albums=$(get_albums "$artist_key")
                        
                        local chosen_album
                        chosen_album=$(echo "$albums" | cut -d'|' -f1 | fzf --reverse --header="Artist: $chosen_artist
Select Album" --prompt="Search Albums > ")
                        
                        if [[ -z "$chosen_album" ]]; then
                            break  # Go back to artist selection
                        fi

                        local album_key
                        album_key=$(echo "$albums" | grep "^${chosen_album}|" | cut -d'|' -f2)
                        
                        while true; do
                            local tracks
                            tracks=$(get_tracks "$album_key")
                            
                            local chosen_track
                            chosen_track=$(echo "$tracks" | cut -d'|' -f1 | fzf --reverse --header="Artist: $chosen_artist
Album: $chosen_album
Select Track" --prompt="Search Tracks > ")
                            
                            if [[ -z "$chosen_track" ]]; then
                                break  # Go back to album selection
                            fi

                            local track_key
                            track_key=$(echo "$tracks" | grep "^${chosen_track}|" | cut -d'|' -f2)
                            
                            local track_title="$chosen_artist - $chosen_album - $chosen_track"
                            play_media "$track_key" "music" "$track_title"
                        done
                    done
                done
            done
            ;;
        
        *)
            echo "Unsupported media type"
            return 1
            ;;
    esac
}

main_menu() {
    local choice
    choice=$(echo -e "Movies\nTV Shows\nMusic\n----------\nUpdate\nHelp\n----------\nQuit" | fzf --reverse --header="Select Media Type" --prompt="Search Menu > ")
    
    # If choice is empty (ESC was pressed), just return to redraw the menu
    if [[ -z "$choice" ]]; then
        clear
        return
    fi
    
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
        "----------") 
            # Do nothing for the separator
            ;;
        Quit) exit 0 ;;
        *) 
            echo "Invalid selection"
            sleep 1
            clear
            ;;
    esac
}

main() {
    # First check dependencies and credentials before parsing arguments
    check_dependencies
    check_plex_credentials
    
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
    
    # Show quick tip at startup
    clear
    echo "-------------------------------------------------------------------------"
    echo "CLIX v${VERSION}"
    echo "Tip: Press ESC to go back to previous menu, or select Help for more info"
    echo "-------------------------------------------------------------------------"
    sleep 2
    clear
    
    while true; do
        main_menu
    done
}

main "$@"
