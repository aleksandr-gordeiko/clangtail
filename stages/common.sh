#!/usr/bin/env bash

die() {
  echo "Error: $*" >&2
  exit 1
}

require_cmd() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "required command '$cmd' not found in PATH"
  fi
}

require_var() {
  local name="$1"

  if [[ -z "${!name:-}" ]]; then
    die "required variable '$name' is not set"
  fi
}

load_config() {
  local config_file="$1"
  local common_dir=""
  local loader=""

  [[ -r "$config_file" ]] || die "config file not readable: $config_file"
  require_cmd python3

  common_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  loader="$common_dir/../scripts/load_config.py"
  [[ -r "$loader" ]] || die "config loader not readable: $loader"

  python3 "$loader" "$config_file"
}

stage_heading() {
  echo
  echo "=== $1 ==="
}

infer_package_arch() {
  local triple="$1"

  case "$triple" in
    aarch64-*) printf '%s\n' "aarch64" ;;
    arm-*) printf '%s\n' "arm" ;;
    x86_64-*) printf '%s\n' "x86_64" ;;
    *) printf '%s\n' "${triple%%-*}" ;;
  esac
}

is_shared_library() {
  case "$1" in
    *.so|*.so.*) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_manifest_path() {
  local manifest_entry="$1"
  local sysroot="$2"
  local relative_path=""
  local resolved_path=""
  local fallback_path=""
  local fallback_name="${manifest_entry##*/}"

  case "$manifest_entry" in
    "$sysroot"/*)
      printf '%s\n' "$manifest_entry"
      return
      ;;
    */sysroot/*)
      relative_path="${manifest_entry#*/sysroot/}"
      ;;
    /usr/*|/lib/*)
      relative_path="${manifest_entry#/}"
      ;;
    usr/*|lib/*)
      relative_path="$manifest_entry"
      ;;
  esac

  if [[ -n "$relative_path" ]]; then
    resolved_path="$sysroot/$relative_path"
    if [[ -e "$resolved_path" ]]; then
      printf '%s\n' "$resolved_path"
      return
    fi
  fi

  fallback_path="$sysroot/usr/lib/$fallback_name"
  if [[ -e "$fallback_path" ]]; then
    printf '%s\n' "$fallback_path"
    return
  fi

  die "could not resolve manifest entry in sysroot: $manifest_entry"
}

copy_manifest_libraries() {
  local manifest="$1"
  local sysroot="$2"
  local destination="$3"
  local copied=0
  local line=""
  local source_path=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    is_shared_library "$line" || continue

    source_path="$(resolve_manifest_path "$line" "$sysroot")"
    cp -a "$source_path" "$destination/"
    copied=$((copied + 1))
  done < "$manifest"

  if [[ "$copied" -eq 0 ]]; then
    die "no shared libraries found in manifest"
  fi
  echo "$copied"
}
