import os
import re
import sys

pattern = re.compile(r"^[a-z0-9_]+\.gd$")
invalid_files = []

def to_snake_case(filename: str) -> str:
    base = os.path.splitext(filename)[0]
    s1 = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", base)
    s2 = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s1)
    s3 = re.sub(r"[-\s]+", "_", s2)
    return s3.lower() + ".gd"

for root, _, files in os.walk('.'):
    for name in files:
        if name.endswith('.gd'):
            if not pattern.match(name):
                suggestion = to_snake_case(name)
                invalid_files.append(
                    (
                        os.path.relpath(os.path.join(root, name)),
                        os.path.relpath(os.path.join(root, suggestion)),
                    )
                )

if invalid_files:
    print('Invalid script filenames detected:')
    for path, suggestion in invalid_files:
        print(f"{path} -> {suggestion}")
    sys.exit(1)
else:
    print('All script filenames follow Godot naming convention.')
