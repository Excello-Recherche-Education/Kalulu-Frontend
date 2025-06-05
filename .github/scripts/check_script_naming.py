import os
import re
import sys

pattern = re.compile(r'^[a-z0-9_]+\.gd$')
invalid_files = []

for root, dirs, files in os.walk('.'):
    for name in files:
        if name.endswith('.gd'):
            if not pattern.match(name):
                invalid_files.append(os.path.join(root, name))

if invalid_files:
    print('Invalid script filenames detected:')
    for f in invalid_files:
        print(f)
    sys.exit(1)
else:
    print('All script filenames follow Godot naming convention.')
