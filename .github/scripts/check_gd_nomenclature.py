import os
import re
import sys


def split_params(param_string: str):
    """Split parameters on commas while ignoring nested structures."""
    params = []
    current: list[str] = []
    stack: list[str] = []
    pairs = {')': '(', ']': '[', '}': '{'}
    in_quote = None
    escape = False
    for char in param_string:
        if escape:
            current.append(char)
            escape = False
            continue

        if char == "\\":
            current.append(char)
            escape = True
            continue

        if in_quote:
            current.append(char)
            if char == in_quote:
                in_quote = None
            continue

        if char in "'\"":
            current.append(char)
            in_quote = char
            continue

        if char in '([{':
            stack.append(char)
        elif char in ')]}':
            if stack and stack[-1] == pairs.get(char):
                stack.pop()
            else:
                raise ValueError("unbalance in delimiter")

        if char == ',' and not stack:
            params.append(''.join(current).strip())
            current = []
        else:
            current.append(char)
    
    if stack:
        raise ValueError("unbalance in delimiter")
    if in_quote:
        raise ValueError(f"Unclosed quote: {in_quote}")

    params.append(''.join(current).strip())
    params = [p for p in params if p]
    return params

EXCLUDED_DIRS = {"addons", ".git", ".github"}

PASCAL_CASE = re.compile(r"^[A-Z][A-Za-z0-9]*$")
SNAKE_CASE = re.compile(r"^_?[a-z][a-z0-9_]*$")
UPPER_SNAKE_CASE = re.compile(r"^_?[A-Z][A-Z0-9_]*$")

issues = []
MESSAGES = {
    'class': 'is a class name and should be in PascalCase',
    'function': 'is a function name and should be in snake_case',
    'variable': 'is a variable name and should be in snake_case',
    'constant': 'is a constant name and should be in UPPER_SNAKE_CASE',
    'signal': 'is a signal name and should be in snake_case',
}

for root, dirs, files in os.walk('.', topdown=True):
    rel_root = os.path.relpath(root, '.')
    if any(rel_root == excluded or rel_root.startswith(f"{excluded}{os.sep}") for excluded in EXCLUDED_DIRS):
        dirs[:] = []
        continue
    for fname in files:
        if fname.endswith('.gd'):
            path = os.path.join(root, fname)
            try:
                with open(path, 'r', encoding='utf-8') as file:
                    lines = file.readlines()
            except Exception as e:
                issues.append((path, 0, 'error', f'Could not read file: {e}'))
                continue
            for idx, line in enumerate(lines, 1):
                stripped = line.strip()
                if stripped.startswith('#') or not stripped:
                    continue
                match_class = re.match(r"class_name\s+([A-Za-z0-9_]+)", stripped)
                if match_class:
                    name = match_class.group(1)
                    if not PASCAL_CASE.match(name):
                        issues.append((path, idx, 'class', name))
                match_func = re.match(r"func\s+([A-Za-z0-9_]+)\s*(\([^)]*\))?", stripped)
                if match_func:
                    name = match_func.group(1)
                    if not SNAKE_CASE.match(name):
                        issues.append((path, idx, 'function', name))
                    params = match_func.group(2)
                    if params:
                        params = params.strip('()')
                        for param in split_params(params):
                            param_name = param.split(':')[0].split('=')[0].strip()
                            if param_name and not SNAKE_CASE.match(param_name):
                                issues.append((path, idx, 'variable', param_name))
                match_export = re.match(r"(?:@export\s+)?var\s+([A-Za-z0-9_]+)", stripped)
                if match_export:
                    name = match_export.group(1)
                    if not SNAKE_CASE.match(name):
                        issues.append((path, idx, 'variable', name))
                match_const = re.match(r"const\s+([A-Za-z0-9_]+)", stripped)
                if match_const:
                    name = match_const.group(1)
                    if not UPPER_SNAKE_CASE.match(name):
                        issues.append((path, idx, 'constant', name))
                match_signal = re.match(r"signal\s+([A-Za-z0-9_]+)", stripped)
                if match_signal:
                    name = match_signal.group(1)
                    if not SNAKE_CASE.match(name):
                        issues.append((path, idx, 'signal', name))
                match_for = re.match(r"for\s+([A-Za-z0-9_]+)(?:\s*:\s*[^\s]+)?\s+in\b", stripped)
                if match_for:
                    name = match_for.group(1)
                    if not SNAKE_CASE.match(name):
                        issues.append((path, idx, 'variable', name))

if issues:
    print("### \u274c GDScript Naming Convention Check Failed\n")
    print(f"The project must follow Godot GDScript naming conventions.\nTotal issues: {len(issues)}\n")
    for path, idx, kind, name in issues:
        if kind == 'error':
            message = name
        else:
            message = f"'{name}' {MESSAGES[kind]}"
        print(f"- `{path}:{idx}` {message}")
    sys.exit(1)
else:
    print("\u2705 All GDScript files follow the naming conventions.")
