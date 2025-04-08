#!/bin/bash

# Fuzzy Drunk Finder - Directory Navigation Script
# Features:
# - Specify starting directory with parameter
# - Option to show hidden files with --hidden flag
# - Simple and fast directory navigation
# - History tracking to prioritize frequently visited directories
# - Context-aware history based on your current location
# - Caching for faster startup in large directories

# Configuration
HISTORY_FILE="$HOME/.fdf_history"
MAX_HISTORY_ENTRIES=1000
CACHE_DIR="$HOME/.cache/fdf"
CACHE_TIMEOUT=3600  # Cache timeout in seconds (1 hour)

# Create necessary directories and files
if [ ! -f "$HISTORY_FILE" ]; then
    touch "$HISTORY_FILE"
    chmod 600 "$HISTORY_FILE"  # Secure permissions
fi

# Create cache directory
if [ ! -d "$CACHE_DIR" ]; then
    mkdir -p "$CACHE_DIR"
    chmod 700 "$CACHE_DIR"  # Secure permissions
fi

# Function to add a directory to history with context
add_to_history() {
    local visited_dir="$1"
    local from_dir="$2"
    
    # Don't add empty entries
    if [ -n "$visited_dir" ] && [ -n "$from_dir" ]; then
        # Format: from_directory:visited_directory
        echo "$from_dir:$visited_dir" >> "$HISTORY_FILE"
        
        # Keep history file at a reasonable size
        if [ "$(wc -l < "$HISTORY_FILE")" -gt "$MAX_HISTORY_ENTRIES" ]; then
            tail -n "$MAX_HISTORY_ENTRIES" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp"
            mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
        fi
    fi
}

# Function to get context-aware history for current directory
get_context_history() {
    local current_dir="$1"
    
    if [ -f "$HISTORY_FILE" ]; then
        # Get most frequently visited directories from this location
        grep "^$current_dir:" "$HISTORY_FILE" | 
            sed "s|^$current_dir:||" | 
            sort | uniq -c | sort -nr | 
            sed 's/^ *[0-9]* *//' | 
            grep -v '^$' | 
            awk '{print "[HISTORY] " $0}'
    fi
}

# Function to create a unique cache key for a directory search
get_cache_key() {
    local dir="$1"
    local hidden="$2"
    local depth="$3"
    local unlimited="$4"
    
    # Create a unique key based on search parameters
    echo "${dir}_h${hidden}_d${depth}_u${unlimited}" | md5sum | cut -d' ' -f1
}

# Function to get directories with caching
get_directories() {
    local dir="$1"
    local hidden="$2"
    local depth="$3"
    local unlimited="$4"
    
    # Create a unique cache key
    local cache_key=$(get_cache_key "$dir" "$hidden" "$depth" "$unlimited")
    local cache_file="$CACHE_DIR/$cache_key"
    
    # Check if we have a valid cache file
    if [ -f "$cache_file" ] && [ $(($(date +%s) - $(stat -c %Y "$cache_file"))) -lt "$CACHE_TIMEOUT" ]; then
        cat "$cache_file"
        return
    fi
    
    # Build the find command based on options
    local find_cmd
    if [ "$hidden" = true ]; then
        # Include hidden files/directories with chosen depth
        if [ "$unlimited" = true ]; then
            find_cmd="find . -type d | sed 's|^\\./||'"
        else
            find_cmd="find . -type d -maxdepth $depth | sed 's|^\\./||'"
        fi
    else
        # Exclude hidden files/directories with chosen depth
        if [ "$unlimited" = true ]; then
            find_cmd="find . -type d -not -path \"*/\\.*\" | sed 's|^\\./||'"
        else
            find_cmd="find . -type d -not -path \"*/\\.*\" -maxdepth $depth | sed 's|^\\./||'"
        fi
    fi
    
    # Execute the find command and cache the results
    eval "$find_cmd" | grep -v '^$' > "$cache_file"
    
    # Return the results
    cat "$cache_file"
}

