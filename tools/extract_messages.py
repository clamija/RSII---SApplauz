import os
import re
from collections import defaultdict


ROOTS = [
    ("Desktop (Flutter)", "desktop/lib", {".dart"}),
    ("Mobile (Flutter)", "mobile/lib", {".dart"}),
    ("Backend (.NET)", "backend", {".cs"}),
]


def iter_files(root_dir: str, exts: set[str]):
    for base, _, files in os.walk(root_dir):
        # skip build artifacts
        if any(part in {"build", ".dart_tool", "obj", "bin"} for part in base.split(os.sep)):
            continue
        for fn in files:
            if os.path.splitext(fn)[1] in exts:
                yield os.path.join(base, fn)


def read_lines(path: str):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.readlines()
    except OSError:
        return []


def norm_path(p: str) -> str:
    return p.replace("\\", "/")


def extract_from_dart(line: str) -> list[str]:
    # Focus on user-facing messages: SnackBars, validators, dialog titles/content
    if not (
        "SnackBar" in line
        or "showSnackBar" in line
        or "validator" in line
        or "return '" in line
        or "AlertDialog" in line
        or "content:" in line
    ):
        return []

    # Exclude obvious non-message UI labels
    if any(
        token in line
        for token in (
            "DataColumn(",
            "DataCell(",
            "NavigationRailDestination(",
            "DropdownMenuItem",
            "labelText:",
            "hintText:",
            "tooltip:",
        )
    ):
        return []

    # Extract single-quoted strings (common in this repo)
    strings = re.findall(r"'([^'\\]*(?:\\.[^'\\]*)*)'", line)
    # Extract double-quoted strings too (rare in dart here)
    strings += re.findall(r"\"([^\"\\]*(?:\\.[^\"\\]*)*)\"", line)
    return [s.replace("\\n", "\n").strip() for s in strings if s.strip()]


def extract_from_cs(line: str) -> list[str]:
    if not (
        "throw" in line
        or "BadRequest" in line
        or "Unauthorized" in line
        or "Forbid" in line
        or "NotFound" in line
        or "Conflict" in line
    ):
        return []
    # Extract C# string literals "..."
    strings = re.findall(r"\"([^\"]*)\"", line)
    return [s.strip() for s in strings if s.strip()]


def extract_messages():
    by_area = {}
    for area_name, root, exts in ROOTS:
        area_messages = defaultdict(list)  # msg -> list[(file,line_no,snippet)]
        for path in iter_files(root, exts):
            lines = read_lines(path)
            for i, raw in enumerate(lines, start=1):
                line = raw.strip()
                if not line:
                    continue
                if path.endswith(".dart"):
                    msgs = extract_from_dart(line)
                else:
                    msgs = extract_from_cs(line)
                for m in msgs:
                    # Keep only error/success/confirmation style messages
                    if path.endswith(".dart"):
                        if not re.search(
                            r"(grešk|uspješn|obavez|molimo|pokušaj|odaber|ne može|neisprav|pristup|sigurn|odust|odjav|nema|blok|važe|rasprod|refund|otkaz|plać|potvrd)",
                            m,
                            flags=re.IGNORECASE,
                        ):
                            continue
                    area_messages[m].append((norm_path(path), i, line[:220]))
        by_area[area_name] = area_messages
    return by_area


def to_markdown(by_area: dict) -> str:
    out = []
    out.append("## Katalog poruka (automatski izvučeno iz koda)\n")
    out.append(
        "**Napomena:** Ovo je best-effort automatska ekstrakcija stringova koji se prikazuju korisniku (SnackBar/validacije/dijalozi) i backend poruka iz exceptiona. "
        "Poruke koje su dinamički konstruisane (npr. `Greška: {e}`) su prikazane kao šablon kroz izvorni snippet.\n"
    )

    for area, msgs in by_area.items():
        out.append(f"### {area}\n")
        # sort by message
        for msg in sorted(msgs.keys(), key=lambda s: s.lower()):
            out.append(f"- **{msg}**\n")
            # show up to 6 occurrences for readability
            occs = msgs[msg][:6]
            for (fp, ln, snippet) in occs:
                situation = "Poruka"
                s = snippet.lower()
                if "snackbar" in s or "showsnackbar" in s:
                    situation = "SnackBar (feedback)"
                elif "validator" in s or "return" in s:
                    situation = "Validacija forme"
                elif "alertdialog" in s or "showdialog" in s:
                    situation = "Dijalog"
                elif fp.endswith(".cs"):
                    situation = "Backend exception / HTTP odgovor"
                out.append(f"  - **situacija**: {situation} — `{fp}:{ln}`\n")
                out.append(f"    - `{snippet}`\n")
            if len(msgs[msg]) > 6:
                out.append(f"  - … (+{len(msgs[msg]) - 6} mjesta)\n")
        out.append("")
    return "".join(out)


def main():
    by_area = extract_messages()
    md = to_markdown(by_area)
    os.makedirs("tools/out", exist_ok=True)
    with open("tools/out/APP_MESSAGES_CATALOG.md", "w", encoding="utf-8") as f:
        f.write(md)


if __name__ == "__main__":
    main()

