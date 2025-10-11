# The primary goal of this script.
- Compile multiple songs into a single audio clip overlayed on an mp4, output as an mp4. This output mp4 will be manually uploaded youtube
- The code will be written to `index.sh

## Requirments

- The duration of the mp4 will be hard coded by me
- The script will read from the folder ./songs to grab the audio files
- The script will determine the length of each song so that it can properly perform a cross fade at the end of each song.
- The output mp4 audio will start with a fade in, 3 seconds will work. There will be a 10 second fade out
- The crossfade will take place over 3 seconds. During the last 5 sec of a song, the next song will begin playing. The current song will fade out, the next song will fade in. (THIS IS WHY THE SONG DURATIONS ARE NEEDED)
- The background.mp4 will loop for as long as the video lasts. If ffmpeg can do this, the video should fade out with the song, 10 seconds before the end of the song

## Success
The script is a success if there is an output mp4 file that plays multiple different tracks in a single audio track, with a looped video. Each song seemlessly flows into the next via a crossfade where the end of a current song (as it fades out) and the begining of the next song (as it fades in), will overlap and be playing at the same time. The video ends with the audio gently fading out over 10 seconds, and if possible, the video fading into black as well.

# IMPORTANT
**The cross fade needs to have both songs playing at the same time for ONLY the last 3 seconds of the current song. This means that at the last 3 seconds of the current song, the next song should start playing with a 3 second fade in** 