#!/usr/bin/env bash

stage_acquire_resources() {
  local llvm_archive=""
  local llvm_url=""

  require_var LLVM_VERSION
  require_var RESOURCES_DIR
  require_var SDK_ARCHIVE_FILENAME

  llvm_archive="llvm-project-${LLVM_VERSION}.src.tar.xz"
  llvm_url="https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/${llvm_archive}"

  stage_heading "Acquire resources"

  mkdir -p "$RESOURCES_DIR"

  echo "Checking for LLVM sources"
  if [[ ! -f "$RESOURCES_DIR/$llvm_archive" ]]; then
    require_cmd wget
    echo "Downloading LLVM sources"
    wget -O "$RESOURCES_DIR/$llvm_archive" "$llvm_url"
  else
    echo "LLVM sources already downloaded"
  fi

  echo "Checking for Buildroot SDK"
  if [[ ! -f "$RESOURCES_DIR/$SDK_ARCHIVE_FILENAME" ]]; then
    die "Buildroot SDK archive not found: $RESOURCES_DIR/$SDK_ARCHIVE_FILENAME"
  else
    echo "Buildroot SDK is present"
  fi
}
