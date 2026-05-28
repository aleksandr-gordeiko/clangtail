#!/usr/bin/env bash
# Builds LLVM host tools and target runtimes, installs them into a Buildroot
# SDK archive, and optionally patches a rootfs partition inside an sdcard image.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGES_DIR="$SCRIPT_DIR/stages"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
CONFIG_FILE="$SCRIPT_DIR/config.json"

RUNTIMES="libcxx;libcxxabi;libunwind;compiler-rt"
RUNTIMES_PACKAGE_NAME="clangtail-runtimes"
PROJECTS="clang;lld"
CMAKE_GENERATOR="Ninja"
JOBS="${JOBS:-$(nproc)}"

BUILD_DIR="$(readlink -f "$SCRIPT_DIR/build")"
RESOURCES_DIR="$SCRIPT_DIR/resources"

mkdir -p "$BUILD_DIR"

# shellcheck source=stages/common.sh
source "$STAGES_DIR/common.sh"
CONFIG_ASSIGNMENTS="$(load_config "$CONFIG_FILE")"
eval "$CONFIG_ASSIGNMENTS"
# shellcheck source=stages/acquire_resources.sh
source "$STAGES_DIR/acquire_resources.sh"
# shellcheck source=stages/prepare_resources.sh
source "$STAGES_DIR/prepare_resources.sh"
# shellcheck source=stages/build_host.sh
source "$STAGES_DIR/build_host.sh"
# shellcheck source=stages/extract_sdk.sh
source "$STAGES_DIR/extract_sdk.sh"
# shellcheck source=stages/build_runtimes.sh
source "$STAGES_DIR/build_runtimes.sh"
# shellcheck source=stages/install_clang_sdk_toolchain.sh
source "$STAGES_DIR/install_clang_sdk_toolchain.sh"
# shellcheck source=stages/patch_rootfs_image.sh
source "$STAGES_DIR/patch_rootfs_image.sh"
# shellcheck source=stages/package_runtimes_deb.sh
source "$STAGES_DIR/package_runtimes_deb.sh"
# shellcheck source=stages/package_runtimes_run.sh
source "$STAGES_DIR/package_runtimes_run.sh"
# shellcheck source=stages/sanity_checks.sh
source "$STAGES_DIR/sanity_checks.sh"
# shellcheck source=stages/repack_sdk.sh
source "$STAGES_DIR/repack_sdk.sh"

if (( $# != 0 )); then
  die "bootstrap.sh does not accept arguments"
fi

clear_build_dir() {
  local host_build_dir="$BUILD_DIR/host-build"
  local entry=""
  local restore_dotglob=""
  local restore_nullglob=""

  [[ -n "$BUILD_DIR" && "$BUILD_DIR" != "/" ]] || die "refusing to clear unsafe build dir: '$BUILD_DIR'"

  mkdir -p "$host_build_dir"

  restore_dotglob="$(shopt -p dotglob || true)"
  restore_nullglob="$(shopt -p nullglob || true)"
  shopt -s dotglob nullglob
  for entry in "$BUILD_DIR"/*; do
    [[ "$entry" == "$host_build_dir" ]] && continue
    rm -rf -- "$entry"
  done
  eval "$restore_dotglob"
  eval "$restore_nullglob"

  echo "Cleared build directory, preserving $host_build_dir"
}

clear_build_dir

require_cmd python3
HOST_PYTHON3="$(python3 -c 'import os, sys; print(os.path.realpath(sys.executable))')"
if [[ ! -x "$HOST_PYTHON3" ]]; then
  HOST_PYTHON3="$(command -v python3)"
fi

SDK_STAGE_DIR="$BUILD_DIR/sdk-stage"
SDK_ARCHIVE_TMP=""

mkdir -p "$BUILD_DIR/host-build" "$BUILD_DIR/host-install" "$BUILD_DIR/runtimes-build"

# Stage output contract:
#   config.json: LLVM_VERSION, TRIPLE, SDK_ARCHIVE_FILENAME, ROOTFS_IMAGE_FILENAME
#   stage_prepare_resources: SDK_ARCHIVE, SRC_DIR, SDCARD_IMG
#   stage_build_host: HOST_BUILD_DIR, HOST_INSTALL_DIR, HOST_CLANG_BIN, HOST_CLANGPP_BIN, RESOURCE_DIR
#   stage_extract_sdk: SDK_ROOT, SYSROOT, GCC_TOOLCHAIN_HINT
#   stage_build_runtimes: SDK_USR_BIN, CLANG_WRAPPER, CLANGPP_WRAPPER, RUNTIMES_BUILD_DIR, INSTALL_PREFIX
#   stage_package_runtimes_deb: RUNTIMES_DEB
#   stage_package_runtimes_run: RUNTIMES_RUN

stage_acquire_resources
RUNTIMES_PACKAGE_VERSION="$LLVM_VERSION"
stage_prepare_resources

if [[ -z "${SDK_ARCHIVE:-}" || -z "${SRC_DIR:-}" ]]; then
  die "prepare_resources did not resolve both SDK_ARCHIVE and SRC_DIR"
fi
if [[ ! -d "$SRC_DIR/llvm" ]]; then
  die "expected llvm directory inside source tree (looked for $SRC_DIR/llvm)"
fi
if [[ ! -r "$SDK_ARCHIVE" ]]; then
  die "cannot read SDK archive '$SDK_ARCHIVE'"
fi
if [[ ! -w "$(dirname "$SDK_ARCHIVE")" ]]; then
  die "cannot rewrite SDK archive in $(dirname "$SDK_ARCHIVE"). Check permissions."
fi
if [[ -n "${SDCARD_IMG:-}" && ! -f "$SDCARD_IMG" ]]; then
  die "sdcard image '$SDCARD_IMG' does not exist"
fi

stage_build_host
stage_extract_sdk
stage_build_runtimes
stage_package_runtimes_deb
stage_package_runtimes_run
stage_install_clang_sdk_toolchain
stage_patch_rootfs_image
stage_sanity_checks
stage_repack_sdk

echo
echo "Done. Key locations:"
echo "  SDK archive: $SDK_ARCHIVE"
echo "  SDK clang path in archive: bin/${TRIPLE}-clang"
echo "  SDK clang++ path in archive: bin/${TRIPLE}-clang++"
echo "  SDK clang setup: clang-environment-setup"
echo "  SDK clang CMake toolchain: share/buildroot/clang-toolchainfile.cmake"
echo "  SDK sysroot libs in archive: ${TRIPLE}/sysroot/usr/lib"
echo "  Runtime opkg package: $RUNTIMES_DEB"
echo "  Runtime makeself package: $RUNTIMES_RUN"
if [[ -n "${SDCARD_IMG:-}" ]]; then
  echo "  Rootfs image updated: $SDCARD_IMG"
fi
echo "  Host toolstage: $HOST_INSTALL_DIR (kept in build-dir)"
echo "  Full build dir: $BUILD_DIR"
