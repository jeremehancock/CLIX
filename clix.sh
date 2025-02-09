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

######################
# Directory Settings #
######################

DOWNLOAD_BASE_DIR="downloads"
MOVIES_DIR="${DOWNLOAD_BASE_DIR}/movies"
SHOWS_DIR="${DOWNLOAD_BASE_DIR}/shows"
MUSIC_DIR="${DOWNLOAD_BASE_DIR}/music"

########################################################################################################
################################### DO NOT EDIT ANYTHING BELOW #########################################
########################################################################################################

VERSION="1.2.6"

create_download_dirs() {
    mkdir -p "${MOVIES_DIR}"
    mkdir -p "${SHOWS_DIR}"
    mkdir -p "${MUSIC_DIR}"
}

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

    if [[ "$remote_version" > "$VERSION" ]]; then
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

    local remote_version
    remote_version=$(curl -s https://raw.githubusercontent.com/jeremehancock/CLIX/refs/heads/main/clix.sh | grep "^VERSION=" | cut -d'"' -f2)
    
    if [[ -z "$remote_version" ]]; then
        echo -e "Error: Could not fetch remote version"
        return 1
    fi

    if [[ "$remote_version" == "$VERSION" ]]; then
        echo -e "No updates available. You are running the latest version (v${VERSION})."
        return 0
    fi

    echo -e "Update available: v$VERSION → v$remote_version"
    
    local backup_dir="backups"
    mkdir -p "$backup_dir"

    local script_name=$(basename "$0")
    local backup_file="${backup_dir}/${script_name}.v${VERSION}.backup"
    cp "$0" "$backup_file"
    
    echo -n "Do you want to proceed with the update? [y/N] "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Update cancelled."
        return 0
    fi
    
    if curl -o "$script_name" -L https://raw.githubusercontent.com/jeremehancock/CLIX/main/clix.sh; then
        local last_backup=$(ls -t "$backup_dir"/*.backup | head -n 1)
        
        if [[ -n "$last_backup" ]]; then
            local old_plex_url=$(grep "^PLEX_URL=" "$last_backup" | cut -d'"' -f2)
            local old_plex_token=$(grep "^PLEX_TOKEN=" "$last_backup" | cut -d'"' -f2)
            
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
        
        exit 0
    else
        echo -e "Update failed"
        mv "$backup_file" "$script_name"
        return 1
    fi
}

display_help() {
    # Disable terminal echoing to prevent screen clearing
    stty -echo
    
    # Clear the screen and display help
    clear
    show_help | less -R

    # Re-enable terminal echoing
    stty echo
    
    # Clear screen after help
    clear
}

# The show_help function remains the same as it was originally in the script
show_help() {
    cat << EOF
CLIX v${VERSION} - Guide

OPTIONS:
    -h          Show this help message
    -v          Show version information
    -u          Update to the latest version

NAVIGATION:
    ↑/↓         Move up/down in menus
    Enter       Select current item
    ESC         Go back to previous menu
    Ctrl+C      Exit the program or Exit from Music track
    Type to search   Fuzzy finding in any menu

MENU STRUCTURE:
    1. Main Menu
        - Movies
        - TV Shows
        - Music
        - Downloads
        - Update
        - Help
        - Quit
    
    2. Library Selection
        → Select your preferred library
        
        If there is only one library of the selected 
        library type it will be auto selected
    
    3. Media Selection
        Movies: Select movie from list
        TV Shows: Select show → season → episode
        Music: Select artist → album → track

DEPENDENCIES:
    Required: curl, xmlstarlet, fzf, mpv

Press q to return to main menu

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
    
    if [ -z "$PLEX_URL" ] || [ -z "$PLEX_TOKEN" ]; then
        echo "Error: Plex URL or token not set"
        echo "Please edit this script and add your Plex credentials"
        exit 1
    fi
    
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

    local auth_response
    auth_response=$(curl -s -m 10 -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/sections")
    
    if ! echo "$auth_response" | xmlstarlet sel -t -v "/MediaContainer" &>/dev/null; then
        echo "Error: Invalid Plex token or unauthorized access"
        echo "The server is reachable, but the provided token does not have proper access permissions"
        echo "Please check your Plex token and try again"
        exit 1
    fi

    local server_info
    server_info=$(curl -s -m 10 -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/")
    
    local server_name
    server_name=$(echo "$server_info" | xmlstarlet sel -t -v "/MediaContainer/@friendlyName" 2>/dev/null)
    
    if [[ -z "$server_name" ]]; then
        server_name=$(echo "$server_info" | xmlstarlet sel -t -v "/MediaContainer/@title" 2>/dev/null || echo "Unknown")
    fi

    local library_count
    library_count=$(echo "$auth_response" | xmlstarlet sel -t -v "count(/MediaContainer/Directory)")
    
    echo "Successfully connected to Plex server: $server_name"
    echo "Found $library_count available libraries"
    sleep 2
}

downloads_menu() {
    while true; do
        local choice
        choice=$(echo -e "Movies\nTV Shows\nMusic" | fzf --reverse --header="Downloads Menu" --prompt="Search Downloads > ")
        
        case "$choice" in
            Movies) list_downloaded_movies ;;
            "TV Shows") list_downloaded_shows ;;
            Music) list_downloaded_music ;;
            "") break ;;
        esac
    done
}

list_downloaded_movies() {
    if [ ! -d "$MOVIES_DIR" ] || [ -z "$(ls -A "$MOVIES_DIR")" ]; then
        echo -e "< Go back" | fzf --reverse --header="No downloaded movies found" --disabled
        return
    fi

    while true; do
        local movies
        movies=$(find "$MOVIES_DIR" -type f -exec basename {} \; | sort -k2,2)
        
        local display_movies=""
        declare -A filename_map
        
        while IFS= read -r movie; do
            local display_name="${movie%.*}"
            # Convert asterisks back to slashes for display
            display_name=$(echo "$display_name" | tr '*' '/')
            display_movies+="$display_name"$'\n'
            filename_map["$display_name"]="$movie"
        done <<< "$movies"
        
        local chosen_display
        chosen_display=$(echo -e "$display_movies" | sed '/^$/d' | fzf --reverse --header="Select Downloaded Movie" --prompt="Search Downloaded Movies > ")
        
        if [[ -z "$chosen_display" ]]; then
            break
        fi

        local movie_file="${filename_map[$chosen_display]}"
        
        mpv --title="$chosen_display" "${MOVIES_DIR}/${movie_file}"
        clear
    done
}

list_downloaded_shows() {
    if [ ! -d "$SHOWS_DIR" ] || [ -z "$(ls -A "$SHOWS_DIR")" ]; then
        echo -e "< Go back" | fzf --reverse --header="No downloaded TV shows found" --disabled
        return
    fi

    while true; do
        local shows
        shows=$(find "$SHOWS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -k2,2)
        
        # Convert asterisks to slashes for display
        local display_shows=""
        declare -A show_map
        
        while IFS= read -r show; do
            local display_name=$(echo "$show" | tr '*' '/')
            display_shows+="$display_name"$'\n'
            show_map["$display_name"]="$show"
        done <<< "$shows"
        
        local chosen_show_display
        chosen_show_display=$(echo -e "$display_shows" | sed '/^$/d' | fzf --reverse --header="Select Downloaded TV Show" --prompt="Search Downloaded TV Shows > ")

        if [[ -z "$chosen_show_display" ]]; then
            break
        fi

        local original_show="${show_map[$chosen_show_display]}"

        while true; do
            local seasons
            seasons=$(find "$SHOWS_DIR/$original_show" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -V)
            
            if [[ -z "$seasons" ]]; then
                echo -e "< Go back" | fzf --reverse --header="No seasons found" --disabled
                break
            fi

            local display_seasons=""
            declare -A season_map
            while IFS= read -r season; do
                local display_name=$(echo "$season" | tr '*' '/')
                display_seasons+="$display_name"$'\n'
                season_map["$display_name"]="$season"
            done <<< "$seasons"

            local chosen_season_display
            chosen_season_display=$(echo -e "$display_seasons" | sed '/^$/d' | fzf --reverse --header="TV Show: $chosen_show_display
Select Downloaded Season" --prompt="Search Downloaded Seasons > ")
            
            if [[ -z "$chosen_season_display" ]]; then
                break
            fi

            local original_season="${season_map[$chosen_season_display]}"

            while true; do
                local episodes
                episodes=$(find "$SHOWS_DIR/$original_show/$original_season" -type f -exec basename {} \; | sort -V)
                
                if [[ -z "$episodes" ]]; then
                    echo -e "< Go back" | fzf --reverse --header="No episodes found" --disabled
                    break
                fi

                local display_episodes=""
                declare -A filename_map
                
                while IFS= read -r episode; do
                    local base_name="${episode%.*}"
                    # Extract episode number and title
                    if [[ $base_name =~ S[0-9]+E([0-9]+)[[:space:]]-[[:space:]](.+)$ ]]; then
                        local ep_num="${BASH_REMATCH[1]}"
                        local ep_title="${BASH_REMATCH[2]}"
                        # Remove leading zeros from episode number
                        ep_num=$((10#$ep_num))
                        # Create simple display format
                        local display_name="${ep_num}. ${ep_title}"
                        display_episodes+="$display_name"$'\n'
                        filename_map["$display_name"]="$episode"
                    else
                        # Fallback to full name if pattern doesn't match
                        local display_name=$(echo "$base_name" | tr '*' '/')
                        display_episodes+="$display_name"$'\n'
                        filename_map["$display_name"]="$episode"
                    fi
                done <<< "$episodes"

                local chosen_display
                chosen_display=$(echo -e "$display_episodes" | sed '/^$/d' | fzf --reverse --header="TV Show: $chosen_show_display
Season: $chosen_season_display
Select Downloaded Episode" --prompt="Search Downloaded Episodes > ")
                
                if [[ -z "$chosen_display" ]]; then
                    break
                fi

                local episode_file="${filename_map[$chosen_display]}"
                mpv --title="$chosen_display" "${SHOWS_DIR}/${original_show}/${original_season}/${episode_file}"
                clear
            done
        done
    done
}

list_downloaded_music() {
    if [ ! -d "$MUSIC_DIR" ] || [ -z "$(ls -A "$MUSIC_DIR")" ]; then
        echo -e "< Go back" | fzf --reverse --header="No downloaded music found" --disabled
        return
    fi

    while true; do
        local artists
        artists=$(find "$MUSIC_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
        
        local display_artists=""
        declare -A artist_map
        while IFS= read -r artist; do
            # Convert asterisks to slashes for display
            local display_name=$(echo "$artist" | tr '*' '/')
            display_artists+="$display_name"$'\n'
            artist_map["$display_name"]="$artist"
        done <<< "$artists"
        
        local chosen_artist_display
        chosen_artist_display=$(echo -e "$display_artists" | sed '/^$/d' | fzf --reverse --header="Select Downloaded Artist" --prompt="Search Downloaded Artists > ")
        
        if [[ -z "$chosen_artist_display" ]]; then
            break
        fi

        local original_artist="${artist_map[$chosen_artist_display]}"

        while true; do
            local albums
            albums=$(find "$MUSIC_DIR/$original_artist" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
            
            if [[ -z "$albums" ]]; then
                echo -e "< Go back" | fzf --reverse --header="No albums found" --disabled
                break
            fi

            local display_albums=""
            declare -A album_map
            while IFS= read -r album; do
                # Convert asterisks to slashes for display
                local display_name=$(echo "$album" | tr '*' '/')
                display_albums+="$display_name"$'\n'
                album_map["$display_name"]="$album"
            done <<< "$albums"

            local chosen_album_display
            chosen_album_display=$(echo -e "$display_albums" | sed '/^$/d' | fzf --reverse --header="Artist: $chosen_artist_display
Select Downloaded Album" --prompt="Search Downloaded Albums > ")
            
            if [[ -z "$chosen_album_display" ]]; then
                break
            fi

            local original_album="${album_map[$chosen_album_display]}"

            while true; do
                local tracks
                tracks=$(find "$MUSIC_DIR/$original_artist/$original_album" -type f -exec basename {} \; | sort -V)
                
                if [[ -z "$tracks" ]]; then
                    echo -e "< Go back" | fzf --reverse --header="No tracks found" --disabled
                    break
                fi

                local display_tracks=""
                declare -A track_map
                while IFS= read -r track; do
                    local base_name="${track%.*}"
                    # Extract track number and title
                    if [[ $base_name =~ -[[:space:]]([0-9]+)[[:space:]]-[[:space:]](.+)$ ]]; then
                        local track_num="${BASH_REMATCH[1]}"
                        local track_title="${BASH_REMATCH[2]}"
                        # Remove leading zeros from track number
                        track_num=$((10#$track_num))
                        # Create simple display format
                        local display_name="${track_num}. ${track_title}"
                        display_tracks+="$display_name"$'\n'
                        track_map["$display_name"]="$track"
                    else
                        # Fallback to full name if pattern doesn't match
                        local display_name=$(echo "$base_name" | tr '*' '/')
                        display_tracks+="$display_name"$'\n'
                        track_map["$display_name"]="$track"
                    fi
                done <<< "$tracks"

                local chosen_track_display
                chosen_track_display=$(echo -e "$display_tracks" | sed '/^$/d' | fzf --reverse --header="Artist: $chosen_artist_display
Album: $chosen_album_display
Select Downloaded Track" --prompt="Search Downloaded Tracks > ")
                
                if [[ -z "$chosen_track_display" ]]; then
                    break
                fi

                local track_file="${track_map[$chosen_track_display]}"
                mpv --title="$chosen_track_display" "${MUSIC_DIR}/${original_artist}/${original_album}/${track_file}"
                clear
            done
        done
    done
}

get_libraries() {
    local response
    response=$(curl -s -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/sections")

    if [[ -z "$response" ]]; then
        echo "Error: No response from Plex server."
        exit 1
    fi

    echo "$response" | xmlstarlet sel -t -m "//Directory" -v "concat(@key, '|', @title, '|', @type)" -n | sed 's/&amp;/\&/g'
}

get_library_contents() {
    local library_key="$1"
    local page=1
    local page_size=50
    local all_items=""
    
    local libraries
    libraries=$(get_libraries | grep "|${library_key}|")
    local library_name
    library_name=$(echo "$libraries" | cut -d'|' -f2)
    
    local total_size
    local first_response
    first_response=$(curl -s -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/sections/${library_key}/all?X-Plex-Container-Start=0&X-Plex-Container-Size=1")
    total_size=$(echo "$first_response" | xmlstarlet sel -t -v "/MediaContainer/@totalSize" -n)
    
    if [[ "$total_size" -eq 0 ]]; then
        echo "EMPTY_LIBRARY"
        return 0
    fi
    
    local first_item_type
    first_item_type=$(echo "$first_response" | xmlstarlet sel -t -m "//Video | //Directory" -v "name()" -n | head -n 1)
    if [[ -z "$first_item_type" ]]; then
        echo "EMPTY_LIBRARY"
        return 0
    fi

    {
        echo "Retrieving contents of library: $library_name" >&2
        echo "Total items: $total_size" >&2
        clear >&2
    
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
                current_items=$(echo "$response" | xmlstarlet sel -t -m "//Video" -v "concat(@title, ' (', @year, ')|', @ratingKey)" -n | sed 's/&amp;/\&/g')
            elif [[ "$first_item_type" == "Directory" ]]; then
                current_items=$(echo "$response" | xmlstarlet sel -t -m "//Directory" -v "concat(@title, '|', @ratingKey)" -n | sed 's/&amp;/\&/g')
            else
                echo "EMPTY_LIBRARY"
                return 0
            fi
            
            if [[ -z "$current_items" ]]; then
                break
            fi
            
            all_items+="$current_items"$'\n'
            local current_count=$((page * page_size))
            if [[ $current_count -gt "$total_size" ]]; then
                current_count="$total_size"
            fi
            
            local progress_percent=$((current_count * 100 / total_size))
            
            printf "\rRetrieving items: [%-50s] %d%% (%d/%d)" \
                "$(printf "#%.0s" $(seq 1 $((progress_percent / 2))))" \
                "$progress_percent" "$current_count" "$total_size" >&2
                
            if [[ $((page * page_size)) -ge "$total_size" ]]; then
                break
            fi
            ((page++))
        done
        echo "" >&2
        clear >&2
    }
    
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

    echo "$response" | xmlstarlet sel -t -m "//Directory" -v "concat(@title, '|', @ratingKey)" -n | sed 's/&amp;/\&/g'
}

get_tracks() {
    local album_key="$1"
    local response

    response=$(curl -s -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/metadata/${album_key}/children")

    if [[ -z "$response" ]]; then
        echo "Error: No response from Plex server."
        exit 1
    fi

    echo "$response" | xmlstarlet sel -t -m "//Track" -v "concat(@index, '. ', @title, '|', @ratingKey)" -n | sed 's/&amp;/\&/g'
}

get_seasons() {
    local show_key="$1"
    local response

    response=$(curl -s -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/metadata/${show_key}/children")

    if [[ -z "$response" ]]; then
        echo "Error: No response from Plex server."
        exit 1
    fi
    
    echo "$response" | xmlstarlet sel -t -m "//Directory[@type='season']" -v "@title" -o "|" -v "@ratingKey" -n | \
    grep -v "^All episodes|" | sort -V | sed 's/&amp;/\&/g'
}

get_episodes() {
    local season_key="$1"
    local response

    response=$(curl -s -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/metadata/${season_key}/children")

    if [[ -z "$response" ]]; then
        echo "Error: No response from Plex server."
        exit 1
    fi

    echo "$response" | xmlstarlet sel -t -m "//Video" -v "concat(@index, '. ', @title, '|', @ratingKey)" -n | sed 's/&amp;/\&/g'
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
        clear
        return 0
    else
        echo "Error: Could not retrieve stream URL."
        read -p "Press Enter to continue..." 
        return 1
    fi
}

download_media() {
    local media_key="$1"
    local media_type="$2"
    local title="$3"
    local additional_path="$4"
    
    echo -n "Do you want to proceed with the download? [y/N] "
    read -r response
    clear
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Download cancelled."
        read -p "Press Enter to continue..." 
        return 0
    fi
    
    local media_url
    media_url=$(get_stream_url "$media_key" "$media_type")
    
    if [[ -z "$media_url" ]]; then
        echo "Error: Could not retrieve download URL."
        read -p "Press Enter to continue..."
        return 1
    fi
    
    local original_ext
    original_ext=$(echo "$media_url" | grep -oP '\.[^./?]+(?=(\?|$))' || echo ".mp4")
    
    local response
    response=$(curl -s -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/metadata/${media_key}")
    
    local display_filename
    local safe_filename
    local relative_path
    case "$media_type" in
        movie)
            local clean_title
            clean_title=$(echo "$title" | sed -E 's/ \([0-9]{4}\)$//')
            
            local year
            year=$(echo "$response" | xmlstarlet sel -t -v "//Video/@year" 2>/dev/null)
            
            # Keep original title for display
            if [[ -n "$year" ]]; then
                display_filename="${clean_title} (${year})${original_ext}"
            else
                display_filename="${clean_title}${original_ext}"
            fi
            
            # Create safe version for filesystem
            safe_filename=$(echo "$display_filename" | tr '/' '*')
            ;;
        episode)
            local show_title=$(echo "$response" | xmlstarlet sel -t -v "//Video/@grandparentTitle" 2>/dev/null)
            local season_num=$(echo "$response" | xmlstarlet sel -t -v "//Video/@parentIndex" 2>/dev/null)
            local episode_num=$(echo "$response" | xmlstarlet sel -t -v "//Video/@index" 2>/dev/null)
            local episode_title=$(echo "$response" | xmlstarlet sel -t -v "//Video/@title" 2>/dev/null)
            
            season_num=$(printf "%02d" "$season_num")
            episode_num=$(printf "%02d" "$episode_num")
            
            local season_folder=$(echo "$response" | xmlstarlet sel -t -v "//Video/@parentTitle" 2>/dev/null)
            
            # Create display versions with slashes
            display_filename="${show_title} - S${season_num}E${episode_num} - ${episode_title}${original_ext}"
            
            # Create safe versions with asterisks for filesystem
            local show_title_safe=$(echo "$show_title" | tr '/' '*')
            local season_folder_safe=$(echo "$season_folder" | tr '/' '*')
            local episode_title_safe=$(echo "$episode_title" | tr '/' '*')
            
            relative_path="${show_title_safe}/${season_folder_safe}"
            safe_filename="${show_title_safe} - S${season_num}E${episode_num} - ${episode_title_safe}${original_ext}"
            ;;
        music)
            local artist=$(echo "$response" | xmlstarlet sel -t -v "//Track/@grandparentTitle" 2>/dev/null)
            local album=$(echo "$response" | xmlstarlet sel -t -v "//Track/@parentTitle" 2>/dev/null)
            local track_num=$(echo "$response" | xmlstarlet sel -t -v "//Track/@index" 2>/dev/null)
            local track_title=$(echo "$response" | xmlstarlet sel -t -v "//Track/@title" 2>/dev/null)
            
            track_num=$(printf "%02d" "$track_num")
            
            # Create display version with slashes
            display_filename="${artist} - ${album} - ${track_num} - ${track_title}${original_ext}"
            
            # Create safe versions with asterisks for filesystem
            local artist_safe=$(echo "$artist" | tr '/' '*')
            local album_safe=$(echo "$album" | tr '/' '*')
            local track_title_safe=$(echo "$track_title" | tr '/' '*')
            
            relative_path="${artist_safe}/${album_safe}"
            safe_filename="${artist_safe} - ${album_safe} - ${track_num} - ${track_title_safe}${original_ext}"
            ;;
        *)
            echo "Unsupported media type for download"
            return 1
            ;;
    esac
    
    # Replace &amp; with & in filenames and paths for downloads
    display_filename=$(echo "$display_filename" | sed 's/&amp;/\&/g' | tr -d '\"' | tr ':' '-')
    safe_filename=$(echo "$safe_filename" | sed 's/&amp;/\&/g' | tr -d '\"' | tr ':' '-')
    [[ -n "$relative_path" ]] && relative_path=$(echo "$relative_path" | sed 's/&amp;/\&/g' | tr -d '\"' | tr ':' '-')
    
    local target_dir
    case "$media_type" in
        movie)
            target_dir="${MOVIES_DIR}"
            ;;
        episode)
            target_dir="${SHOWS_DIR}/${relative_path}"
            ;;
        music)
            target_dir="${MUSIC_DIR}/${relative_path}"
            ;;
    esac
    
    mkdir -p "$target_dir"
    
    echo "Downloading: ${display_filename}"
    echo "Destination: ${target_dir}/${safe_filename}"
    
    if curl -# -L \
        -H "X-Plex-Token: $PLEX_TOKEN" \
        --progress-bar \
        -o "${target_dir}/${safe_filename}" \
        "$media_url"; then
        echo "Download completed successfully!"
    else
        echo "Download failed!"
        return 1
    fi
    
    read -p "Press Enter to continue..."
}

check_local_file() {
    local media_type="$1"
    local title="$2"
    local additional_path="$3"
    local search_dir
    local found_file=""
    
    case "$media_type" in
        episode)
            local base_search_dir="${SHOWS_DIR}"
            
            # Replace forward slashes with asterisks in the path components
            local processed_path=""
            IFS='/' read -ra path_parts <<< "$additional_path"
            for part in "${path_parts[@]}"; do
                local processed_part=$(echo "$part" | tr '/' '*' | sed 's/&amp;/\&/g' | tr -d '\"' | tr ':' '-')
                if [ -z "$processed_path" ]; then
                    processed_path="$processed_part"
                else
                    processed_path="$processed_path/$processed_part"
                fi
            done
            
            search_dir="${base_search_dir}/${processed_path}"
            
            # Convert title to use asterisks for filesystem matching
            local safe_title=$(echo "$title" | tr '/' '*')
            
            if [[ -d "$search_dir" ]]; then
                if [[ "$safe_title" =~ ^(.+)[[:space:]]-[[:space:]]S([0-9]+)E([0-9]+)[[:space:]]-[[:space:]] ]]; then
                    while IFS= read -r -d $'\0' file; do
                        local basename_file=$(basename "$file")
                        local basename_no_ext="${basename_file%.*}"

                        if [[ "$basename_no_ext" == "$safe_title" ]]; then
                            found_file="$file"
                            break
                        fi
                    done < <(find "$search_dir" -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \) -print0)
                fi
            fi
            ;;
            
        movie)
            search_dir="${MOVIES_DIR}"
            local safe_title=$(echo "$title" | tr '/' '*')
            
            while IFS= read -r -d $'\0' file; do
                local basename_file=$(basename "$file")
                local basename_no_ext="${basename_file%.*}"
                
                if [[ "$basename_no_ext" == "$safe_title" ]]; then
                    found_file="$file"
                    break
                fi
            done < <(find "$search_dir" -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \) -print0)
            ;;
            
        music)
            local base_search_dir="${MUSIC_DIR}"
            
            # Replace forward slashes with asterisks in the path components
            local processed_path=""
            IFS='/' read -ra path_parts <<< "$additional_path"
            for part in "${path_parts[@]}"; do
                local processed_part=$(echo "$part" | tr '/' '*' | sed 's/&amp;/\&/g' | tr -d '\"' | tr ':' '-')
                if [ -z "$processed_path" ]; then
                    processed_path="$processed_part"
                else
                    processed_path="$processed_path/$processed_part"
                fi
            done
            
            search_dir="${base_search_dir}/${processed_path}"
            
            if [[ -d "$search_dir" ]]; then
                if [[ "$title" =~ ^([0-9]+)\.[[:space:]](.*)$ ]]; then
                    local track_num=$(printf "%02d" "${BASH_REMATCH[1]}")
                    local track_name="${BASH_REMATCH[2]}"
                    
                    # Use the safe versions for filesystem operations
                    local artist_safe=$(echo "${path_parts[0]}" | tr '/' '*')
                    local album_safe=$(echo "${path_parts[1]}" | tr '/' '*')
                    local track_name_safe=$(echo "$track_name" | tr '/' '*')
                    
                    while IFS= read -r -d $'\0' file; do
                        local basename_file=$(basename "$file")
                        local escaped_artist=$(echo "$artist_safe" | sed 's/[.[\*^$()+?{|]/\\&/g')
                        local escaped_album=$(echo "$album_safe" | sed 's/[.[\*^$()+?{|]/\\&/g')
                        local escaped_track_name=$(echo "$track_name_safe" | sed 's/[.[\*^$()+?{|]/\\&/g')
                        
                        if [[ "$basename_file" =~ ^${escaped_artist}[[:space:]]-[[:space:]]${escaped_album}[[:space:]]-[[:space:]]${track_num}[[:space:]]-[[:space:]]${escaped_track_name}\..+ ]]; then
                            found_file="$file"
                            break
                        fi
                    done < <(find "$search_dir" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" \) -print0)
                fi
            fi
            ;;
    esac
    
    echo "$found_file"
}

handle_media() {
    local media_key="$1"
    local media_type="$2"
    local title="$3"
    local additional_path="$4"
    
    local response
    response=$(curl -s -H "X-Plex-Token: $PLEX_TOKEN" "${PLEX_URL}/library/metadata/${media_key}")
    
    local display_title
    local formatted_title
    local check_path
    case "$media_type" in
        music)
            local artist=$(echo "$response" | xmlstarlet sel -t -v "//Track/@grandparentTitle" 2>/dev/null)
            local album=$(echo "$response" | xmlstarlet sel -t -v "//Track/@parentTitle" 2>/dev/null)
            local track_num=$(echo "$response" | xmlstarlet sel -t -v "//Track/@index" 2>/dev/null)
            local track_title=$(echo "$response" | xmlstarlet sel -t -v "//Track/@title" 2>/dev/null)
            
            # Convert artist and album names to use asterisks for filesystem operations
            local artist_safe=$(echo "$artist" | tr '/' '*')
            local album_safe=$(echo "$album" | tr '/' '*')
            
            # Keep original names for display
            display_title="$title"
            # Use safe versions for filesystem operations
            formatted_title="$title"
            if [[ "$formatted_title" =~ ^([0-9]+)\.[[:space:]](.*)$ ]]; then
                local track_num="${BASH_REMATCH[1]}"
                local track_name="${BASH_REMATCH[2]}"
                formatted_title="${track_num}. ${track_name}"
            fi
            formatted_title=$(echo "$formatted_title" | tr '/' '*')
            check_path="${artist_safe}/${album_safe}"
            ;;
        episode)
            local show_title=$(echo "$response" | xmlstarlet sel -t -v "//Video/@grandparentTitle" 2>/dev/null)
            local season_num=$(echo "$response" | xmlstarlet sel -t -v "//Video/@parentIndex" 2>/dev/null)
            local episode_num=$(echo "$response" | xmlstarlet sel -t -v "//Video/@index" 2>/dev/null)
            local episode_title=$(echo "$response" | xmlstarlet sel -t -v "//Video/@title" 2>/dev/null)
            local season_folder=$(echo "$response" | xmlstarlet sel -t -v "//Video/@parentTitle" 2>/dev/null)
            
            season_num=$(printf "%02d" "$season_num")
            episode_num=$(printf "%02d" "$episode_num")
            
            # Keep original name for display
            display_title="${show_title} - S${season_num}E${episode_num} - ${episode_title}"
            display_title=$(echo "$display_title" | sed 's/&amp;/\&/g')

            # Create safe versions for filesystem
            local show_title_safe=$(echo "$show_title" | tr '/' '*')
            local season_folder_safe=$(echo "$season_folder" | tr '/' '*')
            local episode_title_safe=$(echo "$episode_title" | tr '/' '*')
            
            formatted_title="${show_title_safe} - S${season_num}E${episode_num} - ${episode_title_safe}"
            formatted_title=$(echo "$formatted_title" | sed 's/&amp;/\&/g')

            check_path="${show_title_safe}/${season_folder_safe}"
            check_path=$(echo "$check_path" | sed 's/&amp;/\&/g')
            ;;
        movie)
            # Keep original name for display
            display_title="$title"
            # Create safe version for filesystem
            formatted_title=$(echo "$title" | tr '/' '*')
            check_path=""
            ;;
        *)
            echo "Unsupported media type"
            return 1
            ;;
    esac
    
    local local_file
    local_file=$(check_local_file "$media_type" "$formatted_title" "$check_path")
    
    local action_prompt="Select Action for: $display_title"
    local action_options="Play from Plex\nDownload"
    
    if [[ -n "$local_file" ]]; then
        action_options="Play Local File\n${action_options}"
    fi
    
    local action
    action=$(echo -e "${action_options}\nCancel" | fzf --reverse --header="$action_prompt" --prompt="Choose action > ")
    
    case "$action" in
        "Play Local File")
            clear
            if [[ -n "$local_file" ]]; then
                mpv --title="$display_title" "$local_file"
                clear
            fi
            ;;
        "Play from Plex")
            clear
            play_media "$media_key" "$media_type" "$display_title"
            ;;
        "Download")
            clear
            download_media "$media_key" "$media_type" "$display_title" "$check_path"
            ;;
        *)
            return 0
            ;;
    esac
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
                        echo -e "< Go back" | fzf --reverse --header="Library Empty" --disabled
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
                    
                    handle_media "$movie_key" "movie" "$chosen_movie"
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
                        echo -e "< Go back" | fzf --reverse --header="Library Empty" --disabled
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
                            break
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
                                break
                            fi

                            local episode_key
                            episode_key=$(echo "$episodes" | grep "^${chosen_episode}|" | cut -d'|' -f2)
                            
                            local episode_title="$chosen_show - $chosen_season - $chosen_episode"
                            local show_path="${chosen_show// /_}/Season_${chosen_season#Season }"
                            handle_media "$episode_key" "episode" "$episode_title" "$show_path"
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
                        echo -e "< Go back" | fzf --reverse --header="Library Empty" --disabled
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
                            break
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
                                break
                            fi

                            local track_key
                            track_key=$(echo "$tracks" | grep "^${chosen_track}|" | cut -d'|' -f2)
                            
                            local track_title="$chosen_track"
                            local music_path="${chosen_artist// /_}/${chosen_album// /_}"
                            handle_media "$track_key" "music" "$track_title" "$music_path"
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
    choice=$(echo -e "Movies\nTV Shows\nMusic\nDownloads\n----------\nUpdate\nHelp\n----------\nQuit" | fzf --reverse --header="Select Media Type" --prompt="Search Menu > ")
    
    if [[ -z "$choice" ]]; then
        clear
        return
    fi
    
    case "$choice" in
        Movies) select_media "movie" ;;
        "TV Shows") select_media "show" ;;
        Music) select_media "music" ;;
        Downloads) downloads_menu ;;
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
    check_dependencies
    check_plex_credentials
    create_download_dirs
    
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
