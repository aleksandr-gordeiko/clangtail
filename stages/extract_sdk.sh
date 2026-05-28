#!/usr/bin/env bash

locate_sdk_root() {
  local search_root="$1"
  local candidate=""
  local restore_dotglob=""
  local restore_nullglob=""

  if [[ -d "$search_root/$TRIPLE/sysroot" ]]; then
    printf '%s\n' "$search_root"
    return 0
  fi

  restore_dotglob="$(shopt -p dotglob || true)"
  restore_nullglob="$(shopt -p nullglob || true)"
  shopt -s dotglob nullglob
  for candidate in "$search_root"/*; do
    if [[ -d "$candidate/$TRIPLE/sysroot" ]]; then
      eval "$restore_dotglob"
      eval "$restore_nullglob"
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  eval "$restore_dotglob"
  eval "$restore_nullglob"
  return 1
}

stage_extract_sdk() {
  require_var SDK_ARCHIVE
  require_var SDK_STAGE_DIR
  require_var TRIPLE

  stage_heading "Extract SDK archive"

  require_cmd find
  require_cmd tar

  mkdir -p "$SDK_STAGE_DIR"
  find "$SDK_STAGE_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
  tar -xzf "$SDK_ARCHIVE" -C "$SDK_STAGE_DIR"

  SDK_ROOT="$(locate_sdk_root "$SDK_STAGE_DIR" || true)"
  if [[ -z "$SDK_ROOT" ]]; then
    die "could not find extracted SDK root containing $TRIPLE/sysroot inside '$SDK_ARCHIVE'"
  fi

  SYSROOT="$SDK_ROOT/$TRIPLE/sysroot"
  if [[ ! -d "$SYSROOT" ]]; then
    die "expected sysroot at $SYSROOT after extracting SDK archive. Confirm archive layout."
  fi

  if [[ -x "$SDK_ROOT/bin/${TRIPLE}-gcc" ]]; then
    GCC_TOOLCHAIN_HINT="$SDK_ROOT"
  elif [[ -x "$SDK_ROOT/usr/bin/${TRIPLE}-gcc" ]]; then
    GCC_TOOLCHAIN_HINT="$SDK_ROOT/usr"
  else
    GCC_TOOLCHAIN_HINT=""
    echo "Warning: could not find ${TRIPLE}-gcc in SDK. The clang wrappers will not pass --gcc-toolchain." >&2
  fi

  echo "SDK_ARCHIVE: $SDK_ARCHIVE"
  echo "SDK_ROOT   : $SDK_ROOT"
  echo "SRC_DIR    : $SRC_DIR"
  echo "BUILD_DIR  : $BUILD_DIR"
  echo "SYSROOT    : $SYSROOT"
  echo "TRIPLE     : $TRIPLE"
  echo "JOBS       : $JOBS"
  if [[ -n "$SDCARD_IMG" ]]; then
    echo "SDCARD_IMG : $SDCARD_IMG"
  fi
}
