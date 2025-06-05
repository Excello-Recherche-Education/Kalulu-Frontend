import os
import re
import sys

# File extensions to validate
TARGET_EXTS = {".gd", ".tscn"}

invalid_files = []

_BASE_PATTERN = re.compile(r"^[a-z0-9_]+$")


def to_snake_case(filename: str) -> str:
    base, ext = os.path.splitext(filename)
    s1 = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", base)
    s2 = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s1)
    s3 = re.sub(r"[-\s]+", "_", s2)
    return s3.lower() + ext

for root, _, files in os.walk('.'):
    rel_root = os.path.relpath(root, '.')
    if rel_root == 'addons' or rel_root.startswith(os.path.join('addons', '')):
        continue
    for name in files:
        base, ext = os.path.splitext(name)
        if ext in TARGET_EXTS:
            if not _BASE_PATTERN.match(base):
                suggestion = to_snake_case(name)
                invalid_files.append(
                    (
                        os.path.relpath(os.path.join(root, name)),
                        os.path.relpath(os.path.join(root, suggestion)),
                    )
                )

if invalid_files:
    print('Invalid filenames detected:')
    for path, suggestion in invalid_files:
        print(f"{path} -> {suggestion}")
    sys.exit(1)
else:
    print('All filenames follow Godot naming convention.')
