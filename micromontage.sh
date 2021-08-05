#!/usr/bin/env bash

set  -u -e -o errtrace -o pipefail
trap "echo ""errexit: line $LINENO. Exit code: $?"" >&2" ERR
IFS=$'\n\t'  

source library.sh # library functions
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
  seq "$start" "$step" "$end" | shuf -n1
}

_max_grain_length() {
  # Max grain len can't be > than the length of infile
  local input_length=$2; local grain_length=$1
  [[ $(echo "$grain_length < $input_length" | bc) -eq 1 ]] ||
    grain_length=$(echo "$input_length * .9" | bc)
  echo "$grain_length"
}

_grain_length() {
  _rand $_min_grain_len $_resolution $_max_grain_len 
}


_file_len_in_ms() {
  soxi -D "$1"
}

_grain_start() {
  #file_len=$1; grain_len=$2
  _rand $_resolution $_resolution "$(echo "scale=3; $1 - $2" | bc)"
}

###  MAIN         ###########################################
_setup

# Parse arguments
# arg 1 = file, must exist
if [[ -f "${1-}" ]]; then
  inFile="$1"
  inLen=$(_file_len_in_ms "$inFile")
  _max_grain_len=$(_max_grain_length $_max_grain_len "$inLen")
else
  _print_help && exit 1
fi
## arg 2 = output file, must be format that sox can handle
outFile=${2:-$_defaultOutput}         # value passed, or default
outFile=$(_format_check "$outFile")   # with an ext that sox can parse
# arg 3 = duration in seconds  must be an int, or $_defaultDuration
[[ "${3-}" =~ ^[0-9]+$ ]] && duration=$3 || duration="$_defaultDuration"

while (($(echo "$_current_duration < $duration" | bc -l))); do
  tmp_file=".tmp/$_slice.wav"
  trim_length=$(_grain_length)
  trim_start=$(_grain_start "$inLen" "$trim_length")
  sox "$inFile" "$tmp_file" trim "$trim_start" "$trim_length"
  _slice=$((_slice+1))
  _current_duration=$(echo "scale=3; $_current_duration + $trim_length" | bc)
done

sox .tmp/*.wav "$outFile" && _tidy
