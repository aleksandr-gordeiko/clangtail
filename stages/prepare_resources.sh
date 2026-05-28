#!/usr/bin/env bash

single_match() {
  local description="$1"
  shift
  local matches=( "$@" )

  if (( ${#matches[@]} == 0 )); then
    die "could not find $description"
  fi
  if (( ${#matches[@]} > 1 )); then
    printf 'Error: found multiple %s:\n' "$description" >&2
    printf '  %s\n' "${matches[@]}" >&2
    exit 1
  fi

  printf '%s\n' "${matches[0]}"
}

extract_archive() (
  local archive="$1"
  local destination="$2"
  local temp_dir=""
  local top_entries=()
  local source_dir=""
  local entry=""

  require_cmd cp
  require_cmd find
  require_cmd mktemp
  require_cmd mv
  require_cmd rm
  require_cmd tar

  temp_dir="$(mktemp -d)"
  trap 'rm -rf -- "$temp_dir"' EXIT

  tar -xf "$archive" -C "$temp_dir"

  while IFS= read -r entry; do
    top_entries+=( "$entry" )
  done < <(find "$temp_dir" -mindepth 1 -maxdepth 1 -print)

  if (( ${#top_entries[@]} != 1 )) || [[ ! -d "${top_entries[0]}" ]]; then
    rm -rf "$temp_dir"
    die "expected $archive to unpack into a single top-level source directory"
  fi

  source_dir="${top_entries[0]}"
  rm -rf "$destination"
  mv "$source_dir" "$destination"
)

stage_prepare_resources() {
  local resource_sdk=""
  local llvm_archives=()
  local resource_llvm=""
  local resource_rootfs=""
  local restore_nullglob=""

  require_var BUILD_DIR
  require_var RESOURCES_DIR
  require_var SDK_ARCHIVE_FILENAME

  stage_heading "Prepare resources"

  require_cmd cp
  require_cmd rm

  mkdir -p "$BUILD_DIR"

  if [[ ! -d "$RESOURCES_DIR" ]]; then
    die "resources directory not found: $RESOURCES_DIR"
  fi

  resource_sdk="$RESOURCES_DIR/$SDK_ARCHIVE_FILENAME"
  [[ -f "$resource_sdk" ]] || die "SDK archive not found: $resource_sdk"
  SDK_ARCHIVE="$BUILD_DIR/$SDK_ARCHIVE_FILENAME"
  cp -f "$resource_sdk" "$SDK_ARCHIVE"
  echo "Copied SDK archive to: $SDK_ARCHIVE"

  restore_nullglob="$(shopt -p nullglob || true)"
  shopt -s nullglob
  llvm_archives=(
    "$RESOURCES_DIR"/llvm-project-*.tar
    "$RESOURCES_DIR"/llvm-project-*.tar.gz
    "$RESOURCES_DIR"/llvm-project-*.tar.xz
    "$RESOURCES_DIR"/llvm-project-*.tgz
    "$RESOURCES_DIR"/llvm-project-*.txz
  )
  eval "$restore_nullglob"
  resource_llvm="$(single_match "llvm-project archive in $RESOURCES_DIR" "${llvm_archives[@]}")"
  SRC_DIR="$BUILD_DIR/llvm-project"
  if [[ ! -d "$SRC_DIR/llvm" ]]; then
    echo "Unpacking LLVM sources to: $SRC_DIR"
    extract_archive "$resource_llvm" "$SRC_DIR"
  else
    echo "LLVM sources already prepared at: $SRC_DIR"
  fi

  ROOTFS_IMAGE_FILENAME="${ROOTFS_IMAGE_FILENAME:-}"
  if [[ -n "$ROOTFS_IMAGE_FILENAME" ]]; then
    resource_rootfs="$RESOURCES_DIR/$ROOTFS_IMAGE_FILENAME"
    if [[ -f "$resource_rootfs" ]]; then
      SDCARD_IMG="$BUILD_DIR/$ROOTFS_IMAGE_FILENAME"
      cp -f "$resource_rootfs" "$SDCARD_IMG"
      echo "Copied rootfs image to: $SDCARD_IMG"
    else
      SDCARD_IMG=""
      echo "No rootfs image found at $resource_rootfs; rootfs patch stage will be skipped."
    fi
  else
    SDCARD_IMG=""
    echo "No rootfs image configured; rootfs patch stage will be skipped."
  fi
}
