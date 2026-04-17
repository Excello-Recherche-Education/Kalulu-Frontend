import os
import re
import sys
from collections import defaultdict, Counter


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

issues: list = []

# ─── Messages ────────────────────────────────────────────────────────────────
# Structural issue messages. Use {key} for context-specific values.
# Naming issues are rendered dynamically (see format_message / SUGGESTION_FN).

MESSAGES = {
    # File/header structure
    'annotation_order':    "annotation not allowed here: '{found}' — only @tool, @icon or @static_unload are allowed at the top of the file",
    'class_position':      "class_name must appear right after annotations (if any)",
    'extends_position':    "extends must appear after annotations and class_name",
    'extends_missing':     "extends is missing — add 'extends BaseClass' (or 'extends RefCounted' for base classes)",

    # Function spacing
    'func_blank':          "expected 2 blank lines before function (found {found})",

    # Signals
    'signal_position':     "signal found after {after} — expected order: signal > enum > const > static var > @export > var > @onready",
    'signal_format':       "signal must declare parameters with () — found: '{found}'",
    'signal_blank_extra':  "remove blank line between signal declarations — signals must be grouped together",

    # Enums
    'enum_position':       "enum found after {after} — expected order: signal > enum > const > static var > @export > var > @onready",
    'enum_format':         "enum declaration should be 'enum Name {{' — found: '{found}'",
    'enum_member_blank':   "remove blank line between enum members",
    'enum_member_indent':  "enum member must be indented with a single tab — found: '{found}'",
    'enum_no_close':       "enum declaration is missing a closing '}'",
    'enum_blank_missing':  "missing blank line before the enum section",
    'enum_blank_extra':    "remove blank line between enum declarations — enums must be grouped together",

    # Constants
    'const_position':      "const found after {after} — expected order: signal > enum > const > static var > @export > var > @onready",
    'const_blank_missing': "missing blank line before the const section",
    'const_blank_extra':   "remove blank line between const declarations — constants must be grouped together",

    # Static variables
    'static_position':       "static var found after {after} — expected order: signal > enum > const > static var > @export > var > @onready",
    'static_blank_missing':  "missing blank line before the static var section",
    'static_blank_extra':    "remove blank line between static var declarations — static variables must be grouped together",

    # Export variables
    'export_position':       "@export found after {after} — expected order: signal > enum > const > static var > @export > var > @onready",
    'export_blank_missing':  "missing blank line before the @export section",
    'export_blank_extra':    "remove blank line between @export declarations — export variables must be grouped together",

    # Regular variables
    'var_position':       "var found after {after} — expected order: signal > enum > const > static var > @export > var > @onready",
    'var_blank_missing':  "missing blank line before the var section",
    'var_blank_extra':    "remove blank line between var declarations — variables must be grouped together",

    # @onready variables
    'onready_position':       "@onready var found after {after} — expected order: signal > enum > const > static var > @export > var > @onready",
    'onready_blank_missing':  "missing blank line before the @onready section",
    'onready_blank_extra':    "remove blank line between @onready declarations — @onready variables must be grouped together",
}

# ─── Naming conventions ───────────────────────────────────────────────────────

PASCAL_CASE = re.compile(r"^[A-Z][A-Za-z0-9]*$")
SNAKE_CASE = re.compile(r"^_?[a-z][a-z0-9_]*$")
UPPER_SNAKE_CASE = re.compile(r"^_?[A-Z][A-Z0-9_]*$")
REGION_RE = re.compile(r"#\s*(region|endregion)\b", re.IGNORECASE)


def _to_snake_case(name: str) -> str:
    prefix = '_' if name.startswith('_') else ''
    core = name.lstrip('_')
    s = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', core)
    s = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1_\2', s)
    return prefix + s.lower()


def _to_pascal_case(name: str) -> str:
    prefix = '_' if name.startswith('_') else ''
    core = name.lstrip('_')
    # Split on camelCase boundaries first, then on underscores/spaces
    # e.g. 'myBadEnum' → 'my_Bad_Enum' → 'MyBadEnum'
    snake = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', core)
    snake = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1_\2', snake)
    return prefix + ''.join(w.capitalize() for w in re.split(r'[_\s]+', snake) if w)


def _to_upper_snake_case(name: str) -> str:
    prefix = '_' if name.startswith('_') else ''
    core = name.lstrip('_')
    s = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', core)
    s = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1_\2', s)
    return prefix + s.upper()


