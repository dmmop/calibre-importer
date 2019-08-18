#!/bin/bash


check_calibre_version(){
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
  if [ -z "$CALIBRE_LIBRARY_DIRECTORY" ]; then
    CALIBRE_LIBRARY_DIRECTORY=/opt/calibredb/library
  fi
  if [ -z "$CALIBRE_OUTPUT_EXTENSIONS" ]; then
    CALIBRE_OUTPUT_EXTENSIONS="epub mobi"
  fi
  if [ -z "$CALIBRE_IMPORT_DIRECTORY" ]; then
    CALIBRE_IMPORT_DIRECTORY=/opt/calibredb/import
  fi
  echo "Starting auto-importer process."
}

convert_books() {
  # Convert string to array
  CALIBRE_OUTPUT_EXTENSIONS=($(echo ${CALIBRE_OUTPUT_EXTENSIONS}))
  # Initialice extensions file
  for extension in "${CALIBRE_OUTPUT_EXTENSIONS[@]}";do touch "${extension}.tmp"; done

  # Detect extension files
  for book in ${CALIBRE_IMPORT_DIRECTORY}/*; do
    basename=${book##*/}
    file_name=${basename%.*}
    file_extension=${basename##*.}
    echo $file_name >> files.tmp
    echo $file_name >> "${file_extension}.tmp"
  done

  # Convert files to desired extensions
  for extension in "${CALIBRE_OUTPUT_EXTENSIONS[@]}"
  do
    echo "Convert to $extension:"
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
# Continuously watch for new content in the defined import directory.
while true
do
    if [ $(files_to_import) -gt 0 ]; then
      convert_books
      echo "Attempting import of $(files_to_import) new files/directories."
      /opt/calibre/calibredb add $CALIBRE_IMPORT_DIRECTORY -r --with-library $CALIBRE_LIBRARY_DIRECTORY && rm -rf $CALIBRE_IMPORT_DIRECTORY/*
    fi
#TODO: Make this a configurable variable
    echo "Wait..."
    sleep 1m
done
