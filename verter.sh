#!/bin/bash

# Set directories
DOWNLOAD_DIR="/volumes/data/metube/downloads"
MUSIC_DIR="/path/to/your/mp3/streamer/library"
COMPLETED_DIR="/volumes/data/metube/downloads/completed"
LOG_DIR="/var/log/verter.log"

# Create log file if it doesn't exist
touch "$LOG_DIR"

# Open source utilities
FFMPEG="/usr/bin/ffmpeg"  # Replace with actual path if needed
MP3GAIN="/usr/bin/mp3gain"  # Replace with actual path if needed

# Clean up the crap from YouTube
sanitize_filename() {
  local base_name=$(basename "$1")
  local sanitized_name="${base_name//[^a-zA-Z0-9._-]/_}"
  echo "Normalized MP3 Filename to: $sanitized_name" >> "$LOG_DIR"
  echo "$sanitized_name"
}

# Convert the Video to MP3
convert_to_mp3() {
  local video_file="$1"
  local mp3_file="${video_file%.*}.mp3"

  # Extract audio and convert to MP3
  if ! $FFMPEG -i "$video_file" -vn -acodec libmp3lame -b:a 320k "$mp3_file"; then
    echo "Error: Conversion failed for $video_file" >> "$LOG_DIR"
    return 1
  fi

  # Normalize audio volume
  if ! yes | $MP3GAIN -r "$mp3_file"; then
    echo "Warning: Normalization failed for $mp3_file" >> "$LOG_DIR"
  fi

  echo "Converted MP3 is: $mp3_file" >> "$LOG_DIR"
  echo "$sanitized_file"
}

# Main script logic
for video_file in "$DOWNLOAD_DIR"/*.{mp4,webm}; do
  # Check if file is a video
  if [[ ! -f "$video_file" ]]; then
    continue
  fi

  echo "Processing $video_file..."

  # Convert video to MP3
  converted_file=$(convert_to_mp3 "$video_file") || continue
  
  # Move MP3 file to music directory
  mv -f "$converted_file" "$MUSIC_DIR"

  # Move original video to completed directory
  mv -f "$video_file" "$COMPLETED_DIR"
done

echo "Done processing video files."
