#!/bin/bash

# Script to calculate total duration of all audio files in a track folder

# Check if track number argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <track_number>"
    echo "Example: $0 5"
    echo "This will analyze audio files in Tracks/5/Songs/"
    exit 1
fi

TRACK_NUM="$1"

# Validate that the track number is numeric
if ! [[ "$TRACK_NUM" =~ ^[0-9]+$ ]]; then
    echo "Error: Track number must be a numeric value"
    echo "Usage: $0 <track_number>"
    exit 1
fi

# Construct folder path using the new structure
FOLDER="Tracks/${TRACK_NUM}/Songs"

# Check if folder exists
if [ ! -d "$FOLDER" ]; then
    echo "Error: Songs folder not found: $FOLDER"
    echo "Make sure Track $TRACK_NUM exists with the correct structure:"
    echo "  Tracks/$TRACK_NUM/Songs/"
    exit 1
fi

# Initialize variables
total_seconds=0
file_count=0

echo "Analyzing audio files in: $FOLDER"
echo "-----------------------------------"

# Find all audio files (mp3, wav, flac, m4a, aac, ogg)
# Create a temporary file to store the file list
temp_files=$(mktemp)
find "$FOLDER" -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.aac" -o -iname "*.ogg" \) -print0 | sort -z > "$temp_files"

while IFS= read -r -d $'\0' file; do
    # Get duration using ffprobe
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$duration" ]; then
        # Round to integer
        duration_int=$(printf "%.0f" "$duration")
        total_seconds=$((total_seconds + duration_int))
        file_count=$((file_count + 1))
        
        # Convert to minutes:seconds for display
        minutes=$((duration_int / 60))
        seconds=$((duration_int % 60))
        
        # Get just the filename for display
        filename=$(basename "$file")
        printf "%-50s %3d:%02d\n" "$filename" "$minutes" "$seconds"
    fi
done < "$temp_files"

# Clean up temporary file
rm -f "$temp_files"

echo "-----------------------------------"
echo "Total files: $file_count"

# Convert total to hours:minutes:seconds
hours=$((total_seconds / 3600))
minutes=$(((total_seconds % 3600) / 60))
seconds=$((total_seconds % 60))

echo "Total duration: ${hours}h ${minutes}m ${seconds}s"
echo "Total seconds: ${total_seconds}s"

# Calculate how long to fill common video lengths
echo ""
echo "Loop calculations:"
echo "  - For 15 min video: need $(( (900 / total_seconds) + 1 )) loops"
echo "  - For 30 min video: need $(( (1800 / total_seconds) + 1 )) loops"
echo "  - For 60 min video: need $(( (3600 / total_seconds) + 1 )) loops"
echo "  - For 90 min video: need $(( (5400 / total_seconds) + 1 )) loops"
