#!/bin/bash
set -e
check_calibre_version(){
  echo "dmmop/calibre-importer version: $(cat VERSION)"
  # Perform a software update, if requested
  my_version=`/opt/calibre/calibre --version | awk -F'[() ]' '{print $4}'`
  if [ ! "$AUTO_UPDATE" = "1" ]; then
    echo "AUTO_UPDATE not requested, keeping installed version of $my_version."
  else
    echo "AUTO_UPDATE requested, checking for latest version..."
    latest_version=`wget -q -O- https://raw.githubusercontent.com/kovidgoyal/calibre/master/Changelog.yaml | grep -m 1 "^- version:" | awk '{print $3}'`
    if [ "$my_version" != "$latest_version" ]
    then
      echo "Updating from $my_version to $latest_version."
      wget -O- https://raw.githubusercontent.com/kovidgoyal/calibre/master/setup/linux-installer.py | python -c "import sys; main=lambda:sys.stderr.write('Download failed\n'); exec(sys.stdin.read()); main(install_dir='/opt', isolated=True)"
      rm -rf /tmp/calibre-installer-cache
    else
      echo "Installed version of $my_version is the latest."
    fi
  fi
}


check_env_vars(){
  # Make sure our environment variables are in place, just in case.
  [ -z "$CALIBRE_LIBRARY_DIRECTORY" ] && CALIBRE_LIBRARY_DIRECTORY=/opt/calibredb/library
  # Extensions want to be available
  [ -z "$CALIBRE_OUTPUT_EXTENSIONS" ] && CALIBRE_OUTPUT_EXTENSIONS="epub mobi"
  # Staging area
  [ -z "$CALIBRE_IMPORT_DIRECTORY" ] && CALIBRE_IMPORT_DIRECTORY=/opt/calibredb/import
  # Delay between File Watch
  [ -z "$DELAY_TIME" ] && DELAY_TIME="1m"
}
echoerr() { echo "$@" 1>&2; }

convert_books() {
  # Convert string to array
  CALIBRE_OUTPUT_EXTENSIONS=($(echo ${CALIBRE_OUTPUT_EXTENSIONS}))
  # Initialice extensions file
  for extension in "${CALIBRE_OUTPUT_EXTENSIONS[@]}";do touch "${extension}.tmp"; done

  # Detect extension files
  for book in ${CALIBRE_IMPORT_DIRECTORY}/*; do
    basename="${book##*/}" # Extract basename
    file_name="${basename%.*}" # Extract name without extension
    file_extension=${basename##*.} # extract extension
    echo "$file_name" >> files.tmp # List all files
    echo "$file_name" >> "${file_extension}.tmp" # List file by extension
  done

  # Convert files to desired extensions
  for extension in "${CALIBRE_OUTPUT_EXTENSIONS[@]}"
  do
    echo "Convert $basename to $extension:"
    while read -r file
    do
      /opt/calibre/ebook-convert "${CALIBRE_IMPORT_DIRECTORY}/${file}."* "${CALIBRE_IMPORT_DIRECTORY}/${file}.${extension}"
    done < <(grep -Fvf "${extension}.tmp" files.tmp)
  done

  # Remove temps files
  rm -r *.tmp
}

files_to_import(){
  echo `find $CALIBRE_IMPORT_DIRECTORY -mindepth 1 -maxdepth 1 | wc -l`
}
check_calibre_version
check_env_vars
echo "Starting auto-importer process."
# Continuously watch for new content in the defined import directory.
while true
do
    if [ $(files_to_import) -gt 0 ]; then
      # If there are fails, then try to convert
      convert_books
      # If convert files, retry
      if (( $(files_to_import) % "${#CALIBRE_OUTPUT_EXTENSIONS[@]}" )); then
        continue
      else
        echo "Attempting import of $(files_to_import) new files:"
        # List books to add
        for i in "$(ls $CALIBRE_IMPORT_DIRECTORY)"; do echo -e "\t${i}"; done
        # Add books to calibre library
        /opt/calibre/calibredb add $CALIBRE_IMPORT_DIRECTORY -r --with-library="$CALIBRE_LIBRARY_DIRECTORY" && rm -rf $CALIBRE_IMPORT_DIRECTORY/*

      fi
    fi
    sleep ${DELAY_TIME}
done