CONVENTION_NAMES: dict[str, str] = {
    'class':        'PascalCase',
    'enum_name':    'PascalCase',
    'enum_member':  'UPPER_SNAKE_CASE',
    'function':     'snake_case',
    'variable':     'snake_case',
    'constant':     'UPPER_SNAKE_CASE',
    'signal':       'snake_case',
}

SUGGESTION_FN: dict = {
    'class':        _to_pascal_case,
    'enum_name':    _to_pascal_case,
    'enum_member':  _to_upper_snake_case,
    'function':     _to_snake_case,
    'variable':     _to_snake_case,
    'constant':     _to_upper_snake_case,
    'signal':       _to_snake_case,
}

NAMING_KINDS = frozenset({'class', 'enum_name', 'enum_member', 'function', 'variable', 'constant', 'signal'})

# ─── Naming check ─────────────────────────────────────────────────────────────

def _check_enum_member(path: str, idx: int, name: str) -> None:
    """Flag a single enum member name if it is not UPPER_SNAKE_CASE."""
    if name and not UPPER_SNAKE_CASE.match(name):
        issues.append((path, idx, 'enum_member', name))


def check_naming(path: str, lines: list[str]):
    in_enum = False  # True while scanning the body of a multi-line enum

    for idx, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith('#') or stripped.startswith('@warning_ignore(') or not stripped:
            continue

        # ── Enum-body lines ────────────────────────────────────────────────────
        if in_enum:
            close = stripped.find('}')
            if close != -1:
                in_enum = False
                # Any identifiers before the closing brace on this line
                before = stripped[:close]
                for part in before.split(','):
                    m = re.match(r"\s*([A-Za-z0-9_]+)", part)
                    if m:
                        _check_enum_member(path, idx, m.group(1))
            else:
                # One (or more) members on this line: "NAME," or "NAME = val,"
                for part in stripped.split(','):
                    m = re.match(r"\s*([A-Za-z0-9_]+)", part)
                    if m:
                        _check_enum_member(path, idx, m.group(1))
            continue
        # ── End enum-body ──────────────────────────────────────────────────────

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

        # Match variable declarations with any annotation/modifier prefix.
        # Handles: var, static var, @export var, @export_range(...) var,
        #          @export_multiline var, @onready var, etc.
        # Does NOT match annotation-only lines like @export_category("Difficulty").
        match_var = re.match(r"(?:(?:static|@\w+(?:\([^)]*\))?)\s+)*var\s+([A-Za-z0-9_]+)", stripped)
        if match_var:
            name = match_var.group(1)
            if not SNAKE_CASE.match(name):
                issues.append((path, idx, 'variable', name))

        match_const = re.match(r"const\s+([A-Za-z0-9_]+)", stripped)
        if match_const:
            name = match_const.group(1)
            if not UPPER_SNAKE_CASE.match(name):
                issues.append((path, idx, 'constant', name))

        match_enum = re.match(r"enum\s+([A-Za-z0-9_]+)", stripped)
        if match_enum:
            name = match_enum.group(1)
            if not PASCAL_CASE.match(name):
                issues.append((path, idx, 'enum_name', name))
            # Determine whether the enum body is inline or multi-line
            brace = stripped.find('{')
            if brace != -1:
                rest = stripped[brace + 1:]
                close = rest.find('}')
                if close != -1:
                    # Inline enum — check members immediately
                    for part in rest[:close].split(','):
                        m = re.match(r"\s*([A-Za-z0-9_]+)", part)
                        if m:
                            _check_enum_member(path, idx, m.group(1))
                else:
                    # Body continues on following lines
                    in_enum = True

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


# ─── Content order check ──────────────────────────────────────────────────────

ANNOTATION_LINE_RE = re.compile(
    r"^(?:@(tool|icon|static_unload)(?:\([^\n]*\))?)(?:,\s*@(tool|icon|static_unload)(?:\([^\n]*\))?)*$"
)
ALLOWED_ANNOTATION_RE = re.compile(r"@(tool|icon|static_unload)\b")


