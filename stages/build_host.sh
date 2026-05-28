#!/usr/bin/env bash

stage_build_host() {
  require_var BUILD_DIR
  require_var CMAKE_GENERATOR
  require_var HOST_PYTHON3
  require_var JOBS
  require_var PROJECTS
  require_var SRC_DIR

  HOST_BUILD_DIR="$BUILD_DIR/host-build"
  HOST_INSTALL_DIR="$BUILD_DIR/host-install"

  stage_heading "Build LLVM host tools (clang, lld)"

  cmake -S "$SRC_DIR/llvm" -B "$HOST_BUILD_DIR" \
    -G "$CMAKE_GENERATOR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_PROJECTS="$PROJECTS" \
    -DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
    -DCMAKE_INSTALL_PREFIX="$HOST_INSTALL_DIR" \
    -DPython3_EXECUTABLE="$HOST_PYTHON3" \
    -DLLVM_ENABLE_RTTI=ON \
    -DLLVM_ENABLE_EH=ON

  cmake --build "$HOST_BUILD_DIR" --target install -j "$JOBS"

  HOST_CLANG_BIN="$HOST_INSTALL_DIR/bin/clang"
  HOST_CLANGPP_BIN="$HOST_INSTALL_DIR/bin/clang++"
  if [[ ! -x "$HOST_CLANG_BIN" || ! -x "$HOST_CLANGPP_BIN" ]]; then
    die "built clang not found at $HOST_CLANG_BIN"
  fi

  RESOURCE_DIR="$("$HOST_CLANG_BIN" --print-resource-dir 2>/dev/null || true)"
  echo "Built host clang at: $HOST_CLANG_BIN"
  echo "Clang resource dir: $RESOURCE_DIR"
}
