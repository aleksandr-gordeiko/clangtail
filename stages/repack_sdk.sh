#!/usr/bin/env bash

stage_repack_sdk() {
  local top_entries=()
  local top_entry=""
  local restore_dotglob=""
  local restore_nullglob=""

  require_var BUILD_DIR
  require_var SDK_ARCHIVE
  require_var SDK_STAGE_DIR

  stage_heading "Repack SDK archive"

  require_cmd tar

  restore_dotglob="$(shopt -p dotglob || true)"
  restore_nullglob="$(shopt -p nullglob || true)"
  shopt -s dotglob nullglob
  for top_entry in "$SDK_STAGE_DIR"/*; do
    top_entries+=( "$(basename "$top_entry")" )
  done
  eval "$restore_dotglob"
  eval "$restore_nullglob"

  if (( ${#top_entries[@]} == 0 )); then
    die "extracted SDK staging directory '$SDK_STAGE_DIR' is empty; refusing to repack"
  fi

  SDK_ARCHIVE_TMP="$(mktemp "$BUILD_DIR/sdk-repack.XXXXXX.tar.gz")"

  tar -czf "$SDK_ARCHIVE_TMP" -C "$SDK_STAGE_DIR" "${top_entries[@]}"
  mv "$SDK_ARCHIVE_TMP" "$SDK_ARCHIVE"
  SDK_ARCHIVE_TMP=""

  echo "Repacked SDK archive: $SDK_ARCHIVE"
}
