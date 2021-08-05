#!/usr/bin/env bash

set -u -e -o errtrace -o pipefail
trap "echo ""errexit: line $LINENO. Exit code: $?"" >&2" ERR
IFS=$'\n\t'

###  VARIABLES    ###########################################


###  FUNCTIONS    ###########################################


_print_help() {
  cat <<HEREDOC

Wrapper script containing generic functions used in other scripts.
Source functions rather than run this script direct
HEREDOC
}


_binary_exists() {
  if type "$1" &> /dev/null; then
  echo "$1" found
  else
  echo "$1" not found, exiting... && exit 1
  fi
}

_tidy() {
  rm -rf .tmp
}

_setup() {
  _tidy
  for i in "${_binaries[@]}"; do
    _binary_exists "$i"
  done
  mkdir -p .tmp
}

###  MAIN         ###########################################

_print_help
