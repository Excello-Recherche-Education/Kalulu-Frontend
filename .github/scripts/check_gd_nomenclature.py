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
EXCLUDED_FILES = {os.path.normpath("script_templates/Node/default.gd")}

issues = []
MESSAGES = {
    'class': 'is a class name and should be in PascalCase',
    'function': 'is a function name and should be in snake_case',
    'variable': 'is a variable name and should be in snake_case',
    'constant': 'is a constant name and should be in UPPER_SNAKE_CASE',
    'signal': 'is a signal name and should be in snake_case',
    'annotation_order': 'annotations must be on the first line and include only \@tool, \@icon or \@static_unload',
    'class_position': 'class_name must appear after annotations (if any)',
    'extends_position': 'extends must appear after annotation and class_name',
    'extends_missing': 'extends is required and must follow annotation and class_name',
    'func_blank': 'functions must be preceded by exactly two empty lines (or only one if preceded by a #region comment)',
    'signal_position': 'signals must come right after extends',
    'signal_format': 'signals must end with ()',
    'signal_blank': 'signals must not be separated by empty lines',
    'enum_position': 'enums must come after signals and be grouped together',
    'enum_format': "enum declaration should be 'enum Name {'",
    'enum_member_blank': 'enum members must not be separated by empty lines',
    'enum_member_indent': 'enum members must be indented with a single tab',
    'enum_no_close': 'enum declaration is missing a closing }',
    'enum_blank': 'enums must be preceded by one empty line and must not be separated by empty lines',
    'const_position': 'constants must come after enums and be grouped together',
    'const_blank': 'constants must be preceded by one empty line and must not be separated by empty lines',
    'static_position': 'static variables must come after constants and be grouped together',
    'static_blank': 'static variables must be preceded by one empty line and must not be separated by empty lines',
    'export_position': 'export variables must come after static variables and be grouped together',
    'export_blank': 'export variables must be preceded by one empty line and must not be separated by empty lines',
    'var_position': 'variables must come after export variables and be grouped together',
    'var_blank': 'variables must be preceded by one empty line and must not be separated by empty lines',
    'onready_position': '@onready variables must come after other variables and be grouped together',
    'onready_blank': '@onready variables must be preceded by one empty line and must not be separated by empty lines',
}

# Naming conventions
PASCAL_CASE = re.compile(r"^[A-Z][A-Za-z0-9]*$")
SNAKE_CASE = re.compile(r"^_?[a-z][a-z0-9_]*$")
UPPER_SNAKE_CASE = re.compile(r"^_?[A-Z][A-Z0-9_]*$")
REGION_RE = re.compile(r"#\s*(region|endregion)\b", re.IGNORECASE)

def check_naming(path: str, lines: list[str]):
    for idx, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith('#') or stripped.startswith('@warning_ignore(') or not stripped:
            continue
        match_class = re.match(r"class_name\s+([A-Za-z0-9_]+)", stripped)
        if match_class:
            name = match_class.group(1)
            if not PASCAL_CASE.match(name):
                issues.append((path, idx, 'class', name))
        match_func = re.match(r"(?:static\s+)?func\s+([A-Za-z0-9_]+)\s*(\([^)]*\))?", stripped)
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

# Content order
ANNOTATION_LINE_RE = re.compile(
    r"^(?:@(tool|icon|static_unload)(?:\([^\n]*\))?)(?:,\s*@(tool|icon|static_unload)(?:\([^\n]*\))?)*$"
)
ALLOWED_ANNOTATION_RE = re.compile(r"@(tool|icon|static_unload)\b")

