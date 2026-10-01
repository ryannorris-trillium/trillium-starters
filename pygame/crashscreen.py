"""Shows any error on the game screen, so a crash never looks like a freeze.

You don't need to read or change this file. Two lines in main.py turn it on:

    import crashscreen                      # at the top, with the other imports
    asyncio.run(crashscreen.guard(main))    # the last line, instead of asyncio.run(main())

When your game hits an error, the window stays open and shows which line of
YOUR code stopped it and what the error says. The full error is also printed
in the terminal (or the browser console).
"""
import asyncio
import os
import sys
import traceback

import pygame

HERE = os.path.dirname(os.path.abspath(__file__))


IN_BROWSER = sys.platform == "emscripten"


def _to_terminal(line, bad=False):
    """In the browser, hand a line to dev.sh's server so it prints in the terminal."""
    if IN_BROWSER:
        try:
            import platform
            platform.window.console.log(("[game!] " if bad else "[game] ") + line)
        except Exception:
            pass


class _CopyPrints:
    """Wraps print() output so the terminal gets a copy of every line."""
    def __init__(self, inner):
        self.inner, self.pending = inner, ""

    def write(self, text):
        self.inner.write(text)
        self.pending += text
        while "\n" in self.pending:
            line, self.pending = self.pending.split("\n", 1)
            _to_terminal(line)
        return len(text)

    def flush(self):
        self.inner.flush()

    def __getattr__(self, name):
        return getattr(self.inner, name)


async def guard(main):
    """Run your main(). If it crashes, show the error instead of freezing."""
    if IN_BROWSER and not isinstance(sys.stdout, _CopyPrints):
        sys.stdout = _CopyPrints(sys.stdout)
    try:
        await main()
    except (SystemExit, KeyboardInterrupt):
        raise
    except Exception as error:
        report = _report(error)
        if IN_BROWSER:
            _to_terminal(report, bad=True)
        else:
            print(report, file=sys.stderr)
        await _show(error)


def _report(error):
    """The usual Python traceback, minus this file, with every code line filled in."""
    lines = ["Traceback (most recent call last):"]
    for frame in traceback.extract_tb(error.__traceback__):
        if os.path.basename(frame.filename) == "crashscreen.py":
            continue
        name, code = _source(frame)
        lines.append(f'  File "{name}", line {frame.lineno}, in {frame.name}')
        if code:
            lines.append("    " + code)
    lines.append(f"{type(error).__name__}: {error}")
    return "\n".join(lines)


def _your_line(error):
    """The last line of the error that comes from a file in this folder."""
    frames = traceback.extract_tb(error.__traceback__)
    yours = [
        f for f in frames
        if f.filename == "<console>"  # how the browser build names main.py
        or (os.path.dirname(os.path.abspath(f.filename)) == HERE
            and os.path.basename(f.filename) != "crashscreen.py")
    ]
    return (yours or frames)[-1] if frames else None


def _source(frame):
    """The file name and the line of code, read from disk if Python didn't keep it."""
    name = "main.py" if frame.filename == "<console>" else os.path.basename(frame.filename)
    code = (frame.line or "").strip()
    if not code:
        try:
            with open(os.path.join(HERE, name)) as f:
                code = f.read().split("\n")[frame.lineno - 1].strip()
        except (OSError, IndexError):
            pass
    return name, code


def _wrap(font, text, width):
    lines, line = [], ""
    for word in text.split(" "):
        test = (line + " " + word).strip()
        if font.size(test)[0] <= width or not line:
            line = test
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


async def _show(error):
    if not pygame.get_init():
        pygame.init()
    screen = pygame.display.get_surface() or pygame.display.set_mode((640, 400))
    pygame.display.set_caption("Your game stopped with an error")
    width, height = screen.get_size()
    margin = 24
    title = pygame.font.Font(None, 34)
    body = pygame.font.Font(None, 26)
    small = pygame.font.Font(None, 22)

    frame = _your_line(error)
    name, code = _source(frame) if frame else ("", "")
    where = f"{name}, line {frame.lineno}" if frame else "unknown line"
    message = f"{type(error).__name__}: {error}"

    # (font, text, color, gap after)
    rows = [(title, "Your game stopped with an error", (255, 120, 110), 14),
            (body, "Where:  " + where, (240, 240, 240), 6)]
    rows += [(body, part, (255, 220, 120), 0) for part in _wrap(body, code, width - 2 * margin - 20)]
    rows += [(body, "", (0, 0, 0), 8)]
    rows += [(body, part, (240, 240, 240), 0) for part in _wrap(body, message, width - 2 * margin)]
    rows += [(body, "", (0, 0, 0), 14),
             (small, "Fix that line, save, and run the game again.", (170, 180, 190), 4),
             (small, "The full error is also in the terminal or browser console.", (170, 180, 190), 0)]

    clock = pygame.time.Clock()
    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                return
        screen.fill((30, 18, 22))
        y = margin
        for font, text, color, gap in rows:
            if text:
                indent = 20 if color == (255, 220, 120) else 0
                screen.blit(font.render(text, True, color), (margin + indent, y))
            y += font.get_linesize() + gap
        pygame.display.flip()
        clock.tick(30)
        await asyncio.sleep(0)  # keeps the browser tab alive
