#!/usr/bin/env python3
"""Makes site/engine.js from the app's own Clawd page (Resources/clawd.html), so the website
draws the real Clawd with the app's current animations. Run it again when they change:

    python3 site/sync-engine.py

It keeps the drawing code and every animation, and leaves out the part that only the app needs
(picking animations for Swift). shell.js does that part for the website.
"""
import pathlib

root = pathlib.Path(__file__).resolve().parent.parent
page = (root / "Resources/clawd.html").read_text()
body = page[page.index("<script>") + len("<script>"):page.rindex("</script>")]
cut = body.index("/* Called from Swift when something good or bad just happened")
engine = body[:cut].rstrip() + "\n"
out = "/* Made by sync-engine.py from the app's Resources/clawd.html. Don't edit by hand. */\n" + engine.lstrip("\n")
(root / "site/engine.js").write_text(out)
print(f"engine.js: {len(out) // 1024} KB, {engine.count(chr(10) + 'def(') + engine.count(chr(10) + 'defNew(')} animations")
