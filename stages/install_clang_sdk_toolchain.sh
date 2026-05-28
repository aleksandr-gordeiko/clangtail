#!/usr/bin/env bash

copy_host_tool_to_sdk() {
  local tool="$1"
  local dst_dir="$2"
  local src="$HOST_INSTALL_DIR/bin/$tool"
  local link_target=""

  if [[ ! -e "$src" && ! -L "$src" ]]; then
    die "expected LLVM tool '$src' was not installed"
  fi

  if [[ -L "$src" ]]; then
    link_target="$(readlink "$src")"
    if [[ "$link_target" != /* && ( -e "$HOST_INSTALL_DIR/bin/$link_target" || -L "$HOST_INSTALL_DIR/bin/$link_target" ) ]]; then
      copy_host_tool_to_sdk "$link_target" "$dst_dir"
    fi
  fi

  rm -rf "$dst_dir/$tool"
  cp -a "$src" "$dst_dir/"
}

remove_temporary_clang_wrappers() {
  echo
  echo "Removing temporary clang wrappers from SDK/usr/bin"
  rm -f "$CLANG_WRAPPER" "$CLANGPP_WRAPPER"
}

render_sdk_template() {
  local template_file="$1"
  local output_file="$2"
  local gcc_toolchain_suffix="$3"
  local cmake_gcc_toolchain_block="$4"
  local content=""

  [[ -f "$template_file" ]] || die "template not found: $template_file"

  content="$(<"$template_file")"
  content="${content//@@TRIPLE@@/$TRIPLE}"
  content="${content//@@GCC_TOOLCHAIN_SUFFIX@@/$gcc_toolchain_suffix}"
  content="${content//@@CMAKE_GCC_TOOLCHAIN_BLOCK@@/$cmake_gcc_toolchain_block}"

  printf '%s\n' "$content" > "$output_file"
}

install_clang_sdk_toolchain() {
  local sdk_bin="$SDK_ROOT/bin"
  local sdk_lib="$SDK_ROOT/lib"
  local tool=""
  local tools=(
    clang
    clang++
    clang-cpp
    lld
    ld.lld
    llvm-ar
    llvm-nm
    llvm-objcopy
    llvm-objdump
    llvm-ranlib
    llvm-readelf
    llvm-size
    llvm-strip
  )

  mkdir -p "$sdk_bin" "$sdk_lib"

  for tool in "${tools[@]}"; do
    copy_host_tool_to_sdk "$tool" "$sdk_bin"
  done

  if [[ ! -d "$HOST_INSTALL_DIR/lib/clang" ]]; then
    die "expected clang resource directory at $HOST_INSTALL_DIR/lib/clang"
  fi
  rm -rf "$sdk_lib/clang"
  cp -a "$HOST_INSTALL_DIR/lib/clang" "$sdk_lib/"

  ln -sfn clang "$sdk_bin/${TRIPLE}-clang"
  ln -sfn clang++ "$sdk_bin/${TRIPLE}-clang++"
  ln -sfn ld.lld "$sdk_bin/${TRIPLE}-ld.lld"

  echo "Installed LLVM tools into $sdk_bin"
  echo "Installed clang resource dir into $sdk_lib/clang"
}

generate_clang_sdk_setup() {
  local env_file="$SDK_ROOT/clang-environment-setup"
  local cmake_file="$SDK_ROOT/share/buildroot/clang-toolchainfile.cmake"
  local gcc_toolchain_suffix=""
  local cmake_gcc_toolchain_block=""

  if [[ -n "$GCC_TOOLCHAIN_HINT" ]]; then
    if [[ "$GCC_TOOLCHAIN_HINT" == "$SDK_ROOT" ]]; then
      gcc_toolchain_suffix=""
    elif [[ "$GCC_TOOLCHAIN_HINT" == "$SDK_ROOT/"* ]]; then
      gcc_toolchain_suffix="/${GCC_TOOLCHAIN_HINT#"$SDK_ROOT/"}"
    else
      echo "Warning: GCC toolchain hint '$GCC_TOOLCHAIN_HINT' is outside SDK root; clang setup will not pass --gcc-toolchain." >&2
      gcc_toolchain_suffix="__NONE__"
    fi
  else
    gcc_toolchain_suffix="__NONE__"
  fi

  if [[ "$gcc_toolchain_suffix" != "__NONE__" ]]; then
    cmake_gcc_toolchain_block="set(CMAKE_C_COMPILER_EXTERNAL_TOOLCHAIN \"\${RELOCATED_HOST_DIR}${gcc_toolchain_suffix}\")
set(CMAKE_CXX_COMPILER_EXTERNAL_TOOLCHAIN \"\${RELOCATED_HOST_DIR}${gcc_toolchain_suffix}\")"
  fi

  mkdir -p "$SDK_ROOT/share/buildroot"

  render_sdk_template \
    "$TEMPLATES_DIR/clang-environment-setup.in" \
    "$env_file" \
    "$gcc_toolchain_suffix" \
    "$cmake_gcc_toolchain_block"
  render_sdk_template \
    "$TEMPLATES_DIR/clang-toolchainfile.cmake.in" \
    "$cmake_file" \
    "$gcc_toolchain_suffix" \
    "$cmake_gcc_toolchain_block"

  chmod +x "$env_file"

  echo "Generated clang environment setup: $env_file"
  echo "Generated clang CMake toolchain: $cmake_file"
}

stage_install_clang_sdk_toolchain() {
  require_var CLANG_WRAPPER
  require_var CLANGPP_WRAPPER
  require_var HOST_INSTALL_DIR
  require_var SDK_ROOT
  require_var TEMPLATES_DIR
  require_var TRIPLE

  GCC_TOOLCHAIN_HINT="${GCC_TOOLCHAIN_HINT:-}"

  stage_heading "Install LLVM toolchain into SDK"

  remove_temporary_clang_wrappers
  install_clang_sdk_toolchain
  generate_clang_sdk_setup
}
