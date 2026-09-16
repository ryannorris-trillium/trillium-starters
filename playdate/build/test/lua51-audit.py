"""Check that the shim is Lua 5.1, because love.js is.

    python3 build/test/lua51-audit.py build/shim build/entry.lua

The browser runs plain Lua 5.1. Anything written for 5.2 or later parses fine
on the machine you wrote it on and fails in the tab, which is a blue screen
with a syntax error and no clue why. This looks for the constructs that only
exist in the newer versions:

    goto and ::label::   5.2
    //                   5.3 floor division
    & | ~ << >>          5.3 bitwise operators
    <const> <close>      5.4 attributes

`~=` is not equal, which 5.1 has, so it is allowed. Comments and strings are
blanked out first, so prose about these operators does not trip the check.
"""
import re
import sys
from pathlib import Path


def blank_comments_and_strings(text):
    """Replace comment and string contents with spaces, keeping line breaks."""
    out = []
    i = 0
    n = len(text)
    while i < n:
        # Long bracket, as a comment or a string.
        bracket = re.match(r"(--)?\[(=*)\[", text[i:])
        if bracket:
            level = bracket.group(2)
            close = "]" + level + "]"
            end = text.find(close, i + bracket.end())
            end = n if end == -1 else end + len(close)
            out.append("".join(c if c == "\n" else " " for c in text[i:end]))
            i = end
            continue
        if text.startswith("--", i):
            end = text.find("\n", i)
            end = n if end == -1 else end
            out.append(" " * (end - i))
            i = end
            continue
        if text[i] in "\"'":
            quote = text[i]
            j = i + 1
            while j < n and text[j] != quote:
                if text[j] == "\\":
                    j += 1
                if text[j : j + 1] == "\n":
                    break
                j += 1
            j = min(j + 1, n)
            out.append("".join(c if c == "\n" else " " for c in text[i:j]))
            i = j
            continue
        out.append(text[i])
        i += 1
    return "".join(out)


CHECKS = [
    (re.compile(r"\bgoto\b"), "goto (Lua 5.2)"),
    (re.compile(r"::\s*\w+\s*::"), "::label:: (Lua 5.2)"),
    (re.compile(r"//"), "// floor division (Lua 5.3)"),
    (re.compile(r"<<|>>"), "bit shift operator (Lua 5.3)"),
    (re.compile(r"&"), "& bitwise and (Lua 5.3)"),
    (re.compile(r"\|"), "| bitwise or (Lua 5.3)"),
    (re.compile(r"~(?!=)"), "~ bitwise not or xor (Lua 5.3)"),
    (re.compile(r"<\s*(const|close)\s*>"), "variable attribute (Lua 5.4)"),
]


def audit(path):
    problems = []
    source = blank_comments_and_strings(path.read_text(encoding="utf-8"))
    for number, line in enumerate(source.split("\n"), start=1):
        for pattern, label in CHECKS:
            match = pattern.search(line)
            if match:
                problems.append((number, label, match.group(0)))
    return problems


def main(targets):
    files = []
    for target in targets:
        p = Path(target)
        if p.is_dir():
            files.extend(sorted(p.rglob("*.lua")))
        else:
            files.append(p)

    total = 0
    for path in files:
        for number, label, text in audit(path):
            total += 1
            print("{}:{}: {} -> {!r}".format(path, number, label, text))

    if total:
        print("{} Lua 5.1 problem(s) found".format(total))
        return 1
    print("Lua 5.1 audit clean: {} file(s)".format(len(files)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:] or ["build/shim", "build/entry.lua"]))
