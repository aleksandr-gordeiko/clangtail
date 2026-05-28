#!/usr/bin/env bash

package_installed_size_kb() {
  local root="$1"
  local size=""

  size="$(du -ks "$root" | awk '{ print $1 }')"
  [[ -n "$size" ]] || size=0
  printf '%s\n' "$size"
}

write_runtimes_control_file() {
  local control_file="$1"
  local package_name="$2"
  local package_version="$3"
  local package_arch="$4"
  local installed_size="$5"

  cat > "$control_file" <<EOF
Package: $package_name
Version: $package_version
Architecture: $package_arch
Maintainer: clangtail
Section: libs
Priority: optional
Installed-Size: $installed_size
Description: LLVM target runtime shared libraries for $TRIPLE
EOF
}

build_runtimes_deb() (
  local manifest="$1"
  local sysroot="${2%/}"
  local output="$3"
  local tmp_dir=""
  local package_arch="${RUNTIMES_PACKAGE_ARCH:-}"
  local copied_count=""
  local installed_size=""

  require_var RUNTIMES_PACKAGE_NAME
  require_var RUNTIMES_PACKAGE_VERSION

  [[ -f "$manifest" ]] || die "install manifest not found: $manifest"
  [[ -d "$sysroot" ]] || die "sysroot not found: $sysroot"

  require_cmd ar
  require_cmd awk
  require_cmd cp
  require_cmd du
  require_cmd mktemp
  require_cmd rm
  require_cmd tar

  if [[ -z "$package_arch" ]]; then
    package_arch="$(infer_package_arch "$TRIPLE")"
  fi

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf -- "$tmp_dir"' EXIT

  mkdir -p "$tmp_dir/control" "$tmp_dir/data/usr/lib" "$(dirname "$output")"
  copied_count="$(copy_manifest_libraries "$manifest" "$sysroot" "$tmp_dir/data/usr/lib")"
  installed_size="$(package_installed_size_kb "$tmp_dir/data")"

  write_runtimes_control_file \
    "$tmp_dir/control/control" \
    "$RUNTIMES_PACKAGE_NAME" \
    "$RUNTIMES_PACKAGE_VERSION" \
    "$package_arch" \
    "$installed_size"

  printf '2.0\n' > "$tmp_dir/debian-binary"
  tar -C "$tmp_dir/control" -czf "$tmp_dir/control.tar.gz" ./control
  tar -C "$tmp_dir/data" -czf "$tmp_dir/data.tar.gz" ./usr

  rm -f "$output"
  (cd "$tmp_dir" && ar rc "$output" debian-binary control.tar.gz data.tar.gz)

  echo "Packaged $copied_count shared libraries into $output"
)

stage_package_runtimes_deb() {
  local manifest=""
  local package_arch=""

  require_var BUILD_DIR
  require_var RUNTIMES_BUILD_DIR
  require_var RUNTIMES_PACKAGE_NAME
  require_var RUNTIMES_PACKAGE_VERSION
  require_var SYSROOT
  require_var TRIPLE

  stage_heading "Package target runtimes for opkg"

  package_arch="${RUNTIMES_PACKAGE_ARCH:-$(infer_package_arch "$TRIPLE")}"
  RUNTIMES_DEB="$BUILD_DIR/${RUNTIMES_PACKAGE_NAME}_${RUNTIMES_PACKAGE_VERSION}_${package_arch}.deb"
  manifest="$RUNTIMES_BUILD_DIR/install_manifest.txt"

  build_runtimes_deb "$manifest" "$SYSROOT" "$RUNTIMES_DEB"
}
