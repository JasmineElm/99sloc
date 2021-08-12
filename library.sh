#!/usr/bin/env bash

set -u -e -o errtrace -o pipefail
trap "echo ""errexit: line $LINENO. Exit code: $?"" >&2" ERR
IFS=$' \n\t'

# Wrapper script containing generic functions used in other scripts.
# Source functions rather than run this script direct

###  VARIABLES    ##########################################

##!! VARIABLES SET HERE EFFECT _ALL SCRIPTS_

DEFAULT_FORMAT='wav'
BINARIES=()
###  FUNCTIONS    ##########################################

###################################################### SETUP

lib::binary_exists() {
  type "$1" &>/dev/null || echo "$1" not found, exiting...
}

lib::tidy() {
  rm -rf .tmp
}

lib::setup() {
  # each script has its' own $BINARIES array
  lib::tidy
  for i in "${BINARIES[@]}"; do
    lib::binary_exists "$i"
  done
  mkdir -p .tmp
}

######################################################## SOX

lib::is_valid_format() {
  # is our file format one that sox can handle?
  local formats
  local query
  local ret_val
  formats=$(sox --help | grep "AUDIO FILE FORMATS: ")
  query="$1"
  ret_val=false
  for format in $formats; do
    if [[ $format = "$query" ]]; then
      ret_val=true
    fi
  done
  echo "$ret_val"
}

lib::format_check() {
  #filename.ext - is it valid?
  # looks for anything after the '.'
  local filename
  filename=${1-}
  ext=${filename#*.}
  [[ $(lib::is_valid_format "$ext") = "true" ]] || filename="${filename%.$ext}.$DEFAULT_FORMAT"
  echo "$filename"
}

##################################################### RANDOM

lib::rand_int() {
  start=$1
  step=$2
  end=$3
  seq "$start" "$step" "$end" | shuf -n1
}

lib::rand_float() {
  printf '%.2f\n' "$(printf '0x0.%04xp1' $RANDOM)"
}

lib::cointoss() {
  local bias=${1:-0.5} #how biased is the coin?
  local flip
  flip=$(lib::rand_float)
  local outcome=false
  (($(echo "$flip < $bias" | bc -l))) || outcome=true
  echo "$outcome"
}

lib::rand_string() {
  local DEFAULT_LENGTH=12
  local LENGTH=${1:-$DEFAULT_LENGTH}
  local mode=${2:-a}
  case $mode in
    l) filter='"[:alpha:]"' ;;
    n) filter='"[:digit:]"' ;;
    g) filter='"[:graph:]"' ;;
    *) filter='"[:alnum:]"' ;;
  esac
  (tr -dc "$filter" </dev/urand_om || true) | head -c "$LENGTH"
}

lib::pseudo_word() {
  local length=${1:-8}
  local prefix
  prefix=$(shuf -n 1 ./resources/prefixes)
  local suffix
  suffix=$(shuf -n 1 ./resources/suffixes)
  local rand_str_len=$((length - (${#prefix} + ${#suffix})))
  [[ $rand_str_len -gt 1 ]] || rand_str_len=1
  local rand_string
  rand_string=$(lib::rand_string 1 1 $rand_str_len)
  echo "$prefix$rand_string$suffix"

}

#################################################### HELPERS

lib::dec_to_hex() {
  printf '%02x\n' "$1"
}
