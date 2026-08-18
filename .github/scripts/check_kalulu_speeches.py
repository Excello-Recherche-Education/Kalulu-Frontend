#!/usr/bin/env python3
"""Cross-checks Kalulu's voice lines across the frontend and the language packs.

Three sets are compared:
  - requested: every speech the game can ask for, harvested from the call sites
  - declared:  every slot the Prof Tool exposes for upload
  - shipped:   the mp3 files each language pack actually contains

The report is Markdown, meant to be posted as a pull-request comment. A missing
recording is a reminder, not a broken build, and never fails the job. Being unable
to read one of the three sets does fail it: a report that silently left a set out
would say every pack was complete.
"""
import argparse
import difflib
import os
import pathlib
import re
import sys

# Call sites that look up a speech through Minigame.TYPE_NAMES rather than a
# literal, mapped to the minigames they stand for. base_minigame.gd runs for
# every minigame; boss_minigame.gd only ever runs as the boss. A file that uses
# TYPE_NAMES without an entry here is reported instead of being ignored.
DYNAMIC_CALL_SITES = {
    "sources/minigames/base/base_minigame.gd": "*",
    "sources/minigames/boss/boss_minigame.gd": "boss",
}
LITERAL_CALL = re.compile(r'get_kalulu_speech_path\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\)')
DYNAMIC_CALL = re.compile(r'get_kalulu_speech_path\(\s*TYPE_NAMES\[[^\]]+\][^,]*,\s*"([^"]+)"\s*\)')
CONST_CALL = re.compile(r'get_kalulu_speech_path\(\s*([A-Z_]+)\s*,\s*([A-Z_]+)\s*\)')


def read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def type_names(frontend: pathlib.Path) -> list[str]:
    """The minigame name strings, read from the enum's companion array."""
    source = read(frontend / "sources/minigames/base/base_minigame.gd")
    block = re.search(r"const TYPE_NAMES: Array\[String\] = \[(.*?)\]", source, re.S)
    return re.findall(r'"([^"]+)"', block.group(1)) if block else []


def resolve_consts(source: str, names: tuple[str, str]) -> tuple[str, str] | None:
    """Values of two `const NAME: String = "value"` declarations, if both exist."""
    found = []
    for name in names:
        hit = re.search(rf'{name}: String = "([^"]+)"', source)
        if not hit:
            return None
        found.append(hit.group(1))
    return found[0], found[1]


def collect_requested(frontend: pathlib.Path) -> tuple[set, list]:
    requested, warnings = set(), []
    games = type_names(frontend)
    for path in sorted(frontend.glob("sources/**/*.gd")):
        relative = path.relative_to(frontend).as_posix()
        if relative.startswith("sources/language_tool/"):
            continue
        source = read(path)
        if "get_kalulu_speech_path" not in source:
            continue
        requested.update(LITERAL_CALL.findall(source))
        for category, name in CONST_CALL.findall(source):
            resolved = resolve_consts(source, (category, name))
            if resolved:
                requested.add(resolved)
            else:
                warnings.append(f"`{relative}` looks up a speech through constants "
                                f"`{category}` / `{name}` this check cannot resolve.")
        dynamic = DYNAMIC_CALL.findall(source)
        if not dynamic:
            continue
        owner = DYNAMIC_CALL_SITES.get(relative)
        if owner is None:
            warnings.append(f"`{relative}` looks up speeches through `TYPE_NAMES` but is "
                            f"not listed in DYNAMIC_CALL_SITES, so its lines are unchecked.")
            continue
        for name in dynamic:
            for game in (games if owner == "*" else [owner]):
                requested.add((game, name))
    return requested, warnings


def collect_declared(frontend: pathlib.Path) -> set:
    """Every (category, name) the Prof Tool offers a slot for.

    The dictionary is read off the source between the declaration above it and the
    loop that consumes it below. Both bounds are checked and said out loud if they
    have moved: a refactor of that file must stop this check rather than let it
    report a Prof Tool with no slots in it at all.
    """
    path = frontend / "sources/language_tool/kalulu_speeches.gd"
    source = read(path)
    start, end = source.find("var speeches:"), source.find("\tfor speech_title")
    if start < 0 or end < 0:
        raise SystemExit(f"{path}: the speeches dictionary is no longer bounded by "
                         f"`var speeches:` and `for speech_title`, so this check "
                         f"cannot read it. Fix the anchors in collect_declared().")
    declared, category = set(), None
    for line in source[start:end].split("\n"):
        header = re.match(r'^\t\t"([^"]+)":\s*\{', line)
        if header:
            category = header.group(1)
        entry = re.match(r'^\t\t\t"([^"]+)":', line)
        if entry and category:
            declared.add((category, entry.group(1)))
    return declared


def collect_shipped(packs: pathlib.Path) -> dict[str, set]:
    shipped = {}
    for pack in sorted(packs.iterdir()):
        kalulu = pack / "language_sounds" / "kalulu"
        if kalulu.is_dir():
            shipped[pack.name] = {name[:-4] for name in os.listdir(kalulu)
                                  if name.endswith(".mp3")}
    return shipped


