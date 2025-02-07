<h1><img src="https://raw.githubusercontent.com/jeremehancock/CLIX/main/icons/clix-icon.png" height="50" /> CLIX</h1>

## A Plex Terminal Media Player

CLIX is a powerful command-line interface tool that allows you to browse and play media from your Plex Media Server directly in your terminal. It supports movies, TV shows, and music libraries with an intuitive terminal-based user interface.

*Note: CLIX is for Linux only*

## Features

- Browse and play media directly from your terminal
- Support for Movies, TV Shows, and Music libraries
- Download option to allow local playback
- Fuzzy search functionality for quick media finding
- Intuitive navigation with keyboard controls
- Progress tracking with version checking
- Built-in update mechanism
- Robust error handling and dependency checking

## Screenshots

![Main Menu](https://raw.githubusercontent.com/jeremehancock/CLIX/main/screenshots/main.png "Main Menu")

![Movies Menu](https://raw.githubusercontent.com/jeremehancock/CLIX/main/screenshots/movies.png "Movies Menu")

![TV Shows Menu](https://raw.githubusercontent.com/jeremehancock/CLIX/main/screenshots/tv.png "TV Shows Menu")

![Music Menu](https://raw.githubusercontent.com/jeremehancock/CLIX/main/screenshots/music.png "Music Menu")

![Help Screen](https://raw.githubusercontent.com/jeremehancock/CLIX/main/screenshots/help-screen.png "Help Screen")

## Requirements

- A Plex Media Server
- Plex authentication token
- curl
- xmlstarlet
- fzf
- mpv

## Installation

### Quick Start

1. Download CLIX:
```bash
mkdir CLIX && cd CLIX && curl -o clix.sh https://raw.githubusercontent.com/jeremehancock/CLIX/main/clix.sh && chmod +x clix.sh && ./clix.sh
```

### Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/jeremehancock/CLIX.git
```

2. Change Directory:
```bash
cd CLIX
```

3. Make the script executable:
```bash
chmod +x clix.sh
```

## Configuration

CLIX requires minimal configuration. Edit the script and set these variables at the top:

```bash
###################
# Server Settings #
###################

PLEX_URL="http://localhost:32400"  # Your Plex server URL
PLEX_TOKEN=""                      # Your Plex authentication token
```

To find your Plex token, follow the instructions here: [Finding an authentication token](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/)

## Usage

### Basic Usage

```bash
./clix.sh
```

### Command Line Options

```
-h		Show help message
-v		Show version information
-u		Update to latest version
```

### Navigation Controls

- `↑/↓` - Move up/down in menus
- `Enter` - Select current item
- `ESC` - Go back to previous menu
- `Ctrl+C` - Exit the program
- Type to search - Fuzzy finding in any menu

### Menu Structure

1. Main Menu
   - Movies
   - TV Shows
   - Music
   - Update
   - Help
   - Quit

2. Library Selection
   - Select your library
   - If there is only one library of the selected library type it will be auto selected

3. Media Selection
   - Movies: Browse and select movie
   - TV Shows: Select show → season → episode
   - Music: Select artist → album → track

## Updates

CLIX includes a built-in update mechanism that can be triggered in two ways:
1. Using the Update option in the main menu
2. Running with the -u flag

When updating:
- A backup of the current version is automatically created
- The latest version is downloaded from the repository
- Permissions are preserved
- Version checking ensures you're always up to date

## Note

CLIX needs to be on the same network as your Plex Media Server to run. 

If you want to connect remotely you will need to use something like [Tailscale](https://tailscale.com) to ensure that CLIX can communicate with your Plex Media Server.

## License

[MIT License](LICENSE)

## AI Assistance Disclosure

This tool was developed with assistance from AI language models.