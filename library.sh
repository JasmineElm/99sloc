#!/usr/bin/env bash

set -u -e -o errtrace -o pipefail
trap "echo ""errexit: line $LINENO. Exit code: $?"" >&2" ERR
IFS=$' \n\t'


# Wrapper script containing generic functions used in other scripts.
# Source functions rather than run this script direct


###  VARIABLES    ###########################################

##!! VARIABLES SET HERE EFFECT _ALL SCRIPTS_

_default_format='wav'
_binaries=()
###  FUNCTIONS    ###########################################
_binary_exists() {
  type "$1" &> /dev/null ||  echo "$1" not found, exiting... 
}

_tidy() {
  rm -rf .tmp
}

_rand_int() {
  start=$1; step=$2; end=$3
  seq "$start" "$step" "$end" | shuf -n1
}

_setup() {
  # each script has its' own $_binaries array
  _tidy
  for i in "${_binaries[@]}"; do
    _binary_exists "$i"
  done
  mkdir -p .tmp
}

_is_valid_format() {
  # is our file format one that sox can handle?
  local formats; local query; local ret_val
  formats=$(sox --help | grep "AUDIO FILE FORMATS: ")
  query="$1"; ret_val=false
  for format in $formats; do
    if [[ $format = "$query" ]]; then 
      ret_val=true
    fi
  done
  echo "$ret_val"
}

_format_check(){
  #filename.ext - is it valid?
  # looks for anything after the '.' 
  local filename
  filename=${1-}
  ext=${filename#*.}
  [[ $(_is_valid_format "$ext") = "true" ]] || filename="${filename%.$ext}.$_default_format"
 echo "$filename"
} 

_rand_float(){
  printf '%.2f\n' "$(printf '0x0.%04xp1' $RANDOM)"
}

_rand_string(){
    local DEFAULT_LENGTH=12;
    local LENGTH=${1:-$DEFAULT_LENGTH};
    (tr -dc "[:alnum:]" < /dev/urandom || true) | head -c "$LENGTH" 
}

_dec_to_hex() {
  printf '%02x\n' "$1"
}