def check_content_order(path: str, lines: list[str]):
    content = [
        (line.rstrip('\n'), idx)
        for idx, line in enumerate(lines, 1)
        if not line.startswith('	') # Line is not indented (tab character)
        and not line.lstrip().startswith('#')
        and not line.lstrip().startswith('@warning_ignore(')
    ]
    idx = 0
    n = len(content)

    # 1) Annotations (@tool / @icon / @static_unload must be first)
    if idx < n and ANNOTATION_LINE_RE.fullmatch(content[idx][0].strip()):
        idx += 1
    else:
        for j in range(idx, n):
            if ALLOWED_ANNOTATION_RE.search(content[j][0]):
                issues.append((path, content[j][1], 'annotation_order', {'found': content[j][0].strip()}))
                break

    # 2) class_name (optional)
    for j in range(idx, n):
        if content[j][0].strip().startswith('class_name'):
            if j != idx:
                issues.append((path, content[j][1], 'class_position', 'class_name'))
            else:
                idx += 1
            break

    # 3) extends (recommended; missing is flagged but does not block ordering checks)
    extends_pos = None
    for j in range(idx, n):
        if content[j][0].strip().startswith('extends'):
            extends_pos = j
            break

    if extends_pos is None:
        issues.append((path, 0, 'extends_missing', 'extends'))
        # Don't return — continue ordering checks from current position
        prev_token: str = content[idx - 1][0].strip() if idx > 0 else ''
    else:
        if extends_pos != idx:
            issues.append((path, content[extends_pos][1], 'extends_position', 'extends'))
        idx = extends_pos + 1
        prev_token = content[extends_pos][0].strip()

    order = ['signal', 'enum', 'const', 'static var', '@export', 'var', '@onready var']
    order_index = {name: i for i, name in enumerate(order)}
    seen: set[str] = set()
    current_order = -1
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
                issues.append((path, line_no, 'signal_format', {'found': stripped}))
            if 'signal' in seen and prev_token == '':
                issues.append((path, content[j - 1][1], 'signal_blank_extra', 'signal'))
            seen.add('signal')
        elif stripped.startswith('enum'):
            token = 'enum'
            if not re.fullmatch(r"enum\s+\w+\s*{", stripped):
                issues.append((path, line_no, 'enum_format', {'found': stripped}))
            if 'enum' not in seen:
                if prev_token != '':
                    issues.append((path, line_no, 'enum_blank_missing', 'enum'))
            else:
                if prev_token != '}' and prev_token != ']':
                    issues.append((path, line_no, 'enum_blank_extra', 'enum'))
            k = j + 1
            while k < n and content[k][0].strip() != '}':
                member, m_line_no = content[k]
                if member.strip() == '':
                    issues.append((path, m_line_no, 'enum_member_blank', 'enum'))
                if not member.startswith('\t') or member.startswith('\t\t'):
                    issues.append((path, m_line_no, 'enum_member_indent', {'found': member.strip()}))
                k += 1
            if k >= n:
                issues.append((path, line_no, 'enum_no_close', 'enum'))
                return
            j = k
            prev_token = '}'
            seen.add('enum')
            curr_order = order_index['enum']
            if curr_order < current_order:
                after_token = order[current_order]
                issues.append((path, line_no, 'enum_position', {'after': after_token}))
            else:
                current_order = max(current_order, curr_order)
            j += 1
            continue
        elif stripped.startswith('const '):
            token = 'const'
            if 'const' not in seen:
                if prev_token != '':
                    issues.append((path, line_no, 'const_blank_missing', 'const'))
            else:
                if prev_token != 'const' and prev_token != '}' and prev_token != ']':
                    issues.append((path, line_no, 'const_blank_extra', 'const'))
            seen.add('const')
        elif stripped.startswith('static var '):
            token = 'static var'
            if 'static var' not in seen:
                if prev_token != '':
                    issues.append((path, line_no, 'static_blank_missing', 'static var'))
            else:
                if prev_token != 'static var' and prev_token != '}' and prev_token != ']':
                    issues.append((path, line_no, 'static_blank_extra', 'static var'))
            seen.add('static var')
        elif stripped.startswith('@export'):
            token = '@export'
            if '@export' not in seen:
                if prev_token != '':
                    issues.append((path, line_no, 'export_blank_missing', '@export'))
            else:
                if prev_token != '@export' and prev_token != '}' and prev_token != ']':
                    issues.append((path, line_no, 'export_blank_extra', '@export'))
            seen.add('@export')
        elif stripped.startswith('var '):
            token = 'var'
            if 'var' not in seen:
                if prev_token != '':
                    issues.append((path, line_no, 'var_blank_missing', 'var'))
            else:
                if prev_token != 'var' and prev_token != '}' and prev_token != ']':
                    issues.append((path, line_no, 'var_blank_extra', 'var'))
            seen.add('var')
        elif stripped.startswith('@onready var '):
            token = '@onready var'
            if '@onready var' not in seen:
                if prev_token != '':
                    issues.append((path, line_no, 'onready_blank_missing', '@onready var'))
            else:
                if prev_token != '@onready var' and prev_token != '}' and prev_token != ']':
                    issues.append((path, line_no, 'onready_blank_extra', '@onready var'))
            seen.add('@onready var')
        else:
            prev_token = stripped
            j += 1
            continue

        curr_order = order_index[token]
        key_map = {
            'signal':       'signal_position',
            'enum':         'enum_position',
            'const':        'const_position',
            'static var':   'static_position',
            '@export':      'export_position',
            'var':          'var_position',
            '@onready var': 'onready_position',
        }
        if curr_order < current_order:
            after_token = order[current_order]
            issues.append((path, line_no, key_map[token], {'after': after_token}))
        else:
            current_order = max(current_order, curr_order)

        prev_token = token
        j += 1


