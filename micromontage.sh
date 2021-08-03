#!/usr/bin/env bash

set  -u -e -o errtrace -o pipefail
trap "echo ""errexit: line $LINENO. Exit code: $?"" >&2" ERR
IFS=$'\n\t'  
###  VARIABLES    ###########################################

_ME="$(basename "${0}")"          # this script
_defaultOutput="output.wav"       # name of the output
_defaultDuration=6                # how long will the time be?
_binaries=( soxi shuf bc )        # binaries required
_resolution=0.001                 # time precision
_slice=0                          # used in while loop
_current_duration=0               # used in while loop
_min_grain_len=0.001              # mininum grain length
_max_grain_len=0.05                # maximum grain length 
###  FUNCTIONS    ###########################################

_print_help() {
  cat <<HEREDOC
stitch a soundfile together in a different way

Usage:
  ${_ME} <input file> [<length in seconds>] [<output file>]
HEREDOC
}

_rand() {
  start=$1; step=$2; end=$3
  seq $start $step $end | shuf -n1
}

_max_grain_length() {
  # Max grain len can't be > than the length of infile
  local input_length=$2; local grain_length=$1
  [[ $(echo "$grain_length < $input_length" | bc) -eq 1 ]] ||
    grain_length=$(echo "$input_length * .9" | bc)
  echo $grain_length
}

_grain_length() {
  _rand $_min_grain_len $_resolution $_max_grain_len 
}

_tidy() {
  rm -rf .tmp
}

_binary_exists() { 
  if type "$1" &> /dev/null; then
  echo "$1" found
  else
  echo "$1" not found, exiting... && exit 1
  fi
}

_setup() {
  _tidy
  for i in "${_binaries[@]}"; do
    _binary_exists "$i"
  done
  mkdir -p .tmp
}

_file_len_in_ms() {
  soxi -D $1
}

_grain_start() {
  #file_len=$1; grain_len=$2
  _rand $_resolution $_resolution $(echo "scale=3; $1 - $2" | bc)
}

###  MAIN         ###########################################
_setup
##test switches passed
if [[ -f "${1-}" ]]; then
  inFile="$1"
  inLen=$(_file_len_in_ms "$inFile")
  _max_grain_len=$(_max_grain_length $_max_grain_len $inLen)
  echo $_max_grain_len $inLen
else
  _print_help && exit 1
fi
# really should check the file has an ext that sox can handle
[[ -n "${2-}" ]] && outFile=$2 || outFile="$_defaultOutput"
# option3 must be an int; anything else, use the default duration
[[ "${3-}" =~ ^[0-9]+$ ]] && duration=$3 || duration="$_defaultDuration"

while (($(echo "$_current_duration < $duration" | bc -l))); do
  tmp_file=".tmp/$_slice.wav"
  trim_length=$(_grain_length)
  echo "trim_length="$trim_length ";inLen="$inLen
  trim_start=$(_grain_start "$inLen" "$trim_length")
  echo "sox" "$inFile" "$tmp_file" "start" "$trim_start" "len:""$trim_length"
  sox "$inFile" "$tmp_file" trim "$trim_start" "$trim_length"
  # echo -e "_slice:\t$_slice\tduration:\t$_current_duration"
  _slice=$((_slice+1))
  _current_duration=$(echo "scale=3; $_current_duration + $trim_length" | bc)
done

sox .tmp/*.wav output.wav && _tidy
