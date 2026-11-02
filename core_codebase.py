#!/usr/bin/env python3
"""
Bundle Core Codebase.
Scans lib/core/ (or core/) and outputs a consolidated
text file matching the format of Sacramental-Records-Codebase.txt.
"""

import os
import sys
from pathlib import Path

# Target directory relative to project root
TARGET_REL_DIR = os.path.join("lib", "core")

# Target output file name
OUTPUT_FILE = "Core-Codebase.txt"

# Target file extensions to bundle
TARGET_EXTENSIONS = {".dart"}

# Subdirectories or files to skip (if any)
EXCLUDED_DIRS = {"__pycache__", ".git", ".dart_tool", "build"}
EXCLUDED_FILES = {".DS_Store"}


def bundle_core_codebase(root_path: Path, output_path: Path):
    target_dir = root_path / TARGET_REL_DIR

    # Fallback if script is run directly inside the `lib/` directory
    if not target_dir.exists() and (root_path / "core").exists():
        target_dir = root_path / "core"

    if not target_dir.exists():
        print(f"Error: Target directory '{target_dir}' does not exist.")
        print("Please ensure this script is placed in or executed from your Flutter project root (or lib folder).")
        sys.exit(1)

    collected_files = []

    for dirpath, dirnames, filenames in os.walk(target_dir):
        # Exclude specified directories in-place
        dirnames[:] = [d for d in dirnames if d not in EXCLUDED_DIRS]

        for file in sorted(filenames):
            if file in EXCLUDED_FILES:
                continue
            ext = os.path.splitext(file)[1].lower()
            if ext in TARGET_EXTENSIONS:
                full_path = Path(dirpath) / file
                collected_files.append(full_path)

    # Sort files deterministically (constants -> database -> services -> theme -> widgets)
    collected_files.sort(key=lambda p: str(p.relative_to(root_path)).replace("\\", "/"))

    print(f"Found {len(collected_files)} files in '{target_dir}'. Bundling...")

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
    # Assumes script is run from project root; adjust if passed as argument
    project_root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    output_destination = project_root / OUTPUT_FILE
    bundle_core_codebase(project_root, output_destination)