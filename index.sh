#!/bin/bash

# Create timestamped output folder
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="Rendered/Anolog-2/output_${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"

# Input values
BG_VIDEO="Backgrounds/Anolog-2.mp4"
SONG_DIR="songs/Anolog-2"
OUTPUT="${OUTPUT_DIR}/output.mp4"
# DURATION=400      # 60 minutes (seconds) #!test
DURATION=3600      # 60 minutes (seconds)
FADEOUT_START=410   # fade out starts 10 seconds before end
FADEOUT_DUR=10      # fade-out duration
XFADE_DUR=3         # crossfade overlap duration (seconds)
SONG_FADEOUT_START=5 # start fading out this many seconds before song ends (should be >= XFADE_DUR)
VOLUME_BOOST=1.75    # Volume multiplier (1.0 = no change, 2.0 = double volume)

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
num_songs=${#SONGS[@]}

# Build the crossfade chain - each song crossfades with the next using acrossfade filter
# First, prepare all songs with volume boost
for repeat in $(seq 0 $((num_repeats - 1))); do
    for i in "${!SONGS[@]}"; do
        stream_index=$((i + 1))
        song_dur=${SONG_DURATIONS[$i]}
        
        filter_complex+="[${stream_index}:a]volume=${VOLUME_BOOST},aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo[a${stream_index}_r${repeat}];"
    done
done

# Now chain crossfades together
# Start with the first song
previous_label="a1_r0"
crossfade_label=""

segment_count=0
for repeat in $(seq 0 $((num_repeats - 1))); do
    for i in "${!SONGS[@]}"; do
        stream_index=$((i + 1))
        song_dur=${SONG_DURATIONS[$i]}
        
        # Skip the very first song as it's already our starting point
        if [ $segment_count -eq 0 ]; then
            segment_count=$((segment_count + 1))
            continue
        fi
        
        current_input="a${stream_index}_r${repeat}"
        crossfade_label="xf${segment_count}"
        
        # Use acrossfade to create overlapping crossfade - both inputs before the filter
        filter_complex+="[${previous_label}][${current_input}]acrossfade=d=${SONG_FADEOUT_START}:c1=tri:c2=tri[${crossfade_label}];"
        previous_label="$crossfade_label"
        
        segment_count=$((segment_count + 1))
    done
done

# Trim to final duration and add final fades
filter_complex+="[${previous_label}]atrim=0:$DURATION,afade=t=in:st=0:d=3,afade=t=out:st=$((DURATION - FADEOUT_DUR)):d=$FADEOUT_DUR[a];"

# Scale the video and set the pixel format
filter_complex+="[0:v]scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p[v]"

# Add the filter_complex to the ffmpeg arguments
ffmpeg_args+=(-filter_complex "$filter_complex")

# Map the final video and audio streams and set encoding options
ffmpeg_args+=(-map "[v]" -map "[a]" -c:v libx264 -c:a aac -b:a 192k -t "$DURATION" "$OUTPUT")

# --- Execute the ffmpeg command ---

# For debugging, uncomment the following line to see the full command
echo "ffmpeg ${ffmpeg_args[*]}" > "${OUTPUT_DIR}/ffmpeg_command.txt"
echo "Filter complex saved to ${OUTPUT_DIR}/filter_complex.txt"
echo "$filter_complex" > "${OUTPUT_DIR}/filter_complex.txt"

# Execute the command
ffmpeg "${ffmpeg_args[@]}"