#!/bin/bash

# Script to remove the first X characters from all filenames in a folder

# Check if arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <number_of_chars> <folder_path> [file_pattern]"
    echo ""
    echo "Examples:"
    echo "  $0 5 ./Tracks/1/Songs          # Remove first 5 chars from all files"
    echo "  $0 3 ./Tracks/1/Songs '*.mp3'  # Remove first 3 chars from .mp3 files only"
    echo "  $0 10 .                        # Remove first 10 chars from files in current dir"
    echo ""
    exit 1
fi

NUM_CHARS="$1"
FOLDER_PATH="$2"
FILE_PATTERN="${3:-*}"  # Default to all files if no pattern specified

# Validate that NUM_CHARS is a number
if ! [[ "$NUM_CHARS" =~ ^[0-9]+$ ]]; then
    echo "Error: Number of characters must be a positive integer"
    exit 1
fi

# Check if folder exists
if [ ! -d "$FOLDER_PATH" ]; then
    echo "Error: Folder not found: $FOLDER_PATH"
    exit 1
fi

# Change to the target directory
cd "$FOLDER_PATH" || exit 1

echo "Removing first $NUM_CHARS characters from filenames in: $FOLDER_PATH"
echo "File pattern: $FILE_PATTERN"
echo ""

# Counter for renamed files
count=0

# Find all files matching the pattern (non-recursive)
shopt -s nullglob  # Handle case when no files match
for file in $FILE_PATTERN; do
    # Skip if it's a directory
    if [ -d "$file" ]; then
        continue
    fi
    
    # Get the filename
    filename=$(basename "$file")
    
    # Check if filename is long enough
    if [ ${#filename} -le $NUM_CHARS ]; then
        echo "⚠️  Skipping '$filename' - filename too short (${#filename} chars)"
        continue
    fi
    
    # Remove first N characters
    new_filename="${filename:$NUM_CHARS}"
    
    # Check if new filename would be empty or already exists
    if [ -z "$new_filename" ]; then
        echo "⚠️  Skipping '$filename' - would result in empty filename"
        continue
    fi
    
    if [ -e "$new_filename" ]; then
        echo "⚠️  Skipping '$filename' - '$new_filename' already exists"
        continue
    fi
    
    # Rename the file
    mv "$file" "$new_filename"
    echo "✓ '$filename' → '$new_filename'"
    ((count++))
done

echo ""
echo "Renamed $count file(s)"
