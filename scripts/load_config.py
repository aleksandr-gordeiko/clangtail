#!/usr/bin/env python3
import json
import shlex
import sys

REQUIRED_KEYS = {
    "target_triple": "TRIPLE",
    "llvm_version": "LLVM_VERSION",
    "sdk_archive_filename": "SDK_ARCHIVE_FILENAME",
}
OPTIONAL_KEYS = {
    "rootfs_image_filename": "ROOTFS_IMAGE_FILENAME",
}


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: load_config.py <config.json>", file=sys.stderr)
        return 2

    config_file = sys.argv[1]
    with open(config_file, "r", encoding="utf-8") as handle:
        config = json.load(handle)

    assignments = {}
    for key, variable in REQUIRED_KEYS.items():
        value = config.get(key)
        if not isinstance(value, str) or not value:
            print(f"config key '{key}' must be a non-empty string", file=sys.stderr)
            return 1
        assignments[variable] = value

    for key, variable in OPTIONAL_KEYS.items():
        value = config.get(key, "")
        if value is None:
            value = ""
        if not isinstance(value, str):
            print(f"config key '{key}' must be a string or null", file=sys.stderr)
            return 1
        assignments[variable] = value

    for variable, value in assignments.items():
        print(f"{variable}={shlex.quote(value)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
