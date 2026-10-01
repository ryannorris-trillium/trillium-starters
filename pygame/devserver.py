"""Serves the browser build and sends the game's output to this terminal.

dev.sh starts this for you. Anything your game prints, and every error, shows
up here next to the "built" messages, even if the game tab freezes.
"""
import http.server
import json
import os
import sys
import threading
import time

WEB_DIR = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "build/web")
PORT = int(sys.argv[2] if len(sys.argv) > 2 else 3000)

RED, YELLOW, GREEN, DIM, RESET = "\033[31m", "\033[33m", "\033[32m", "\033[2m", "\033[0m"

# Injected at the top of index.html: copies the page's console and errors to /__log,
# and sends a heartbeat so a frozen tab can be noticed.
BRIDGE = b"""<script>(function(){
var send=function(kind,text){try{navigator.sendBeacon('/__log',JSON.stringify({kind:kind,text:String(text)}))}catch(e){}};
var show=function(x){if(typeof x==='string')return x;if(x&&x.stack)return x.stack;try{return JSON.stringify(x)}catch(e){return String(x)}};
['log','info','warn','error'].forEach(function(k){var o=console[k].bind(console);console[k]=function(){try{var t=Array.prototype.map.call(arguments,show).join(' ');if(t.indexOf('[game!] ')===0)send('error',t.slice(8));else if(t.indexOf('[game] ')===0)send('print',t.slice(7))}catch(e){}o.apply(null,arguments)}});
addEventListener('error',function(e){send('error',(e.error&&e.error.stack)||e.message)});
addEventListener('unhandledrejection',function(e){send('error',(e.reason&&e.reason.stack)||String(e.reason))});
addEventListener('pagehide',function(){send('bye','')});
send('hello',location.pathname);setInterval(function(){send('beat','')},1000);
})();</script>"""

state = {"last_beat": None, "warned": False}
lock = threading.Lock()


def say(text, color=""):
    sys.stdout.write(color + text + (RESET if color else "") + "\n")
    sys.stdout.flush()


def handle_log(kind, text):
    with lock:
        if kind == "beat":
            if state["warned"]:
                say("game: the tab is responding again", GREEN)
            state["last_beat"], state["warned"] = time.time(), False
            return
        if kind == "hello":
            state["last_beat"], state["warned"] = time.time(), False
            say("game: tab opened", DIM)
            return
        if kind == "bye":
            state["last_beat"] = None
            return
    for line in text.rstrip("\n").split("\n"):
        say("game | " + line, RED if kind == "error" else "")


def watch_for_freeze():
    while True:
        time.sleep(1)
        with lock:
            beat = state["last_beat"]
            if beat and not state["warned"] and time.time() - beat > 4:
                state["warned"] = True
                say("game: the tab stopped responding. The game is stuck in a loop that never "
                    "reaches `await asyncio.sleep(0)`. Look at your while loops.", YELLOW)


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def log_message(self, *args):  # keep the terminal for the game's output
        pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_POST(self):
        if self.path != "/__log":
            self.send_error(404)
            return
        body = self.rfile.read(int(self.headers.get("Content-Length", 0) or 0))
        try:
            data = json.loads(body or b"{}")
            handle_log(str(data.get("kind", "log")), str(data.get("text", "")))
        except ValueError:
            pass
        self.send_response(204)
        self.end_headers()

    def do_GET(self):
        if self.path.split("?")[0] in ("/", "/index.html"):
            try:
                with open(os.path.join(WEB_DIR, "index.html"), "rb") as f:
                    page = f.read()
            except OSError:
                self.send_error(404, "No build yet")
                return
            at = page.lower().find(b"<head>")
            page = page[: at + 6] + BRIDGE + page[at + 6:] if at >= 0 else BRIDGE + page
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(page)))
            self.end_headers()
            self.wfile.write(page)
            return
        super().do_GET()


if __name__ == "__main__":
    threading.Thread(target=watch_for_freeze, daemon=True).start()
    server = http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
