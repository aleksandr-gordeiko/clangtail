#!/usr/bin/env bash

write_runtimes_run_installer() {
  local installer="$1"

  cat > "$installer" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

install_root="${DESTDIR:-/}"
install_root="${install_root%/}"
if [[ -z "$install_root" ]]; then
  install_root="/"
fi

target_lib_dir="$install_root/usr/lib"

if [[ "$install_root" == "/" && "$(id -u)" -ne 0 ]]; then
  echo "Error: installing to /usr/lib requires root; rerun as root or set DESTDIR" >&2
  exit 1
fi

mkdir -p "$target_lib_dir"
cp -a usr/lib/. "$target_lib_dir/"

echo "Installed LLVM target runtime shared libraries to $target_lib_dir"
EOF

  chmod +x "$installer"
}

build_runtimes_run() (
  local manifest="$1"
  local sysroot="${2%/}"
  local output="$3"
  local tmp_dir=""
  local package_arch="${RUNTIMES_PACKAGE_ARCH:-}"
  local copied_count=""
  local label=""

  require_var RUNTIMES_PACKAGE_NAME
  require_var RUNTIMES_PACKAGE_VERSION

  [[ -f "$manifest" ]] || die "install manifest not found: $manifest"
  [[ -d "$sysroot" ]] || die "sysroot not found: $sysroot"

  require_cmd chmod
  require_cmd cp
  require_cmd makeself
  require_cmd mktemp
  require_cmd rm

  if [[ -z "$package_arch" ]]; then
    package_arch="$(infer_package_arch "$TRIPLE")"
  fi

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf -- "$tmp_dir"' EXIT

  mkdir -p "$tmp_dir/payload/usr/lib" "$(dirname "$output")"
  copied_count="$(copy_manifest_libraries "$manifest" "$sysroot" "$tmp_dir/payload/usr/lib")"
  write_runtimes_run_installer "$tmp_dir/payload/install.sh"

  label="${RUNTIMES_PACKAGE_NAME} ${RUNTIMES_PACKAGE_VERSION} ${package_arch}"
  rm -f "$output"
  makeself --gzip --quiet "$tmp_dir/payload" "$output" "$label" ./install.sh

  echo "Packaged $copied_count shared libraries into $output"
)

stage_package_runtimes_run() {
  local manifest=""
  local package_arch=""

  require_var BUILD_DIR
  require_var RUNTIMES_BUILD_DIR
  require_var RUNTIMES_PACKAGE_NAME
  require_var RUNTIMES_PACKAGE_VERSION
  require_var SYSROOT
  require_var TRIPLE

  stage_heading "Package target runtimes with makeself"

  package_arch="${RUNTIMES_PACKAGE_ARCH:-$(infer_package_arch "$TRIPLE")}"
  RUNTIMES_RUN="$BUILD_DIR/${RUNTIMES_PACKAGE_NAME}_${RUNTIMES_PACKAGE_VERSION}_${package_arch}.run"
  manifest="$RUNTIMES_BUILD_DIR/install_manifest.txt"

  build_runtimes_run "$manifest" "$SYSROOT" "$RUNTIMES_RUN"
}
