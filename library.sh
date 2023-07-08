#!/usr/bin/env bash

set -u -e -o errtrace -o pipefail
trap "echo ""errexit: line $LINENO. Exit code: $?"" >&2" ERR
IFS=$' \n\t'

# Wrapper script containing generic functions used in other scripts.
# Source functions rather than run this script direct

###################################################### SETUP

lib::binary_exists() {

  if [[ $(type "$1" &>/dev/null) ]]; then
    echo "$1 found!"
  else
    echo "$1 not found, exiting..."
    exit 1
  fi

}

lib::tidy() {
  rm -rf .tmp
}

lib::create_temp_dir() {
  # create a temp dir
  rm -rf tmp
  mkdir -p .tmp
}

lib::setup() {
  # each script has its' own $BINARIES array
  lib::tidy
  for i in "${BINARIES[@]}"; do
    lib::binary_exists "$i"
  done
  lib::create_temp_dir
}

lib::print_and_exit() {
  echo -e "${1:-$HELP_TEXT}"
  exit 1
}

######################################################## SOX
util::tmp_file() {
  # don't write to the file you're reading from, use a tmp file...
  local out_file=${1:-}
  local file_ext
  file_ext="${out_file##*.}"
  echo "$(date +%s).$file_ext"

}

util::generate_silent_file() {
  # generate a silent file of given $DURATION etc
  # $0 [output file] [sample rate] [channels] [duration]
  local OUT_FILE=${1:-}
  local SAMPLE_RATE=${2:-}
  local CHANNELS=${3:-1}
  local DURATION=${4:-}
  sox -n -r "$SAMPLE_RATE" -c "$CHANNELS" "$OUT_FILE" trim 0 "$DURATION"
}

sox::duration_in_samples() {
  # sox can handle durations in seconds (e.g. 4.3) or samples (eg 125s)
  # if the  duration ends in 's',it's in samples, otherwise it's in seconds
  # $0 [duration] [sample rate]
  local duration=${1:-}
  local sample_rate=${2:-}
  if [[ "$duration" =~ "s$" ]]; then
    # already in samples; do nothing
    echo "$duration"
  else
    echo "$(bc <<<"scale=0; $duration * $sample_rate")"s
  fi
}

util::trim_to_length() {
  #  trim/pad sample to length
  #  $0 [input_file] [length] ([output_file] [in_place])
  local in_file=${1:-}
  in_file="$(util::file_exists "$in_file")"
  local desired_length=${2:-}
  local out_file
  out_file=$(util::tmp_file "$in_file")
  local current_length
  current_length=$(sox::get_length "$in_file")
  if [[ "$current_length" > "$desired_length" ]]; then
    desired_length=$desired_length"s"
    sox "$in_file" "$out_file" trim 0 "$desired_length"
    mv "$out_file" "$in_file"
  fi
}

sox::pan() {
  local in_file=${1-}
  local r_vol=${2:-0.5} # 0 = full left-pan, 1 = full right-pan
  local l_vol
  l_vol=$(echo "1 - $r_vol" | bc)
  local out_file
  out_file=$(util::tmp_file "$in_file")
  # assumes stereo file
  [[ $(sox::get_channels "$in_file") == 2 ]] || lib::print_and_exit "wrong number of channels, exiting"
  echo sox "$in_file" "$out_file" remix 1v"$l_vol" 2v"$r_vol"
  sox "$in_file" "$out_file" remix 1v"$l_vol" 2v"$r_vol"
  mv "$out_file" "$in_file"
}

sox::pitch() {
  #pitch is in cents, range here is 0..1 (half-speed to double speed)
  local in_file=${1-}
  in_file=$(lib::format_check "$in_file")
  local pitch=${2:-0.5}
  local pitch_in_cents
  pitch_in_cents=$(util::one_range_to_another 0 1 -1200 1200 "$pitch")
  local out_file=${3-}
  [[ -z $out_file ]] && out_file=$(util::tmp_file "$in_file") && tmp=true
  sox "$in_file" "$out_file" pitch "$pitch_in_cents"
  [[ "$tmp" == true ]] && mv "$out_file" "$in_file"
}

sox::stretch() {
  #pitch is in cents, range here is 0..1 (half-speed to double speed)
  local in_file=${1-}
  in_file=$(lib::format_check "$in_file")
  local stretch=${2:-0.5}
  local stretch_ratio
  stretch_ratio=$(util::one_range_to_another 0 1 0.5 2.0 "$stretch" false)
  local out_file=${3-}
  [[ -z $out_file ]] && out_file=$(util::tmp_file "$in_file") && tmp=true
  sox "$in_file" "$out_file" stretch "$stretch_ratio"
  [[ "$tmp" == true ]] && mv "$out_file" "$in_file"
}

