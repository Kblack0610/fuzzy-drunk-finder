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
    
    # For unlimited depth in very large directories, we need a pragmatic approach
    # to avoid hanging - limit to a reasonable max depth of 7 which is still very deep
    local max_depth_limit=7
    
    if [ "$hidden" = true ]; then
        # Include hidden files/directories with chosen depth
        if [ "$unlimited" = true ]; then
            # Still use a reasonable max depth to prevent hanging in huge directories
            find_cmd="find . -type d -maxdepth $max_depth_limit | sed 's|^\\./||'"
        else
            find_cmd="find . -type d -maxdepth $depth | sed 's|^\\./||'"
        fi
    else
        # Exclude hidden files/directories with chosen depth
        if [ "$unlimited" = true ]; then
            # Still use a reasonable max depth to prevent hanging in huge directories
            find_cmd="find . -type d -not -path \"*/\\.*\" -maxdepth $max_depth_limit | sed 's|^\\./||'"
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
    local debug_mode=false
    local search_term=""
    local test_mode=false
    
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
            --debug)
                debug_mode=true
                shift
                ;;
            --search)
                test_mode=true
                if [[ -n "$2" && "$2" != -* ]]; then
                    search_term="$2"
                    shift 2
                else
                    search_term=""
                    shift
                fi
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
                echo "Usage: fdf [--hidden] [--depth N] [--unlimited] [--no-history] [--debug] [--search [TERM]] [directory]"
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
    
    # For very large directories like /home/username, limit the depth
    # even with --unlimited to prevent hanging
    local max_depth=7
    local effective_depth="$depth"
    
    if [[ "$unlimited" = true && "$start_dir" =~ ^/home/.* ]]; then
        # For home directories, be extra careful with depth to prevent system hang
        unlimited=false
        effective_depth="$max_depth"
        echo "Notice: Using maximum depth of $max_depth for home directory to prevent system hang"
    fi
    
    # Get directories with caching
    local dirs=$(get_directories "$start_dir" "$show_hidden" "$effective_depth" "$unlimited")
    
    # Get context-specific history entries
    local history_entries=""
    if [ "$use_history" = true ]; then
        if [ -f "$HISTORY_FILE" ]; then
            # Find directories visited from this location
            history_entries=$(grep "^$start_dir:" "$HISTORY_FILE" | 
                              sed "s|^$start_dir:||" | 
                              sort | uniq -c | sort -nr | 
                              sed 's/^ *[0-9]* *//' | 
                              grep -v '^$')
        fi
    fi
    
    # Calculate boot time before showing UI
    local boot_time=$(echo "$(date +%s.%N) - $start_time" | bc)
    
    # Setup FZF preview text
    local header_text="Directory: $start_dir"
    [ "$show_hidden" = true ] && header_text="$header_text [Hidden: ON]" 
    [ "$unlimited" = true ] && header_text="$header_text [Depth: Unlimited]"
    [ "$debug_mode" = true ] && header_text="$header_text [DEBUG MODE]"
    header_text="$header_text [Boot: ${boot_time}s]"
    
    # Debug output
    if [ "$debug_mode" = true ]; then
        echo "Debug: Current directory: $start_dir"
        echo "Debug: Show hidden: $show_hidden"
        echo "Debug: Depth: $depth (effective: $effective_depth)"
        echo "Debug: Unlimited: $unlimited"
        echo "Debug: History entries: $(echo "$history_entries" | wc -l)"
        echo "Debug: Total directories: $(echo "$dirs" | wc -l)"
        echo "Debug: Boot time: ${boot_time}s"
    fi
    
    # Create a temporary file for FZF input
    local tmp_history=$(mktemp)
    local tmp_dirs=$(mktemp)
    
    # Debug info
    if [ "$debug_mode" = true ]; then
        echo "Debug: Using temporary history file: $tmp_history"
        echo "Debug: Using temporary dirs file: $tmp_dirs"
    fi
    
    # Add history entries to a separate temp file
    local history_count=0
    if [ -n "$history_entries" ]; then
        while IFS= read -r hentry; do
            if [ -n "$hentry" ]; then
                # Make history entries stand out with a distinctive prefix
                echo "HISTORY: $hentry" >> "$tmp_history"
                history_count=$((history_count + 1))
            fi
        done <<< "$history_entries"
    fi
    
    # Add directories to a separate temp file
    echo "$dirs" > "$tmp_dirs"
    
    # In debug mode, show even more details
    if [ "$debug_mode" = true ]; then
        echo "Debug: History entries added: $history_count"
        echo "Debug: Total directories: $(wc -l < "$tmp_dirs")"
        
        if [ -n "$history_entries" ]; then
            echo "Debug: First few history entries:"
            echo "$history_entries" | head -3 | sed 's/^/  /'
        fi
        
        echo "Debug: First few directory entries:"
        echo "$dirs" | head -3 | sed 's/^/  /'
        
        echo "Debug: First few lines of history file:"
        head -3 "$tmp_history" | sed 's/^/  /'
    fi
    
    # Test mode - simulate a search without using FZF
    if [ "$test_mode" = true ]; then
        echo "=== TEST MODE: Showing entries that would be searched ==="
        echo "Search term: '${search_term}'"
        echo "=== History Entries ==="
        
        if [ -n "$history_entries" ]; then
            if [ -n "$search_term" ]; then
                # Search within history entries
                matched_history=$(echo "$history_entries" | grep -i "$search_term" || echo "")
                if [ -n "$matched_history" ]; then
                    echo "$matched_history" | sed 's/^/[HISTORY] /'
                    history_count=$(echo "$matched_history" | wc -l)
                else
                    echo "No history entries match the search term."
                    history_count=0
                fi
            else
                # Show all history entries
                echo "$history_entries" | sed 's/^/[HISTORY] /'
                history_count=$(echo "$history_entries" | wc -l)
            fi
        else
            echo "No history entries found for this directory."
            history_count=0
        fi
        
        echo "=== Regular Directories ==="
        local dirs_count=0
        
        if [ -n "$search_term" ]; then
            # Search within directories
            matched_dirs=$(echo "$dirs" | grep -i "$search_term" || echo "")
            if [ -n "$matched_dirs" ]; then
                echo "$matched_dirs" | head -20
                dirs_count=$(echo "$matched_dirs" | wc -l)
                if [ "$dirs_count" -gt 20 ]; then
                    echo "... ($(($dirs_count - 20)) more matches)"
                fi
            else
                echo "No directory entries match the search term."
                dirs_count=0
            fi
        else
            # Show sample of directories
            echo "$dirs" | head -20
            dirs_count=$(echo "$dirs" | wc -l)
            if [ "$dirs_count" -gt 20 ]; then
                echo "... ($(($dirs_count - 20)) more entries)"
            fi
        fi
        
        echo "=== Summary ==="
        echo "Total history matches: $history_count"
        echo "Total directory matches: $dirs_count"
        echo "Total matches: $(($history_count + $dirs_count))"
        echo "Test complete. Exiting without selection."
        
        # Cleanup
        rm -f "$tmp_history" "$tmp_dirs"
        return 0
    fi
    
    # Use FZF for selection with improved options - critically important!
    local fzf_opts=(
        --height 40%
        --reverse
        --header="$header_text"
        --prompt="Fuzzy Drunk Finder > "
        --bind="ctrl-/:toggle-preview"
        --preview="echo {} | grep -q '^HISTORY:' && echo 'History entry from previous navigation' || ls -la ${start_dir}/{} 2>/dev/null || ls -la {} 2>/dev/null || echo 'No preview available'"
    )
    
    if [ "$debug_mode" = true ]; then
        echo "Debug: FZF options: ${fzf_opts[*]}"
    fi
    
    # Select with FZF - combine history entries and directories
    # IMPORTANT: History entries must come first to ensure they appear in search
    local selected=$(cat "$tmp_history" "$tmp_dirs" | fzf "${fzf_opts[@]}")
    
    # Clean up the temporary files
    rm -f "$tmp_history" "$tmp_dirs"
    
    # If user selected a directory, navigate to it
    if [ -n "$selected" ]; then
        # Remove the history prefix if present
        selected=$(echo "$selected" | sed 's/^HISTORY: //')
        
        # Debug output
        if [ "$debug_mode" = true ]; then
            echo "Debug: Selected directory: $selected"
        else
            echo "Changing to directory: $selected"
        fi
        
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
            
            if [ "$debug_mode" = true ]; then
                echo "Debug: Added to history - From: $original_dir, To: $(pwd)"
            fi
        fi
        
        # Return success
        return 0
    fi
    
    # User cancelled, return to original directory
    if [ "$debug_mode" = true ]; then
        echo "Debug: User cancelled selection"
    fi
    
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
    echo "  fdf [--hidden] [--depth N] [--unlimited] [--no-history] [--debug] [--search [TERM]] [directory]"
    echo ""
    echo "Options:"
    echo "  --hidden      Include hidden directories in the search"
    echo "  --depth N     Set search depth (default: 3)"
    echo "  --unlimited   Remove depth limit for searches (may be slow in large directories)"
    echo "  --no-history  Don't use or update the directory history"
    echo "  --debug       Enable debug mode with detailed information"
    echo "  --search      Test mode: show what would be searched (optional: provide search term)"
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
