#!/usr/bin/env python3
"""
Bundle Notifications & IoT Codebase.
Scans notification services/models/dialogs and smart_archive (IoT) module files,
outputting a consolidated text file for context.
"""

import os
import sys
from pathlib import Path

# Target output file name
OUTPUT_FILE = "Notifications-And-IoT-Codebase.txt"

# Specific target files and directories relative to project root
TARGET_PATHS = [
    os.path.join("lib", "core", "services", "notification_service.dart"),
    os.path.join("lib", "features", "notifications"),
    os.path.join("lib", "features", "dashboard", "presentation", "dialogs", "notification_dialog.dart"),
    os.path.join("lib", "features", "smart_archive"),
]

TARGET_EXTENSIONS = {".dart", ".yaml"}
EXCLUDED_FILES = {".DS_Store", "pubspec.lock"}
EXCLUDED_DIRS = {"__pycache__", ".git", ".dart_tool", "build"}


def bundle_notifications_iot_codebase(root_path: Path, output_path: Path):
    collected_files = []

    for target_rel in TARGET_PATHS:
        target_path = root_path / target_rel
        if target_path.is_file():
            collected_files.append(target_path)
        elif target_path.is_dir():
            for dirpath, dirnames, filenames in os.walk(target_path):
                dirnames[:] = [d for d in dirnames if d not in EXCLUDED_DIRS]
                for file in sorted(filenames):
                    if file in EXCLUDED_FILES:
                        continue
                    ext = os.path.splitext(file)[1].lower()
                    if ext in TARGET_EXTENSIONS:
                        collected_files.append(Path(dirpath) / file)

    # Include pubspec.yaml for dependency context
    pubspec_path = root_path / "pubspec.yaml"
    if pubspec_path.exists():
        collected_files.append(pubspec_path)

    # Deduplicate and sort deterministically
    collected_files = list(set(collected_files))
    collected_files.sort(key=lambda p: str(p.relative_to(root_path)).replace("\\", "/"))

    print(f"Found {len(collected_files)} files for Notifications & IoT. Generating {OUTPUT_FILE}...")

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
    bundle_notifications_iot_codebase(project_root, output_destination)
