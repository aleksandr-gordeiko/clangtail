#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/config.json"

# shellcheck source=../docker/env
source "$PROJECT_DIR/docker/env"
# shellcheck source=../stages/common.sh
source "$PROJECT_DIR/stages/common.sh"
CONFIG_ASSIGNMENTS="$(load_config "$CONFIG_FILE")"
eval "$CONFIG_ASSIGNMENTS"

BUILD_DIR="$PROJECT_DIR/build"
SDK_ARCHIVE="$BUILD_DIR/$SDK_ARCHIVE_FILENAME"
PACKAGE_ARCH="$(infer_package_arch "$TRIPLE")"
RUNTIMES_DEB="$BUILD_DIR/clangtail-runtimes_${LLVM_VERSION}_${PACKAGE_ARCH}.deb"
RUNTIMES_RUN="$BUILD_DIR/clangtail-runtimes_${LLVM_VERSION}_${PACKAGE_ARCH}.run"
LLVM_SRC_DIR="$BUILD_DIR/llvm-project"
SDCARD_IMG="$BUILD_DIR/$ROOTFS_IMAGE_FILENAME"
LOG_FILE="${CHECK_BUILD_LOG:-$BUILD_DIR/check_build.log}"

die() {
  echo "Error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

check_file() {
  [[ -f "$1" ]] || die "expected file not found: $1"
}

check_dir() {
  [[ -d "$1" ]] || die "expected directory not found: $1"
}

check_executable() {
  [[ -x "$1" ]] || die "expected executable not found: $1"
}

archive_contains() {
  local pattern="$1"
  local entries=""

  entries="$(tar -tzf "$SDK_ARCHIVE")"
  grep -Eq "$pattern" <<<"$entries" || die "SDK archive is missing entry matching: $pattern"
}

run_bootstrap_in_docker() {
  local docker_args=()

  mkdir -p "$BUILD_DIR"
  : > "$LOG_FILE"

  echo "Building Docker image: $IMAGE_NAME (log: $LOG_FILE)"
  if ! docker build -t "$IMAGE_NAME" "$THIS_DIR" >>"$LOG_FILE" 2>&1; then
    die "Docker image build failed. See log: $LOG_FILE"
  fi

  docker_args=(
    --rm
    --net=host
    --privileged
    -u "$(id -u):$(id -g)"
    -e "JOBS=${JOBS:-$(nproc)}"
    -e LIBGUESTFS_BACKEND=direct
    -v "$PROJECT_DIR/:$CONTAINER_HOME/clangtail/"
    -w "$CONTAINER_HOME/clangtail"
  )
  if [[ -d "$HOME/.ssh" ]]; then
    docker_args+=( -v "$HOME/.ssh/:$CONTAINER_HOME/.ssh/:ro" )
  fi

  echo "Running bootstrap.sh inside Docker (log: $LOG_FILE)"
  if ! docker run "${docker_args[@]}" "$IMAGE_NAME" bash ./bootstrap.sh >>"$LOG_FILE" 2>&1; then
    die "bootstrap.sh failed inside Docker. See log: $LOG_FILE"
  fi
}

verify_build_outputs() {
  echo "Verifying build outputs"

  check_dir "$LLVM_SRC_DIR/llvm"
  check_file "$SDK_ARCHIVE"
  check_file "$RUNTIMES_DEB"
  check_file "$RUNTIMES_RUN"
  check_executable "$BUILD_DIR/host-install/bin/clang"
  check_executable "$BUILD_DIR/host-install/bin/clang++"
  check_file "$BUILD_DIR/runtimes-build/install_manifest.txt"

  if [[ -n "$ROOTFS_IMAGE_FILENAME" && -f "$PROJECT_DIR/resources/$ROOTFS_IMAGE_FILENAME" ]]; then
    check_file "$SDCARD_IMG"
  fi

  archive_contains '(^|/)bin/clang$'
  archive_contains '(^|/)bin/clang\+\+$'
  archive_contains "(^|/)bin/${TRIPLE}-clang$"
  archive_contains "(^|/)bin/${TRIPLE}-clang\\+\\+$"
  archive_contains '(^|/)lib/clang/'
  archive_contains '(^|/)clang-environment-setup$'
  archive_contains '(^|/)share/buildroot/clang-toolchainfile\.cmake$'
  archive_contains "(^|/)${TRIPLE}/sysroot/usr/lib/libc\\+\\+"

  echo "Build verification passed"
}

main() {
  if (( $# != 0 )); then
    die "check_build.sh does not accept arguments"
  fi

  require_cmd docker
  require_cmd grep
  require_cmd tar

  run_bootstrap_in_docker
  verify_build_outputs
}

main "$@"
