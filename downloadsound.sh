#!/usr/bin/env bash

set  -u -e -o errtrace -o pipefail
trap "echo ""errexit: line $LINENO. Exit code: $?"" >&2" ERR
IFS=$'\n\t'  

###  VARIABLES    ###########################################

_ME="$(basename "${0}")"          # this script
_defaultOutput="output.wav"       # name of the output
_binaries=( youtube-dl )     # binaries required
_max_len_mins=5                   # don't download anything longer than 

###  FUNCTIONS    ###########################################

_print_help() {
cat <<HEREDOC
Simply download the audio from a given youtube video.
pass no arguments, and get a random audio

Usage:
${_ME} [<video url>] [<output file>]
HEREDOC
}

_random_word() {
#random word for youtube search 
shuf -n 1 /usr/share/dict/words
}

_get_vid_url() {
# search YT using our search term
youtube-dl ytsearch:\""$1"\" --get-id
}

_get_vid_len() {
#get the video length
local length
length=$(youtube-dl "$1" --get-duration)
# convert from HH:MM:SS to a simple MM int
colon_count=$(awk -F: '{print NF-1}' <<<"$length")
if [[ "$colon_count" -ne 1 ]]; then #we have HH in there
  length="hours"
else
  length=$($length | cut -d: -f1) #pattern to remove ":SS"
fi
echo "$length"
}

_is_too_long() {
  local in_len; local max_len; local ret_val
  in_len=$1; max_len=$2; ret_val=false
  if [[ "$in_len" = "hours" ]] && [[ $in_len > $max_len ]]; then
    ret_val=true
  fi
  echo "$ret_val"
}

_get_random_url(){
  local url; local search_term; local len; local too_long;
  too_long="true"  
  while [[ "$too_long" = "true" ]]; do
    search_term=$(_random_word)
    url=$(_get_vid_url "$search_term")
    len=$(_get_vid_len "$url")
    too_long=$(_is_too_long "$len" "$_max_len_mins")
  done
  echo "$url"
}

###  MAIN         ###########################################
source ./library.sh

_setup
# Parse arguments
[[ -z ${1-} ]] && url="$(_get_random_url)" || url="$1" 
[[ -n ${2-} ]] && outFile="$2" || outFile="$_defaultOutput"

echo "$url" "$outFile"
youtube-dl "$url" --extract-audio --audio-format wav --output "$outFile"
