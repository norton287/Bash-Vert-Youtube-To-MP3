#!/bin/bash

# Set directories
DOWNLOAD_DIR="/volumes/data/metube/downloads"
MUSIC_DIR="/music/music"
COMPLETED_DIR="/volumes/data/metube/downloads/completed"
LOG_DIR="/var/log/verter.log"

# Create log file if it doesn't exist
touch "$LOG_DIR"

# Open source utilities
FFMPEG="/usr/bin/ffmpeg"
MP3GAIN="/usr/bin/mp3gain"

# Check if FFMPEG and MP3GAIN are installed, if not, install them
install_utilities() {
  if ! command -v ffmpeg &> /dev/null; then
    echo "FFmpeg not found, installing..." >> "$LOG_DIR"
    sudo apt update && sudo apt install -y ffmpeg
    if [[ $? -ne 0 ]]; then
      echo "Error: Failed to install FFmpeg." >> "$LOG_DIR"
      exit 1
    fi
  fi

  if ! command -v mp3gain &> /dev/null; then
    echo "MP3Gain not found, installing..." >> "$LOG_DIR"
    sudo apt update && sudo apt install -y mp3gain
    if [[ $? -ne 0 ]]; then
      echo "Error: Failed to install MP3Gain." >> "$LOG_DIR"
      exit 1
    fi
  fi
}

# Install utilities if needed
install_utilities

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

  # Sanitize the MP3 filename
  local sanitized_name=$(sanitize_filename "$mp3_file")
  local sanitized_path=$(dirname "$mp3_file")/"$sanitized_name"

  # Rename the file to the sanitized version
  mv "$mp3_file" "$sanitized_path"
  
  echo "$sanitized_path"
}

# Enable nullglob to handle no matches gracefully
shopt -s nullglob

# Main script logic
for video_file in "$DOWNLOAD_DIR"/*.{mp4,webm}; do
  # Check if file is a video
  if [[ ! -f "$video_file" ]]; then
    continue
  fi

  echo "Processing $video_file..." >> "$LOG_DIR"

  # Convert video to MP3
  converted_file=$(convert_to_mp3 "$video_file") || continue
  
  # Move MP3 file to music directory
  if [[ -f "$converted_file" ]]; then
    mv -f "$converted_file" "$MUSIC_DIR"
  else
    echo "Error: Converted MP3 file not found for $video_file" >> "$LOG_DIR"
    continue
  fi

  # Move original video to completed directory
  mv -f "$video_file" "$COMPLETED_DIR"
done

echo "Done processing video files." >> "$LOG_DIR"
