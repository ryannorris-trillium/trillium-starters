"""Rewrite `goto continue` loops for the browser build.

love.js runs plain Lua 5.1, which has no `goto`. Playbit uses the
`goto continue` / `::continue::` idiom in a few loops. This turns each such
loop body into `repeat ... until true` with `break` in place of the goto,
which is the standard Lua 5.1 equivalent and runs unchanged everywhere.

    python3 build/lua51-continue.py _web

Only loops that contain a `::continue::` label are touched, and only if
their body has no other `break` (a `break` inside the rewritten body would
leave the repeat instead of the loop, so the script refuses those).
"""
import re
import sys
from pathlib import Path

LABEL = re.compile(r"^(\s*)::continue::\s*$")
LOOP = re.compile(r"^(\s*)(for\b.*\bdo|while\b.*\bdo)\s*$")


def rewrite(text):
    lines = text.split("\n")
    i = 0
    changed = False
    while i < len(lines):
        m = LABEL.match(lines[i])
        if not m:
            i += 1
            continue
        label_indent = len(m.group(1))
        # Walk back to the loop header: the nearest line ending in `do` with
        # a smaller indent than the label.
        j = i - 1
        while j >= 0:
            lm = LOOP.match(lines[j])
            if lm and len(lm.group(1)) < label_indent:
                break
            j -= 1
        if j < 0:
            raise SystemExit(f"no loop header found above ::continue:: at line {i + 1}")
        body = lines[j + 1:i]
        indent = " " * label_indent
        loop_indent = " " * (len(LOOP.match(lines[j]).group(1)))
        has_break = any(re.search(r"\bbreak\b", b) for b in body)
        # A real `break` in the body must still leave the outer loop, not just
        # the repeat block, so it sets a flag that is checked after `until`.
        if has_break:
            body = [re.sub(r"\bbreak\b", "__stop = true break", b) for b in body]
        body = [re.sub(r"\bgoto continue\b", "break", b) for b in body]
        new = [indent + "repeat"] + body + [indent + "until true"]
        if has_break:
            new = new + [indent + "if __stop then break end"]
            lines[j:j] = [loop_indent + "local __stop = false"]
            j += 1
            i += 1
        lines[j + 1:i + 1] = new
        changed = True
        i = j + len(new) + 1
    return "\n".join(lines), changed


def main(root):
    touched = []
    for path in Path(root).rglob("*.lua"):
        text = path.read_text(encoding="utf-8")
        if "::continue::" not in text:
            continue
        new, changed = rewrite(text)
        if changed:
            path.write_text(new, encoding="utf-8")
            touched.append(str(path))
    for t in touched:
        print("rewrote goto continue in", t)
    leftovers = [str(p) for p in Path(root).rglob("*.lua") if re.search(r"\bgoto\b", p.read_text(encoding="utf-8"))]
    if leftovers:
        raise SystemExit("goto still present in: " + ", ".join(leftovers))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "_web")