sox::generic() {
  ## generic wrapper for single parameter effects
  # usage: $0 $in_file $effect $strength [$out_file]
  local in_file=${1-}
  in_file=$(lib::format_check "$in_file")
  local effect=${2-}
  local strength=${3-0.5}
  local out_file=${4-}
  [[ -z $out_file ]] && out_file=$(util::tmp_file "$in_file") && tmp=true
  ## different effects have different ranges.
  local min
  local max
  case $effect in
  pitch)
    min=-1200
    max=1200
    ;;
  *)
    min=0.5
    max=2.0
    ;;
  esac
  strength=$(util::one_range_to_another 0 1 "$min" "$max" "$strength" false)
  sox "$in_file" "$out_file" "$effect" "$strength"
  [[ "$tmp" == true ]] && mv "$out_file" "$in_file"
}

sox::speed() {
  local in_file=${1-}
  in_file=$(lib::format_check "$in_file")
  local speed=${2:-1.0} #range 0..4.0
  speed=$(util::one_range_to_another 0 1 0 4.0 "$speed" false)
  local out_file=${3:-$in_file}
  [[ -z $out_file ]] && out_file=$(util::tmp_file "$in_file") && tmp=true
  sox "$in_file" "$out_file" speed "$speed"
  [[ "$tmp" == true ]] && mv "$out_file" "$in_file"
}

sox::reverse() {
  local in_file=${1-}
  in_file=$(lib::format_check "$in_file")
  local out_file=${3:-$in_file}
  [[ -z $out_file ]] && out_file=$(util::tmp_file "$in_file") && tmp=true
  sox "$in_file" "$out_file" reverse
  [[ "$tmp" == true ]] && mv "$out_file" "$in_file"
}

sox::get_sample_rate() {
  local in_file=${1:-}
  in_file=$(lib::format_check "$in_file")
  soxi -r "$in_file"
}

sox::get_length() {
  local in_file=${1:-}
  in_file=$(lib::format_check "$in_file")
  soxi -s "$in_file"
}

sox::get_length() {
  local in_file=${1:-}
  in_file=$(lib::format_check "$in_file")
  soxi -s "$in_file"
}

sox::get_channels() {
  local in_file=${1:-}
  in_file=$(lib::format_check "$in_file")
  soxi -c "$in_file"
}

sox::append_file() {
  # in-place append
  local base_file=${1:-}
  local file_to_append=${2:-}
  local tmp_file
  tmp_file=$(util::tmp_file "$base_file")
  sox "$base_file" "$file_to_append" "$tmp_file"
  mv "$tmp_file" "$base_file"
}

##########################################################
# UTILITY FUNCTIONS
##########################################################

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
  local filename
  filename=${1-}
  ext=${filename#*.}
  if [[ $(lib::is_valid_format "$ext") = "true" ]]; then
    echo "$filename"
  else
    lib::print_and_exit "$SOX_FORMAT_ERROR"
  fi
}

lib::is_soundfile() {
  # if exists, and sox can handle it, return the filename
  local in_file
  in_file=${1-}
  lib::format_check "$(util::file_exists "$in_file")"
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

lib::random_word() {
  #random word for youtube search
  shuf -n 1 /usr/share/dict/words
}
#################################################### HELPERS

util::dec_to_hex() {
  printf '%02x\n' "$1"
}

util::round_float() {
  local in_float=${1-}
  local precision=${2:-0}
  echo "$in_float" | LC_ALL=C xargs /usr/bin/printf "%0.*f\\n" "$precision"
}

util::float_2_abs_int() {
  local in_float=${1-}
  local precision=${2:-0}
  int=$(echo "$in_float" | LC_ALL=C xargs /usr/bin/printf "%0.*f\\n" "$precision")
  echo "${int#-}" #remove negative sign
}

util::one_range_to_another() {
  # $0 old_min old_max new_min new_max in_val integer(true/false)
  local from_min=${1:-0}
  local from_max=${2:-1}
  local from_range
  from_range=$(echo "$from_max - $from_min" | bc)
  local to_min=${3:-0}
  local to_max=${4:-255}
  local to_range
  to_range=$(echo "$to_max - $to_min" | bc)
  local in_val=${5-}
  local int=${6:-"true"}
  local out_val
  out_val=$(echo "$in_val * ($to_range / $from_range) + $to_min" | bc)
  if [[ "$int" == "true" ]]; then
    out_val=$(util::round_float "$out_val")
  else
    out_val=$(util::round_float "$out_val" 3)
  fi
  echo "$out_val"
}

util::file_exists() {
  local file=${1:-}
  [[ -f "$file" ]] && echo "$file" \
    || echo lib::print_and_exit "file $file does not exist"
}

util::tmp_file() {
  # don't write to the file you're reading from, use a tmp file...
  local out_file=${1-}
  local file_ext
  file_ext="${out_file##*.}"
  echo "$(date +%s).$file_ext"
}

util::outfile_check() {
  local out_file=${1:-"tmp.wav"}
  if [[ -z "$out_file" ]]; then
    out_file=$(util::tmp_file "$out_file")
    exit 1
  fi
  echo "$out_file"
}

util::get_duration_in_samples() {
  # $0 [duration in seconds] [sample rate]
  local duration=${1:-}
  local sample_rate=${2:-}
  util::float_2_abs_int "$(bc <<<"scale=3; $duration * $sample_rate")"
}