def check_content_order(path: str, lines: list[str]):
    content = [
        (line.rstrip('\n'), idx)
        for idx, line in enumerate(lines, 1)
        if not line.startswith('	') # Line is not indented
        and not line.lstrip().startswith('#')
        and not line.lstrip().startswith('@warning_ignore(')
    ]
    idx = 0
    n = len(content)

    # 1) annotations
    if idx < n and ANNOTATION_LINE_RE.fullmatch(content[idx][0].strip()):
        idx += 1
    else:
        for j in range(idx, n):
            if ALLOWED_ANNOTATION_RE.search(content[j][0]):
                issues.append((path, content[j][1], 'annotation_order', content[j][0].strip()))
                break

    # 2) class_name (optional)
    for j in range(idx, n):
        if content[j][0].strip().startswith('class_name'):
            if j != idx:
                issues.append((path, content[j][1], 'class_position', 'class_name'))
            else:
                idx += 1
            break

    # 3) extends (required)
    extends_pos = None
    for j in range(idx, n):
        if content[j][0].strip().startswith('extends'):
            extends_pos = j
            break
    if extends_pos is None:
        issues.append((path, 0, 'extends_missing', 'extends'))
        return
    if extends_pos != idx:
        issues.append((path, content[extends_pos][1], 'extends_position', 'extends'))
    idx = extends_pos + 1

    order = ['signal', 'enum', 'const', 'static var', '@export', 'var', '@onready var']
    order_index = {name: i for i, name in enumerate(order)}
    seen: set[str] = set()
    current_order = -1
    prev_token: str | None = content[extends_pos][0].strip()
    j = idx
    while j < n:
        line, line_no = content[j]
        stripped = line.strip()
        if stripped == '':
            prev_token = ''
            j += 1
            continue
        if re.match(r'(?:static\s+)?func\b', stripped):
            break
        token = None
        if stripped.startswith('signal'):
            token = 'signal'
            if not re.fullmatch(r"signal\s+\w+\([^)]*\)", stripped):
                issues.append((path, line_no, 'signal_format', stripped))
            if 'signal' in seen and prev_token == '':
                issues.append((path, content[j - 1][1], 'signal_blank', 'signal'))
            seen.add('signal')
        elif stripped.startswith('enum'):
            token = 'enum'
            if not re.fullmatch(r"enum\s+\w+\s*{", stripped):
                issues.append((path, line_no, 'enum_format', stripped))
            if 'enum' not in seen:
                if prev_token != '':
                    issues.append((path, line_no, 'enum_blank', 'enum'))
            else:
                if prev_token != '}' and prev_token != ']':
                    issues.append((path, line_no, 'enum_blank', 'enum'))
            k = j + 1
            while k < n and content[k][0].strip() != '}':
                member, m_line_no = content[k]
                if member.strip() == '':
                    issues.append((path, m_line_no, 'enum_member_blank', 'enum'))
                if not member.startswith('\t') or member.startswith('\t\t'):
                    issues.append((path, m_line_no, 'enum_member_indent', member.strip()))
                k += 1
            if k >= n:
                issues.append((path, line_no, 'enum_no_close', 'enum'))
                return
            j = k
            prev_token = '}'
            seen.add('enum')
            curr_order = order_index['enum']
            if curr_order < current_order:
                issues.append((path, line_no, 'enum_position', 'enum'))
            else:
                current_order = max(current_order, curr_order)
            j += 1
            continue
        elif stripped.startswith('const '):
            token = 'const'
            if 'const' not in seen:
                if prev_token != '':
                    issues.append((path, line_no, 'const_blank', 'const'))
            else:
                if prev_token != 'const' and prev_token != '}' and prev_token != ']':
                    issues.append((path, line_no, 'const_blank', 'const'))
            seen.add('const')
        elif stripped.startswith('static var '):
            token = 'static var'
            if 'static var' not in seen:
                if prev_token != '':
                    issues.append((path, line_no, 'static_blank', 'static var'))
            else:
                if prev_token != 'static var' and prev_token != '}' and prev_token != ']':
                    issues.append((path, line_no, 'static_blank', 'static var'))
            seen.add('static var')
        elif stripped.startswith('@export'):
            token = '@export'
            if '@export' not in seen:
                if prev_token != '':
                    issues.append((path, line_no, 'export_blank', '@export'))
            else:
                if prev_token != '@export' and prev_token != '}' and prev_token != ']':
                    issues.append((path, line_no, 'export_blank', '@export'))
            seen.add('@export')
        elif stripped.startswith('var '):
            token = 'var'
            if 'var' not in seen:
                if prev_token != '':
                    issues.append((path, line_no, 'var_blank', 'var'))
            else:
                if prev_token != 'var' and prev_token != '}' and prev_token != ']':
                    issues.append((path, line_no, 'var_blank', 'var'))
            seen.add('var')
        elif stripped.startswith('@onready var '):
            token = '@onready var'
            if '@onready var' not in seen:
                if prev_token != '':
                    issues.append((path, line_no, 'onready_blank', '@onready var'))
            else:
                if prev_token != '@onready var' and prev_token != '}' and prev_token != ']':
                    issues.append((path, line_no, 'onready_blank', '@onready var'))
            seen.add('@onready var')
        else:
            prev_token = stripped
            j += 1
            continue
        curr_order = order_index[token]
        key_map = {
            'signal': 'signal_position',
            'enum': 'enum_position',
            'const': 'const_position',
            'static var': 'static_position',
            '@export': 'export_position',
            'var': 'var_position',
            '@onready var': 'onready_position',
        }
        if curr_order < current_order:
            issues.append((path, line_no, key_map[token], token))
        else:
            current_order = max(current_order, curr_order)

        prev_token = token
        j += 1


