import os
import re
import sys

# File extensions to validate
TARGET_EXTS = {
    ".gd",  # Godot scripts
    ".tscn",  # Godot scenes
    ".tres", ".res",  # resources
    ".png", ".jpg",  # images
    ".glb", ".gltf", ".dae", ".obj",  # 3D models
    ".wav", ".ogg", ".mp3",  # sounds
}

# Directories to ignore entirely (e.g., external or tooling folders)
EXCLUDED_DIRS = {"addons", ".git", ".github"}

invalid_files = []
invalid_dirs = []

_BASE_PATTERN = re.compile(r"^[a-z0-9_]+$")


def to_snake_case(filename: str) -> str:
    base, ext = os.path.splitext(filename)
    s1 = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", base)
    s2 = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s1)
    s3 = re.sub(r"[-\s]+", "_", s2)
    return s3.lower() + ext

for root, dirs, files in os.walk('.', topdown=True):
    rel_root = os.path.relpath(root, '.')
    if any(
        rel_root == excluded or rel_root.startswith(f"{excluded}{os.sep}")
        for excluded in EXCLUDED_DIRS
    ):
        dirs[:] = []
        continue

    if rel_root != '.':
        dirname = os.path.basename(root)
        if not _BASE_PATTERN.match(dirname):
            suggestion = to_snake_case(dirname)
            if os.path.dirname(rel_root):
                suggested_rel = os.path.join(os.path.dirname(rel_root), suggestion)
            else:
                suggested_rel = suggestion
            invalid_dirs.append((rel_root, suggested_rel))

    # Validate subdirectories
    for dir in list(dirs):
        rel_path = os.path.join(rel_root, dir) if rel_root != '.' else dir
        if any(
            rel_path == excluded or rel_path.startswith(f"{excluded}{os.sep}")
            for excluded in EXCLUDED_DIRS
        ):
            dirs.remove(dir)
            continue
        if not _BASE_PATTERN.match(dir):
            suggestion = to_snake_case(dir)
            suggested_rel = os.path.join(rel_root, suggestion) if rel_root != '.' else suggestion
            invalid_dirs.append((rel_path, suggested_rel))

    for name in files:
        base, ext = os.path.splitext(name)
        if ext in TARGET_EXTS:
            if not _BASE_PATTERN.match(base):
                suggestion = to_snake_case(name)
                rel_path = os.path.join(rel_root, name) if rel_root != '.' else name
                suggested_rel = os.path.join(rel_root, suggestion) if rel_root != '.' else suggestion
                invalid_files.append((rel_path, suggested_rel))

if invalid_dirs or invalid_files:
    count = len(invalid_dirs) + len(invalid_files)
    print("### \u274c Godot File Naming Convention Check Failed\n")
    print(f"Script names must be in snake_case.\n{count} invalid name{'s' if count > 1 else ''} detected:\n")
    for path, suggestion in invalid_dirs:
        print(f"- **Directory** `{path}` \u2192 `{suggestion}`")
    for path, suggestion in invalid_files:
        print(f"- **File** `{path}` \u2192 `{suggestion}`")
    sys.exit(1)
else:
    print("\u2705 All filenames and directories follow Godot naming convention.")
