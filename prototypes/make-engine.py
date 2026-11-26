#!/usr/bin/env python3
"""Makes prototypes/clawd-engine.js from the app's own Clawd page (Resources/clawd.html),
so the prototypes show the real Clawd and his real animations.

The app's page draws one Clawd on one canvas. A prototype page shows many at once, so this
wraps the same drawing code in a function that can be started once per canvas:

    const clawd = makeClawd(canvas, said => { ... });   // said: { word, mode, anim }
    clawd.setColor("#D97757"); clawd.setMode("working"); clawd.celebrate("hop");

Run it again whenever Resources/clawd.html changes:  python3 prototypes/make-engine.py
"""
import pathlib, re

root = pathlib.Path(__file__).resolve().parent.parent
page = (root / "Resources/clawd.html").read_text()
body = page[page.index("<script>") + len("<script>"):page.rindex("</script>")]

def swap(old, new, count=1):
    global body
    assert body.count(old) == count, (body.count(old), old)
    body = body.replace(old, new)

# What Swift calls on the page becomes what the prototype calls on one Clawd.
for name in ["setOutfit", "celebrate", "setMode", "setColor", "nextStep", "setAnim", "setCalm"]:
    swap(f"window.{name} = ", f"api.{name} = ")

# The canvas is handed in, and sized by the page's own CSS (drawn as sharp as the app draws it).
swap('const cv = document.getElementById("c");\n', "")
size = body[body.index("function size() {"):body.index("function tell(word) {")]
swap(size, """function size() {
  const dpr = window.devicePixelRatio || 1;
  const s = (cv.clientWidth || SW) / SW;
  cv.width = Math.round(SW * s * dpr); cv.height = Math.round(SH * s * dpr);
  cv._s = s * dpr; cv._w = cv.clientWidth;
}
""")

# Clawd tells whoever started him what he's doing, instead of telling Swift.
tell = body[body.index("function tell(word) {"):body.index("/* Nothing running: hobbies all day.")]
swap(tell, """function tell(word) {
  if (said) said({ word, mode, anim: current.id });
}
""")

# The settings preview's messages aren't used here.
listener = body[body.index("/* The settings preview talks to us with messages"):body.index("function frame(t) {")]
swap(listener, "")

# Stop drawing once the canvas has left the page, and follow its size.
swap("function frame(t) {\n", "function frame(t) {\n  if (!cv.isConnected) return;\n  if (cv.clientWidth !== cv._w) size();\n")
swap('addEventListener("resize", size);\n', "")

assert "window.webkit" not in body and "document." not in body, "something still reaches outside its canvas"
out = ("/* Made by prototypes/make-engine.py from Resources/clawd.html. Don't edit by hand. */\n"
       "window.makeClawd = function (cv, said) {\nconst api = {};\n" + body.strip() + "\nreturn api;\n};\n")
(root / "prototypes/clawd-engine.js").write_text(out)
animations = len(re.findall(r"^def(?:New)?[(]", body, re.M))
print(f"clawd-engine.js: {len(out) // 1024} KB, {animations} animations")