# Spacing for functions
def check_func_spacing(path: str):
    with open(path, 'r', encoding='utf-8') as file:
        lines = file.readlines()
    for idx, line in enumerate(lines):
        stripped_line = line.lstrip()
        if re.match(r'(?:static\s+)?func\b', stripped_line):
            if re.match(r'(?:static\s+)?func\s*\(', stripped_line):
                continue
            start_idx = idx
            # Skip annotations and regular comments above the function
            while start_idx > 0:
                prev_line = lines[start_idx - 1].lstrip()
                if prev_line.startswith('@warning_ignore('):
                    start_idx -= 1
                elif prev_line.startswith('#') and not REGION_RE.match(prev_line):
                    start_idx -= 1
                else:
                    break
            test_index = start_idx - 1
            blank_count = 0
            while test_index >= 0:
                stripped = lines[test_index].lstrip()
                if stripped == '':
                    blank_count += 1
                    test_index -= 1
                    continue
                if stripped.startswith('@warning_ignore('):
                    test_index -= 1
                    continue
                if stripped.startswith('#') and not REGION_RE.match(stripped):
                    test_index -= 1
                    continue
                break
            region_above = test_index >= 0 and REGION_RE.match(lines[test_index].lstrip())
            if region_above:
                if blank_count > 1:
                    issues.append((path, idx + 1, 'func_blank', 'func'))
                continue
            elif blank_count != 2:
                if not (blank_count == 1 and test_index >= 0 and lines[test_index].lstrip().startswith('#region')):
                    issues.append((path, idx + 1, 'func_blank', 'func'))


# Main function
for root, dirs, files in os.walk('.', topdown=True):
    rel_root = os.path.relpath(root, '.')
    if any(rel_root == excluded or rel_root.startswith(f"{excluded}{os.sep}") for excluded in EXCLUDED_DIRS):
        dirs[:] = []
        continue
    for fname in files:
        if not fname.endswith('.gd'):
            continue
        path = os.path.join(root, fname)
        rel_path = os.path.normpath(os.path.relpath(path, '.'))
        if rel_path in EXCLUDED_FILES:
            continue
        try:
            with open(path, 'r', encoding='utf-8') as file:
                lines = file.readlines()
        except Exception as e:
            issues.append((path, 0, 'error', f'Could not read file: {e}'))
            continue
        check_naming(path, lines)
        check_content_order(path, lines)
        check_func_spacing(path)

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
