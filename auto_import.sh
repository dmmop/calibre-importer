#!/bin/bash

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


check_env_vars() {
    # Make sure our environment variables are in place, just in case.
    [ -z "$CALIBRE_LIBRARY_DIRECTORY" ] && CALIBRE_LIBRARY_DIRECTORY="/opt/calibredb/library"
    # Extensions want to be available
    [ -z "$CALIBRE_OUTPUT_EXTENSIONS" ] && CALIBRE_OUTPUT_EXTENSIONS="mobi epub"
    CALIBRE_OUTPUT_EXTENSIONS=($(echo ${CALIBRE_OUTPUT_EXTENSIONS}))
    # Staging area
    [ -z "$CALIBRE_IMPORT_DIRECTORY" ] && CALIBRE_IMPORT_DIRECTORY="/opt/calibredb/import"
    # Staging area for proccessing books
    [ -z "$SCRIPT_PROCESSING_DIRECTORY" ] && SCRIPT_PROCESSING_DIRECTORY="${CALIBRE_IMPORT_DIRECTORY}/in_progress"
    # Delay between File Watch
    if [ -z "$DELAY_TIME" ];then
        DELAY_TIME="1m"
    fi    
}



move_files_to_process() {
    # List whole files
    for book in ${CALIBRE_IMPORT_DIRECTORY}/*; do
        # Exclude directories if founded
        if [ -d "${book}" ]; then continue; fi
        basename="${book##*/}" # Extract basename
        file_name="${basename%.*}" # Extract name without extension
        echo "$file_name" >> files.tmp # List all files
    done

    # Remove duplicate list of files
    awk '!a[$0]++' files.tmp > filesUnique.tmp

    # Move all books to their directories
    while read -r ebook
    do
        mkdir -p "${SCRIPT_PROCESSING_DIRECTORY}/${ebook}"
        cp "${CALIBRE_IMPORT_DIRECTORY}/${ebook}."* "${SCRIPT_PROCESSING_DIRECTORY}/${ebook}"
    done < filesUnique.tmp

    rm -r filesUnique.tmp files.tmp
}

ebook_convert(){
    ebook_folder=$1
    file_name=$(basename "${ebook_folder}") # Extract name without extensionfile_name
    echo "Processing: ${file_name}"

    # Extract missing extensions
    for book in "${book_folder}"*; do
        basename=${book##*/} # Extract full filename
        file_name=${basename%.*} # Extract name without extension 
        file_extension=${basename##*.} # Extract extension
        echo ${file_extension} >> "${file_name}.tmp"
    done
    missing_extensions=($(grep -Fvf "${file_name}.tmp" target_extensions.tmp))
    # Convert book to missing extensions
    for extension in ${missing_extensions[@]}; do
        echo "Converting \"${file_name}\" to ${extension}"
        /opt/calibre/ebook-convert "${ebook_folder}/${file_name}."* "${ebook_folder}/${file_name}.${extension}" >/dev/null 2>&1 &
    done

    wait # Wait to convert all files
    echo "Importing: ${file_name}"
    /opt/calibre/calibredb add -r --one-book-per-directory "${ebook_folder}" --with-library="$CALIBRE_LIBRARY_DIRECTORY" && rm -rf "${ebook_folder}"

    rm -r "${file_name}.tmp"
}

process_ebooks() {
    # Extract target extensions
    echo "Output extensions:" ${CALIBRE_OUTPUT_EXTENSIONS[@]}
    for extension in ${CALIBRE_OUTPUT_EXTENSIONS[@]};do echo ${extension} >> target_extensions.tmp; done
    move_files_to_process

    # Iterate over all book folder
    for book_folder in ${SCRIPT_PROCESSING_DIRECTORY}/*/ ; do
        ebook_convert "${book_folder}"
    done
    rm -r *.tmp
    rm -r "${SCRIPT_PROCESSING_DIRECTORY}"
}

files_to_import(){
    echo `find $CALIBRE_IMPORT_DIRECTORY -mindepth 1 -maxdepth 1 -not -type d| wc -l`
}

check_calibre_version
check_env_vars
echo "Starting auto-import process."
# Continuously watch for new content in the defined import directory.
while true
do
    if [ $(files_to_import) -gt 0 ]; then
        # If there are fails, then try to convert
        process_ebooks
    else
        sleep ${DELAY_TIME}
    fi
    sleep "10s"
done
