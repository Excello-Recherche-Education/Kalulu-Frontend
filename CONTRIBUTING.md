# Contributing to Kalulu

Thank you for your interest in Kalulu! This short guide explains **how to contribute** (code, docs, i18n).

---

## 1) Requirements

- **Godot 4.x** (recommended in 2025/08: 4.4.1)
- Cloned repository or fork.
- **SQLite addon**: install `godot-sqlite` from the AssetLib **after** opening the project in Godot.  
  > The folder `addons/godot-sqlite/bin` is not versioned; do not commit it.

---

## 2) Getting started

1. **Fork** and **clone** your fork.
2. Open the project in **Godot 4** (`project.godot`).
3. Make sure the project runs without errors (F5).

---

## 3) Branches & Pull Requests

- Create a branch from **`main`** (e.g. `feature/...`, `fix/...`).
- Open your **PR to `main`**.
- Clearly describe your changes (include screenshots if relevant).

---

## 4) Minimal conventions (to pass CI)

Kalulu uses **automatic checks** on PRs:

- **GDScript naming conventions** (scripts).  
- **Godot file naming conventions** (scenes/resources).  
- **No single-character variable names** in GDScript code.  

Please follow these rules:

- **Variables & functions**: `snake_case`.
- **Scene and script file names**: `snake_case` (no `PascalCase`).
- **Meaningful names** (avoid `a`, `b`, `x`, etc.).

---

## 5) Run checks locally (optional but recommended)

From the repository root:

```bash
# GDScript naming conventions
python3 .github/scripts/check_gd_nomenclature.py

# Godot file naming conventions (.gd, .tscn, etc.)
python3 .github/scripts/check_file_naming.py

# Single-character variable names (fails if found)
python3 .github/scripts/check_single_char_vars.py
```

---

## 6) Translations (i18n)

- Edit **`kalulu_localization.csv`** to add/update keys.  
- Do not remove existing keys and keep the file structure.  
- Avoid directly editing `.translation` files: they will be regenerated if needed.

---

## 7) License

By contributing, you agree that your contributions will be released under the **repository license** (see `LICENSE`).

---

## 8) Need help?

Open an **Issue** (question/bug/feature) and describe the context clearly.
