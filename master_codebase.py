#!/usr/bin/env python3
"""
Bundle ParishServe Master Codebase.
Scans the entire lib/ directory and pubspec.yaml, outputting a consolidated
text file matching the format of Core-Codebase.txt and Sacramental-Records-Codebase.txt.
"""

import os
import sys
from pathlib import Path

# Target output file name
OUTPUT_FILE = "Master-Codebase.txt"

# Target file extensions and specific root files to bundle
TARGET_EXTENSIONS = {".dart", ".yaml"}
EXCLUDED_FILES = {".DS_Store", "pubspec.lock"}

# Subdirectories or files to skip
EXCLUDED_DIRS = {"__pycache__", ".git", ".dart_tool", "build"}


def bundle_master_codebase(root_path: Path, output_path: Path):
    collected_files = []

    # 1. Scan lib/ directory recursively
    lib_dir = root_path / "lib"
    if lib_dir.exists():
        for dirpath, dirnames, filenames in os.walk(lib_dir):
            dirnames[:] = [d for d in dirnames if d not in EXCLUDED_DIRS]
            for file in sorted(filenames):
                if file in EXCLUDED_FILES:
                    continue
                ext = os.path.splitext(file)[1].lower()
                if ext in TARGET_EXTENSIONS:
                    full_path = Path(dirpath) / file
                    collected_files.append(full_path)

    # 2. Include pubspec.yaml from root if present
    pubspec_path = root_path / "pubspec.yaml"
    if pubspec_path.exists():
        collected_files.append(pubspec_path)

    # Sort files deterministically by relative path
    collected_files.sort(key=lambda p: str(p.relative_to(root_path)).replace("\\", "/"))

    print(f"Found {len(collected_files)} files to bundle. Generating {OUTPUT_FILE}...")

    with open(output_path, "w", encoding="utf-8") as out:
        out.write(f"--- START OF FILE {OUTPUT_FILE} ---\n\n")

        for file_path in collected_files:
            rel_path = file_path.relative_to(root_path).as_posix()

            try:
                content = file_path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                content = file_path.read_text(encoding="latin-1")

            out.write("=====================================\n")
            out.write(f"{rel_path}\n")
            out.write("=====================================\n\n")
            out.write(content.strip("\n"))
            out.write("\n\n")

        out.write(f"--- END OF FILE {OUTPUT_FILE} ---\n")

    print(f"Successfully generated: {output_path.resolve()}")
    print(f"Total size: {output_path.stat().st_size / 1024:.2f} KB")


if __name__ == "__main__":
    project_root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    output_destination = project_root / OUTPUT_FILE
    bundle_master_codebase(project_root, output_destination)
