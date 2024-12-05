#!/bin/bash

# Set directories
DOWNLOAD_DIR="/volumes/data/metube/downloads"
MUSIC_DIR="/music/music"
COMPLETED_DIR="/volumes/data/metube/downloads/completed"
LOG_DIR="/var/log/spindlecrank/verter.log"

# Create log file if it doesn't exist
touch "$LOG_DIR"

# Open source utilities
FFMPEG="/usr/bin/ffmpeg"
MP3GAIN="/usr/bin/mp3gain"
RETURN_NAME=""

# Check if FFMPEG and MP3GAIN are installed, if not, install them
install_utilities() {
  if ! command -v ffmpeg &> /dev/null; then
    echo "FFmpeg not found, installing..." >> "$LOG_DIR"
    sudo apt update && sudo apt install -y ffmpeg
  fi

  if ! command -v mp3gain &> /dev/null; then
    echo "MP3Gain not found, installing..." >> "$LOG_DIR"
    sudo apt update && sudo apt install -y mp3gain
  fi
}

# Install utilities if needed
install_utilities

# Clean up filename from unwanted characters
sanitize_filename() {
  echo "Normalizing MP3 Filename" >> "$LOG_DIR"
  # Extract the base name of the file
  local base_name=$(basename "$1")
  echo "base_name: '$base_name'" >> "$LOG_DIR" # Debug line

  # Trim leading/trailing whitespace from the base_name
  local trimmed_name=$(echo "$base_name" | xargs)
  echo "trimmed_name: '$trimmed_name'" >> "$LOG_DIR" # Debug line

  # Use sed to remove any non-alphanumeric characters from the end
  local sanitized_name=$(echo "$trimmed_name" | sed 's/[^[:alnum:]._-]*$//') 
  echo "sanitized_name: '$sanitized_name'" >> "$LOG_DIR" # Debug line

  # Remove any duplicate spaces
  sanitized_name=$(echo "$sanitized_name" | tr -s ' ')
  echo "sanitized_name after tr -s: '$sanitized_name'" >> "$LOG_DIR" # Debug line

  echo "Normalized MP3 Filename to: ${sanitized_name}" >> "$LOG_DIR"
  echo "$sanitized_name"
}

# Convert the Video to MP3
convert_to_mp3() {
  local video_file="$1"
  local mp3_file="${video_file%.*}.mp3"

  # Extract audio and convert to MP3
  if ! $FFMPEG -i "$video_file" -vn -acodec libmp3lame -b:a 320k "$mp3_file";
  then
    echo "Error: Conversion failed for $video_file" >> "$LOG_DIR"
    RETURN_NAME=""
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

  if [[ -z "$sanitized_path" ]]; 
  	then
    	echo "Error: Conversion failed for $video_file" >> "$LOG_DIR"
        RETURN_NAME=""
    	return 1
    else
    	RETURN_NAME="$sanitized_path"
  fi
}

# Enable nullglob to handle no matches gracefully
shopt -s nullglob

# Main script logic
for video_file in "$DOWNLOAD_DIR"/*.{mp4,webm};
do
  # Check if file is a video
  if [[ ! -f "$video_file" ]];
  then
    continue
  fi

  echo "Processing $video_file..." >> "$LOG_DIR"

  # Convert video to MP3
  convert_to_mp3 "$video_file" 

  # Check if conversion was successful
  if [[ -z "$RETURN_NAME" ]]; then
    echo "Error: Conversion failed for $video_file" >> "$LOG_DIR"
    continue
  fi

  echo "Converted output was: ${RETURN_NAME}" >> "$LOG_DIR"

  # Move original video to completed directory after successful MP3 conversion
  if [[ -f "$RETURN_NAME" ]];
  then
    mv -f "$video_file" "$COMPLETED_DIR/"
    if [[ $? -eq 0 ]];
    then
      echo "Moved video to $COMPLETED_DIR" >> "$LOG_DIR"
    else
      echo "Error: Failed to move $video_file to $COMPLETED_DIR" >> "$LOG_DIR"
    fi
  else
    echo "Error: Converted MP3 not found for $video_file" >> "$LOG_DIR"
  fi
done

echo "Done processing video files." >> "$LOG_DIR"
