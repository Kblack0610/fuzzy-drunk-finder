# Fuzzy Drunk Finder (FDF)

A lightweight, fast directory navigation tool powered by fzf. Navigate your filesystem with ease and precision, even after a few drinks!

## Overview

Fuzzy Drunk Finder provides an intuitive interface for quickly navigating your filesystem using fuzzy search. It's designed to be:

- **Fast**: Near-instant startup time
- **Intuitive**: Simple, consistent interface
- **Flexible**: Customizable search depth and starting locations
- **Friendly**: Works with hidden files when you need it to

## Installation

1. Clone this repository or download the script
2. Make it executable: `chmod +x fuzzy-drunk-finder.sh`
3. Source the script in your shell: `source fuzzy-drunk-finder.sh`

You can add this line to your `.bashrc` or `.zshrc` for permanent access:
```bash
source /path/to/fuzzy-drunk-finder/fuzzy-drunk-finder.sh
```

## Usage

After sourcing the script, you can use the `fdf` command:

```bash
# Basic usage - navigate from current directory
fdf

# Start from a specific directory
fdf /home/username/projects

# Include hidden directories
fdf --hidden

# Adjust search depth (default is 3)
fdf --depth 5

# Unlimited depth search
fdf --unlimited
# OR
fdf --depth 0

# Disable history tracking
fdf --no-history

# Combine options
fdf --hidden --unlimited /usr/local
```

## Features

- **Simple Navigation**: Quickly find and change to any directory within your search depth
- **Hidden File Support**: Toggle visibility of hidden directories with `--hidden` flag
- **Customizable Depth**: Control how deep the search goes with `--depth N`
- **Unlimited Depth**: Use `--unlimited` or `--depth 0` for searching without depth limits
- **History Tracking**: Automatically saves and prioritizes your most frequently visited directories
- **Custom Starting Point**: Begin your search from any directory
- **Help System**: Built-in help with `fdf_help`

## Requirements

- [fzf](https://github.com/junegunn/fzf) must be installed
- Bash or compatible shell

## How It Works

Fuzzy Drunk Finder uses `find` to locate directories within your specified depth and `fzf` to provide the fuzzy search interface. When you select a directory, it automatically changes your current working directory to the selected location.

The script also maintains a history file at `~/.fdf_history` to track your most frequently used directories. These directories are presented at the top of the selection list, letting you quickly access your common destinations.

The script must be sourced (not executed directly) because it needs to change your shell's current directory, which a separate process cannot do.

## Tips

- Use tab completion within the fzf interface to quickly navigate deep directories
- The `--depth` parameter lets you control performance vs search comprehensiveness
- For large directory structures, keep the depth lower (2-3) for best performance
- For repositories or project directories, a depth of 4-5 often works well
- Use `--unlimited` with caution in large directory structures (like `/` or `/home`) as it can be slow
- Your history will improve over time as the script learns your navigation patterns
- Set `--depth 0` as an alternative to `--unlimited` if you prefer

## License

This is free and unencumbered software released into the public domain.

---

*This tool was created to help navigate the filesystem after a long night of coding (or drinking), when remembering exact paths becomes challenging. Use responsibly!*
