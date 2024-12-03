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


# Clean up filename from unwanted characters
sanitize_filename() {
  echo "Normalizing MP3 Filename" >> "$LOG_DIR"
  # Extract the base name of the file
  local base_name=$(basename "$1")
  local sanitized_name=$(echo "$base_name" | tr -c '[:alnum:]._-' ' ')
  echo "Normalized MP3 Filename to: ${filename}" >> "$LOG_DIR"
  echo "$sanitized_name"
}


# Clean up the filename from unwanted characters
#sanitize_filename() {
#  local base_name=$(basename "$1")
#  local sanitized_name="${base_name//[^a-zA-Z0-9._-]/_}"
#  echo "Sanitized MP3 Filename: $sanitized_name" >> "$LOG_DIR"
#  echo "$sanitized_name"
#}

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

  # Sanitize the filename
  local sanitized_name=$(sanitize_filename "$mp3_file")
  local sanitized_path="$MUSIC_DIR/$sanitized_name"

  # Move the MP3 file to the music directory
  mv -f "$mp3_file" "$sanitized_path"
  echo "Moved MP3 to $sanitized_path" >> "$LOG_DIR"

  echo "$sanitized_path"  # Return the path for further use
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
  
  # Move original video to completed directory
  if [[ -f "$converted_file" ]]; then
    mv -f "$video_file" "$COMPLETED_DIR"
    echo "Moved video to $COMPLETED_DIR" >> "$LOG_DIR"
  else
    echo "Error: Converted MP3 not found for $video_file" >> "$LOG_DIR"
  fi
done

echo "Done processing video files." >> "$LOG_DIR"

