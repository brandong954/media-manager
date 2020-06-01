#!/bin/bash

SOURCE_DIRECTORY="$1"
PICTURES_BACKUP_DIRECTORY="${2:-./BACKUP/Pictures}"
VIDEOS_BACKUP_DIRECTORY="${3:-./BACKUP/Videso}"
SORTED_ROOT_DIRECTORY="./SORTED"
PICTURE_EXTENSIONS="jpg|jpeg|png|heic|gif|aae"
VIDEO_EXTENSIONS="mp4|m4v|mov"
EMPTY_DIRECTORIES=()
ALWAYS_MERGE_DIRECTORIES=false
ERRORS=false

shopt -s nullglob
shopt -s nocasematch
shopt -s dotglob

function print_warn () {
  echo -e "\n[WARN] - $1"
}

function print_error () {
  echo -e "\n[ERROR] - $1"
  ERRORS=true
}

function containsElement () {
  local e match="$1"
  shift

  for e
  do
    [[ "$e" == "$match" ]] && return 0
  done
  return 1
}

function remove_empty_directories () {
  if [ ${#EMPTY_DIRECTORIES[@]} -ne 0 ]; then
    echo -e "\n=============== REMOVING EMPTY DIRECTORIES ===============\n"

    for directory in "${EMPTY_DIRECTORIES[@]}"
    do
      if [ -d "$directory" ]; then
        # Don't let 'ds_store_file' prevent directory clean up
        local ds_store_file="${directory}/.DS_Store"
        if [ -f "$ds_store_file" ]; then
          rm "$ds_store_file"
        fi
        if [ -z "$(ls -A "$directory")" ]; then
          rm -r "$directory"
          if [ $? -eq 0 ]; then
            echo "Deleted empty directory: '$directory'"
          else
            ERRORS=true
          fi
        else
          directory_contents=$(ls -al "$directory")
          print_warn "Not Deleting '${directory}', not an empty directory:\n$directory_contents\n"
        fi
      fi
    done
    echo -e "\nDone removing empty directories!\n"
  fi
}

function prompt_to_merge_directories () {
  local directory="$1"
  local destination="$2"
  local merge=false

  if [ "$ALWAYS_MERGE_DIRECTORIES" = false ]; then
    PS3="Merge '${directory}' into '${destination}'?"
    local options=( "Yes" "No" "Always" )
    select options in "${options[@]}"
    do
      case $options in
        "Yes")
          merge=true
          break
          ;;
        "No")
          break
          ;;
        "Always")
          ALWAYS_MERGE_DIRECTORIES=true
          break
          ;;
        *)
          break
          ;;
      esac
    done
  fi

  if [ "$merge" = true ] || [ "$ALWAYS_MERGE_DIRECTORIES" = true ]; then
    local files=("$directory"/*)
    move_files "$destination" "${files[@]}"
  else
    echo "Not merging."
  fi
}

function move_file () {
  local file="$1"
  local destination="$2"

  output=$(mv "$file" "$destination" 2>&1)
  if [ $? -eq 0 ]; then
    echo "Moved '${file}' -> '${destination}/'"
  else
    echo $output | grep "Directory not empty"
    if [ $? -eq 0 ]; then
      if [ -d "$file" ]; then
        # Explicity define destination by appending the existing directory name
        # Imporant for recursion
        prompt_to_merge_directories "$file" "$destination/${file##*/}"
      else
        # TODO is file, prompt to overwrite or ignore
        echo $output
        ERRORS=true
      fi
    else
      echo $output
      ERRORS=true
    fi
  fi
}

