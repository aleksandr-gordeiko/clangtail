#!/usr/bin/env bash

stage_sanity_checks() {
  require_var INSTALL_PREFIX
  require_var SDK_ROOT
  require_var TRIPLE

  stage_heading "Sanity checks"

  if ls "$INSTALL_PREFIX/lib"/libc++* >/dev/null 2>&1; then
    echo "Found libc++ in $INSTALL_PREFIX/lib"
  else
    echo "Warning: libc++ not found in $INSTALL_PREFIX/lib. Build may have failed." >&2
  fi

  echo
  echo "Invoking SDK clang to show version info:"
  "$SDK_ROOT/bin/${TRIPLE}-clang" --version | sed -n '1,3p' || true
  echo "Clang resource dir:"
  "$SDK_ROOT/bin/${TRIPLE}-clang" --print-resource-dir || true
}
