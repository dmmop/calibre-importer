#!/bin/bash
set -e

# Make sure our environment variables are in place, just in case.
echo "Check environment vars"
[ -z "$CALIBRE_LIBRARY_DIRECTORY" ] && CALIBRE_LIBRARY_DIRECTORY=/opt/calibredb/library
[ -z "$CALIBRE_OUTPUT_EXTENSIONS" ] && CALIBRE_OUTPUT_EXTENSIONS="epub mobi"

# Extract information from calibredb command line.
echo "Extracting calibre database information..."
/opt/calibre/calibredb list --with-library="${CALIBRE_LIBRARY_DIRECTORY}" --fields formats --for-machine > calibre_list.tmp
echo "Calibre information extracted."

#
# Extract an array of extensions
#
extract_extensions() {
  local book_info_json=$1
  local -p extensions
  while read format_path;
  do
    format_path=${format_path%?} # Remove last quote
    format_path=${format_path#?} # Remove first quote
    file_extension=${format_path##*.} # extract extension
    extensions+=("$file_extension")
  done <<<$(echo "$book_info_json" | jq -c -M '.formats[]')
  echo "${extensions[@]}"
}

# TODO: Add progress bar
n_books=$(jq -c -M '. | length' calibre_list.tmp)
while read book_info_json;
do
  book_id=$(echo "$book_info_json" | jq -c -M '.id') # Extract calibre book_id
  echo -ne "${book_id}//${n_books}\r"
  extensions=($(extract_extensions "${book_info_json}")) # List of formats
  declare -a a
  a=($(echo ${CALIBRE_OUTPUT_EXTENSIONS})) # Array of extensions wanted
  # Extract the missing extensions
  missing_formats=($(grep -Fvxf  <(printf '%s\n' "${extensions[@]}" | LC_ALL=C sort) <(printf '%s\n' "${a[@]}" | LC_ALL=C sort) | tr "\n" " " | sed 's/.$//'))

  for miss_format in ${missing_formats[*]}
  do
    # Path of original book in calibre library
    source_book=$(echo $book_info_json | jq -c -M '.formats[0] // empty')
    [ -z "$source_book" ] && continue
    echo "Convert ${source_book##*/} to ${miss_format}"
    # Convert book to desired format
    eval /opt/calibre/ebook-convert "$source_book" "/tmp/book.${miss_format}"
    echo "Adding ${source_book##*/} in ${miss_format}"
    # Import the new format to calibre library
    /opt/calibre/calibredb add_format --with-library="${CALIBRE_LIBRARY_DIRECTORY}" ${book_id} "/tmp/book.${miss_format}" && rm "/tmp/book.${miss_format}"
  done

done <<<$(jq -c -M '.[]' calibre_list.tmp)

echo "Finished!"
