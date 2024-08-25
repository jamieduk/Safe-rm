#!/bin/bash

# Directory to move files under 10MB
BACKUP_DIR="$HOME/deleted_files"
TRACKING_FILE="$BACKUP_DIR/deleted_files.log"

# Create the backup directory and tracking file if they don't exist
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
fi

if [ ! -f "$TRACKING_FILE" ]; then
    touch "$TRACKING_FILE"
fi

# Function to check if a file is a critical shared library or system file
is_critical_file() {
    local file="$1"

    # Critical paths or files
    critical_files=(
        "/lib" "/lib64" "/usr/lib" "/usr/lib64" "/bin" "/sbin" "/usr/bin" "/usr/sbin"
        "/etc" "/boot" "/root" "/var" "/opt"
    )

    # Block deletion of certain types of critical files
    critical_extensions=(
        "*.so" "*.so.*" "*.ko" "*.conf" "*.service" "*.bin" "*.sh" "*.desktop" "*.config"
    )

    # Check if the file matches critical paths
    for critical in "${critical_files[@]}"; do
        if [[ "$file" == $critical/* ]]; then
            echo "Error: '$file' is in a critical system directory and cannot be removed."
            return 0
        fi
    done

    # Check if the file matches critical extensions
    for ext in "${critical_extensions[@]}"; do
        if [[ "$file" == $ext ]]; then
            echo "Error: '$file' is a critical system file (matches extension) and cannot be removed."
            return 0
        fi
    done

    return 1
}

# Function to restore a file from the backup directory
undelete() {
    local filename="$1"
    local backup_file="$BACKUP_DIR/$filename"

    echo "Attempting to restore '$filename'..."

    # Check if the file exists in the backup directory
    if [ -f "$backup_file" ]; then
        # Get the original path from the tracking file
        local original_path=$(grep "^$filename " "$TRACKING_FILE" | cut -d' ' -f2-)

        # If the original path is found, restore the file
        if [ -n "$original_path" ]; then
            mv "$backup_file" "$original_path"
            echo "'$filename' has been restored to its original location: '$original_path'."
            
            # Remove the entry from the tracking file
            sed -i "/^$filename /d" "$TRACKING_FILE"
        else
            # If original path is not found, restore to current directory
            mv "$backup_file" "$(pwd)/$filename"
            echo "'$filename' has been restored to the current directory."
            
            # Optionally, remove the entry from the log file
            sed -i "/^$filename /d" "$TRACKING_FILE"
        fi
    else
        echo "Error: '$filename' not found in the backup directory."
    fi
}

# Main script logic
if [ "$1" == "--undelete" ]; then
    undelete "$2"
    exit 0
fi

# File deletion and backup handling
for file in "$@"; do
    if [ -e "$file" ]; then
        # Check if the file is a critical system file before deletion
        if is_critical_file "$file"; then
            continue
        fi

        FILE_SIZE=$(stat -c%s "$file")
        
        if [ "$FILE_SIZE" -lt 10485760 ]; then
            original_path=$(realpath "$file")
            mv "$file" "$BACKUP_DIR/"
            echo "'$file' moved to '$BACKUP_DIR'."
            echo "$(basename "$file") $original_path" >> "$TRACKING_FILE"
        else
            read -p "Are you sure you want to delete '$file'? (y/n) " CONFIRM
            if [[ "$CONFIRM" == [yY] ]]; then
                rm "$file"
                echo "'$file' has been deleted."
            else
                echo "'$file' was not deleted."
            fi
        fi
    else
        echo "Error: '$file' does not exist."
    fi
done