# ─── Function spacing check ───────────────────────────────────────────────────

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
                    issues.append((path, idx + 1, 'func_blank', {'found': blank_count}))
                continue
            elif blank_count != 2:
                if not (blank_count == 1 and test_index >= 0 and lines[test_index].lstrip().startswith('#region')):
                    issues.append((path, idx + 1, 'func_blank', {'found': blank_count}))


# ─── Main ─────────────────────────────────────────────────────────────────────

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


# ─── Output ───────────────────────────────────────────────────────────────────

ORDERING_KINDS = frozenset({
    'annotation_order', 'class_position', 'extends_position', 'extends_missing',
    'signal_position', 'enum_position', 'const_position', 'static_position',
    'export_position', 'var_position', 'onready_position',
})
FORMATTING_KINDS = frozenset({
    'func_blank',
    'signal_format', 'signal_blank_extra',
    'enum_format', 'enum_blank_missing', 'enum_blank_extra',
    'enum_member_blank', 'enum_member_indent', 'enum_no_close',
    'const_blank_missing', 'const_blank_extra',
    'static_blank_missing', 'static_blank_extra',
    'export_blank_missing', 'export_blank_extra',
    'var_blank_missing', 'var_blank_extra',
    'onready_blank_missing', 'onready_blank_extra',
})


def categorize(kind: str) -> str:
    if kind in NAMING_KINDS:
        return 'naming'
    if kind in ORDERING_KINDS:
        return 'ordering'
    if kind in FORMATTING_KINDS:
        return 'formatting'
    return 'other'


_KIND_LABEL: dict[str, str] = {
    'class':        'class names',
    'enum_name':    'enum names',
    'enum_member':  'enum member names',
    'function':     'function names',
    'variable':     'variable names',
    'constant':     'constant names',
    'signal':       'signal names',
}


def format_message(kind: str, data) -> str:
    if kind in NAMING_KINDS:
        suggestion = SUGGESTION_FN[kind](data)
        conv = CONVENTION_NAMES[kind]
        label = _KIND_LABEL.get(kind, f"{kind}s")
        return f"'{data}' should be '{suggestion}' ({label} must be {conv})"
    if kind == 'error':
        return str(data)
    template = MESSAGES.get(kind, kind)
    if isinstance(data, dict):
        return template.format(**data)
    return template


if not issues:
    print("✅ All GDScript files follow the naming conventions.")
    sys.exit(0)

# Group issues by file, sort by line number within each file
by_file: dict = defaultdict(list)
counts: Counter = Counter()
for path, line_no, kind, data in issues:
    by_file[path].append((line_no, kind, data))
    counts[categorize(kind)] += 1

total = len(issues)
file_count = len(by_file)

summary_parts = []
for cat in ('naming', 'ordering', 'formatting', 'other'):
    if counts[cat]:
        summary_parts.append(f"{counts[cat]} {cat}")
summary = ', '.join(summary_parts)

print(f"### ❌ GDScript Naming Convention Check Failed\n")
print(f"**{total} issue{'s' if total != 1 else ''}** in {file_count} file{'s' if file_count != 1 else ''} ({summary})\n")

for fpath in sorted(by_file):
    file_issues = sorted(by_file[fpath], key=lambda x: x[0])
    count = len(file_issues)
    print("<details>")
    print(f"<summary><code>{fpath}</code> — {count} issue{'s' if count != 1 else ''}</summary>\n")
    print("| Line | Issue |")
    print("|------|-------|")
    for line_no, kind, data in file_issues:
        msg = format_message(kind, data)
        print(f"| {line_no} | {msg} |")
    print("\n</details>\n")

sys.exit(1)
