#!/usr/bin/env bash

run_guestfish() {
  local backend="${LIBGUESTFS_BACKEND:-direct}"

  if [[ "$(id -u)" -eq 0 ]]; then
    env LIBGUESTFS_BACKEND="$backend" guestfish "$@"
  else
    sudo -n env LIBGUESTFS_BACKEND="$backend" guestfish "$@"
  fi
}

detect_rootfs_device() {
  local image="$1"
  local filesystems=""

  filesystems="$(run_guestfish --ro -a "$image" <<'EOF'
run
list-filesystems
EOF
)" || die "failed to inspect image filesystems with guestfish"

  awk -F': ' '
    $2 ~ /^(ext2|ext3|ext4|btrfs|xfs|f2fs)$/ {
      print $1
      exit
    }
  ' <<<"$filesystems"
}

patch_rootfs_image() (
  local image="$1"
  local manifest="$2"
  local sysroot="${3%/}"
  local tmp_dir=""
  local payload_tar=""
  local rootfs_device=""
  local copied_count=""

  [[ -f "$image" ]] || die "sdcard image not found: $image"
  [[ -f "$manifest" ]] || die "install manifest not found: $manifest"
  [[ -d "$sysroot" ]] || die "sysroot not found: $sysroot"

  require_cmd guestfish
  if [[ "$(id -u)" -ne 0 ]]; then
    require_cmd sudo
  fi
  require_cmd awk
  require_cmd cp
  require_cmd mktemp
  require_cmd tar

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf -- "$tmp_dir"' EXIT

  mkdir -p "$tmp_dir/root/usr/lib"
  copied_count="$(copy_manifest_libraries "$manifest" "$sysroot" "$tmp_dir/root/usr/lib")"

  payload_tar="$tmp_dir/usr-lib.tar"
  tar -C "$tmp_dir/root" -cpf "$payload_tar" usr/lib

  rootfs_device="${ROOTFS_DEVICE:-}"
  if [[ -z "$rootfs_device" ]]; then
    rootfs_device="$(detect_rootfs_device "$image")"
  fi
  [[ -n "$rootfs_device" ]] || die "could not detect rootfs partition; set ROOTFS_DEVICE=/dev/sdXN"

  echo "Copying $copied_count shared libraries to /usr/lib on $rootfs_device"

  run_guestfish --rw -a "$image" <<EOF
run
mount $rootfs_device /
mkdir-p /usr/lib
tar-in $payload_tar /
sync
umount-all
EOF

  echo "Updated image: $image"
)

stage_patch_rootfs_image() {
  local manifest=""

  require_var RUNTIMES_BUILD_DIR
  require_var SYSROOT

  SDCARD_IMG="${SDCARD_IMG:-}"
  if [[ -z "$SDCARD_IMG" ]]; then
    return 0
  fi

  stage_heading "Patch sdcard image rootfs"

  manifest="$RUNTIMES_BUILD_DIR/install_manifest.txt"
  patch_rootfs_image "$SDCARD_IMG" "$manifest" "$SYSROOT"
}
