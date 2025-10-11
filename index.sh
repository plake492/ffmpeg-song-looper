#!/bin/bash

# Create timestamped output folder
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="output_${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"

# Input values
BG_VIDEO="background.mp4"
SONG_DIR="songs"
OUTPUT="${OUTPUT_DIR}/output.mp4"
DURATION=1800       # 30 minutes (seconds)
FADEOUT_START=410   # fade out starts 10 seconds before end
FADEOUT_DUR=10      # fade-out duration
XFADE_DUR=3         # crossfade overlap duration (seconds)
SONG_FADEOUT_START=5 # start fading out this many seconds before song ends

# Find all mp3 files in the song directory, sorted alphabetically
# The null delimiter is used to handle filenames with spaces or special characters
SONGS=()
SONG_DURATIONS=()
while IFS= read -r -d $'\0'; do
    SONGS+=("$REPLY")
    # Get the actual duration of each song using ffprobe
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$REPLY")
    # Round to integer seconds
    duration_int=$(printf "%.0f" "$duration")
    SONG_DURATIONS+=("$duration_int")
done < <(find "$SONG_DIR" -name "*.mp3" -print0 | sort -z)


# Check if songs were found
if [ ${#SONGS[@]} -eq 0 ]; then
    echo "No mp3 files found in $SONG_DIR"
    exit 1
fi

# --- Build the ffmpeg command ---

# Start with the base command and the background video input
ffmpeg_args=(-y -stream_loop -1 -i "$BG_VIDEO")

# Add each song as an input
for song in "${SONGS[@]}"; do
    ffmpeg_args+=(-i "$song")
done

# --- Build the filter_complex string ---

# Calculate total duration of one pass through all songs
total_sequence_duration=0
for i in "${!SONGS[@]}"; do
    song_dur=${SONG_DURATIONS[$i]}
    total_sequence_duration=$((total_sequence_duration + song_dur - SONG_FADEOUT_START))
done
# Add back the fadeout time from the last song
total_sequence_duration=$((total_sequence_duration + SONG_FADEOUT_START))

# Calculate how many times we need to repeat to exceed the target duration
num_repeats=$(( (DURATION / total_sequence_duration) + 2 ))

echo "Total sequence duration: ${total_sequence_duration}s"
echo "Will repeat sequence ${num_repeats} times to fill ${DURATION}s"

filter_complex=""
mix_inputs=""
num_songs=${#SONGS[@]}
cumulative_time=0

# Create multiple passes of the song sequence
for repeat in $(seq 0 $((num_repeats - 1))); do
    for i in "${!SONGS[@]}"; do
        stream_index=$((i + 1))
        song_dur=${SONG_DURATIONS[$i]}
        
        # Base filter for trimming the audio (use actual song duration)
        filter="[${stream_index}:a]atrim=0:$song_dur"

        # Add a fade-in for all songs except the very first one
        if [ $repeat -gt 0 ] || [ $i -gt 0 ]; then
            filter+=",afade=t=in:st=0:d=$XFADE_DUR"
        fi

        # Add a fade-out for all songs except the very last one in the last repeat
        if [ $repeat -lt $((num_repeats - 1)) ] || [ $i -lt $((num_songs - 1)) ]; then
            filter+=",afade=t=out:st=$((song_dur - SONG_FADEOUT_START)):d=$SONG_FADEOUT_START"
        fi
        
        # Add a delay
        if [ $cumulative_time -gt 0 ]; then
            filter+=",adelay=${cumulative_time}:all=1"
        fi

        filter_complex+="${filter}[song${stream_index}_r${repeat}];"
        mix_inputs+="[song${stream_index}_r${repeat}]"
        
        # Update cumulative time for next song (in milliseconds)
        cumulative_time=$(( cumulative_time + (song_dur - SONG_FADEOUT_START) * 1000 ))
    done
done

# Count total inputs for amix
total_inputs=$((num_songs * num_repeats))

# Mix all the song streams together
filter_complex+="${mix_inputs}amix=inputs=${total_inputs}:duration=longest:dropout_transition=0,atrim=0:$DURATION,afade=t=in:st=0:d=3,afade=t=out:st=$((DURATION - FADEOUT_DUR)):d=$FADEOUT_DUR[a];"

# Scale the video and set the pixel format
filter_complex+="[0:v]scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p[v]"

# Add the filter_complex to the ffmpeg arguments
ffmpeg_args+=(-filter_complex "$filter_complex")

# Map the final video and audio streams and set encoding options
ffmpeg_args+=(-map "[v]" -map "[a]" -c:v libx264 -c:a aac -b:a 192k -t "$DURATION" "$OUTPUT")

# --- Execute the ffmpeg command ---

# For debugging, you can uncomment the following line to see the full command
# echo "ffmpeg ${ffmpeg_args[*]}"

# Execute the command
ffmpeg "${ffmpeg_args[@]}"