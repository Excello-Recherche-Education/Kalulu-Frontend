import csv
import re
import sys
from collections import Counter
from pathlib import Path

UTILS_PATH = Path("sources/utils/autoloads/utils.gd")
LOCALIZATION_PATH = Path("kalulu_localization.csv")


def parse_supported_locales() -> list[str]:
    content = UTILS_PATH.read_text(encoding="utf-8")
    match = re.search(
        r"const\s+SUPPORTED_LOCALES\s*:\s*Dictionary\[String,\s*String\]\s*=\s*\{(.*?)\}",
        content,
        re.S,
    )
    if not match:
        raise ValueError("Could not find SUPPORTED_LOCALES in utils.gd")

    dictionary_body = match.group(1)
    locale_keys = re.findall(r'"([A-Za-z0-9_]+)"\s*:', dictionary_body)
    if not locale_keys:
        raise ValueError("No locale keys found in SUPPORTED_LOCALES")
    return locale_keys


def build_required_columns(locales: list[str], headers: list[str]) -> tuple[set[str], dict[str, str]]:
    base_counts = Counter(locale.split("_", 1)[0] for locale in locales)
    required = set()
    resolved_columns = {}

    for locale in locales:
        base = locale.split("_", 1)[0]
        if base_counts[base] > 1:
            required.add(base)
            if base in headers:
                resolved_columns[base] = base
            continue

        # Unique locale: accept either base (e.g. fr) or full locale (e.g. pt_BR)
        required.add(base)
        if base in headers:
            resolved_columns[base] = base
        elif locale in headers:
            resolved_columns[base] = locale

    return required, resolved_columns


def main() -> int:
    locales = parse_supported_locales()

    with LOCALIZATION_PATH.open("r", encoding="utf-8-sig", newline="") as csv_file:
        reader = csv.reader(csv_file)
        rows = list(reader)

    if not rows:
        print("### ❌ Localization check failed\n")
        print("`kalulu_localization.csv` is empty.")
        return 1

    headers = [header.strip() for header in rows[0]]
    required_columns, resolved_columns = build_required_columns(locales, headers)

    missing_columns = sorted(column for column in required_columns if column not in resolved_columns)

    missing_translations = []
    if not missing_columns:
        header_indexes = {header: idx for idx, header in enumerate(headers)}
        for row_number, row in enumerate(rows[1:], start=2):
            if not row:
                continue

            key = row[0].strip() if len(row) > 0 else ""
            key_label = key if key else f"<missing key at row {row_number}>"

            for required_column, actual_header in resolved_columns.items():
                column_index = header_indexes[actual_header]
                value = row[column_index].strip() if column_index < len(row) else ""
                if value == "":
                    missing_translations.append((row_number, key_label, required_column))

    if missing_columns or missing_translations:
        print("### ❌ Localization translation check failed\n")

        for column in missing_columns:
            print(f"- Missing translation column {column} in kalulu_localization.csv")

        for row_number, key_label, column in missing_translations:
            print(
                f"- Missing translation for key `{key_label}` in language `{column}` "
                f"(row {row_number} in kalulu_localization.csv)"
            )

        return 1

    print("✅ All required translation columns and values are present.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