# Function for fuzzy directory navigation
fdf() {
    # Default values
    local start_dir="$(pwd)"
    local show_hidden=false
    local depth=3
    local unlimited=false
    local use_history=true
    local start_time=$(date +%s.%N)
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --hidden)
                show_hidden=true
                shift
                ;;
            --unlimited)
                unlimited=true
                shift
                ;;
            --no-history)
                use_history=false
                shift
                ;;
            --depth)
                if [[ "$2" =~ ^[0-9]+$ ]]; then
                    depth="$2"
                    # Special case: depth 0 means unlimited
                    if [ "$depth" -eq 0 ]; then
                        unlimited=true
                    fi
                    shift 2
                else
                    echo "Error: --depth requires a number"
                    return 1
                fi
                ;;
            -*)
                echo "Unknown option: $1"
                echo "Usage: fdf [--hidden] [--depth N] [--unlimited] [--no-history] [directory]"
                return 1
                ;;
            *)
                # Assume it's a directory
                if [ -d "$1" ]; then
                    start_dir="$1"
                    shift
                else
                    echo "Error: '$1' is not a valid directory"
                    return 1
                fi
                ;;
        esac
    done
    
    # Go to the start directory
    cd "$start_dir" || return 1
    
    # Get context-specific history for this directory
    local history_entries=""
    if [ "$use_history" = true ]; then
        history_entries=$(get_context_history "$start_dir")
    fi
    
    # Get directories with caching
    local dirs=$(get_directories "$start_dir" "$show_hidden" "$depth" "$unlimited")
    
    # Calculate boot time before showing UI
    local boot_time=$(echo "$(date +%s.%N) - $start_time" | bc)
    
    # Combine history and current directories (if we have history entries)
    local suggestions="$dirs"
    if [ -n "$history_entries" ]; then
        suggestions=$(
            (
                echo "$history_entries"
                echo "$dirs"
            )
        )
    fi
    
    # Use fzf to let user select a directory
    local prompt_text="Directory"
    [ "$unlimited" = true ] && prompt_text="Directory (unlimited depth)"
    [ "$show_hidden" = true ] && prompt_text="$prompt_text (hidden files)"
    
    local selected=$(echo "$suggestions" | fzf --height 40% --reverse \
        --header="Select directory to navigate to (from: $start_dir) [Boot: ${boot_time}s]" \
        --prompt="$prompt_text > ")
    
    # If user selected a directory, navigate to it
    if [ -n "$selected" ]; then
        # Strip [HISTORY] tag if present
        selected="${selected#[HISTORY] }"
        
        echo "Changing to directory: $selected"
        # Store original directory before changing
        local original_dir="$(pwd)"
        
        # Check if it's a relative or absolute path
        if [[ "$selected" == /* ]]; then
            cd "$selected" || return 1
        else
            cd "$start_dir/$selected" || return 1
        fi
        
        # Add to history with context information
        if [ "$use_history" = true ]; then
            add_to_history "$(pwd)" "$original_dir"
        fi
        
        # Return success
        return 0
    fi
    
    # User cancelled, return to original directory
    return 0
}

# Create a default alias 
alias fdf_quick="fdf"

# Function to clear cache
fdf_clear_cache() {
    if [ -d "$CACHE_DIR" ]; then
        rm -rf "$CACHE_DIR"/*
        mkdir -p "$CACHE_DIR"
        echo "Fuzzy Drunk Finder cache cleared."
    else
        mkdir -p "$CACHE_DIR"
        echo "Cache directory created at $CACHE_DIR."
    fi
}

# Usage examples function
fdf_help() {
    echo "Fuzzy Drunk Finder (FDF) - Simple Directory Navigation"
    echo ""
    echo "Usage:"
    echo "  fdf [--hidden] [--depth N] [--unlimited] [--no-history] [directory]"
    echo ""
    echo "Options:"
    echo "  --hidden      Include hidden directories in the search"
    echo "  --depth N     Set search depth (default: 3)"
    echo "  --unlimited   Remove depth limit for searches (may be slow in large directories)"
    echo "  --no-history  Don't use or update the directory history"
    echo "  directory     Starting directory (default: current directory)"
    echo ""
    echo "Commands:"
    echo "  fdf_help      Show this help message"
    echo "  fdf_clear_cache  Clear the directory cache to force fresh searches"
    echo ""
    echo "Examples:"
    echo "  fdf                         # Navigate from current directory"
    echo "  fdf --hidden                # Include hidden directories"
    echo "  fdf --depth 5               # Search 5 levels deep" 
    echo "  fdf --unlimited             # Search without depth limit (may be slow)"
    echo "  fdf --depth 0               # Same as --unlimited"
    echo "  fdf /home                   # Start from /home"
    echo "  fdf --hidden --unlimited ~  # Unlimited search from home, show hidden"
    echo ""
    echo "History:"
    echo "  FDF saves your directories visited from specific locations."
    echo "  History is context-aware - you'll only see history relevant to your current location."
    echo "  Your history file is stored at: $HISTORY_FILE"
    echo ""
    echo "Performance:"
    echo "  FDF caches directory listings to improve boot time in large directories."
    echo "  The cache expires after $(($CACHE_TIMEOUT/60)) minutes or can be cleared with fdf_clear_cache."
    echo "  Cache is stored at: $CACHE_DIR"
    echo ""
    echo "Note: This script must be sourced, not executed."
    echo "Please run: source fuzzy-drunk-finder.sh or . fuzzy-drunk-finder.sh"
}

# Execute the function immediately when sourced with any provided arguments
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Script is being sourced
    echo "Fuzzy Drunk Finder loaded. Type 'fdf' to use or 'fdf_help' for help."
else
    # Script is being executed directly
    echo "⚠️  This script must be sourced, not executed."
    echo "Please run: source $(basename "${BASH_SOURCE[0]}") or . $(basename "${BASH_SOURCE[0]}")"
    exit 1
fi