def slug(pair: tuple[str, str]) -> str:
    return f"{pair[0]}_{pair[1]}"


# A near-miss on the whole name is almost always a typo. On the category alone the
# bar has to be higher: `garden_screen` scores .96 against the real `gardens_screen`
# and a typo like `pengin` scores .92, while the retired `lesson_screen` scores .80
# against `login_screen` -- a different category, not a misspelling. Hence .90.
NAME_MATCH_CUTOFF = 0.85
CATEGORY_MATCH_CUTOFF = 0.90


def closest_category(name: str, categories: list[str]) -> tuple[str, float]:
    """Best (category, score) for the leading `_`-separated chunks of a file name."""
    parts = name.split("_")
    best, score = "", 0.0
    for size in range(1, len(parts)):
        candidate = "_".join(parts[:size])
        for category in categories:
            ratio = difflib.SequenceMatcher(None, candidate, category).ratio()
            if ratio > score:
                best, score = category, ratio
    return best, score


def verdict_for(name: str, known: set[str], categories: list[str]) -> str:
    """Why a pack file matches nothing: a likely typo, a retired line, or neither."""
    near = difflib.get_close_matches(name, sorted(known), n=1, cutoff=NAME_MATCH_CUTOFF)
    if near:
        return f"almost certainly a misspelling of `{near[0]}` — **rename**"
    category = next((one for one in categories if name.startswith(one + "_")), None)
    if category:
        return f"category `{category}` is live, this line is not — **delete or wire up**"
    best, score = closest_category(name, categories)
    if score >= CATEGORY_MATCH_CUTOFF:
        return f"category looks misspelled: `{best}` is the live one — **rename**"
    return "no live category, no close match — **delete?**"


def report(frontend: pathlib.Path, packs: pathlib.Path) -> str:
    requested, warnings = collect_requested(frontend)
    declared = collect_declared(frontend)
    shipped = collect_shipped(packs)

    lines = ["## 🎙️ Kalulu voice lines", ""]
    if not shipped:
        lines.append(f"No language pack found under `{packs}` — nothing to compare against.")
        return "\n".join(lines)

    lines.append(f"{len(requested)} speeches requested by the game · "
                 f"{len(declared)} slots in the Prof Tool · "
                 f"{len(shipped)} packs checked.")
    lines.append("")

    lines.append("### Missing recordings")
    lines.append("")
    incomplete = {pack: sorted(slug(pair) for pair in requested if slug(pair) not in files)
                  for pack, files in shipped.items()}
    if any(incomplete.values()):
        lines.append("| Pack | Missing | Files |")
        lines.append("|---|---|---|")
        for pack, missing in incomplete.items():
            listed = ", ".join(f"`{name}.mp3`" for name in missing) if missing else "—"
            lines.append(f"| {pack} | {len(missing)} | {listed} |")
    else:
        lines.append("Every pack ships every speech the game asks for. ✅")
    lines.append("")

    no_slot = sorted(requested - declared)
    no_consumer = sorted(declared - requested)
    if no_slot or no_consumer or warnings:
        lines.append("### Slots out of step with the code")
        lines.append("")
        for pair in no_slot:
            lines.append(f"- `{slug(pair)}` is requested by the game but has **no slot** "
                         f"in the Prof Tool, so nobody can upload it.")
        for pair in no_consumer:
            lines.append(f"- `{slug(pair)}` has a slot but the game **never requests** it.")
        for warning in warnings:
            lines.append(f"- ⚠️ {warning}")
        lines.append("")

    known = {slug(pair) for pair in requested | declared}
    categories = sorted({pair[0] for pair in requested | declared})
    orphans = {pack: sorted(files - known) for pack, files in shipped.items()}
    if any(orphans.values()):
        lines.append("### Recordings nothing uses")
        lines.append("")
        lines.append("In the packs, but requested by neither the game nor the Prof Tool. "
                     "Either leftovers to delete, or a name to fix -- a close match in the "
                     "verdict means the file is probably just misnamed.")
        lines.append("")
        for pack, extra in orphans.items():
            if not extra:
                continue
            lines.append(f"<details><summary><b>{pack}</b> — {len(extra)} unused "
                         f"recordings</summary>")
            lines.append("")
            lines.append("| File | Verdict |")
            lines.append("|---|---|")
            for name in extra:
                lines.append(f"| `{name}.mp3` | {verdict_for(name, known, categories)} |")
            lines.append("")
            lines.append("</details>")
            lines.append("")

    lines.append("<sub>Reminder only — this check never fails a build.</sub>")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frontend", default=".", type=pathlib.Path,
                        help="path to the Kalulu-Frontend checkout (default: .)")
    parser.add_argument("--packs", default="../Kalulu-Languages", type=pathlib.Path,
                        help="path to the Kalulu-Languages checkout")
    args = parser.parse_args()
    print(report(args.frontend, args.packs))
    return 0


if __name__ == "__main__":
    sys.exit(main())