function move_files () {
  local destination="$1"
  shift
  local files=("${@}")

  if [ ${#files[@]} -ne 0 ]; then
    if [ ! -d "$destination" ]; then
      mkdir -p "$destination"
    fi
    for file in "${files[@]}"
    do
      move_file "$file" "$destination"
    done
  fi
}

function sort_and_move_media_file () {
  local media_file="$1"
  local media_directory_path="$2"
  local media_directory_name="${media_directory_path##*/}"

  if [[ "$media_file" =~ .*\.($PICTURE_EXTENSIONS) ]]; then
    local destination="${SORTED_PICTURES_DIRECTORY}/${media_directory_name}"
  elif [[ "$media_file" =~ .*\.($VIDEO_EXTENSIONS) ]]; then
    local destination="${SORTED_VIDEOS_DIRECTORY}/${media_directory_name}"
  else
    echo "Media file '$media_file' not recognized. Skipping..."
    return
  fi
  if [ ! -d "$destination" ]; then
    mkdir -p "$destination"
  fi
  move_file "$media_file" "$destination" 
}

function sort_and_move_media_directory () {
  local media_directory="$1"
  local media_files=("$media_directory"/*)

  for media_file in "${media_files[@]}"
  do
    sort_and_move_media_file "$media_file" "$media_directory"
  done

  EMPTY_DIRECTORIES+=("$media_directory")
}

function sort_media () {
  local files=("$SOURCE_DIRECTORY"/*)

  if [ ${#files[@]} -ne 0 ]; then
    echo -e "\n=============== SORTING MEDIA ===============\n"
    for file in "${files[@]}"
    do
      if [[ -d "$file" ]]; then
        sort_and_move_media_directory "$file"
      elif [[ -f "$file" ]]; then
        sort_and_move_media_file "$file"
      else
        echo "$file is not a directory or file, skipping..."
        continue
      fi
    done
    EMPTY_DIRECTORIES+=("$SOURCE_DIRECTORY")
    echo -e "\nDone sorting media!\n"
  else
    echo -e "\nNo files to sort.\n"
    return 1
  fi
}

function determine_media_device_source () {
  local device_name_1="iPhone X"
  local device_name_2="iPhone 6S Plus"

  PS3='Which device did this media come from?'
  local device_names=( "$device_name_1" "$device_name_2" "Quit")
  select device in "${device_names[@]}"
  do
    case $device in
      "$device_name_1")
        MEDIA_DEVICE_SOURCE="$device_name_1"
        break
        ;;
      "$device_name_2")
        MEDIA_DEVICE_SOURCE="$device_name_2"
        break
        ;;
      "Quit")
        exit
        ;;
      *)
        echo "INVALID OPTION!"
        exit
        ;;
    esac
  done
  echo

  SORTED_MEDIA_DEVICE_DIRECTORY="${SORTED_ROOT_DIRECTORY}/${MEDIA_DEVICE_SOURCE}"
  SORTED_PICTURES_DIRECTORY="${SORTED_MEDIA_DEVICE_DIRECTORY}/Pictures"
  SORTED_VIDEOS_DIRECTORY="${SORTED_MEDIA_DEVICE_DIRECTORY}/Videos"
}

function determine_root_media_destination () {
  PS3='What kind of media is this?'
  local media_types=( "Pictures" "Videos" "Quit")
  select media_type in "${media_types[@]}"
  do
    case $media_type in
      "Pictures")
        echo "$PICTURES_BACKUP_DIRECTORY"
        break
        ;;
      "Videos")
        echo "$VIDEOS_BACKUP_DIRECTORY"
        break
        ;;
      "Quit")
        exit
        ;;
      *)
        echo "INVALID OPTION!"
        exit
        ;;
    esac
  done
  echo
}

function backup_media () {
  local media_source_directory="$1"
  local media_backup_directory="$2"
  local months=( "January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December" )
  local files=("$media_source_directory"/*)

  for file in "${files[@]}"
  do
    local moment_date=$(echo "$file" | grep -Eo "\w+ [[:digit:]]{2}, [[:digit:]]{4}")

    if [[ -z "${moment_date// }" ]]; then
      moment_date=$(echo "$file" | grep -Eo "\w+ [[:digit:]]{1}, [[:digit:]]{4}")
    fi

    if [[ -z "${moment_date// }" ]]; then
      print_warn "$file does not have a valid moment date in its filename. Skipping...\n"
      continue
    fi

    # The awk since \w+ considers all character segments as words based on space delimiters
    local month=$(echo "$moment_date" | grep -Eo "\w+" | awk '{ if (NR==1) print $0 }' | tr -d '\n')
    if [[ -z "${month// }" ]] || ! containsElement "$month" "${months[@]}"; then
      print_warn "$file does not have a valid month in its filename. Skipping...\n"
      continue
    fi

    local year=$(echo "$moment_date" | grep -Eo "[[:digit:]]{4}" | tr -d '\n')
    if [[ -z "${year// }" ]]; then
      print_warn "$file does not have a valid year in its filename. Skipping...\n"
      continue
    fi

    local destination="${media_backup_directory}/${year}/${month}/${MEDIA_DEVICE_SOURCE}"
    local monthly_files=( "$file" )
    move_files "$destination" "${monthly_files[@]}"
  done

  EMPTY_DIRECTORIES+=("$media_source_directory")
}

function intro_prompt () {
  determine_media_device_source

  PS3='What would you like to do?'
  local options=( "Sort and Backup Media" "Sort Media" "Backup Media" "Quit" )
  select option in "${options[@]}"
  do
    case $option in
      "Sort and Backup Media")
        if sort_media; then
          echo -e "\n=============== BACKING UP PICTURES ===============\n"
          backup_media "$SORTED_PICTURES_DIRECTORY" "$PICTURES_BACKUP_DIRECTORY"
          echo -e "\n=============== BACKING UP VIDEOS ===============\n"
          backup_media "$SORTED_VIDEOS_DIRECTORY" "$VIDEOS_BACKUP_DIRECTORY"
          EMPTY_DIRECTORIES+=("$SORTED_MEDIA_DEVICE_DIRECTORY" "$SORTED_ROOT_DIRECTORY")
          if [ "$ERRORS" = false ]; then
            echo -e "\nDone backing up media!\n"
          else
            echo -e "\nDONE BACKING UP MEDIA WITH ERRORS!\n"
          fi
        fi
        break
        ;;
      "Sort Media")
        sort_media
        break
        ;;
      "Backup Media")
        backup_media "$SOURCE_DIRECTORY" "$(determine_root_media_destination)"
        break
        ;;
      "Quit")
        exit
        ;;
      *)
        echo "INVALID OPTION!"
        exit
        ;;
    esac
  done
}

function main () {
  if [ -z "$SOURCE_DIRECTORY" ]; then
    echo "'SOURCE_DIRECTORY' not supplied."
    exit
  fi

  cat << EndOfMessage

######################### MEDIA MANAGER ##########################

 This script will be ran with the following arguments:

   SOURCE DIRECTORY: '${SOURCE_DIRECTORY}'
   PICTURES BACKUP DIRECTORY: '${PICTURES_BACKUP_DIRECTORY}'
   VIDEOS BACKUP DIRECTORY: '${VIDEOS_BACKUP_DIRECTORY}'

##################################################################

EndOfMessage

  intro_prompt
  remove_empty_directories
}

main
