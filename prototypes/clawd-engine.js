/* Made by prototypes/make-engine.py from Resources/clawd.html. Don't edit by hand. */
window.makeClawd = function (cv, said) {
const api = {};
/* Clawd's drawing engine (from the contact sheet) */
/* =====================================================================
   Pixel engine
   Units: 1 unit = 1 square pixel. Clawd's own pixels are 1 wide x 2 tall,
   like the block characters in the Claude Code terminal logo.
   Every animation draws into a 40 x 26 unit stage. Ground is at y = 22.
   ===================================================================== */
let CL = "#D97757"; const EYE = "#141413", WOOD = "#a0764e", METAL = "#b4b2a9", GLASS = "#d3d1c7";
const SW = 40, SH = 26, X0 = 12, Y0 = 12;

const R = (c, x, y, w, h, col) => { c.fillStyle = col; c.fillRect(Math.round(x), Math.round(y), w, h); };
const st = (t, fps, n) => Math.floor(t * fps) % n;                // frame index
const rnd = i => { const s = Math.sin(i * 127.1) * 43758.5453; return s - Math.floor(s); };
function line(c, x0, y0, x1, y1, col) {
  x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
  const dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
  let e = dx + dy;
  for (;;) { R(c, x0, y0, 1, 1, col); if (x0 === x1 && y0 === y1) break;
    const e2 = 2 * e; if (e2 >= dy) { e += dy; x0 += sx; } if (e2 <= dx) { e += dx; y0 += sy; } }
}
function glyph(c, map, x, y, col) {
  map.forEach((row, j) => [...row].forEach((ch, i) => { if (ch === "#") R(c, x + i, y + j, 1, 1, col); }));
}
const G = {
  bang:  ["#", "#", "#", ".", "#"],
  q:     ["###", "..#", ".##", "...", ".#."],
  z:     ["###", "..#", ".#.", "#..", "###"],
  heart: [".#.#.", "#####", "#####", ".###.", "..#.."],
  heartS:["#.#", "###", ".#."],
  star:  [".#.", "###", ".#."],
  note:  ["..##", "..#.", "..#.", "###.", "##.."],
  bulb:  [".###.", "#####", "#####", "#####", ".###."],
  bulbBase: ["###", ".#."],
  trophy:["#######", "#.###.#", ".#####.", "..###..", "...#...", "..###.."],
  bell:  ["..#..", ".###.", ".###.", "#####", "#####", "..#.."],
  cloud: [".##.##.", "#######", "#######"],
  globe: [".####.", "######", "######", "######", "######", ".####."],
  puff:  [".##.", "####", ".##."],
  arrR:  ["#..", ".#.", "..#", ".#.", "#.."],
  arrL:  ["..#", ".#.", "#..", ".#.", "..#"],
  fish:  ["#.###.", "######", "#.###."],
  check: ["....#", "...#.", "#.#..", ".#..."],
};
const LAND = ["##...#..", ".###..#.", "..##.###", "...#..##", "#.....#.", "##....#."];

/* Clawd, from the terminal logo:  ▐▛███▜▌ / ▝▜█████▛▘ / ▘▘ ▝▝
   o.eyes: open closed happy left right up down wide x heart
   o.armL / o.armR: out up down none
   o.legs: 0 standing, 1 / 2 one pair lifted, 3 all tucked, "none" sitting
   o.squash: 0..6 flattens the body (it also gets wider) */
function clawd(c, x, y, o = {}) {
  x = Math.round(x); y = Math.round(y);
  const col = o.color || CL, sq = o.squash || 0, wd = Math.floor(sq / 2), top = y + sq;
  if (o.legs !== "none") {
    const lift = o.legs || 0;
    [[3, 1], [5, 2], [10, 1], [12, 2]].forEach(([lx, p]) => {
      const up = lift === p || lift === 3;
      R(c, x + lx, y + 8, 1, up ? 1 : 2, col);
    });
  }
  R(c, x + 2 - wd, top, 12 + wd * 2, y + 8 - top, col);
  const armY = top + Math.round((8 - sq) / 2);
  arm(c, x - wd, armY, o.armL || "out", col);
  arm(c, x + 14 + wd, armY, o.armR || "out", col);
  eyes(c, x, top + Math.max(0, 2 - Math.floor(sq / 3)), o.eyes || "open");
  if (OUTFIT) hat(c, x, top, OUTFIT);
}
/* Seasonal outfits, set from Swift: a hat on top of Clawd's head. */
let OUTFIT = null;
api.setOutfit = o => { OUTFIT = o || null; };
function hat(c, x, top, kind) {
  const r = (dx, dy, w, h, col) => R(c, x + dx, top + dy, w, h, col);
  if (kind === "santa") {          // red, floppy to the right, white brim and bobble
    r(3, -1, 10, 1, "#f5f4ed");
    r(4, -2, 8, 1, "#E24B4A"); r(5, -3, 6, 1, "#E24B4A"); r(7, -4, 5, 1, "#E24B4A"); r(10, -5, 3, 1, "#E24B4A");
    r(13, -6, 2, 2, "#f5f4ed");
  } else if (kind === "party") {   // a striped cone with a pom-pom
    r(8, -1, 5, 1, "#ED93B1"); r(9, -2, 3, 1, "#FAC775"); r(9, -3, 3, 1, "#ED93B1");
    r(10, -4, 1, 1, "#FAC775"); r(9, -6, 3, 2, "#85B7EB");
  } else if (kind === "witch") {   // purple, wide brim, orange band, bent tip
    r(2, -1, 12, 1, "#7F77DD"); r(5, -2, 6, 1, "#EF9F27"); r(6, -3, 4, 1, "#7F77DD");
    r(7, -4, 3, 1, "#7F77DD"); r(8, -5, 2, 1, "#7F77DD"); r(9, -6, 2, 1, "#7F77DD");
  }
}
function arm(c, ax, ay, mode, col) {
  if (mode === "out") R(c, ax, ay, 2, 2, col);
  else if (mode === "up") R(c, ax, ay - 5, 2, 6, col);
  else if (mode === "down") R(c, ax, ay + 2, 2, 2, col);
}
function eyes(c, x, eY, mode) {
  [x + 4, x + 11].forEach(e => {
    const d = (dx, dy, w = 1, h = 1, col = EYE) => R(c, e + dx, eY + dy, w, h, col);
    switch (mode) {
      case "closed": d(0, 1); break;
      case "happy":  d(-1, 1); d(0, 0); d(1, 1); break;
      case "left":   d(-1, 0, 1, 2); break;
      case "right":  d(1, 0, 1, 2); break;
      case "up":     d(0, -1, 1, 2); break;
      case "down":   d(0, 1, 1, 2); break;
      case "wide":   d(0, -1, 1, 3); break;
      case "x":      d(-1, -1); d(1, -1); d(0, 0); d(-1, 1); d(1, 1); break;
      case "shades": if (e === x + 4) { R(c, x + 3, eY, 3, 2, EYE); R(c, x + 6, eY, 4, 1, EYE); } else R(c, x + 10, eY, 3, 2, EYE); break;
      case "none":   break;
      case "heart":  ["#.#", "###", ".#."].forEach((r, j) => [...r].forEach((ch, i) => { if (ch === "#") d(i - 1, j - 1, 1, 1, "#E24B4A"); })); break;
      default:       d(0, 0, 1, 2);
    }
  });
}
function mini(c, x, y, f) {   // a small helper Clawd, 8 x 5
  glyph(c, [".######.", ".#.##.#.", "########", ".######."], x, y, CL);
  R(c, x + 2, y + 1, 1, 1, EYE); R(c, x + 5, y + 1, 1, 1, EYE);
  glyph(c, f ? ["..#..#.."] : [".#....#."], x, y + 4, CL);
}
function alpha(c, a, fn) { c.globalAlpha = Math.max(0, Math.min(1, a)); fn(); c.globalAlpha = 1; }

/* =====================================================================
   Animations
   ===================================================================== */
const GROUPS = [
  ["working",  "Working"],
  ["thinking", "Thinking"],
  ["waiting",  "Needs you"],
  ["done",     "Done"],
  ["error",    "Something went wrong"],
  ["idle",     "Idle"],
];
const A = [];
const def = (id, name, group, when, draw) => A.push({ id, name, group, when, draw });

/* ---------- Working ---------- */
def("walk", "Pacing", "working", "Working (default)", (c, t) => {
  const a = t * 1.3, f = st(t, 6, 2);
  clawd(c, X0 + Math.round(Math.sin(a) * 9), Y0 - f, { legs: f + 1, eyes: Math.cos(a) > 0 ? "right" : "left" });
});

def("type", "Typing", "working", "Edit, Write", (c, t) => {
  const f = st(t, 8, 2), X = X0, Y = Y0;
  clawd(c, X, Y, { eyes: "down", armL: f ? "out" : "down", armR: f ? "down" : "out" });
  for (let i = 0; i < 3; i++) { const p = (t * 1.2 + i / 3) % 1; alpha(c, 1 - p, () => R(c, X + 5 + i * 3, Y + 3 - Math.round(p * 10), 1, 1, "#85B7EB")); }
  R(c, X + 3, Y + 4, 10, 4, "#c2c0b6"); R(c, X + 7, Y + 5, 2, 1, "#9a9a95"); R(c, X + 1, Y + 8, 14, 1, "#888780");
});

def("read", "Reading", "working", "Read", (c, t) => {
  const X = X0, Y = Y0;
  clawd(c, X, Y, { eyes: st(t, 1.5, 2) ? "right" : "left" });
  R(c, X + 1, Y + 5, 1, 4, "#378ADD"); R(c, X + 14, Y + 5, 1, 4, "#378ADD");
  R(c, X + 2, Y + 4, 12, 5, "#f5f4ed"); R(c, X + 7, Y + 4, 2, 5, "#d3d1c7");
  for (let k = 0; k < 2; k++) { R(c, X + 3, Y + 5 + k * 2, 3, 1, "#b4b2a9"); R(c, X + 10, Y + 5 + k * 2, 3, 1, "#b4b2a9"); }
  const p = t % 2.5; if (p < 0.35) R(c, X + 9 - Math.round(p / 0.35 * 6), Y + 3, 5, 1, "#ffffff");
});

def("search", "Searching", "working", "Grep, Glob", (c, t) => {
  const X = 8, Y = Y0;
  clawd(c, X, Y, { eyes: "right" });
  const gx = X + 17 + Math.round(Math.sin(t * 2.2) * 3), gy = Y - 1 + Math.round(Math.cos(t * 4.4));
  R(c, gx - 1, gy + 5, 1, 1, WOOD); R(c, gx - 2, gy + 6, 1, 1, WOOD);
  R(c, gx + 1, gy, 3, 1, GLASS); R(c, gx + 1, gy + 4, 3, 1, GLASS); R(c, gx, gy + 1, 1, 3, GLASS); R(c, gx + 4, gy + 1, 1, 3, GLASS);
  alpha(c, .45, () => R(c, gx + 1, gy + 1, 3, 3, "#6fa8ff"));
  if (t % 3 > 2.5) glyph(c, G.star, gx + 5, gy - 3, "#FAC775");
});

def("dig", "Digging", "working", "Exploring a codebase", (c, t) => {
  const X = 6, Y = Y0, p = t % 1, down = p < 0.5;
  R(c, 0, 22, 40, 1, "#444441"); R(c, 26, 22, 6, 1, EYE);
  R(c, 33, 20, 5, 2, "#6b4423"); R(c, 34, 19, 3, 1, "#6b4423");
  clawd(c, X, Y - (down ? 0 : 1), { eyes: "right", armR: down ? "down" : "out" });
  if (down) { line(c, X + 16, Y + 6, X + 21, Y + 9, WOOD); R(c, X + 21, Y + 9, 2, 2, METAL); }
  else {
    line(c, X + 16, Y + 5, X + 20, Y + 1, WOOD); R(c, X + 20, Y, 2, 2, METAL);
    const q = (p - 0.5) * 2;
    for (let i = 0; i < 4; i++) R(c, X + 21 + q * 10 + i * 1.5, Y + 1 - Math.sin(q * Math.PI) * 5 + i, 1, 1, "#8a5a2b");
  }
});

def("hammer", "Hammering", "working", "Bash, running commands", (c, t) => {
  const X = 8, Y = Y0, f = st(t, 5, 3);
  R(c, 27, 19, 6, 3, "#5F5E5A"); R(c, 28, 18, 4, 1, "#888780");
  clawd(c, X, Y + (f === 2 ? 1 : 0), { eyes: "right", armR: f === 0 ? "up" : "out", squash: f === 2 ? 1 : 0 });
  if (f === 0) { line(c, X + 15, Y + 2, X + 16, Y - 2, WOOD); R(c, X + 15, Y - 5, 4, 3, METAL); }
  else if (f === 1) { line(c, X + 16, Y + 5, X + 19, Y + 2, WOOD); R(c, X + 19, Y, 3, 3, METAL); }
  else {
    line(c, X + 16, Y + 6, X + 20, Y + 6, WOOD); R(c, X + 20, Y + 3, 3, 3, METAL);
    [[24, 14], [29, 13], [33, 15], [26, 12]].forEach(([a, b]) => R(c, a, b, 1, 1, "#FAC775"));
  }
});

def("run", "Sprinting", "working", "Long-running task", (c, t) => {
  const X = 14, Y = Y0, f = st(t, 12, 2);
  for (let i = 0; i < 3; i++) R(c, ((-t * 40 + i * 11) % 24 + 24) % 24 - 12, Y + 1 + i * 3, 5, 1, "#5f5e5a");
  const d = (t * 3) % 1; alpha(c, 1 - d, () => R(c, X - 2 - d * 4, Y + 9 - d * 2, 2, 1, "#888780"));
  clawd(c, X, Y - f, { legs: f + 1, eyes: "right", armL: f ? "out" : "down", armR: f ? "down" : "out" });
});

def("juggle", "Juggling", "working", "Lots of to-dos", (c, t) => {
  const f = st(t, 4, 2), cols = ["#5DCAA5", "#85B7EB", "#F0997B"];
  clawd(c, X0, Y0, { eyes: "up", armL: f ? "up" : "out", armR: f ? "out" : "up" });
  for (let i = 0; i < 3; i++) { const a = t * 2.2 + i * 2.094; R(c, 19 + Math.cos(a) * 8, Y0 - 5 - Math.abs(Math.sin(a)) * 6, 2, 2, cols[i]); }
});

def("spawn", "Sending helpers", "working", "Subagents", (c, t) => {
  let pop = false;
  for (let k = 0; k < 2; k++) {
    const p = ((t + k * 1.6) % 3.2) / 3.2, dir = k ? 1 : -1;
    if (p < 0.15) pop = true;
    mini(c, Math.round(16 + dir * (4 + p * 26)), Math.round(17 - (p < 0.25 ? Math.sin(p / 0.25 * Math.PI) * 5 : 0)), st(t, 6, 2));
  }
  clawd(c, X0, Y0, { eyes: pop ? "happy" : "open", armL: pop ? "up" : "out", armR: pop ? "up" : "out" });
});

def("web", "Browsing", "working", "WebFetch, WebSearch", (c, t) => {
  const X = 8, Y = Y0, gx = X + 16, gy = Y - 7, sh = Math.floor(t * 4);
  clawd(c, X, Y, { eyes: "right", armR: "up" });
  for (let v = 0; v < 6; v++) for (let u = 0; u < 6; u++) {
    if (G.globe[v][u] !== "#") continue;
    R(c, gx + u, gy + v, 1, 1, LAND[v][(u + sh) % 8] === "#" ? "#5DCAA5" : "#378ADD");
  }
});

def("test", "Experimenting", "working", "Running tests", (c, t) => {
  const X = 6, Y = Y0, liq = (t % 4) > 3 ? "#AFA9EC" : "#5DCAA5";
  clawd(c, X, Y, { eyes: "right" });
  R(c, 25, 11, 2, 3, GLASS); R(c, 23, 14, 6, 7, GLASS); R(c, 24, 16, 4, 4, liq);
  for (let i = 0; i < 3; i++) { const p = (t * 1.1 + i / 3) % 1; alpha(c, 1 - p, () => R(c, 25 + (i % 2), 10 - Math.round(p * 8), 1, 1, liq)); }
  if ((t % 4) > 3.6) glyph(c, G.puff, 24, 4, "#d3d1c7");
});

def("paint", "Designing", "working", "UI and design work", (c, t) => {
  const X = 4, Y = Y0;
  line(c, 25, 16, 23, 22, WOOD); line(c, 34, 16, 36, 22, WOOD); R(c, 24, 6, 12, 10, "#f5f4ed");
  const S = [[26, 8, 4, 2, "#F0997B"], [30, 9, 4, 3, "#85B7EB"], [26, 11, 3, 3, "#5DCAA5"], [29, 13, 5, 2, "#FAC775"], [33, 7, 2, 3, "#AFA9EC"]];
  const n = Math.floor((t % 3.5) / 0.6);
  for (let i = 0; i < Math.min(n, 5); i++) R(c, ...S[i].slice(0, 4), S[i][4]);
  const cur = S[Math.min(n, 4)], bx = cur[0] + Math.round(Math.sin(t * 10)), by = cur[1];
  clawd(c, X, Y, { eyes: "right", armR: "up" });
  line(c, X + 16, Y + 1, bx, by, WOOD); R(c, bx, by, 1, 1, cur[4]);
});

def("sweep", "Tidying up", "working", "Refactors and cleanup", (c, t) => {
  const X = 8, Y = Y0, bx = Math.round(25 + Math.sin(t * 5) * 4);
  clawd(c, X, Y, { eyes: "down", armR: "down" });
  line(c, X + 16, Y + 6, bx, Y + 9, WOOD); R(c, bx - 1, Y + 9, 4, 1, "#EF9F27"); R(c, bx - 1, Y + 8, 3, 1, "#BA7517");
  for (let i = 0; i < 3; i++) { const p = (t * 2 + i / 3) % 1; alpha(c, 1 - p, () => R(c, bx + 3 + p * 6, Y + 9 - p * 3 - i, 1, 1, "#888780")); }
});

def("lift", "Heavy lifting", "working", "Big builds", (c, t) => {
  const X = X0, Y = Y0, p = (t % 3.2) / 3.2;
  // bar rests on the floor, a little squat, heave it overhead, wobble, drop it
  const up = p < 0.28 ? 0 : p < 0.38 ? (p - 0.28) / 0.1 : p < 0.82 ? 1 : p < 0.88 ? 1 - (p - 0.82) / 0.06 : 0;
  const hold = up === 1, squat = p > 0.16 && p < 0.28, shake = hold && p > 0.6 ? st(t, 12, 2) : 0;
  const by = Math.round(Y + 7 - up * 9) - (p >= 0.88 && p < 0.92 ? 1 : 0);
  const arms = up > 0.5 ? "up" : up > 0 ? "out" : "down";
  clawd(c, X + shake, Y, { eyes: hold || squat ? "closed" : up > 0 ? "up" : p >= 0.88 ? "happy" : "down", armL: arms, armR: arms, squash: squat ? 2 : 0 });
  R(c, X - 4 + shake, by, 24, 1, "#888780"); R(c, X - 5 + shake, by - 2, 2, 5, "#444441"); R(c, X + 19 + shake, by - 2, 2, 5, "#444441");
  if (hold) R(c, X + 13, Y + 2 + Math.round(((t * 1.5) % 1) * 6), 1, 1, "#85B7EB");
  if (p >= 0.88 && p < 0.97) { const q = (p - 0.88) / 0.09; alpha(c, 1 - q, () => { R(c, X - 8 - q * 2, 21, 2, 1, "#888780"); R(c, X + 22 + q * 2, 21, 2, 1, "#888780"); }); }
});

def("compact", "Squishing memory", "working", "Compacting the conversation", (c, t) => {
  const X = X0, Y = Y0, p = (t % 3) / 3;
  const sq = p < 0.35 ? Math.round(p / 0.35 * 6) : p < 0.6 ? 6 : 0;
  const hop = p >= 0.6 && p < 0.72 ? 2 : 0;
  clawd(c, X, Y - hop, { squash: sq, eyes: sq > 3 ? "closed" : "open" });
  if (p < 0.6) { const ax = Math.round(Math.min(1, p / 0.35) * 3); glyph(c, G.arrR, X - 9 + ax, Y + 4, "#888780"); glyph(c, G.arrL, X + 22 - ax, Y + 4, "#888780"); }
});

def("stack", "Stacking blocks", "working", "Step-by-step builds", (c, t) => {
  const X = 6, Y = Y0, cols = ["#F0997B", "#85B7EB", "#5DCAA5", "#FAC775", "#AFA9EC"];
  const T = t % 4.2, n = Math.min(5, Math.floor(T / 0.7));
  for (let i = 0; i < n; i++) R(c, 27 + (i % 2), 19 - i * 3, 6, 3, cols[i]);
  if (n < 5) { const q = Math.min(1, ((T % 0.7) / 0.7) * 1.4), ty = 19 - n * 3; R(c, 27 + (n % 2), Math.round(-3 + (ty + 3) * q), 6, 3, cols[n]); }
  clawd(c, X, Y, { eyes: n > 2 ? "up" : "right", armR: st(t, 3, 2) ? "up" : "out" });
});

def("carry", "Shipping it", "working", "git commit, push", (c, t) => {
  const a = t * 1.1, x = X0 + Math.round(Math.sin(a) * 8), f = st(t, 6, 2), Y = Y0 + 1 - f;
  clawd(c, x, Y, { legs: f + 1, armL: "up", armR: "up", eyes: Math.cos(a) > 0 ? "right" : "left" });
  R(c, x, Y - 6, 16, 5, "#BA7517"); R(c, x + 7, Y - 6, 2, 5, "#EF9F27");
});

/* ---------- Thinking ---------- */
def("ponder", "Pondering", "thinking", "Thinking", (c, t) => {
  const X = X0, Y = Y0;
  clawd(c, X + Math.round(Math.sin(t * 0.8)), Y, { eyes: st(t, 0.8, 2) ? "up" : "left" });
  const n = st(t, 2.5, 4);
  for (let i = 0; i < n; i++) R(c, X + 15 + i * 3, Y - 2 - i * 3, i + 1, i + 1, "#d3d1c7");
});

def("idea", "Eureka", "thinking", "Found the answer", (c, t) => {
  const X = X0, Y = Y0, p = (t % 3) / 3, lit = p > 0.5, hop = p > 0.5 && p < 0.62 ? 2 : 0;
  clawd(c, X, Y - hop, { eyes: lit ? "wide" : "up", armR: lit ? "up" : "out" });
  glyph(c, G.bulb, X + 6, Y - 10 - hop, lit ? "#FAC775" : "#5f5e5a");
  glyph(c, G.bulbBase, X + 7, Y - 5 - hop, "#888780");
  if (lit && st(t, 6, 2)) [[X + 3, Y - 9], [X + 13, Y - 9], [X + 8, Y - 12], [X + 3, Y - 6], [X + 13, Y - 6]].forEach(([a, b]) => R(c, a, b - hop, 1, 1, "#FAC775"));
});

def("puzzled", "Puzzled", "thinking", "Unsure, re-planning", (c, t) => {
  const X = X0, Y = Y0, f = st(t, 1.2, 2);
  clawd(c, X, Y, { eyes: f ? "left" : "right", armL: f ? "up" : "out", armR: f ? "up" : "out" });
  glyph(c, G.q, X + 7, Y - 8 + st(t, 2, 2), "#f5f4ed");
});

def("plan", "Making a plan", "thinking", "Plan mode", (c, t) => {
  const X = 6, Y = Y0, n = Math.floor((t % 3.2) / 0.8);
  clawd(c, X, Y, { eyes: "right" });
  R(c, 24, 6, 10, 13, "#f5f4ed"); R(c, 27, 5, 4, 2, "#888780");
  for (let i = 0; i < 3; i++) {
    R(c, 26, 9 + i * 3, 2, 2, i < n ? "#5DCAA5" : "#d3d1c7");
    R(c, 29, 9 + i * 3 + 1, 3, 1, "#b4b2a9");
  }
});

/* ---------- Needs you ---------- */
def("jump", "Jumping", "waiting", "Permission request", (c, t) => {
  const p = (t % 1.1) / 1.1;
  let j = 0;
  if (p < 0.3) j = Math.round(Math.sin(p / 0.3 * Math.PI) * 5);
  else if (p > 0.4 && p < 0.55) j = Math.round(Math.sin((p - 0.4) / 0.15 * Math.PI) * 2);
  clawd(c, X0, Y0 - j, { eyes: "wide", legs: j > 0 ? 3 : 0 });
  glyph(c, G.bang, X0 + 7, Y0 - 8 - j, "#f5f4ed");
});

def("wave", "Waving", "waiting", "Asking you a question", (c, t) => {
  const f = st(t, 4, 2), b = st(t, 1, 2) && (t % 1) < 0.25 ? 1 : 0;      // a small hop every other second
  clawd(c, X0, Y0 - b, { eyes: "happy", armR: f ? "up" : "out" });
  if (f) { R(c, X0 + 17, Y0 - 3 - b, 1, 2, "#f5f4ed"); R(c, X0 + 19, Y0 - 1 - b, 1, 2, "#f5f4ed"); }
  else R(c, X0 + 17, Y0 + 1 - b, 2, 1, "#888780");
});

def("knock", "Knock knock", "waiting", "Been waiting a while", (c, t) => {
  const X = 17, Y = Y0, p = t % 1.4, hit = p < 0.15 || (p > 0.3 && p < 0.45);
  R(c, 34, 2, 1, 21, "#5f5e5a");
  clawd(c, X + (hit ? 1 : 0), Y, { eyes: "right", armR: hit ? "out" : "down" });
  if (hit) { R(c, 36, Y + 2, 2, 1, "#f5f4ed"); R(c, 36, Y + 6, 2, 1, "#f5f4ed"); R(c, 37, Y + 4, 2, 1, "#f5f4ed"); }
});

def("sign", "Holding a sign", "waiting", "Needs your approval", (c, t) => {
  const b = st(t, 2, 2), Y = Y0 - b;
  clawd(c, X0, Y, { armL: "up", armR: "up" });
  R(c, X0, Y - 11, 16, 10, "#f5f4ed"); glyph(c, G.q, X0 + 6, Y - 9, CL);
});

def("bell", "Ringing", "waiting", "Notification", (c, t) => {
  const X = 6, Y = Y0, s = st(t, 8, 2) ? 1 : -1;
  clawd(c, X, Y, { eyes: "wide", armR: "up" });
  glyph(c, G.bell, X + 14 + s, Y - 8, "#FAC775");
  if (st(t, 4, 2)) { R(c, X + 22, Y - 8, 1, 2, "#f5f4ed"); R(c, X + 24, Y - 9, 1, 4, "#f5f4ed"); R(c, X + 11, Y - 8, 1, 2, "#f5f4ed"); }
});

/* ---------- Done ---------- */
def("hop", "Happy hop", "done", "Task finished", (c, t) => {
  const p = (t % 1.2) / 1.2, j = p < 0.4 ? Math.round(Math.sin(p / 0.4 * Math.PI) * 4) : 0;
  clawd(c, X0, Y0 - j, { eyes: "happy", armL: j > 2 ? "up" : "out", armR: j > 2 ? "up" : "out", legs: j > 0 ? 3 : 0 });
});

def("confetti", "Confetti", "done", "Big task finished", (c, t) => {
  const T = t % 2.4, cols = ["#F0997B", "#85B7EB", "#5DCAA5", "#FAC775", "#AFA9EC", "#ED93B1"];
  clawd(c, X0, Y0, { eyes: "happy", armL: "up", armR: "up" });
  for (let i = 0; i < 20; i++) {
    const a = -Math.PI * (0.1 + rnd(i) * 0.8), sp = 10 + rnd(i + 40) * 12;
    const x = 20 + Math.cos(a) * sp * T, y = 6 + Math.sin(a) * sp * T + 10 * T * T;
    if (y < SH) R(c, x, y, 1, st(t + i, 6, 2) + 1, cols[i % cols.length]);
  }
});

def("dance", "Dancing", "done", "Celebrating", (c, t) => {
  const f = st(t, 3, 2);
  clawd(c, X0 + (f ? 2 : -2), Y0 - st(t, 6, 2), { eyes: "happy", armL: f ? "up" : "down", armR: f ? "down" : "up", legs: f + 1 });
  for (let i = 0; i < 2; i++) { const p = (t * 0.7 + i / 2) % 1; alpha(c, Math.min(1, (1 - p) * 2), () => glyph(c, G.note, (i ? 32 : 3) + Math.round(Math.sin(p * 6)), Y0 + 2 - Math.round(p * 12), i ? "#85B7EB" : "#FAC775")); }
});

def("trophy", "Trophy", "done", "All tests passing", (c, t) => {
  clawd(c, X0, Y0, { eyes: "happy", armL: "up", armR: "up" });
  glyph(c, G.trophy, X0 + 4, Y0 - 8, "#FAC775"); R(c, X0 + 6, Y0 - 2, 3, 1, "#BA7517");
  const f = st(t, 3, 2); glyph(c, G.star, f ? X0 - 1 : X0 + 14, f ? Y0 - 9 : Y0 - 6, "#f5f4ed");
});

def("party", "Party hat", "done", "Shipped", (c, t) => {
  const f = st(t, 4, 2), Y = Y0 - st(t, 8, 2);
  clawd(c, X0, Y, { eyes: "happy", armL: f ? "up" : "out", armR: f ? "out" : "up" });
  const hx = X0 + 5;
  R(c, hx + 2, Y - 6, 2, 1, "#f5f4ed"); R(c, hx + 2, Y - 5, 2, 1, "#85B7EB"); R(c, hx + 1, Y - 4, 4, 1, "#FAC775");
  R(c, hx + 1, Y - 3, 4, 1, "#85B7EB"); R(c, hx, Y - 2, 6, 1, "#FAC775"); R(c, hx, Y - 1, 6, 1, "#85B7EB");
  for (let i = 0; i < 6; i++) { const p = (t * 0.6 + rnd(i)) % 1; R(c, 2 + rnd(i + 9) * 36, p * 24 - 2, 1, 1, ["#F0997B", "#5DCAA5", "#FAC775"][i % 3]); }
});

/* ---------- Something went wrong ---------- */
def("dizzy", "Dizzy", "error", "Error or crash", (c, t) => {
  const X = X0 + Math.round(Math.sin(t * 3)), Y = Y0;
  clawd(c, X, Y, { eyes: "x" });
  for (let i = 0; i < 2; i++) { const a = t * 4 + i * Math.PI; glyph(c, G.star, X + 7 + Math.round(Math.cos(a) * 7), Y - 4 + Math.round(Math.sin(a) * 2), "#FAC775"); }
});

def("sweat", "Nervous", "error", "Tool failed, retrying", (c, t) => {
  const X = X0 + (st(t, 14, 2) ? 1 : 0), Y = Y0;
  clawd(c, X, Y, { eyes: "wide", armL: "down", armR: "down" });
  for (let i = 0; i < 2; i++) { const p = (t * 0.9 + i / 2) % 1; alpha(c, 1 - p, () => { const sx = i ? X + 15 : X; R(c, sx, Y - 1 + Math.round(p * 8), 1, 2, "#85B7EB"); }); }
});

def("smoke", "Smoking", "error", "Command failed", (c, t) => {
  const X = X0, Y = Y0;
  clawd(c, X, Y, { eyes: "x", color: st(t, 3, 2) ? CL : "#b8644a" });
  for (let i = 0; i < 4; i++) { const p = (t * 0.8 + i / 4) % 1, s = 1 + Math.round(p * 2); alpha(c, Math.min(1, (1 - p) * 1.6), () => R(c, X + 6 + Math.sin(p * 6 + i) * 2, Y - 2 - p * 9, s, s, i % 2 ? "#888780" : "#b4b2a9")); }
});

def("rain", "Bummed", "error", "Rejected or cancelled", (c, t) => {
  const X = X0, Y = Y0;
  clawd(c, X, Y, { eyes: "down", armL: "down", armR: "down" });
  for (let i = 0; i < 4; i++) R(c, X + 3 + i * 3, Y - 6 + ((t * 12 + i * 3) % 6), 1, 1, "#85B7EB");
  glyph(c, G.cloud, X + 4, Y - 10, "#888780"); R(c, X + 3, Y - 8, 1, 1, "#888780"); R(c, X + 11, Y - 8, 1, 1, "#888780");
});

/* ---------- Idle ---------- */
def("sleep", "Sleeping", "idle", "No agents running", (c, t) => {
  clawd(c, X0, Y0 + 2, { eyes: "closed", legs: "none", squash: st(t, 0.7, 2) });
  for (let i = 0; i < 3; i++) { const p = (t * 0.5 + i / 3) % 1; alpha(c, Math.min(1, (1 - p) * 2), () => glyph(c, G.z, 28 + p * 5, 10 - p * 8, "#d3d1c7")); }
});

def("yawn", "Yawn and stretch", "idle", "Just woke up", (c, t) => {
  const p = (t % 4) / 4, s = p > 0.2 && p < 0.55, blink = p > 0.8 && p < 0.83;
  clawd(c, X0, Y0 - (s ? 1 : 0), { eyes: s || blink ? "closed" : "open", armL: s ? "up" : "out", armR: s ? "up" : "out" });
  if (s) R(c, X0 + 7, Y0 + 4, 2, 2, EYE);
});

def("peek", "Peeking in", "idle", "Session starting", (c, t) => {
  const p = (t % 4) / 4;
  const x = p < 0.2 ? -16 + p / 0.2 * 15 : p < 0.75 ? -1 : -1 - (p - 0.75) / 0.25 * 15;
  clawd(c, Math.round(x), Y0, { eyes: p > 0.45 && p < 0.48 ? "closed" : "right" });
  R(c, 0, 0, 3, SH, "#2a2a2d");
});

def("coffee", "Coffee break", "idle", "Idle, waiting", (c, t) => {
  const X = 9, Y = Y0, sip = (t % 3.5) / 3.5 > 0.65, my = sip ? Y : Y + 2;
  clawd(c, X, Y, { eyes: sip ? "closed" : "open" });
  R(c, X + 16, my, 4, 4, "#f5f4ed"); R(c, X + 20, my + 1, 1, 2, "#f5f4ed"); R(c, X + 17, my, 2, 1, "#6b4423");
  for (let i = 0; i < 2; i++) { const q = (t * 0.9 + i / 2) % 1; alpha(c, 1 - q, () => R(c, X + 17 + i * 2 + Math.round(Math.sin(q * 6)), my - 1 - Math.round(q * 6), 1, 1, "#888780")); }
});

def("fish", "Gone fishing", "idle", "Long wait", (c, t) => {
  const X = 2, Y = Y0 + 2, bob = st(t, 1.5, 2), p = t % 6;
  R(c, 0, 22, 22, 4, "#444441"); R(c, 22, 23, 18, 3, "#185FA5");
  for (let i = 0; i < 3; i++) R(c, 22 + ((i * 6 + Math.floor(t * 3)) % 17), 23, 2, 1, "#378ADD");
  clawd(c, X, Y, { legs: "none", eyes: p > 5 ? "wide" : "right", armR: "up" });
  line(c, X + 15, Y - 1, X + 24, Y - 8, WOOD);
  R(c, X + 24, Y - 8, 1, 22 + bob - (Y - 8), "#d3d1c7"); R(c, X + 24, 22 + bob, 1, 1, "#E24B4A");
  if (p > 5.1) { const q = (p - 5.1) / 0.9; glyph(c, G.fish, 30 + q * 4, 22 - Math.sin(q * Math.PI) * 9, "#FAC775"); }
});

def("look", "Looking around", "idle", "Nothing happening", (c, t) => {
  const seq = ["left", "left", "open", "right", "right", "open", "closed", "open"];
  clawd(c, X0, Y0, { eyes: seq[st(t, 2.5, 8)] });
});

def("love", "Love", "idle", "You said thanks", (c, t) => {
  clawd(c, X0, Y0, { eyes: "heart" });
  for (let i = 0; i < 3; i++) { const p = (t * 0.6 + i / 3) % 1, mid = i === 1; alpha(c, Math.min(1, (1 - p) * 2), () => glyph(c, G.heartS, 5 + i * 12 + Math.round(Math.sin(p * 6 + i)), Y0 - (mid ? 4 : 1) - Math.round(p * (mid ? 8 : 11)), "#E24B4A")); }
});

/* =====================================================================
   Batch 2 — more props, more celebrations
   ===================================================================== */
const NEW = new Set();
const defNew = (...args) => { def(...args); NEW.add(args[0]); };
G.plane = ["#....", "###..", "#####"];
G.ball = [".####.", "######", "######", "######", "######", ".####."];
G.balloon = [".##.", "####", "####", ".##."];
G.bubble = [".#.", "#.#", ".#."];
G.bubbleL = [".##.", "#..#", "#..#", ".##."];
G.flower = [".#.", "#.#", ".#."];
function bug(c, x, y, f) {
  glyph(c, f ? ["#...#", ".###.", ".#.#."] : [".#.#.", ".###.", "#...#"], x, y, "#97C459");
  R(c, x + 4, y + 1, 1, 1, "#3B6D11");
}

/* ---------- Working ---------- */
defNew("bugnet", "Bug hunting", "working", "Debugging", (c, t) => {
  const X = 4, Y = Y0, p = (t % 2) / 2, down = p > 0.65;
  bug(c, down ? 28 : Math.round(28 + Math.sin(t * 5) * 5), 19, st(t, 8, 2));
  clawd(c, X, Y, { eyes: down ? "happy" : "right", armR: down ? "out" : "up" });
  if (!down) {
    line(c, X + 15, Y - 1, X + 19, Y - 4, WOOD);
    R(c, X + 19, Y - 8, 5, 1, GLASS); R(c, X + 19, Y - 4, 5, 1, GLASS); R(c, X + 19, Y - 7, 1, 3, GLASS); R(c, X + 23, Y - 7, 1, 3, GLASS);
    alpha(c, .2, () => R(c, X + 20, Y - 7, 3, 3, "#ffffff"));
  } else {
    line(c, X + 16, Y + 4, X + 22, Y + 5, WOOD);
    R(c, 26, 17, 9, 1, GLASS); R(c, 26, 17, 1, 5, GLASS); R(c, 34, 17, 1, 5, GLASS);
    alpha(c, .2, () => R(c, 27, 18, 7, 4, "#ffffff"));
  }
});

defNew("rocket", "Launching", "working", "Deploying", (c, t) => {
  const X = 4, Y = Y0, p = (t % 3) / 3, up = p > 0.4, k = up ? (p - 0.4) / 0.6 : 0, ry = Math.round(15 - k * k * 36);
  R(c, 25, 22, 9, 1, "#5f5e5a");
  if (up && k < 0.6) for (let i = 0; i < 4; i++) { const q = (k * 3 + i / 4) % 1; alpha(c, 1 - q, () => R(c, 28 + (i < 2 ? -1 : 1) * (1 + q * 4) + (i % 2), 20 - q * 2, 2, 2, "#888780")); }
  R(c, 29, ry, 1, 1, "#E24B4A"); R(c, 28, ry + 1, 3, 6, "#f5f4ed"); R(c, 29, ry + 3, 1, 1, "#378ADD");
  R(c, 27, ry + 5, 1, 2, "#E24B4A"); R(c, 31, ry + 5, 1, 2, "#E24B4A");
  if (up) { R(c, 28, ry + 7, 3, 1, "#FAC775"); R(c, 29, ry + 8, 1, 1 + st(t, 12, 2), "#EF9F27"); }
  clawd(c, X, Y, { eyes: up ? "up" : "right", armL: k > 0.3 ? "up" : "out", armR: k > 0.3 ? "up" : "out" });
});

defNew("cook", "Cooking", "working", "Building, compiling", (c, t) => {
  const X = 5, Y = Y0, sx = Math.round(29 + Math.sin(t * 4) * 3);
  for (let i = 0; i < 3; i++) { const q = (t * 0.8 + i / 3) % 1; alpha(c, 1 - q, () => R(c, 27 + i * 3 + Math.round(Math.sin(q * 6 + i)), 14 - Math.round(q * 9), 1, 1, "#888780")); }
  R(c, 25, 17, 9, 5, "#444441"); R(c, 25, 16, 9, 1, "#EF9F27"); R(c, 24, 16, 1, 1, "#888780"); R(c, 34, 16, 1, 1, "#888780");
  R(c, 26 + (Math.floor(t * 4) * 3) % 8, 15, 1, 1, "#FAC775");
  clawd(c, X, Y, { eyes: "right" });
  line(c, X + 16, Y + 4, sx, 15, WOOD);
  R(c, X + 4, Y - 2, 8, 2, "#f5f4ed"); R(c, X + 3, Y - 5, 10, 3, "#f5f4ed");
});

defNew("water", "Growing a feature", "working", "Adding a new feature", (c, t) => {
  const X = 6, Y = Y0, h = Math.min(6, Math.floor((t % 5) / 0.6));
  R(c, 28, 19, 5, 3, "#993C1D"); R(c, 27, 18, 7, 1, "#BA7517");
  if (h > 0) R(c, 30, 18 - h, 1, h, "#639922");
  if (h > 2) R(c, 28, 17 - Math.floor(h / 2), 2, 1, "#97C459");
  if (h > 3) R(c, 31, 16 - Math.floor(h / 2), 2, 1, "#97C459");
  if (h >= 6) { glyph(c, G.flower, 29, 10, "#ED93B1"); R(c, 30, 11, 1, 1, "#FAC775"); }
  clawd(c, X, Y, { eyes: "right" });
  R(c, X + 16, Y + 2, 4, 3, "#85B7EB"); line(c, X + 20, Y + 3, X + 22, Y + 1, "#85B7EB");
  if (h < 6) for (let i = 0; i < 3; i++) { const q = (t * 2 + i / 3) % 1; R(c, X + 22 + (i % 2), Y + 2 + Math.round(q * 5), 1, 1, "#B5D4F4"); }
});

defNew("unpack", "Unpacking", "working", "Installing packages", (c, t) => {
  const X = 5, Y = Y0, cols = ["#F0997B", "#85B7EB", "#5DCAA5"];
  for (let i = 0; i < 3; i++) { const q = (t * 0.8 + i / 3) % 1; if (q < 0.92) R(c, 29 + (i - 1) * q * 7, 16 - Math.sin(q * Math.PI) * 11, 2, 2, cols[i]); }
  R(c, 25, 16, 10, 6, "#BA7517"); R(c, 25, 16, 10, 1, "#854F0B");
  line(c, 25, 16, 23, 13, "#EF9F27"); line(c, 34, 16, 36, 13, "#EF9F27");
  clawd(c, X, Y, { eyes: "right", armR: st(t, 1.6, 2) ? "up" : "out" });
});

defNew("plane", "Sending a message", "working", "Slack, email, MCP tools", (c, t) => {
  const X = 6, Y = Y0, p = (t % 2.2) / 2.2;
  if (p < 0.25) { clawd(c, X, Y, { eyes: "right", armR: "up" }); glyph(c, G.plane, X + 14, Y - 4, "#f5f4ed"); }
  else { const q = (p - 0.25) / 0.75; clawd(c, X, Y, { eyes: "right" }); glyph(c, G.plane, X + 16 + q * 26, Y - 4 - Math.sin(q * Math.PI * 2) * 3 - q * 4, "#f5f4ed"); }
});

defNew("camera", "Snapshot", "working", "Screenshots, checking the page", (c, t) => {
  const X = X0, Y = Y0, p = t % 2.4, flash = p > 2.0 && p < 2.3;
  clawd(c, X, Y, { eyes: flash ? "closed" : "open" });
  R(c, X + 3, Y + 3, 10, 5, "#444441"); R(c, X + 10, Y + 2, 2, 1, "#888780");
  R(c, X + 6, Y + 4, 4, 3, "#888780"); R(c, X + 7, Y + 5, 2, 1, "#378ADD");
  if (flash) {                                                            // a burst from the flash bulb, not the whole stage
    const q = (p - 2.0) / 0.3, fx = X + 11, fy = Y + 1;
    alpha(c, 1 - q * 0.6, () => { R(c, fx - 2, fy, 5, 1, "#ffffff"); R(c, fx, fy - 2, 1, 5, "#ffffff"); R(c, fx - 1, fy - 1, 3, 3, "#ffffff"); });
    alpha(c, 1 - q, () => { for (let i = 0; i < 8; i++) { const a = i * Math.PI / 4, r = 4 + q * 5; R(c, fx + Math.cos(a) * r, fy + Math.sin(a) * r, 1, 1, "#FAC775"); } });
  }
});

defNew("wand", "Magic refactor", "working", "Refactoring", (c, t) => {
  const X = 5, Y = Y0, p = (t % 3) / 3;
  if (p < 0.45) for (let i = 0; i < 10; i++) R(c, 26 + rnd(i) * 8 + (st(t, 4, 2) && i % 3 === 0 ? 1 : 0), 13 + rnd(i + 20) * 8, 1 + (i % 2), 1, ["#888780", "#5f5e5a", "#b4b2a9"][i % 3]);
  else if (p < 0.6) { const r = (p - 0.45) / 0.15 * 6; for (let i = 0; i < 6; i++) { const a = i * Math.PI / 3 + t * 3; R(c, 30 + Math.cos(a) * r, 17 + Math.sin(a) * r, 1, 1, "#FAC775"); } }
  else { R(c, 27, 14, 6, 6, "#5DCAA5"); R(c, 28, 15, 4, 4, "#9FE1CB"); if (st(t, 3, 2)) R(c, 34, 13, 1, 1, "#f5f4ed"); }
  clawd(c, X, Y, { eyes: p > 0.45 && p < 0.6 ? "wide" : "right", armR: "up" });
  line(c, X + 15, Y - 1, X + 18, Y - 4, "#444441"); R(c, X + 18, Y - 5, 1, 1, "#FAC775");
  R(c, X + 17 + st(t, 6, 3), Y - 7 + st(t, 5, 2), 1, 1, "#FAC775");
});

defNew("telescope", "Stargazing", "working", "Researching", (c, t) => {
  const X = 4, Y = Y0;
  for (let i = 0; i < 6; i++) if (st(t + i * 0.37, 2, 2)) R(c, 22 + rnd(i) * 16, 1 + rnd(i + 7) * 7, 1, 1, "#f5f4ed");
  if (t % 4 > 3.2) { const q = (t % 4 - 3.2) / 0.8; R(c, 38 - q * 14, 1 + q * 5, 2, 1, "#FAC775"); }
  line(c, 22, 11, 19, 22, WOOD); line(c, 22, 11, 25, 22, WOOD);
  clawd(c, X, Y, { eyes: "right" });
  line(c, X + 13, Y + 2, X + 22, Y - 4, "#b4b2a9"); line(c, X + 13, Y + 3, X + 22, Y - 3, "#888780"); R(c, X + 22, Y - 6, 2, 4, "#b4b2a9");
});

/* ---------- Thinking ---------- */
defNew("chess", "Weighing options", "thinking", "Comparing approaches", (c, t) => {
  const X = 4, Y = Y0, k = Math.floor(t / 1.2) % 3, q = (t % 1.2) / 1.2, moving = q > 0.5;
  for (let i = 0; i < 6; i++) R(c, 24 + i * 2, 20, 2, 2, i % 2 ? "#f5f4ed" : "#5f5e5a");
  R(c, 24, 22, 12, 1, "#444441");
  R(c, 35, 17, 1, 3, "#E24B4A"); R(c, 34, 19, 3, 1, "#E24B4A");
  const sx = 25 + k * 2 + (moving ? Math.round(2 * Math.min(1, (q - 0.5) * 3)) : 0), lift = q > 0.5 && q < 0.8 ? 3 : 0;
  R(c, sx, 17 - lift, 1, 2, "#FAC775"); R(c, sx - 1, 19 - lift, 3, 1, "#FAC775");
  clawd(c, X, Y, { eyes: moving ? "right" : "down", armR: moving ? "up" : "out" });
});

defNew("crystal", "Seeing the future", "thinking", "Planning ahead", (c, t) => {
  const X = 4, Y = Y0;
  R(c, 26, 19, 7, 3, "#BA7517"); R(c, 27, 18, 5, 1, "#854F0B");
  glyph(c, G.ball, 26, 12, "#7F77DD");
  for (let i = 0; i < 3; i++) { const a = t * 3 + i * 2.09; R(c, 28.5 + Math.cos(a) * 2, 14.5 + Math.sin(a) * 1.5, 1, 1, "#EEEDFE"); }
  if (st(t, 3, 2)) { R(c, 25, 11, 1, 1, "#AFA9EC"); R(c, 33, 13, 1, 1, "#AFA9EC"); } else { R(c, 33, 10, 1, 1, "#AFA9EC"); }
  clawd(c, X, Y, { eyes: "wide" });
});

defNew("board", "Working it out", "thinking", "A hard problem", (c, t) => {
  const X = 3, Y = Y0, n = Math.min(36, Math.floor((t % 6) * 9));
  R(c, 22, 4, 16, 13, "#f5f4ed"); R(c, 22, 17, 16, 1, "#888780");
  line(c, 24, 18, 23, 22, "#888780"); line(c, 36, 18, 37, 22, "#888780");
  let lx = 24, ly = 6;
  for (let k = 0; k < n; k++) {
    const row = Math.floor(k / 12); lx = 24 + (k % 12);
    ly = 6 + row * 4 + (rnd(k + row * 3) > 0.6 ? 1 : 0) - (rnd(k * 1.7) > 0.85 ? 1 : 0);
    R(c, lx, ly, 1, 1, row === 2 ? "#E24B4A" : "#185FA5");
  }
  clawd(c, X, Y, { eyes: "right", armR: "up" });
  R(c, lx + 1, ly - 2, 1, 3, "#444441");
});

/* ---------- Needs you ---------- */
defNew("megaphone", "Calling you", "waiting", "Needs you now", (c, t) => {
  const X = 6, Y = Y0, f = st(t, 6, 3);
  clawd(c, X, Y, { eyes: "wide" });
  for (let i = 0; i < 6; i++) R(c, X + 15 + i, Y + 3 - Math.floor(i / 2), 1, 2 + 2 * Math.floor(i / 2), i > 3 ? "#E24B4A" : "#f5f4ed");
  for (let k = 0; k <= f; k++) { const h = 4 + k * 3; R(c, X + 23 + k * 3, Y + 4 - Math.floor(h / 2), 1, h, "#f5f4ed"); }
});

defNew("flag", "Flagging you down", "waiting", "Waiting on your answer", (c, t) => {
  const X = 8, Y = Y0, px = X + 16;
  clawd(c, X, Y, { eyes: "happy", armR: "up" });
  R(c, px, Y - 10, 1, 14, "#888780");
  for (let col = 0; col < 8; col++) R(c, px + 1 + col, Y - 10 + Math.round(Math.sin(t * 8 - col * 0.8)), 1, 5, "#E24B4A");
});

defNew("flagjump", "Jumping flag", "waiting", "Needs you", (c, t) => {
  // The flag-waver from "Flagging you down", hopping like "Jumping"
  const X = 8, p = (t % 1.1) / 1.1;
  let j = 0;
  if (p < 0.3) j = Math.round(Math.sin(p / 0.3 * Math.PI) * 5);
  else if (p > 0.4 && p < 0.55) j = Math.round(Math.sin((p - 0.4) / 0.15 * Math.PI) * 2);
  const Y = Y0 - j, px = X + 16;
  clawd(c, X, Y, { eyes: "wide", armR: "up", legs: j > 0 ? 3 : 0 });
  R(c, px, Y - 10, 1, 14, "#888780");
  for (let col = 0; col < 8; col++) R(c, px + 1 + col, Y - 10 + Math.round(Math.sin(t * 8 - col * 0.8)), 1, 5, "#E24B4A");
});

defNew("tapfoot", "Tapping his foot", "waiting", "Still waiting on you", (c, t) => {
  // Impatient: taps a foot, glances at you, and there's a ticking clock
  const X = X0 - 2, Y = Y0, tap = st(t, 5, 2), glance = (t % 3) < 1.2;
  clawd(c, X, Y, { eyes: glance ? "right" : "down", armL: "down", legs: tap ? 2 : 0 });
  if (!tap) { R(c, X + 15, Y + 9, 1, 1, "#d3d1c7"); R(c, X + 16, Y + 8, 1, 1, "#d3d1c7"); }
  const cx = X + 20, cy = Y - 8;
  glyph(c, [".###.", "#...#", "#...#", "#...#", ".###."], cx, cy, "#f5f4ed");
  R(c, cx + 2, cy + 2, 1, 1, "#f5f4ed");
  const [hx, hy] = [[2, 1], [3, 2], [2, 3], [1, 2]][st(t, 2, 4)];
  R(c, cx + hx, cy + hy, 1, 1, "#E24B4A");
});

defNew("nightcap", "Nightcap", "idle", "Late at night", (c, t) => {
  // Bedtime: Clawd dozes in a nightcap under the moon
  const X = X0, Y = Y0 + 2, sq = st(t, 0.7, 2), top = Y + sq, CAP = "#378ADD";
  clawd(c, X, Y, { eyes: "closed", legs: "none", squash: sq });
  R(c, X + 2, top - 1, 12, 1, "#f5f4ed");
  R(c, X + 3, top - 2, 10, 1, CAP); R(c, X + 5, top - 3, 8, 1, CAP);
  R(c, X + 8, top - 4, 6, 1, CAP); R(c, X + 12, top - 5, 3, 1, CAP); R(c, X + 15, top - 4, 1, 2, CAP);
  R(c, X + 15, top - 2, 2, 2, "#f5f4ed");
  glyph(c, [".##.", "#...", "#...", ".##."], 3, 2, "#FAC775");
  if (st(t, 1.2, 3) === 0) R(c, 10, 1, 1, 1, "#f5f4ed");
  for (let i = 0; i < 3; i++) { const p = (t * 0.5 + i / 3) % 1; alpha(c, Math.min(1, (1 - p) * 2), () => glyph(c, G.z, 29 + p * 5, 10 - p * 8, "#d3d1c7")); }
});

defNew("mail", "You've got mail", "waiting", "A message for you", (c, t) => {
  const X = 5, Y = Y0, p = (t % 2.4) / 2.4, up = p > 0.3;
  R(c, 29, 15, 2, 7, WOOD); R(c, 25, 10, 9, 5, "#378ADD"); R(c, 26, 9, 7, 1, "#378ADD"); R(c, 26, 12, 1, 2, "#0C447C");
  if (up) { R(c, 34, 7, 1, 5, "#E24B4A"); R(c, 35, 7, 2, 2, "#E24B4A"); } else R(c, 34, 12, 4, 1, "#E24B4A");
  if (up) {
    const ey = 9 - Math.round(Math.min(1, (p - 0.3) / 0.3) * 5);
    R(c, 27, ey, 6, 4, "#f5f4ed"); line(c, 27, ey, 29, ey + 2, "#b4b2a9"); line(c, 32, ey, 30, ey + 2, "#b4b2a9");
  }
  clawd(c, X, Y, { eyes: up ? "wide" : "right", armR: up ? "up" : "out" });
});

/* ---------- Done ---------- */
defNew("fireworks", "Fireworks", "done", "A huge milestone", (c, t) => {
  const cols = ["#F0997B", "#85B7EB", "#FAC775", "#5DCAA5", "#ED93B1"];
  clawd(c, X0, Y0, { eyes: "up", armL: "up", armR: "up" });
  for (let b = 0; b < 2; b++) {
    const tt = t + b * 0.8, T = tt % 1.6, round = Math.floor(tt / 1.6);
    const cx = 7 + b * 22 + (round % 3) * 2, cy = 5 + b * 2, col = cols[(round + b) % 5];
    if (T < 0.4) R(c, cx, 22 - T / 0.4 * (22 - cy), 1, 2, "#FAC775");
    else { const q = (T - 0.4) / 1.2; for (let i = 0; i < 8; i++) { const a = i * Math.PI / 4; alpha(c, Math.min(1, (1 - q) * 1.7), () => R(c, cx + Math.cos(a) * q * 7, cy + Math.sin(a) * q * 7 + q * q * 3, 1, 1, col)); } if (q < 0.12) R(c, cx, cy, 1, 1, "#f5f4ed"); }
  }
});

defNew("cake", "Blowing candles", "done", "Milestone reached", (c, t) => {
  const X = 5, Y = Y0, p = (t % 3) / 3, blow = p > 0.45 && p < 0.6, out = p >= 0.55;
  R(c, 25, 16, 10, 6, "#f5f4ed"); R(c, 25, 16, 10, 2, "#ED93B1");
  [26, 29, 33].forEach(x => R(c, x, 18, 1, 1, "#ED93B1"));
  R(c, 30, 13, 1, 3, "#85B7EB");
  if (!out) R(c, 30, 11, 1, 2, st(t, 8, 2) ? "#FAC775" : "#EF9F27");
  else { const q = (p - 0.55) / 0.45; alpha(c, 1 - q, () => R(c, 30 + Math.round(Math.sin(q * 8)), 11 - q * 8, 1, 1, "#888780")); }
  clawd(c, X, Y, { eyes: out ? "happy" : "right", squash: blow ? 1 : 0 });
  if (blow) for (let i = 0; i < 3; i++) R(c, X + 17 + i * 2 + Math.round((p - 0.45) / 0.15 * 3), Y + 3 + (i % 2), 2, 1, "#B5D4F4");
});

defNew("highfive", "High five", "done", "Helpers finished", (c, t) => {
  const X = 7, Y = Y0, p = (t % 2.4) / 2.4, hit = p > 0.4 && p < 0.55, j = hit ? 2 : 0;
  const mx = p < 0.4 ? Math.round(40 - p / 0.4 * 16) : p < 0.7 ? 24 : Math.round(24 + (p - 0.7) / 0.3 * 18);
  mini(c, mx, 17 - j, st(t, 6, 2)); R(c, mx - 1, 14 - j, 1, 4, CL);
  clawd(c, X, Y - j, { eyes: hit ? "happy" : "right", armR: p > 0.3 && p < 0.7 ? "up" : "out" });
  if (hit) { glyph(c, G.star, 21, Y - 6, "#FAC775"); R(c, 19, Y - 7, 1, 1, "#FAC775"); R(c, 25, Y - 6, 1, 1, "#FAC775"); }
});

defNew("balloons", "Floating", "done", "Light as air", (c, t) => {
  const X = X0, Y = Y0 - 2 + Math.round(Math.sin(t * 1.5) * 2);
  alpha(c, .5, () => R(c, X + 4, 23, 8, 1, "#2c2c2a"));
  const B = [[X + 17, Y - 9, "#E24B4A"], [X + 21, Y - 7, "#85B7EB"], [X + 13, Y - 6, "#FAC775"]];
  B.forEach(([bx, by]) => line(c, X + 15, Y - 1, bx + 1, by + 4, "#888780"));
  B.forEach(([bx, by, col]) => glyph(c, G.balloon, bx, by, col));
  clawd(c, X, Y, { eyes: "happy", armR: "up", legs: 3 });
});

defNew("micdrop", "Mic drop", "done", "Nailed it", (c, t) => {
  const X = X0 - 2, Y = Y0, p = (t % 2.6) / 2.6;
  clawd(c, X, Y, { eyes: "shades", armR: p < 0.35 ? "out" : "down" });
  if (p < 0.35) { R(c, X + 16, Y + 3, 1, 3, "#444441"); R(c, X + 16, Y + 1, 2, 2, "#888780"); }
  else {
    const q = Math.min(1, (p - 0.35) / 0.2);
    if (q < 1) { const my = Math.round(Y + 1 + q * (19 - Y - 1)); R(c, X + 17, my, 2, 2, "#888780"); R(c, X + 17, my + 2, 1, 3, "#444441"); }
    else {
      R(c, X + 17, 21, 4, 1, "#444441"); R(c, X + 21, 20, 2, 2, "#888780");
      if (p < 0.75) { R(c, X + 16, 18, 1, 1, "#f5f4ed"); R(c, X + 24, 18, 1, 1, "#f5f4ed"); R(c, X + 20, 17, 1, 1, "#f5f4ed"); }
    }
  }
});

/* ---------- Something went wrong ---------- */
defNew("collapse", "It all fell over", "error", "Build failed", (c, t) => {
  const X = 3, Y = Y0, p = (t % 3.2) / 3.2, cols = ["#F0997B", "#85B7EB", "#5DCAA5", "#FAC775"];
  const stand = [[28, 19], [28, 16], [28, 13], [28, 10]], fallen = [[24, 19], [32, 19], [36, 19], [20, 19]];
  for (let i = 0; i < 4; i++) {
    let x, y;
    if (p < 0.45) { x = stand[i][0] + Math.round(Math.sin(t * 10) * i * 0.4 * (p / 0.45)); y = stand[i][1]; }
    else { const q = Math.min(1, (p - 0.45) / 0.2), e = q * q; x = stand[i][0] + (fallen[i][0] - stand[i][0]) * e; y = stand[i][1] + (fallen[i][1] - stand[i][1]) * e - Math.sin(q * Math.PI) * 2 * i; }
    R(c, x, y, 4, 3, cols[i]);
  }
  clawd(c, X, Y, { eyes: p > 0.45 ? "x" : "wide", armL: p > 0.45 ? "up" : "out", armR: p > 0.45 ? "up" : "out" });
});

defNew("buggy", "Bug on the loose", "error", "Tests failing", (c, t) => {
  const X = X0, Y = Y0, a = t * 2.5, front = Math.sin(a) > 0, bx = Math.round(18 + Math.cos(a) * 13), f = st(t, 8, 2);
  if (!front) bug(c, bx, 19, st(t, 10, 2));
  clawd(c, X, Y - f, { eyes: Math.cos(a) > 0 ? "right" : "left", legs: f ? 3 : 0, armL: "up", armR: "up" });
  if (front) bug(c, bx, 20, st(t, 10, 2));
});

/* ---------- Idle ---------- */
defNew("guitar", "Strumming", "idle", "Chilling", (c, t) => {
  const X = X0, Y = Y0, f = st(t, 4, 2);
  clawd(c, X, Y, { eyes: "closed", armL: f ? "down" : "out" });
  line(c, X + 9, Y + 6, X + 17, Y + 1, WOOD); line(c, X + 9, Y + 7, X + 17, Y + 2, WOOD); R(c, X + 17, Y, 2, 2, "#854F0B");
  R(c, X + 3, Y + 5, 6, 4, "#BA7517"); R(c, X + 4, Y + 4, 4, 1, "#BA7517"); R(c, X + 5, Y + 6, 2, 2, "#412402");
  for (let i = 0; i < 2; i++) { const q = (t * 0.6 + i / 2) % 1; alpha(c, Math.min(1, (1 - q) * 2), () => glyph(c, G.note, X + 19 + i * 4, Y - 2 - Math.round(q * 10), i ? "#85B7EB" : "#FAC775")); }
});

defNew("bubbles", "Blowing bubbles", "idle", "Waiting around", (c, t) => {
  const X = 6, Y = Y0;
  clawd(c, X, Y, { eyes: "happy" });
  line(c, X + 16, Y + 4, X + 19, Y + 2, "#85B7EB"); glyph(c, G.bubble, X + 19, Y - 1, "#85B7EB");
  for (let i = 0; i < 4; i++) {
    const q = (t * 0.4 + i / 4) % 1, bx = X + 22 + q * 12 + Math.sin(q * 8 + i) * 2, by = Y - 1 - q * 12;
    if (q < 0.85) glyph(c, i % 2 ? G.bubble : G.bubbleL, bx, by, "#B5D4F4");
    else { R(c, bx, by, 1, 1, "#f5f4ed"); R(c, bx + 2, by + 1, 1, 1, "#f5f4ed"); R(c, bx + 1, by - 1, 1, 1, "#f5f4ed"); }
  }
});

/* ---------- Living his life: what Clawd does on his day off ---------- */
defNew("gaming", "Gaming", "idle", "Living his life", (c, t) => {
  const X = X0, Y = Y0, f = st(t, 10, 2);
  clawd(c, X, Y, { eyes: "down", armL: f ? "out" : "down", armR: f ? "down" : "out" });
  R(c, X + 3, Y + 4, 10, 5, "#3a3a38");
  R(c, X + 5, Y + 5, 6, 3, ["#7cc79a", "#6aa9e9", "#e8c66a"][st(t, 3, 3)]);
  R(c, X + 4, Y + 6, 1, 1, "#888780"); R(c, X + 11, Y + 6, 1, 1, "#E24B4A");
  if (t % 4 > 3.2) glyph(c, G.star, X + 17, Y - 3, "#FAC775");
});

defNew("headphones", "Vibing", "idle", "Living his life", (c, t) => {
  const X = X0, Y = Y0 - st(t, 3, 2);
  clawd(c, X, Y, { eyes: "closed", armL: "down", armR: "down" });
  R(c, X + 2, Y - 2, 12, 1, "#3a3a38"); R(c, X + 1, Y - 1, 1, 1, "#3a3a38"); R(c, X + 14, Y - 1, 1, 1, "#3a3a38");
  R(c, X, Y, 2, 3, "#E24B4A"); R(c, X + 14, Y, 2, 3, "#E24B4A");
  for (let i = 0; i < 2; i++) { const q = (t * 0.5 + i / 2) % 1; alpha(c, Math.min(1, (1 - q) * 2), () => glyph(c, G.note, X + 18 + i * 5, Y - 1 - Math.round(q * 9), i ? "#b48ad9" : "#FAC775")); }
});

defNew("icecream", "Ice cream", "idle", "Living his life", (c, t) => {
  const X = X0 - 2, Y = Y0, lick = t % 3 < 0.5;
  clawd(c, X, Y, { eyes: lick ? "closed" : "happy" });
  const cx = X + 17;
  R(c, cx, Y + 4, 4, 1, "#d9a35a"); R(c, cx, Y + 5, 4, 1, "#c08a45"); R(c, cx + 1, Y + 6, 2, 1, "#d9a35a"); R(c, cx + 1, Y + 7, 2, 1, "#c08a45");
  R(c, cx - 1, Y + 1, 6, 3, "#e98aa8"); R(c, cx, Y, 4, 1, "#e98aa8"); R(c, cx + 1, Y - 1, 2, 1, "#f5f4ed");
  if (lick) R(c, cx - 1, Y + 1, 1, 1, CL);
  const d = (t * 0.7) % 1; if (d < 0.8) R(c, cx + 4, Y + 4 + Math.round(d * 5), 1, 1, "#e98aa8");
});

defNew("kite", "Flying a kite", "idle", "Living his life", (c, t) => {
  const X = 5, Y = Y0, kx = 29 + Math.round(Math.sin(t * 1.3) * 3), ky = 1 + Math.round(Math.cos(t * 1.7) * 1.5);
  clawd(c, X, Y, { eyes: "up", armR: "up" });
  line(c, X + 15, Y - 1, kx + 2, ky + 4, "#d3d1c7");
  glyph(c, ["..#..", ".###.", "#####", ".###.", "..#.."], kx, ky, "#6aa9e9");
  R(c, kx + 2, ky + 1, 1, 3, "#f5f4ed"); R(c, kx + 1, ky + 2, 3, 1, "#f5f4ed");
  for (let i = 1; i <= 4; i++) R(c, kx + 2 + Math.round(Math.sin(t * 5 + i) * 1.2), ky + 4 + i * 2, 1, 1, i % 2 ? "#E24B4A" : "#FAC775");
});

defNew("sunbathe", "Sunbathing", "idle", "Living his life", (c, t) => {
  const X = X0 - 3, Y = Y0 + 2;
  // deck chair: slanted striped back, then the seat
  for (let i = 0; i < 9; i++) R(c, X - 3 + Math.floor(i / 3), Y - 1 + i, 2, 1, i % 2 ? "#f5f4ed" : "#6aa9e9");
  R(c, X - 2, Y + 8, 20, 1, "#6aa9e9"); R(c, X - 1, Y + 9, 1, 1, WOOD); R(c, X + 15, Y + 9, 1, 1, WOOD);
  clawd(c, X, Y, { legs: "none", eyes: "shades", armL: "up", armR: "down" });
  const sx = 33, sy = 1;
  glyph(c, [".###.", "#####", "#####", "#####", ".###."], sx, sy, "#FAC775");
  const r = st(t, 2, 2);
  [[-2, 2], [6, 2], [2, -2], [2, 6]].forEach(([dx, dy]) => R(c, sx + dx, sy + dy, 1, 1, r ? "#FAC775" : "#e8c66a"));
  if (r) { R(c, sx - 1, sy - 1, 1, 1, "#FAC775"); R(c, sx + 5, sy + 5, 1, 1, "#FAC775"); }
  R(c, X + 20, Y + 5, 2, 3, "#e8c66a"); R(c, X + 21, Y + 3, 1, 2, "#E24B4A"); R(c, X + 19, Y + 3, 4, 1, "#7cc79a");
});

defNew("skate", "Skating", "idle", "Living his life", (c, t) => {
  const a = t * 1.1, x = X0 + Math.round(Math.sin(a) * 8), Y = Y0 - 1, right = Math.cos(a) > 0;
  clawd(c, x, Y, { eyes: right ? "right" : "left" });
  R(c, x + 1, Y + 10, 14, 1, "#b48ad9"); R(c, x, Y + 9, 1, 1, "#b48ad9"); R(c, x + 15, Y + 9, 1, 1, "#b48ad9");
  R(c, x + 3, Y + 11, 2, 1, "#3a3a38"); R(c, x + 11, Y + 11, 2, 1, "#3a3a38");
  const bx = right ? x - 4 : x + 18;
  for (let i = 0; i < 2; i++) alpha(c, 0.5, () => R(c, bx, Y + 3 + i * 3, 3, 1, "#d3d1c7"));
});

defNew("cat", "Petting the cat", "idle", "Living his life", (c, t) => {
  const X = 6, Y = Y0 + 2, f = st(t, 3, 2);
  clawd(c, X, Y, { legs: "none", eyes: "happy", armR: f ? "out" : "down" });
  const cx = 23, cy = Y0 + 4;
  glyph(c, ["#..#....", "####....", "####....", ".######.", ".######.", ".#.#.##."], cx, cy, "#d9d6cc");
  R(c, cx + 1, cy + 2, 1, 1, EYE); R(c, cx + 3, cy + 2, 1, 1, EYE);
  R(c, cx + 7, cy + 2 + st(t, 2, 2), 1, 2, "#d9d6cc");
  const q = (t * 0.45) % 1; alpha(c, 1 - q, () => glyph(c, G.heartS, cx + 2, cy - 3 - Math.round(q * 6), "#E24B4A"));
});

/* =====================================================================
   Batch 3 — animations for Claude's status words ("Moonwalking…")
   ===================================================================== */
NEW.clear();
GROUPS.push(["words", "Status words"]);
const INK = "#3a3a38", WHITE = "#f5f4ed";
function fedora(c, x, y) {             // dark hat with a white band
  x = Math.round(x); y = Math.round(y);
  R(c, x + 4, y - 4, 8, 3, INK); R(c, x + 4, y - 2, 8, 1, WHITE); R(c, x + 1, y - 1, 14, 1, INK); R(c, x + 1, y - 1, 1, 1, "#5f5e5a");
}
function cowboyHat(c, x, y) {
  x = Math.round(x); y = Math.round(y);
  R(c, x + 4, y - 4, 8, 3, "#BA7517"); R(c, x + 4, y - 2, 8, 1, "#412402");
  R(c, x, y - 1, 16, 1, "#854F0B"); R(c, x, y - 2, 1, 1, "#854F0B"); R(c, x + 15, y - 2, 1, 1, "#854F0B");
}
function socks(c, x, y, legs) {         // white socks on the feet that touch the ground
  x = Math.round(x); y = Math.round(y);
  [[3, 1], [5, 2], [10, 1], [12, 2]].forEach(([lx, p]) => { if (legs !== p && legs !== 3) R(c, x + lx, y + 9, 1, 1, WHITE); });
}

defNew("moonwalk", "Moonwalking", "words", "Moonwalking…", (c, t) => {
  // Glide backwards, spin, toe stand — then the same again the other way, so it never jumps back.
  const H = 4.4, T = t % H, flip = Math.floor(t / H) % 2;
  c.save(); if (flip) { c.translate(SW, 0); c.scale(-1, 1); }
  if (T < 2.8) {
    const x = 21 - Math.round(T / 2.8 * 18), f = st(t, 3, 2) + 1;       // glides backwards while facing forward
    clawd(c, x, Y0, { eyes: "right", legs: f, armL: "down" });
    socks(c, x, Y0, f); fedora(c, x, Y0);
    R(c, x + 14, Y0 + 4, 2, 2, WHITE);                                   // the one sparkly glove
    if (st(t, 4, 2)) R(c, x + 16, Y0 + 3, 1, 1, WHITE);
  } else if (T < 3.2) {
    const x = 3, v = Math.min(3, Math.floor((T - 2.8) / 0.1));           // one quick spin
    const view = [{ eyes: "none" }, { eyes: "left", armR: "none" }, { eyes: "open" }, { eyes: "right", armL: "none" }][v], legs = v % 2 ? 0 : 3;
    clawd(c, x, Y0, { ...view, legs });
    socks(c, x, Y0, legs); fedora(c, x, Y0);
    if (v >= 2) R(c, x + 14, Y0 + 4, 2, 2, WHITE);
  } else {
    const x = 3, Y = Y0 - 2;                                             // up on his toes, hand on the hat
    clawd(c, x, Y, { eyes: "closed", armR: "up", armL: "down" });
    [3, 5, 10, 12].forEach(lx => R(c, x + lx, Y + 10, 1, 2, WHITE));     // socks, stretched tall
    fedora(c, x, Y);
    R(c, x + 14, Y - 1, 2, 2, WHITE);
    glyph(c, G.star, x + 16, Y - 5, st(t, 6, 2) ? WHITE : "#FAC775");
  }
  c.restore();
});

defNew("hyperspace", "Hyperspacing", "words", "Hyperspacing…", (c, t) => {
  for (let i = 0; i < 12; i++) {
    const sp = 0.6 + rnd(i) * 1.2, len = 3 + Math.round(sp * 6), y = Math.round(rnd(i + 30) * 25);
    const x = ((rnd(i + 60) * 70 - t * 70 * sp) % 70 + 70) % 70 - 12;
    R(c, x, y, len, 1, i % 3 ? WHITE : "#85B7EB");
  }
  const j = st(t, 16, 2);
  clawd(c, X0 + j, Y0 - 1, { eyes: "wide", legs: 3, armL: "down", armR: "down" });
});

defNew("levitate", "Levitating", "words", "Levitating…", (c, t) => {
  const h = 4 + Math.round((Math.sin(t * 2) + 1) * 2), Y = Y0 - h;
  alpha(c, 0.6 - h * 0.05, () => R(c, X0 + 3 + Math.floor(h / 3), 22, 10 - Math.floor(h / 3) * 2, 1, "#5f5e5a"));
  const spark = front => { for (let i = 0; i < 4; i++) { const a = t * 1.5 + i * Math.PI / 2; if ((Math.sin(a) > 0) === front && st(t + i * 0.3, 3, 2)) R(c, X0 + 7 + Math.cos(a) * 11, Y + 4 + Math.sin(a) * 3, 1, 1, "#AFA9EC"); } };
  spark(false);                                                           // sparkles circle behind him, then in front
  clawd(c, X0, Y, { eyes: "closed", legs: 3 });
  spark(true);
});

defNew("photosynth", "Photosynthesizing", "words", "Photosynthesizing…", (c, t) => {
  const X = 8, Y = Y0, sx = 31, sy = 4;
  R(c, sx - 1, sy - 1, 4, 4, "#FAC775"); R(c, sx - 2, sy, 6, 2, "#FAC775"); R(c, sx, sy - 2, 2, 6, "#FAC775");
  const f = st(t, 3, 2);
  [[-4, 0], [5, 0], [0, -4], [0, 5], [-3, -3], [4, -3], [-3, 4], [4, 4]].forEach(([dx, dy], i) => { if ((i % 2) === f) R(c, sx + dx, sy + dy, 1, 1, "#FAC775"); });
  for (let i = 0; i < 3; i++) { const q = (t * 0.7 + i / 3) % 1; R(c, sx - 2 - q * 14, sy + 3 + q * 7, 1, 1, "#FAC775"); }
  clawd(c, X, Y, { eyes: "happy", armL: "up", armR: "up" });
  const w = st(t, 2, 2);
  R(c, X + 7, Y - 2, 1, 2, "#639922"); R(c, X + 5, Y - 3 + w, 2, 1, "#97C459"); R(c, X + 9, Y - 3 - w + 1, 2, 1, "#97C459");
});

defNew("spelunk", "Spelunking", "words", "Spelunking…", (c, t) => {
  const X = 4, Y = Y0;
  [[3, 3], [9, 2], [16, 4], [24, 2], [31, 3], [36, 2]].forEach(([x, h]) => { R(c, x, 0, 2, h, "#444441"); R(c, x + 0.5, h, 1, 1, "#444441"); });
  R(c, 0, 22, 40, 1, "#444441");
  const tilt = Math.sin(t * 1.5) * 0.3, gem = 32, gy = 19;
  alpha(c, 0.16, () => { for (let dx = 1; dx < 22; dx++) { const sp = dx * 0.45, cy = Y + 1 + tilt * dx; R(c, X + 15 + dx, cy - sp, 1, sp * 2 + 1, "#FAC775"); } });
  const lit = Math.abs((Y + 1 + tilt * (gem - X - 15)) - gy) < (gem - X - 15) * 0.45;
  glyph(c, [".#.", "###", ".#."], gem, gy, lit ? "#5DCAA5" : "#2c2c2a");
  if (lit && st(t, 5, 2)) R(c, gem + 3, gy - 1, 1, 1, WHITE);
  clawd(c, X, Y, { eyes: lit ? "wide" : "right" });
  R(c, X + 6, Y - 1, 4, 1, "#5f5e5a"); R(c, X + 13, Y, 1, 2, "#FAC775");
});

defNew("honk", "Honking", "words", "Honking…", (c, t) => {
  const X = 6, Y = Y0, p = t % 1.2, squeeze = p < 0.18;
  clawd(c, X, Y, { eyes: squeeze ? "happy" : "right" });
  R(c, X + 15, Y + (squeeze ? 3 : 2), 3, squeeze ? 2 : 3, "#E24B4A");
  R(c, X + 18, Y + 3, 2, 1, "#EF9F27"); R(c, X + 20, Y + 2, 1, 3, "#EF9F27"); R(c, X + 21, Y + 1, 1, 5, "#FAC775");
  if (p < 0.45) { const k = Math.round(p / 0.45 * 3); R(c, X + 23 + k, Y + 3, 2, 1, WHITE); R(c, X + 22 + k, Y - 1 + 0, 1, 2, WHITE); R(c, X + 22 + k, Y + 6, 1, 2, WHITE); }
});

defNew("gallop", "Galloping", "words", "Galloping…", (c, t) => {
  const X = 8, f = st(t, 4, 2), Y = Y0 - f * 2;
  for (let i = 0; i < 2; i++) { const q = (t * 2 + i / 2) % 1; alpha(c, 1 - q, () => R(c, X - 1 - q * 6, 21 - q * 2, 2, 1, "#888780")); }
  line(c, X + 2, Y + 11, X + 18, Y + 3, WOOD);
  clawd(c, X, Y, { eyes: "happy", legs: f + 1, armR: "out" });
  const hx = X + 17, hy = Y - 1;
  R(c, hx, hy, 4, 3, "#BA7517"); R(c, hx + 3, hy + 1, 2, 2, "#BA7517"); R(c, hx + 1, hy - 1, 1, 1, "#BA7517");
  R(c, hx + 1, hy, 1, 1, EYE); R(c, hx - 1, hy, 1, 3, "#412402");
});

defNew("spin", "Spinning", "words", "Spinning…", (c, t) => {
  const v = st(t, 8, 4);
  const view = [{ eyes: "open" }, { eyes: "right", armL: "none" }, { eyes: "none" }, { eyes: "left", armR: "none" }][v];
  clawd(c, X0, Y0, { ...view, legs: v % 2 ? 3 : 0 });
  const f = st(t, 8, 2);
  R(c, X0 - 4, Y0 + 2 + f * 3, 3, 1, "#5f5e5a"); R(c, X0 + 17, Y0 + 5 - f * 3, 3, 1, "#5f5e5a");
});

defNew("hatch", "Hatching", "words", "Hatching…", (c, t) => {
  const p = (t % 5) / 5, ex = 15, ey = 11;
  const EGG = ["...####...", "..######..", ".########.", ".########.", "##########", "##########", "##########", "##########", "##########", ".########.", "..######.."];
  if (p < 0.4) {
    const w = p > 0.15 ? Math.round(Math.sin(t * 20) * (p > 0.3 ? 1 : 0.6)) : 0;
    glyph(c, EGG, ex + w, ey, WHITE);
    const n = Math.floor(p / 0.4 * 5);
    [[2, 5], [3, 4], [4, 5], [5, 4], [6, 5]].slice(0, n).forEach(([dx, dy]) => R(c, ex + w + dx, ey + dy, 1, 1, "#888780"));
  } else if (p < 0.55) {
    const q = (p - 0.4) / 0.15;
    clawd(c, X0 + 1, Y0 + 1, { eyes: "wide", legs: "none" });
    glyph(c, EGG.slice(5), ex, ey + 5, WHITE);
    glyph(c, EGG.slice(0, 5), ex + q * 6, ey - q * 9, WHITE);
  } else {
    const j = p < 0.7 ? Math.round(Math.sin((p - 0.55) / 0.15 * Math.PI) * 4) : 0;
    glyph(c, ["#.#.#.#.#.", "##########", ".########."], ex, 19, WHITE);
    clawd(c, X0 + 1, Y0 - 3 - j, { eyes: "happy", legs: j ? 3 : 0, armL: "up", armR: "up" });
    glyph(c, ["..####..", ".######.", "#.#..#.#"], X0 + 5, Y0 - 6 - j, WHITE);
  }
});

defNew("mosey", "Moseying", "words", "Moseying…", (c, t) => {
  const x = Math.round(((t * 4) % 50) - 16), f = st(t, 2, 2);
  R(c, 0, 22, 40, 1, "#444441");
  clawd(c, x, Y0, { legs: f + 1, eyes: "right" }); cowboyHat(c, x, Y0);
  const q = (t % 5) / 5;
  if (q > 0.4) {
    const k = (q - 0.4) / 0.6, tx = 42 - k * 52, ty = 18 - Math.abs(Math.sin(k * 12)) * 3;
    glyph(c, st(t, 6, 2) ? [".##.", "#..#", "#.##", ".##."] : [".##.", "##.#", "#..#", ".##."], tx, ty, "#BA7517");
  }
});

defNew("noodle", "Noodling", "words", "Noodling…", (c, t) => {
  const X = 6, Y = Y0, p = (t % 1.6) / 1.6, up = Math.sin(p * Math.PI), ty = Math.round(16 - up * 7);
  for (let i = 0; i < 2; i++) { const q = (t * 0.8 + i / 2) % 1; alpha(c, 1 - q, () => R(c, 28 + i * 3, 14 - q * 7, 1, 1, "#888780")); }
  R(c, 25, 17, 9, 3, WHITE); R(c, 26, 20, 7, 1, WHITE); R(c, 26, 16, 7, 1, "#FAC775");
  if (ty < 16) for (let k = 0; k < 3; k++) R(c, 28 + k, ty + 1, 1, 16 - ty, "#FAC775");
  clawd(c, X, Y, { eyes: up > 0.6 ? "happy" : "right" });
  line(c, X + 16, Y + 3, 29, ty, WOOD); line(c, X + 16, Y + 5, 30, ty + 1, WOOD);
});

defNew("boop", "Booping", "words", "Booping…", (c, t) => {
  const X = 6, Y = Y0, p = (t % 2) / 2;
  const ext = p < 0.4 ? Math.round(p / 0.4 * 7) : p < 0.6 ? 7 : Math.round((1 - p) / 0.4 * 7);
  const booped = p > 0.38 && p < 0.62;
  mini(c, 28, 17, 0);
  if (booped) { R(c, 30, 18, 1, 1, CL); R(c, 33, 18, 1, 1, CL); R(c, 30, 19, 1, 1, EYE); R(c, 33, 19, 1, 1, EYE); }
  clawd(c, X, Y, { eyes: booped ? "happy" : "right" });
  if (ext) R(c, X + 16, Y + 4, ext, 2, CL);
  if (p > 0.4) { const q = (p - 0.4) / 0.6; alpha(c, 1 - q, () => glyph(c, G.heartS, 31, 13 - q * 9, "#E24B4A")); }
});

/* =====================================================================
   Batch 4 — more status-word animations
   ===================================================================== */
NEW.clear();
function clip(c, x, y, w, h, fn) { c.save(); c.beginPath(); c.rect(x, y, w, h); c.clip(); fn(); c.restore(); }
const pong = p => p < 0.5 ? p * 2 : 2 - p * 2;

defNew("waddle", "Waddling", "words", "Waddling…", (c, t) => {
  const x = Math.round(((t * 5) % 52) - 16), f = st(t, 3, 2), bob = f;
  clawd(c, x, Y0 + bob, { legs: f + 1, eyes: "right", armL: f ? "down" : "out", armR: f ? "out" : "down" });
  R(c, x + 5, Y0 + bob + 4, 6, 4, WHITE);                                  // penguin belly
  R(c, x + 14, Y0 + bob + 3, 2, 1, "#EF9F27");                            // little beak
});

defNew("burrow", "Burrowing", "words", "Burrowing…", (c, t) => {
  const p = (t % 4) / 4, DIRT = "#5f3a1e", flip = Math.floor(t / 4) % 2;   // tunnels one way, then back again
  c.save(); if (flip) { c.translate(SW, 0); c.scale(-1, 1); }
  R(c, 0, 22, 40, 4, DIRT); R(c, 0, 22, 40, 1, "#854F0B");
  if (p < 0.3) {                                                          // digs down
    const d = Math.round(p / 0.3 * 12);
    clip(c, 0, 0, 40, 22, () => clawd(c, 4, Y0 + d, { eyes: "closed", armL: "up", armR: "up" }));
    for (let i = 0; i < 4; i++) { const q = (t * 3 + i / 4) % 1; R(c, 12 + (i % 2 ? 1 : -1) * q * 8, 21 - Math.sin(q * Math.PI) * 6, 1, 1, "#854F0B"); }
  } else if (p < 0.65) {                                                  // a bump travels under the ground
    const mx = 8 + (p - 0.3) / 0.35 * 16;
    glyph(c, ["..####..", ".######.", "########"], mx, 19, "#854F0B");
  } else {                                                                // pops up with dirt on his head
    const up = Math.min(1, (p - 0.65) / 0.1), y = Y0 + Math.round((1 - up) * 12);
    clip(c, 0, 0, 40, 22, () => clawd(c, 20, y, { eyes: p > 0.8 ? "happy" : "wide" }));
    glyph(c, ["..##....", ".####.#."], 23, y - 2, "#854F0B");
  }
  c.restore();
});

defNew("catapult", "Catapulting", "words", "Catapulting…", (c, t) => {
  const p = (t % 4.8) / 4.8, hopOn = p >= 0.9 ? (p - 0.9) / 0.1 : 0;
  R(c, 5, 20, 14, 2, WOOD); R(c, 6, 22, 2, 1, METAL); R(c, 15, 22, 2, 1, METAL); R(c, 15, 15, 2, 5, WOOD);
  const k = p < 0.22 ? 0 : hopOn > 0.6 ? 1 - (hopOn - 0.6) / 0.4 : 1;     // 0 = arm pulled down, 1 = fired
  line(c, 16, 15, 5 + k * 7, 12 - k * 8, WOOD);
  if (p < 0.22) {
    const shake = p > 0.14 ? st(t, 16, 2) : 0;
    clawd(c, shake, 4, { eyes: "wide", legs: "none", armL: "up", armR: "up" });
  } else if (p < 0.5) {                                                   // flung across
    const q = (p - 0.22) / 0.28, x = q * 22, y = 4 - Math.sin(q * Math.PI) * 7 + q * 8;
    clawd(c, x, y, { eyes: "happy", legs: 3, armL: "up", armR: "up" });
  } else if (p < 0.72) {
    const q = (p - 0.5) / 0.22;
    clawd(c, 22, Y0, { eyes: q < 0.35 ? "x" : "happy", squash: q < 0.15 ? 4 : 0, armR: q > 0.45 ? "up" : "out" });
    if (q < 0.3) { R(c, 20 - q * 6, 21, 2, 1, "#888780"); R(c, 38 + q * 4, 21, 2, 1, "#888780"); }
  } else if (p < 0.9) {                                                   // trots back for another go
    const q = (p - 0.72) / 0.18, f = st(t, 7, 2);
    clawd(c, 22 - q * 17, Y0 - f, { eyes: "left", legs: f + 1 });
  } else {                                                                // hops on, his weight pulls the arm down
    clawd(c, 5 - hopOn * 5, Y0 + (4 - Y0) * hopOn - Math.sin(hopOn * Math.PI) * 4, { eyes: "left", legs: 3, armL: "up", armR: "up" });
  }
});

defNew("magic", "Prestidigitating", "words", "Prestidigitating…", (c, t) => {
  const p = (t % 4) / 4, X = 4, Y = Y0;
  R(c, 26, 16, 11, 1, INK); R(c, 27, 17, 9, 5, INK); R(c, 27, 20, 9, 1, "#E24B4A");
  const wv = p < 0.5 ? st(t, 4, 2) : 0;
  clawd(c, X, Y, { eyes: p < 0.5 ? "right" : "happy" });
  line(c, X + 16, Y + 4, X + 21, Y + 1 + wv * 3, INK); R(c, X + 21, Y + wv * 3, 1, 1, WHITE);
  if (p < 0.5) for (let i = 0; i < 3; i++) if (st(t + i * 0.2, 5, 2)) R(c, 27 + rnd(i + Math.floor(t * 5)) * 8, 10 + rnd(i + 9 + Math.floor(t * 5)) * 5, 1, 1, "#FAC775");
  if (p > 0.45 && p < 0.6) alpha(c, 1 - (p - 0.45) / 0.15, () => { glyph(c, G.cloud, 28, 12, WHITE); glyph(c, G.puff, 26, 10, WHITE); glyph(c, G.puff, 33, 10, WHITE); });
  if (p >= 0.55) {
    const b = Math.round(Math.abs(Math.sin(t * 5))), by = 10 - b;
    glyph(c, ["#..#", "#..#", "####", "####", "####"], 30, by, WHITE);
    R(c, 30, by + 3, 1, 1, EYE); R(c, 33, by + 3, 1, 1, EYE); R(c, 31, by + 4, 2, 1, "#ED93B1");
    R(c, 29, 16, 6, 1, WHITE);
  }
});

defNew("metamorph", "Metamorphosing", "words", "Metamorphosing…", (c, t) => {
  const p = (t % 5) / 5;
  R(c, 0, 1, 40, 1, WOOD);
  if (p < 0.45) {                                                         // cocoon hangs and wiggles
    const w = p > 0.25 ? Math.round(Math.sin(t * 18)) : 0;
    R(c, 20, 2, 1, 3, GLASS);
    glyph(c, ["..#####..", ".#######.", "#########", "#########", "#########", "#########", "#########", "#########", ".#######.", "..#####.."], 16 + w, 5, "#C0DD97");
    [7, 10, 13].forEach(y => R(c, 17 + w, y, 7, 1, "#97C459"));
    if (p > 0.38) R(c, 20 + w, 7, 1, 4, EYE);
  } else {                                                                // out with wings
    const q = (p - 0.45) / 0.55, fl = st(t, 5, 2), x = X0, y = Y0 - 4 - Math.round(Math.sin(t * 3) * 2) - Math.round(q * 2);
    const WL = fl ? ["####...", "#####..", "######.", ".#####.", "..####.", "...###."] : ["..###..", ".####..", ".#####.", "..####.", "..###..", "...##.."];
    const WR = WL.map(r => [...r].reverse().join(""));
    glyph(c, WL, x - 6, y + 1, "#7F77DD"); glyph(c, WR, x + 15, y + 1, "#7F77DD");
    R(c, x - 4, y + 3, 2, 1, "#FAC775"); R(c, x + 18, y + 3, 2, 1, "#FAC775");
    clawd(c, x, y, { eyes: "happy", legs: 3, armL: "none", armR: "none" });
    R(c, x + 5, y - 2, 1, 2, EYE); R(c, x + 10, y - 2, 1, 2, EYE); R(c, x + 4, y - 3, 1, 1, EYE); R(c, x + 11, y - 3, 1, 1, EYE);
  }
});

defNew("slither", "Slithering", "words", "Slithering…", (c, t) => {
  const x = Math.round(((t * 4) % 52) - 16);
  for (let i = 0; i < 16; i++) clip(c, x + i, 0, 1, 26, () => clawd(c, x, Y0 + Math.round(Math.sin(t * 5 - i * 0.4) * 1.1), { eyes: "right", legs: 3 }));
  if (st(t, 3, 2)) { R(c, x + 16, Y0 + 6, 2, 1, "#E24B4A"); R(c, x + 18, Y0 + 5, 1, 1, "#E24B4A"); R(c, x + 18, Y0 + 7, 1, 1, "#E24B4A"); }
});

defNew("frost", "Frosting", "words", "Frosting…", (c, t) => {
  const p = (t % 4) / 4, X = 3, Y = Y0;
  R(c, 27, 18, 9, 4, "#85B7EB"); [28, 30, 32, 34].forEach(x => R(c, x, 18, 1, 4, "#378ADD"));
  R(c, 27, 17, 9, 1, "#BA7517");
  const n = Math.min(3, Math.floor(p / 0.2));
  const layers = [[26, 15, 11], [27, 13, 9], [29, 11, 5]];
  layers.slice(0, n).forEach(([x, y, w]) => R(c, x, y, w, 2, "#F4C0D1"));
  if (p > 0.7) [[28, 15], [33, 14], [30, 13], [35, 16]].forEach(([x, y], i) => R(c, x, y, 1, 1, ["#E24B4A", "#FAC775", "#5DCAA5", "#7F77DD"][i]));
  if (p > 0.8) { R(c, 31, 9, 2, 2, "#E24B4A"); R(c, 32, 8, 1, 1, "#639922"); }
  const layer = layers[Math.min(2, n)], bx = layer[0] + Math.round(pong((t * 1.5) % 1) * (layer[2] - 2)), by = layer[1] - 5;
  if (p < 0.65) {
    glyph(c, ["####", "###.", "##..", "#..."], bx, by, WHITE); R(c, bx, by + 4, 1, 1, "#F4C0D1");
    line(c, X + 16, Y + 4, bx, by + 1, CL);
  }
  clawd(c, X, Y, { eyes: p > 0.8 ? "happy" : "right", armR: "none" });
});

defNew("roost", "Roosting", "words", "Roosting…", (c, t) => {
  const p = (t % 5) / 5, X = X0, Y = Y0 + 2;
  clawd(c, X, Y, { eyes: "closed", legs: "none" });
  R(c, X - 1, Y + 6, 18, 4, WOOD); [0, 3, 7, 10, 14].forEach((i, k) => R(c, X + i, Y + 6 + (k % 2), 3, 1, "#854F0B"));
  R(c, X - 2, Y + 7, 1, 1, WOOD); R(c, X + 17, Y + 7, 1, 1, WOOD);
  let bx, by;
  if (p < 0.25) { const q = p / 0.25; bx = 40 - q * 20; by = 2 + Math.sin(q * Math.PI) * -1 + q * 6; }
  else if (p < 0.75) { bx = 20; by = Y - 3; }
  else { const q = (p - 0.75) / 0.25; bx = 20 - q * 24; by = Y - 3 - q * 10; }
  const flap = p < 0.25 || p > 0.75 ? st(t, 8, 2) : 0;
  glyph(c, [".##.", "####", ".##."], bx, by, "#85B7EB"); R(c, bx - 1, by + 1, 1, 1, "#EF9F27"); R(c, bx + 1, by, 1, 1, EYE);
  R(c, bx + 1, by - 1 + flap * 2, 2, 1, "#378ADD");
  if (p > 0.35 && p < 0.7 && st(t, 2, 2)) glyph(c, G.note, bx - 6, by - 6, WHITE);
});

defNew("pounce", "Pouncing", "words", "Pouncing…", (c, t) => {
  const p = (t % 3) / 3, dot = 34, flip = Math.floor(t / 3) % 2;         // pounces one way, then the other
  c.save(); if (flip) { c.translate(SW, 0); c.scale(-1, 1); }
  if (p < 0.6) R(c, dot + Math.round(Math.sin(t * 9)), 21, 1, 1, "#E24B4A");
  const next = p > 0.86;                                                  // the dot got away: it shows up behind him
  if (next) R(c, SW - 1 - dot + Math.round(Math.sin(t * 9)), 21, 1, 1, "#E24B4A");
  if (p < 0.5) {
    const wig = p > 0.25 ? st(t, 10, 2) : 0;
    clawd(c, 3 + wig, Y0, { eyes: p < 0.12 ? "right" : "wide", squash: 3, armL: "down", armR: "down" });
  } else if (p < 0.72) {
    const q = (p - 0.5) / 0.22;
    clawd(c, 3 + q * 18, Y0 - Math.sin(q * Math.PI) * 8, { eyes: "wide", legs: 3, armL: "up", armR: "out" });
  } else {
    clawd(c, 21, Y0, { eyes: next ? "left" : "happy", squash: p < 0.8 ? 3 : 0, armR: next ? "out" : "down" });
  }
  c.restore();
});

defNew("skedaddle", "Skedaddling", "words", "Skedaddling…", (c, t) => {
  const p = (t % 3.5) / 3.5;
  if (p < 0.3) {
    clawd(c, X0, Y0, { eyes: "wide", legs: p > 0.18 ? st(t, 14, 2) + 1 : 0, armL: "up", armR: "up" });
    glyph(c, G.bang, X0 + 18, Y0 - 5, "#FAC775");
  } else if (p < 0.4) {
    const x = X0 + (p - 0.3) / 0.1 * 34;
    for (let i = 0; i < 4; i++) R(c, x - 4 - i * 3, Y0 + 2 + i * 2, 3 + i, 1, WHITE);
    clawd(c, x, Y0, { eyes: "right", legs: 3 });
  } else if (p > 0.72) {                                                  // sheepishly walks back in
    const q = (p - 0.72) / 0.28, x = -16 + q * (X0 + 16);
    clawd(c, x, Y0, { eyes: "right", legs: q < 1 ? st(t, 4, 2) + 1 : 0 });
  }
  if (p >= 0.3 && p < 0.75) alpha(c, 1 - (p - 0.3) / 0.45, () => { glyph(c, G.cloud, X0 + 4, Y0 + 5, "#888780"); glyph(c, G.puff, X0 + 1, Y0 + 3, "#888780"); glyph(c, G.puff, X0 + 10, Y0 + 2, "#888780"); });
});

defNew("philosophize", "Philosophizing", "words", "Philosophizing…", (c, t) => {
  const X = 4, Y = Y0, g = st(t, 1.2, 2);
  clawd(c, X, Y, { eyes: g ? "up" : "closed", armR: g ? "up" : "out" });
  for (let i = 0; i < 6; i++) R(c, X + 2 + i * 2, Y + 4 + Math.round(i * 0.6), 2, 2, WHITE);   // toga, worn below the eyes
  for (let i = 0; i < 7; i++) R(c, X + 2 + i * 2, Y - 1 + (i % 2), 1, 1, "#639922"); // laurel wreath
  R(c, X + 1, Y, 1, 1, "#639922"); R(c, X + 14, Y, 1, 1, "#639922");
  glyph(c, [".#########.", "###########", "###########", "###########", ".#########.", "..##......."], 24, 3, WHITE);
  const k = st(t, 2, 4);
  [26, 29, 32].forEach((x, i) => { if (i < k) R(c, x, 5, 2, 2, EYE); });
});

defNew("clauding", "Clauding", "words", "Clauding…", (c, t) => {
  const cx = X0 + 8, cy = 5, a = t * 1.6;
  for (let k = 0; k < 6; k++) { const an = a + k * Math.PI / 3; line(c, cx, cy, cx + Math.cos(an) * 4, cy + Math.sin(an) * 4, k % 2 ? "#F0997B" : CL); }
  R(c, cx, cy, 1, 1, "#FAC775");
  for (let i = 0; i < 4; i++) if (st(t + i * 0.37, 2.5, 2)) R(c, 4 + rnd(i + Math.floor(t * 2.5)) * 32, 2 + rnd(i + 7 + Math.floor(t * 2.5)) * 14, 1, 1, "#FAC775");
  clawd(c, X0, Y0, { eyes: "happy", armL: "up", armR: "up", legs: st(t, 2, 2) ? 0 : 3 });
});

defNew("warp", "Warping", "words", "Warping…", (c, t) => {
  const p = (t % 2.5) / 2.5, spot = Math.floor(t / 2.5) % 2, x = spot ? 22 : 2;
  const glitch = p > 0.7;
  if (glitch) {
    const j = st(t, 14, 3) - 1;
    alpha(c, 0.7, () => clawd(c, x - 2 + j, Y0, { color: "#5DCAA5", eyes: "wide" }));
    alpha(c, 0.7, () => clawd(c, x + 2 - j, Y0, { color: "#ED93B1", eyes: "wide" }));
    clip(c, 0, Y0 + 2, 40, 2, () => clawd(c, x + j * 3, Y0, { eyes: "wide" }));
    clip(c, 0, Y0 + 6, 40, 2, () => clawd(c, x - j * 2, Y0, { eyes: "wide" }));
    if (p > 0.85) alpha(c, 0.5, () => clawd(c, spot ? 2 : 22, Y0, { color: "#5DCAA5" }));
  } else {
    const ap = Math.min(1, p / 0.12);
    alpha(c, ap, () => clawd(c, x, Y0, { eyes: p < 0.12 ? "wide" : "open" }));
  }
});

defNew("harmonize", "Harmonizing", "words", "Harmonizing…", (c, t) => {
  const b1 = Math.round((Math.sin(t * 4) + 1)), b2 = Math.round((Math.sin(t * 4 + Math.PI) + 1));
  clawd(c, 2, Y0 + b1 - 1, { eyes: "closed", legs: "none", armR: "up" });
  clawd(c, 22, Y0 + b2 - 1, { eyes: "closed", legs: "none", armL: "up" });
  for (let i = 0; i < 4; i++) {
    const q = (t * 0.5 + i / 4) % 1, left = i % 2 === 0;
    alpha(c, 1 - q, () => glyph(c, G.note, (left ? 8 : 28) + Math.sin(q * 6 + i) * 3, 8 - q * 8, left ? "#FAC775" : "#85B7EB"));
  }
});

defNew("gust", "Gusting", "words", "Gusting…", (c, t) => {
  R(c, 33, 3, 1, 19, METAL); R(c, 31, 2, 5, 2, METAL);
  for (let i = 0; i < 6; i++) {
    const sp = 0.8 + rnd(i) * 0.8, y = 2 + Math.round(rnd(i + 20) * 20), x = 44 - ((t * 40 * sp + rnd(i + 40) * 60) % 60);
    R(c, x, y, 4 + Math.round(sp * 3), 1, i % 2 ? "#5f5e5a" : "#888780");
  }
  const q = (t * 0.7) % 1; glyph(c, st(t, 6, 2) ? ["##", ".#"] : [".#", "##"], 40 - q * 50, 6 + Math.sin(q * 10) * 3, "#97C459");
  const j = st(t, 10, 2), lift = st(t, 5, 3);
  clawd(c, 17 + j, Y0 - (lift === 2 ? 1 : 0), { eyes: "closed", armR: "up", armL: "out", legs: lift ? lift : 0 });
});

/* =====================================================================
   Batch 5 — the rest of the status words
   ===================================================================== */
NEW.clear();
function turn(c, cx, cy, q, fn) { c.save(); c.translate(cx, cy); c.rotate(q * Math.PI / 2); c.translate(-cx, -cy); fn(); c.restore(); }
const DIG = ["###,#.#,#.#,#.#,###", "..#,..#,..#,..#,..#", "###,..#,###,#..,###", "###,..#,###,..#,###", "#.#,#.#,###,..#,..#",
             "###,#..,###,..#,###", "###,#..,###,#.#,###", "###,..#,..#,..#,..#", "###,#.#,###,#.#,###", "###,#.#,###,..#,###"].map(s => s.split(","));
function path(pts, p) {                 // [x, y, time] waypoints → position at time p
  if (p <= pts[0][2]) return pts[0];
  for (let i = 1; i < pts.length; i++) if (p <= pts[i][2]) {
    const [x0, y0, t0] = pts[i - 1], [x1, y1, t1] = pts[i], k = (p - t0) / (t1 - t0);
    return [x0 + (x1 - x0) * k, y0 + (y1 - y0) * k];
  }
  return pts[pts.length - 1];
}

defNew("ufo", "Beaming up", "words", "Beaming…", (c, t) => {
  const p = (t % 4) / 4, blink = st(t, 6, 3);
  let y = Y0;
  if (p > 0.15 && p < 0.6) y = Y0 - (p - 0.15) / 0.45 * 16;
  else if (p >= 0.6 && p < 0.75) y = -10;
  else if (p >= 0.75 && p < 0.9) y = Y0 - (1 - (p - 0.75) / 0.15) * 16;
  if (p > 0.1 && p < 0.92) alpha(c, 0.4 + st(t, 8, 2) * 0.1, () => { for (let r = 7; r < 22; r++) { const w = 6 + (r - 7) * 0.8; R(c, 20 - w / 2, r, w, 1, "#9FE1CB"); } });
  clip(c, 0, 7, 40, 19, () => clawd(c, X0, y, { eyes: p < 0.15 ? "up" : p > 0.85 ? "happy" : "wide", legs: y < Y0 ? 3 : 0, armL: y < Y0 ? "up" : "out", armR: y < Y0 ? "up" : "out" }));
  R(c, 16, 1, 8, 2, "#85B7EB"); R(c, 10, 3, 20, 2, METAL); R(c, 12, 5, 16, 1, "#888780");
  [12, 17, 22, 27].forEach((x, i) => R(c, x, 4, 1, 1, i % 3 === blink ? "#FAC775" : "#5f5e5a"));
});

defNew("swoop", "Swooping", "words", "Swooping…", (c, t) => {
  const p = (t % 2.6) / 2.6, q = Math.min(1, p / 0.75), x = -18 + q * 60, y = Y0 - 9 + Math.round(Math.sin(q * Math.PI) * 9);
  const flap = st(t, 8, 2);
  if (p < 0.75) {
    R(c, x - 6, y + 1 + flap, 7, 3, "#E24B4A"); R(c, x - 8, y + 2 + flap * 2, 3, 2, "#E24B4A");
    clawd(c, x, y, { eyes: "right", legs: 3, armL: "down", armR: "out" });
    for (let i = 1; i < 4; i++) R(c, x - 8 - i * 4, y + 4 + i, 3, 1, "#5f5e5a");
  }
});

defNew("zigzag", "Zigzagging", "words", "Zigzagging…", (c, t) => {
  const wrap = (v, n) => ((v % n) + n) % n;
  const pos = tt => { const x = wrap(tt * 8, 58) - 18, k = wrap(tt * 1.6, 1); return [x, Y0 - (k < 0.5 ? k * 2 : 2 - k * 2) * 8]; };
  for (let d = 0.15; d < 1.6; d += 0.12) { const [px, py] = pos(t - d); if (px < pos(t)[0]) alpha(c, 0.7 - d * 0.4, () => R(c, px + 2, py + 9, 1, 1, WHITE)); }
  const [x, y] = pos(t);
  clawd(c, x, y, { eyes: "right", legs: y < Y0 - 1 ? 3 : 0 });
});

defNew("yarn", "Unraveling", "words", "Unraveling…", (c, t) => {
  const p = (t % 3.5) / 3.5, bx = 22 + Math.round(p * 14), big = p < 0.5;
  R(c, 21, 21, bx - 21, 1, "#ED93B1");
  if (big) glyph(c, [".###.", "#####", "#####", ".###."], bx, 18, "#ED93B1"); else glyph(c, [".#.", "###", ".#."], bx, 19, "#ED93B1");
  R(c, bx + 1, big ? 19 : 20, 1, 1, "#D4537E");
  const bat = st(t, 3, 2);
  clawd(c, 4, Y0, { eyes: "right", armR: bat ? "down" : "out", legs: bat ? 2 : 0 });
});

defNew("surf", "Surfing", "words", "Flowing…", (c, t) => {
  const wh = i => 20 + Math.round(Math.sin(i * 0.25 - t * 3) * 2);
  for (let i = 0; i < 40; i++) { const h = wh(i); R(c, i, h, 1, 26 - h, "#185FA5"); R(c, i, h, 1, 1, "#85B7EB"); }
  const x = 11 + Math.round(Math.sin(t * 1.3) * 3), hl = wh(x), hr = wh(x + 16), mid = Math.round((hl + hr) / 2);
  line(c, x - 1, hl - 1, x + 17, hr - 1, "#FAC775");
  const bal = st(t, 2, 2);
  clawd(c, x, mid - 11, { eyes: "happy", armL: bal ? "up" : "out", armR: bal ? "out" : "up" });
  for (let i = 0; i < 3; i++) { const q = (t * 2 + i / 3) % 1; alpha(c, 1 - q, () => R(c, x - 2 - q * 6, hl - 2 - Math.sin(q * Math.PI) * 4, 1, 1, WHITE)); }
});

defNew("umbrella", "Puddle jumping", "words", "Precipitating…", (c, t) => {
  const p = (t % 1.6) / 1.6, hop = p < 0.3 ? Math.round(Math.sin(p / 0.3 * Math.PI) * 2) : 0, X = X0, Y = Y0 - hop;
  for (let i = 0; i < 16; i++) {
    const x = Math.round(rnd(i) * 40), y = ((t * 30 + rnd(i + 9) * 26) % 26) - 2;
    if (x >= X + 4 && x <= X + 20 && y > Y - 11) continue;                // dry under the umbrella
    R(c, x, y, 1, 2, "#85B7EB");
  }
  R(c, X - 2, 22, 22, 1, "#378ADD");
  if (p > 0.3 && p < 0.5) { const q = (p - 0.3) / 0.2; [[-1, 1], [1, 1], [-1, 0.6], [1, 0.6]].forEach(([d, s], i) => R(c, X + 8 + d * (6 + q * 8 * s), 21 - Math.sin(q * Math.PI) * 4 * s, 1, 1, "#85B7EB")); }
  clawd(c, X, Y, { eyes: "happy", armR: "up", legs: hop ? 3 : 0 });
  line(c, X + 15, Y - 2, X + 12, Y - 6, INK);                             // tilted over his head, and low enough to fit
  glyph(c, ["....#######....", "..###########..", ".#############.", "###############"], X + 5, Y - 10, "#E24B4A");
  R(c, X + 12, Y - 11, 1, 1, INK);
});

defNew("flutter", "Fluttering", "words", "Fluttering…", (c, t) => {
  const bs = [[0, "#FAC775"], [2.1, "#ED93B1"], [4.2, "#AFA9EC"]];
  let lookX = X0 + 8;
  bs.forEach(([o, col], i) => {
    const a = t * 1.2 + o, x = 20 + Math.cos(a) * 15, y = 8 + Math.sin(a * 2) * 5, f = st(t + i * 0.1, 8, 2);
    if (i === 0) lookX = x;
    R(c, x, y, 1, 2, EYE);
    if (f) { R(c, x - 2, y - 1, 2, 2, col); R(c, x + 1, y - 1, 2, 2, col); } else { R(c, x - 1, y, 1, 2, col); R(c, x + 1, y, 1, 2, col); }
  });
  clawd(c, X0, Y0, { eyes: lookX < X0 + 6 ? "left" : lookX > X0 + 10 ? "right" : "up" });
});

defNew("calc", "Calculating", "words", "Calculating…", (c, t) => {
  const X = 2, Y = Y0, f = st(t, 4, 2), n = Math.floor(t * 4);
  R(c, 24, 8, 14, 14, "#444441"); R(c, 25, 9, 12, 7, "#173404");
  [26, 30, 34].forEach((x, i) => glyph(c, DIG[Math.floor(rnd(n + i * 3) * 10)], x, 10, "#97C459"));
  const lit = Math.floor(rnd(n + 1) * 6);
  [0, 1, 2, 3, 4, 5].forEach(k => R(c, 26 + (k % 3) * 4, 17 + Math.floor(k / 3) * 2, 2, 1, f && k === lit ? "#FAC775" : GLASS));
  const len = Math.round((t * 2) % 8);
  R(c, 27, 8 - len, 7, len, WHITE); for (let y = 8 - len + 1; y < 8; y += 2) R(c, 28, y, 4, 1, "#888780");
  clawd(c, X, Y, { eyes: "right" });
  if (f) R(c, X + 16, Y + 4, 8, 2, CL); else R(c, X + 16, Y + 3, 3, 2, CL);
});

defNew("jester", "Cartwheeling", "words", "Tomfoolering…", (c, t) => {
  const x = Math.round(((t * 10) % 60) - 18), q = Math.floor(t * 6) % 4, cy = [17, 14, 14, 14][q];
  turn(c, x + 8, cy, q, () => {
    const y = cy - 5;
    clawd(c, x, y, { eyes: "happy", armL: "up", armR: "up", legs: 0 });
    R(c, x + 3, y - 2, 5, 2, "#7F77DD"); R(c, x + 8, y - 2, 5, 2, "#FAC775");
    R(c, x + 1, y - 3, 3, 1, "#7F77DD"); R(c, x + 12, y - 3, 3, 1, "#FAC775");
    R(c, x, y - 4, 1, 1, "#FAC775"); R(c, x + 15, y - 4, 1, 1, "#7F77DD");
  });
});

defNew("lollipop", "Lollygagging", "words", "Lollygagging…", (c, t) => {
  const sw = Math.round(Math.sin(t * 1.4) * 2);
  R(c, 1, 6, 1, 16, WOOD); R(c, 38, 6, 1, 16, WOOD);
  const X = 12 + sw, Y = Y0 + 1;
  clawd(c, X, Y, { eyes: st(t, 1.5, 2) ? "closed" : "happy", legs: "none", armR: "up" });
  for (let i = 2; i < 38; i++) { const y = 8 + Math.round(Math.sin(Math.PI * (i - 2) / 36) * 12) + (i > 8 && i < 32 ? 0 : 0); R(c, i + (i > 6 && i < 34 ? sw : 0), Math.min(y, 20), 1, 1, i % 2 ? "#F0997B" : "#FAC775"); }
  R(c, X + 15, Y - 6, 1, 5, WHITE);
  const sp = st(t, 4, 4);
  glyph(c, [".###.", "#####", "#####", "#####", ".###."], X + 13, Y - 11, "#ED93B1");
  [[1, 1], [2, 1], [3, 2], [3, 3], [2, 3], [1, 2]].forEach(([dx, dy], i) => { if ((i + sp) % 2) R(c, X + 13 + dx, Y - 11 + dy, 1, 1, WHITE); });
});

defNew("gesticulate", "Gesticulating", "words", "Gesticulating…", (c, t) => {
  const f = st(t, 5, 4), poses = [["up", "out"], ["out", "up"], ["up", "up"], ["down", "out"]];
  clawd(c, X0, Y0 - (f === 2 ? 1 : 0), { eyes: f % 2 ? "wide" : "closed", armL: poses[f][0], armR: poses[f][1] });
  if (f === 0 || f === 2) { R(c, X0 - 3, Y0 - 3, 1, 2, "#888780"); R(c, X0 - 4, Y0, 2, 1, "#888780"); }
  if (f === 1 || f === 2) { R(c, X0 + 18, Y0 - 3, 1, 2, "#888780"); R(c, X0 + 18, Y0, 2, 1, "#888780"); }
  glyph(c, st(t, 2, 2) ? G.bang : G.q, X0 + 22, Y0 - 6, "#FAC775");
});

defNew("sax", "Improvising", "words", "Improvising…", (c, t) => {
  const sw = Math.round(Math.sin(t * 3) * 1), X = 6 + sw, Y = Y0;
  clawd(c, X, Y, { eyes: "closed", armR: "down" });
  glyph(c, ["##....", ".#....", ".#....", ".#....", ".#..##", ".#..#.", ".####.", "..##.."], X + 14, Y + 2, "#EF9F27");
  [[1, 3], [1, 5]].forEach(([dx, dy]) => R(c, X + 15 + dx - 1, Y + 2 + dy, 1, 1, "#854F0B"));
  for (let i = 0; i < 3; i++) { const q = (t * 0.6 + i / 3) % 1; alpha(c, 1 - q, () => glyph(c, G.note, X + 19 + q * 10, Y + 2 - q * 12 + Math.sin(q * 9) * 2, ["#FAC775", "#85B7EB", "#ED93B1"][i])); }
});

defNew("propeller", "Whirring", "words", "Whirring…", (c, t) => {
  const p = (t % 3) / 3, h = Math.round(Math.sin(Math.max(0, p - 0.15) / 0.85 * Math.PI) * 7), Y = Y0 - h;
  alpha(c, 0.5 - h * 0.04, () => R(c, X0 + 3 + Math.floor(h / 3), 22, 10 - Math.floor(h / 3) * 2, 1, "#5f5e5a"));
  clawd(c, X0, Y, { eyes: h ? "happy" : "up", legs: h > 1 ? 3 : 0, armL: h ? "down" : "out", armR: h ? "down" : "out" });
  R(c, X0 + 4, Y - 2, 3, 2, "#E24B4A"); R(c, X0 + 7, Y - 2, 2, 2, "#FAC775"); R(c, X0 + 9, Y - 2, 3, 2, "#378ADD");
  R(c, X0 + 7, Y - 4, 2, 2, METAL);
  if (st(t, 12, 2)) R(c, X0 + 2, Y - 5, 12, 1, "#E24B4A"); else R(c, X0 + 6, Y - 5, 4, 1, "#E24B4A");
});

defNew("pram", "Perambulating", "words", "Perambulating…", (c, t) => {
  const x = 4, px = x + 18, f = st(t, 3, 2), bump = st(t, 1.5, 4) === 0 ? 1 : 0;
  // He strolls on the spot and the path slides by, so the pair is always in view.
  for (let i = 0; i < 4; i++) R(c, ((i * 11 - t * 6) % 44 + 44) % 44 - 3, 22, 3, 1, "#444441");
  const fx = 44 - ((t * 6) % 70);
  glyph(c, G.flower, fx, 17, "#ED93B1"); R(c, fx + 1, 18, 1, 1, "#FAC775"); R(c, fx + 1, 20, 1, 2, "#639922");
  mini(c, px + 2, 11 - bump, 0);
  R(c, px, 15 - bump, 12, 5, "#7F77DD"); glyph(c, ["..####", ".#####", "######"], px + 6, 11 - bump, "#534AB7");
  R(c, px + 1, 20, 2, 2, INK); R(c, px + 9, 20, 2, 2, INK);
  line(c, x + 15, Y0 + 3, px, 15 - bump, METAL);
  clawd(c, x, Y0, { eyes: "right", legs: f + 1 });
  const hp = (t % 3) / 3; if (hp < 0.5) alpha(c, Math.min(1, (0.5 - hp) * 4), () => glyph(c, G.heartS, px + 4, 7 - Math.round(hp * 8), "#E24B4A"));
});

defNew("reassemble", "Recombobulating", "words", "Recombobulating…", (c, t) => {
  const p = (t % 3.5) / 3.5;
  let s = 0;
  if (p > 0.3 && p < 0.45) s = (p - 0.3) / 0.15; else if (p >= 0.45 && p < 0.55) s = 1; else if (p >= 0.55 && p < 0.85) s = 1 - (p - 0.55) / 0.3;
  s = s * s;
  let k = 0;
  for (let by = 0; by < 5; by++) for (let bx = 0; bx < 8; bx++, k++) {
    const dx = Math.round((rnd(k) - 0.5) * 30 * s), dy = Math.round((rnd(k + 50) - 0.5) * 18 * s);
    clip(c, X0 + bx * 2 + dx, Y0 + by * 2 + dy, 2, 2, () => clawd(c, X0 + dx, Y0 + dy, { eyes: p > 0.85 ? "happy" : "open" }));
  }
});

defNew("tea", "Infusing", "words", "Infusing…", (c, t) => {
  const X = 8, Y = Y0, dunk = st(t, 1.5, 2), steep = Math.min(1, (t % 6) / 6);
  R(c, 26, 15, 8, 7, WHITE); R(c, 34, 16, 2, 1, WHITE); R(c, 35, 17, 1, 2, WHITE); R(c, 34, 19, 2, 1, WHITE);
  R(c, 27, 15, 6, 1, steep > 0.5 ? "#854F0B" : "#BA7517");
  const bx = 29, by = dunk ? 14 : 10;
  line(c, X + 15, Y - 5, bx + 1, by, GLASS);
  clip(c, 0, 0, 40, 15, () => R(c, bx, by, 3, 3, "#C9A26B"));
  for (let i = 0; i < 2; i++) { const q = (t * 0.7 + i / 2) % 1; alpha(c, 1 - q, () => R(c, 28 + i * 3 + Math.sin(q * 6) , 13 - q * 7, 1, 1, "#888780")); }
  clawd(c, X, Y, { eyes: "happy", armR: "up" });
});

defNew("machine", "Contraption", "words", "Boondoggling…", (c, t) => {
  const p = (t % 4.5) / 4.5;
  line(c, 1, 7, 15, 11, WOOD); line(c, 19, 14, 5, 18, WOOD); R(c, 15, 11, 1, 3, WOOD); R(c, 19, 14, 1, 8, WOOD);
  const pressed = p > 0.62;
  R(c, 1, pressed ? 21 : 20, 5, pressed ? 1 : 2, "#E24B4A"); R(c, 1, 21, 5, 1, "#E24B4A");
  const [bx, by] = path([[2, 4, 0.05], [13, 7, 0.25], [16, 9, 0.3], [17, 12, 0.34], [6, 15, 0.55], [3, 19, 0.62]], p);
  if (p > 0.03) R(c, bx, by, 2, 2, METAL);
  const lit = pressed && p < 0.97;
  glyph(c, G.bulb, 28, 2, lit ? "#FAC775" : "#444441"); glyph(c, G.bulbBase, 29, 7, METAL);
  if (lit && st(t, 4, 2)) { R(c, 26, 3, 1, 1, "#FAC775"); R(c, 34, 3, 1, 1, "#FAC775"); R(c, 30, 0, 1, 1, "#FAC775"); }
  clawd(c, 22, Y0, { eyes: lit ? "happy" : "left", armR: lit ? "up" : "out" });
});

defNew("detective", "Sleuthing", "words", "Inferring…", (c, t) => {
  const x = 3, f = st(t, 2, 2);
  // He follows the trail on the spot: the footprints slide towards him and show up bright under the glass.
  for (let i = 0; i < 6; i++) {
    const fx = Math.round(((i * 7 - t * 3) % 42 + 42) % 42) - 1;
    if (fx < x + 17) continue;
    const seen = fx <= x + 20;
    R(c, fx, seen ? 20 : 21 - (i % 2), 2, 1, seen ? WHITE : "#888780");
  }
  clawd(c, x, Y0, { eyes: "right", legs: f + 1, armR: "down" });
  R(c, x + 3, Y0 - 3, 10, 3, "#854F0B"); [[4, -3], [7, -3], [10, -3], [5, -2], [8, -2], [11, -2]].forEach(([dx, dy]) => R(c, x + dx, Y0 + dy, 1, 1, "#BA7517"));
  R(c, x + 1, Y0 - 1, 3, 1, "#854F0B"); R(c, x + 12, Y0 - 1, 3, 1, "#854F0B");
  line(c, x + 15, Y0 + 6, x + 17, Y0 + 7, WOOD);
  glyph(c, [".###.", "#...#", "#...#", "#...#", ".###."], x + 17, Y0 + 5, METAL);
  alpha(c, 0.35, () => R(c, x + 18, Y0 + 6, 3, 3, "#85B7EB"));
});

/* =====================================================================
   Batch 6 — one animation for every remaining status word
   ===================================================================== */
NEW.clear();

/* ---- word batch: kitchen ---- */
/* Kitchen words — twenty cooking gags, each its own scene (the chef-hat "cook" already covers Cooking). */
(() => {
  const DOUGH = "#EBD9B4", CRUST = "#BA7517", BROWN = "#854F0B", DARK = "#2c2c2a", POT = "#444441", RIM = "#5f5e5a";
  const RED = "#E24B4A", YEL = "#FAC775", AMBER = "#EF9F27", BLUE = "#85B7EB", BLUE2 = "#378ADD";
  const LEAF = "#97C459", STEM = "#639922", GREY = "#888780";
  const hex = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
  const mix = (a, b, k) => { k = Math.max(0, Math.min(1, k)); const A = hex(a), B = hex(b); return "#" + A.map((v, i) => Math.round(v + (B[i] - v) * k).toString(16).padStart(2, "0")).join(""); };
  const sm = k => { k = Math.max(0, Math.min(1, k)); return k * k * (3 - 2 * k); };
  const seg = (p, a, b) => Math.max(0, Math.min(1, (p - a) / (b - a)));
  const PI = Math.PI;
  function dome(c, cx, base, hw, h, col) {          // half-ellipse sitting on y = base
    for (let dx = -hw; dx <= hw; dx++) { const hh = Math.round(h * Math.sqrt(Math.max(0, 1 - (dx / (hw + 0.5)) ** 2))); if (hh > 0) R(c, cx + dx, base - hh, 1, hh, col); }
  }
  function disc(c, cx, cy, r, col) {
    for (let dy = -r; dy <= r; dy++) { const w = Math.round(Math.sqrt(Math.max(0, r * r - dy * dy))); R(c, cx - w, cy + dy, w * 2 + 1, 1, col); }
  }
  function steam(c, x, y, t, n, gap, h) {
    for (let i = 0; i < n; i++) { const q = (t * 0.8 + i / n) % 1; alpha(c, 1 - q, () => R(c, x + i * gap + Math.round(Math.sin(q * 6 + i)), y - Math.round(q * h), 1, 1, GREY)); }
  }
  function mitts(c, x, y, o = {}) {                 // blue oven mitts on whatever the arms are doing
    [[x, o.armL || "out"], [x + 14, o.armR || "out"]].forEach(([ax, m]) => {
      if (m === "out") R(c, ax, y + 4, 2, 2, BLUE2); else if (m === "up") R(c, ax, y - 1, 2, 2, BLUE2); else if (m === "down") R(c, ax, y + 6, 2, 2, BLUE2);
    });
  }

  /* Baking — the loaf rises behind the oven window, ding, out it comes and gets wolfed down */
  defNew("w-baking", "Baking", "words", "Baking…", (c, t) => {
    const p = t % 5, X = 4, Y = Y0;
    R(c, 22, 6, 17, 16, POT); R(c, 22, 6, 17, 3, RIM);
    R(c, 24, 7, 2, 1, METAL); R(c, 27, 7, 2, 1, METAL);
    const ding = p > 2.6 && p < 3.2, open = p > 3.2 && p < 4.7;
    R(c, 31, 7, 6, 1, ding && st(t, 8, 2) ? RED : "#173404");
    R(c, 24, 11, 13, 8, DARK);
    alpha(c, 0.35 + 0.1 * Math.sin(t * 6), () => R(c, 24, 11, 13, 8, AMBER));
    R(c, 24, 18, 13, 1, METAL);
    const rise = sm(p / 2.6), loafCol = mix(DOUGH, CRUST, rise);
    if (p < 3.4) dome(c, 30, 18, 3, 2 + Math.round(rise * 3), loafCol);
    else if (p > 4.6) alpha(c, seg(p, 4.6, 4.95), () => dome(c, 30, 18, 3, 2, DOUGH));
    if (!open) {
      alpha(c, 0.18, () => R(c, 24, 11, 13, 8, GLASS));
      R(c, 23, 10, 15, 1, RIM); R(c, 23, 19, 15, 1, RIM); R(c, 23, 10, 1, 10, RIM); R(c, 37, 10, 1, 10, RIM);
      R(c, 25, 10, 11, 1, METAL);
      R(c, 22, 20, 17, 2, POT);
    } else {
      R(c, 21, 19, 19, 3, RIM); R(c, 23, 21, 15, 1, METAL);
    }
    if (ding) { glyph(c, G.bell, 28, 0, YEL); if (st(t, 8, 2)) { R(c, 25, 2, 1, 1, YEL); R(c, 35, 2, 1, 1, YEL); } }
    const jump = ding && p < 2.9 ? 1 : 0, eat = p > 3.7 && p < 4.6;
    const o = { eyes: ding ? "wide" : (p > 3.4 && p < 4.7 ? "happy" : "right"), legs: jump ? 3 : 0 };
    clawd(c, X, Y - jump, o); mitts(c, X, Y - jump, o);
    if (p >= 3.4 && p < 4.6) {                     // loaf slides to his mitt, then bite by bite it's gone
      const k = sm(seg(p, 3.4, 3.7)), lx = Math.round(30 - k * 9), ly = Math.round(18 - k * 2);
      const hw = eat ? 3 - Math.floor(seg(p, 3.8, 4.5) * 4) : 3;
      if (hw >= 0) dome(c, lx, ly, hw, 5, CRUST);
      if (hw >= 0) steam(c, lx - 1, ly - 6, t, 2, 2, 5);
      if (eat && st(t, 6, 2)) { R(c, lx - 3, ly - 2, 1, 1, CRUST); R(c, lx + 2, ly - 4, 1, 1, CRUST); }
    }
  });

  /* Blanching — boiling pot, hop, ice bath: he goes red, then pale, then back to normal */
  defNew("w-blanching", "Blanching", "words", "Blanching…", (c, t) => {
    const p = t % 4, HOT = RED, PALE = "#ece6dc";
    let x, y, col, eyes, legs = 0, where = "";
    if (p < 1.2) { x = 2; y = 9; col = mix(CL, HOT, sm(p / 1.0)); eyes = "closed"; where = "A"; }
    else if (p < 1.7) { const k = (p - 1.2) / 0.5; x = 2 + 20 * k; y = 9 - Math.sin(k * PI) * 8; col = HOT; eyes = "wide"; legs = 3; }
    else if (p < 3.0) { x = 22 + (st(t, 14, 2) ? 1 : 0); y = 9; col = mix(HOT, PALE, sm((p - 1.7) / 0.4)); eyes = p < 2.1 ? "wide" : "x"; where = "B"; }
    else if (p < 3.5) { const k = (p - 3) / 0.5; x = 22 - 20 * k; y = 9 - Math.sin(k * PI) * 8; col = PALE; eyes = "closed"; legs = 3; }
    else { x = 2; y = 9; col = mix(PALE, CL, sm((p - 3.5) / 0.5)); eyes = "happy"; where = "A"; }
    clawd(c, x, y, { color: col, eyes, legs, armL: where ? "out" : "up", armR: where ? "out" : "up" });
    // hot pot on a burner
    R(c, 1, 15, 19, 5, POT); R(c, 0, 15, 21, 1, RIM); R(c, 2, 20, 17, 1, DARK); R(c, 1, 21, 19, 1, RIM);
    for (let i = 0; i < 5; i++) R(c, 4 + i * 3, 20 - st(t + i * 0.13, 7, 2), 1, 1 + st(t + i * 0.13, 7, 2), i % 2 ? AMBER : YEL);
    steam(c, 4, 13, t, 4, 4, 9);
    for (let i = 0; i < 3; i++) { const q = (t * 1.5 + i / 3) % 1; R(c, 3 + i * 6 + (where === "A" && i === 1 ? 13 : 0), 14 - Math.round(q * 2), 1, 1, BLUE); }
    // ice bath
    R(c, 21, 16, 19, 4, BLUE2); R(c, 22, 20, 17, 1, BLUE2); R(c, 24, 21, 13, 1, BLUE2); R(c, 20, 15, 21, 1, BLUE);
    [[22, 0], [34, 1], [28, 2]].forEach(([ix, i]) => R(c, ix + (where === "B" && i === 2 ? 9 : 0), 13 + st(t + i * 0.4, 2, 2), 2, 2, WHITE));
    if (where === "B" && p > 2.1) { R(c, x - 2, y + 1 + st(t, 6, 2), 1, 2, BLUE); R(c, x + 17, y + 2 - st(t, 6, 2), 1, 2, BLUE); }
  });

  /* Bunning — Clawd is the hot dog: lying in the bun while a mustard zigzag goes on, then shakes it off */
  defNew("w-bunning", "Bunning", "words", "Bunning…", (c, t) => {
    const p = t % 4, BUN = "#C9A26B", MUST = YEL;
    const shake = p > 3.1 && p < 3.6, X = 12 + (shake ? (st(t, 16, 2) ? 1 : -1) : 0), Y = 11;
    R(c, 8, 14, 25, 1, CRUST); R(c, 7, 15, 27, 4, BUN);                    // back half of the bun
    const happy = p > 2.4 && p < 3.1;
    clawd(c, X, Y - (happy && st(t, 6, 2) ? 1 : 0), { legs: "none", eyes: happy ? "happy" : (shake ? "closed" : "up"), armL: happy ? "up" : "none", armR: happy ? "up" : "none" });
    const k = seg(p, 0.4, 2.4), end = 14 + Math.round(k * 12);
    if (p < 3.1) for (let x = 14; x <= end && x <= 26; x++) R(c, x, 15 + (Math.floor((x - 14) / 2) % 2), 1, 1, MUST);
    if (shake || (p >= 3.6 && p < 3.9)) for (let i = 0; i < 6; i++) { const q = seg(p, 3.1, 3.9), a = i / 6 * PI * 2; alpha(c, 1 - q, () => R(c, 20 + Math.cos(a) * (6 + q * 12), 15 + Math.sin(a) * (2 + q * 8), 1, 1, MUST)); }
    R(c, 6, 18, 29, 1, CRUST); R(c, 5, 19, 31, 2, BUN); R(c, 6, 21, 29, 1, BUN);     // front half
    // the mustard bottle, upside down
    let bx, by;
    if (p < 0.4) { bx = 14; by = Math.round(-2 + 11 * sm(p / 0.4)); }
    else if (p < 2.4) { bx = end; by = 9; }
    else { bx = 26; by = Math.round(9 - 18 * sm(seg(p, 2.4, 3.0))); }
    if (by > -9) { R(c, bx - 2, by - 8, 5, 6, MUST); R(c, bx - 1, by - 9, 3, 1, MUST); R(c, bx - 2, by - 2, 5, 1, RED); R(c, bx - 1, by - 1, 3, 1, RED); R(c, bx - 1, by - 6, 1, 3, WHITE); }
    if (p > 0.4 && p < 2.4 && st(t, 10, 2)) R(c, bx, by, 1, 15 + (Math.floor((end - 14) / 2) % 2) - by, MUST);
  });

  /* Caramelizing — a crème brûlée slides in, gets torched golden, then tap-tap, crack */
  defNew("w-caramelizing", "Caramelizing", "words", "Caramelizing…", (c, t) => {
    const p = t % 5, X = 2, Y = Y0;
    const rx = Math.round(p < 0.6 ? 40 - 16 * sm(p / 0.6) : p < 4.4 ? 24 : 24 + 17 * sm((p - 4.4) / 0.6));
    const burn = seg(p, 0.8, 2.8), top = burn < 0.5 ? mix(WHITE, AMBER, burn * 2) : mix(AMBER, CRUST, (burn - 0.5) * 2);
    R(c, rx, 15, 11, 7, WHITE); for (let i = 1; i < 11; i += 2) R(c, rx + i, 17, 1, 5, "#c2c0b6");
    R(c, rx + 1, 15, 9, 2, top);
    const cracked = p > 3.3;
    if (cracked) { R(c, rx + 3, 15, 1, 1, BROWN); R(c, rx + 4, 16, 1, 1, BROWN); R(c, rx + 6, 15, 1, 1, BROWN); R(c, rx + 5, 16, 1, 1, BROWN); R(c, rx + 7, 16, 1, 1, BROWN); }
    if (p > 3.3 && p < 3.9) { const q = seg(p, 3.3, 3.9); [[-1, 0], [1, 1], [0.4, 2]].forEach(([d, i]) => R(c, rx + 5 + d * q * 6, 14 - Math.sin(q * PI) * (4 + i), 1, 1, CRUST)); }
    const spoon = p > 3.0 && p < 3.7, happy = p > 3.4 && p < 4.6;
    clawd(c, X, Y, { eyes: happy ? "happy" : "right" });
    if (p > 0.5 && p < 3.0) {                       // torch
      R(c, 18, 12, 3, 6, RED); R(c, 18, 11, 3, 1, METAL); R(c, 21, 11, 2, 1, METAL); R(c, 22, 12, 1, 1, METAL);
      if (burn > 0 && burn < 1) {
        const tx = rx + 2 + Math.round(((t * 1.4) % 1 < 0.5 ? (t * 1.4) % 1 : 1 - (t * 1.4) % 1) * 12);
        line(c, 23, 13, tx, 14, BLUE); R(c, 23 + st(t, 12, 2), 13, 1, 1, BLUE2);
        R(c, tx, 15, 1, 1, st(t, 10, 2) ? YEL : WHITE);
      }
    }
    if (spoon) { const up = p < 3.22 || p > 3.45, sx = rx + 4, sy = up ? 9 : 13; line(c, 17, 16, sx, sy, METAL); R(c, sx, sy, 2, 2, METAL); }
    if (happy && st(t, 4, 2)) glyph(c, G.star, rx + 9, 10, YEL);
  });

  /* Drizzling — a little syrup raincloud on a string, steered over a pancake stack */
  defNew("w-drizzling", "Drizzling", "words", "Drizzling…", (c, t) => {
    const X = 3, Y = Y0, PC = "#C9A26B";
    const cx = 23 + Math.round((Math.sin(t * 1.6) + 1) * 3.5), cy = 3;
    R(c, 20, 21, 19, 1, WHITE);
    for (let i = 0; i < 3; i++) { const y = 19 - i * 2; R(c, 22, y, 15, 2, PC); R(c, 22, y + 1, 15, 1, CRUST); }
    R(c, 22, 15, 15, 1, BROWN); R(c, 27, 14, 4, 1, YEL);
    [24, 29, 34].forEach((dx, i) => {                // syrup runs down the stack, a drop falls off
      const q = (t * 0.45 + i * 0.37) % 1, len = Math.round(Math.min(q / 0.75, 1) * 4);
      R(c, dx, 16, 1, len, BROWN);
      if (q > 0.75) R(c, dx, 20 + Math.round(seg(q, 0.75, 1) * 1), 1, 1, BROWN);
    });
    for (let i = 0; i < 4; i++) { const q = (t * 1.6 + i / 4) % 1; R(c, cx + 1 + i * 2, cy + 4 + Math.round(q * 8), 1, 2, BROWN); }
    clawd(c, X, Y, { eyes: "up", armR: "up" });
    line(c, X + 15, Y - 2, cx + 4, cy + 3, GLASS);
    glyph(c, ["...###.....", "..#####.##.", ".##########", "###########", ".#########."], cx - 1, cy - 1, CRUST);
    R(c, cx + 2, cy - 1, 3, 1, YEL); R(c, cx + 1, cy, 2, 1, YEL);
  });

  /* Flambéing — match to the cherries, WHOOSH, singed and sooty */
  defNew("w-flambeing", "Flambéing", "words", "Flambéing…", (c, t) => {
    const p = t % 4;
    R(c, 24, 19, 13, 2, METAL); R(c, 26, 21, 9, 1, METAL); R(c, 23, 18, 15, 1, GLASS);
    [26, 29, 32, 34].forEach((x, i) => R(c, x, 17, 2, 1, RED));
    const boom = p > 1.2 && p < 2.6, back = sm(seg(p, 1.22, 1.35)) - sm(seg(p, 3.2, 3.8));
    const X = 3 - Math.round(back * 2), Y = Y0 - (p > 1.22 && p < 1.5 ? 2 : 0);
    if (boom) {
      const H = 17 * sm(seg(p, 1.2, 1.4)) * (1 - sm(seg(p, 2.0, 2.6)));
      for (let i = 0; i < 13; i++) {
        const shape = 1 - Math.abs(i - 6) / 8, h = Math.round(H * shape * (0.7 + 0.3 * Math.sin(t * 25 + i * 1.7)));
        if (h > 0) { R(c, 24 + i, 18 - h, 1, h, RED); if (h > 3) R(c, 24 + i, 18 - h + 2, 1, h - 2, AMBER); if (h > 7 && i > 2 && i < 10) R(c, 24 + i, 18 - h + 5, 1, h - 5, YEL); }
      }
    } else if (p >= 2.6) {
      const n = Math.round(4 * (1 - seg(p, 2.6, 4)));
      for (let i = 0; i < n; i++) R(c, 26 + i * 3, 16 - st(t + i * 0.2, 8, 2), 1, 1 + st(t + i * 0.3, 7, 2), BLUE);
    }
    const sooty = p > 2.0 && p < 3.8;
    clawd(c, X, Y, { eyes: boom ? "wide" : (sooty && p < 3.1 ? "closed" : "right"), armL: boom ? "up" : "out", armR: boom ? "up" : "out", legs: Y < Y0 ? 3 : 0, color: sooty ? mix(CL, "#993C1D", 1 - seg(p, 3.0, 3.8)) : CL });
    if (sooty && p < 3.4) { R(c, X + 7, Y + 1, 1, 1, EYE); R(c, X + 9, Y + 5, 1, 1, EYE); R(c, X + 3, Y + 6, 1, 1, EYE); steam(c, X + 5, Y - 1, t, 3, 3, 6); }
    if (!boom) {                                     // the long match
      const k = sm(seg(p, 0.2, 1.2)), mx = Math.round(X + 20 + k * 5), my = Math.round(Y + 2 + k * 3);
      line(c, X + 16, Y + 4, mx, my, WOOD);
      if (p < 1.25 && p > 0.15) R(c, mx, my - 1, 1, 1, st(t, 10, 2) ? YEL : AMBER);
      else if (p <= 0.15 && st(t, 20, 2)) { R(c, mx + 1, my - 2, 1, 1, YEL); R(c, mx - 1, my - 1, 1, 1, WHITE); }
      else R(c, mx, my, 1, 1, EYE);
    }
  });

  /* Garnishing — Clawd garnishes himself on a plate, poses, then sneezes it all off */
  defNew("w-garnishing", "Garnishing", "words", "Garnishing…", (c, t) => {
    const p = t % 5, X = X0, Y = Y0 - 1;
    R(c, 2, 21, 36, 1, WHITE); R(c, 4, 22, 32, 1, GLASS);
    const dots = [[5, 20], [30, 20], [33, 20], [35, 20], [3, 20]];
    dots.forEach(([x, y], i) => { const on = seg(p, 1.5 + i * 0.1, 1.55 + i * 0.1); if (on > 0) alpha(c, on * (1 - seg(p, 3.9, 4.5)), () => R(c, x, y, 1, 1, RED)); });
    const sneeze = p > 3.6 && p < 3.9, achoo = p >= 3.9 && p < 4.3, pose = p > 2.0 && p < 3.6;
    const o = { eyes: pose ? "happy" : (sneeze || achoo ? "closed" : "up"), squash: sneeze ? Math.round(seg(p, 3.6, 3.85) * 2) : 0,
      armR: p < 0.8 ? "up" : (pose ? "up" : "out"), armL: p > 0.6 && p < 1.4 ? "up" : "out" };
    clawd(c, X, Y, o);
    if (achoo) { R(c, X + 17, Y + 3, 2, 1, WHITE); R(c, X + 18, Y + 6, 2, 1, WHITE); R(c, X - 3, Y + 4, 2, 1, WHITE); }
    // parsley sprig: drops into his raised hand, onto his head, flies off on the sneeze
    const sprig = (x, y) => { glyph(c, [".#.#.", "##.##", ".###."], Math.round(x), Math.round(y), LEAF); R(c, Math.round(x) + 2, Math.round(y) + 3, 1, 1, STEM); };
    if (p < 0.3) sprig(X + 13, -4 + 6 * sm(p / 0.3));
    else if (p < 0.8) { const k = sm(seg(p, 0.5, 0.8)); sprig(X + 13 - k * 7, Y - 6 + k * 2); }
    else if (p < 3.9) sprig(X + 6, Y - 4);
    else if (p < 4.5) { const k = seg(p, 3.9, 4.5); sprig(X + 6 - k * 22, Y - 4 - Math.sin(k * PI * 0.9) * 8 - k * 6); }
    // lemon wheel: into his left hand, leaned against him, rolls away on the sneeze
    const lemon = (x, y) => { x = Math.round(x); y = Math.round(y); disc(c, x, y, 2, YEL); R(c, x, y - 1, 1, 3, WHITE); R(c, x - 1, y, 3, 1, WHITE); };
    if (p > 0.6 && p < 0.9) lemon(X + 1, -3 + 9 * sm(seg(p, 0.6, 0.9)));
    else if (p >= 0.9 && p < 1.4) { const k = sm(seg(p, 1.1, 1.4)); lemon(X + 1 - k * 6, Y - 6 + k * 13); }
    else if (p >= 1.4 && p < 3.9) lemon(X - 5, Y + 7);
    else if (p >= 3.9 && p < 4.6) { const k = seg(p, 3.9, 4.6); lemon(X - 5 - k * k * 26, Y + 7); }
    if (pose && st(t, 4, 2)) { glyph(c, G.star, X + 18, Y - 4, WHITE); glyph(c, G.star, X - 5, Y - 2, YEL); }
  });

  /* Julienning — chop-chop along a carrot, toss the matchsticks, fetch the next carrot */
  defNew("w-julienning", "Julienning", "words", "Julienning…", (c, t) => {
    const p = t % 4, K = AMBER;
    let X, prog, cdx = 0;
    if (p < 2.4) { prog = p / 2.4; X = 2 + Math.round(prog * 14); }
    else if (p < 3.2) { prog = 1; X = 16; }
    else { prog = 1; X = 16 - Math.round(sm((p - 3.2) / 0.8) * 14); cdx = Math.round(24 * (1 - sm((p - 3.2) / 0.8))); }
    const chopping = p < 2.4, down = chopping && st(t, 10, 2), walk = p >= 3.2;
    clawd(c, X, Y0, { eyes: p >= 2.4 && p < 3.2 ? "happy" : "down", armR: down ? "down" : (p >= 2.4 && p < 3.2 ? "up" : "out"), armL: p >= 2.4 && p < 3.2 ? "up" : "out", legs: walk ? st(t, 8, 2) + 1 : 0 });
    R(c, 0, 19, 40, 2, WOOD); R(c, 0, 21, 40, 1, "#854F0B");
    const cut = X + 18;
    if (p < 2.4) {                                   // carrot: sticks to the left of the knife, whole to the right
      for (let x = 20; x < cut; x += 2) R(c, x, 17 - (x > cut - 4 && st(t + x, 10, 2) ? 1 : 0), 1, 2, K);
      R(c, Math.max(cut, 20), 17, 36 - Math.max(cut, 20), 2, K); if (cut <= 20) R(c, 19, 18, 1, 1, K);
      glyph(c, ["#.#", ".##", "##."], 36, 15, LEAF);
    } else if (p < 3.2) {
      const q = seg(p, 2.4, 3.2);
      for (let x = 20, i = 0; x < 36; x += 2, i++) { const sp = 0.6 + rnd(i) * 0.6; R(c, x + q * q * (20 + i * 2), 17 - Math.sin(Math.min(1, q * sp * 1.6) * PI) * (6 + rnd(i + 9) * 6) - q * 12, 1, 2, K); }
    }
    if (p >= 3.2) { R(c, 20 + cdx, 17, 16, 2, K); R(c, 19 + cdx, 18, 1, 1, K); glyph(c, ["#.#", ".##", "##."], 36 + cdx, 15, LEAF); }
    if (chopping) { const ky = down ? 14 : 11; R(c, X + 16, ky, 3, 2, INK); R(c, X + 18, ky + 2, 4, 3 + (down ? 1 : 0), METAL); R(c, X + 18, ky + 4 + (down ? 1 : 0), 4, 1, WHITE); if (down) R(c, X + 22, 16, 1, 1, K); }
  });

  /* Kneading — behind the counter on a stool, pressing the dough left, right, left, right */
  defNew("w-kneading", "Kneading", "words", "Kneading…", (c, t) => {
    const X = X0, Y = 9, f = st(t, 3, 2), ph = (t * 3) % 1, press = Math.sin(ph * PI), L = f === 0;
    clawd(c, X, Y + (press > 0.6 ? 1 : 0), { eyes: "closed", armL: "none", armR: "none", squash: press > 0.6 ? 1 : 0, legs: 3 });
    R(c, 1, 19, 38, 1, WOOD); R(c, 1, 20, 38, 1, "#854F0B"); R(c, 3, 21, 2, 2, WOOD); R(c, 35, 21, 2, 2, WOOD);
    const pawX = [X + 3, X + 11], dentX = L ? pawX[0] + 1 : pawX[1] + 1, other = L ? pawX[1] + 1 : pawX[0] + 1;
    const top = [];
    for (let dx = -9; dx <= 9; dx++) {
      const x = X + 8 + dx; let h = 4 * Math.sqrt(Math.max(0, 1 - (dx / 9.5) ** 2));
      h -= press * 2 * Math.max(0, 1 - Math.abs(x - dentX) / 3); h += press * Math.max(0, 1 - Math.abs(x - other) / 3);
      const hh = Math.max(1, Math.round(h)); top[x] = 19 - hh; R(c, x, 19 - hh, 1, hh, DOUGH); if (hh > 2) R(c, x, 18, 1, 1, "#d3c29b");
    }
    pawX.forEach((px, i) => {                        // stubby paws pressing in turn, like a cat making biscuits
      const pressing = (i === 0) === L, y = Math.min(top[px], top[px + 1]) - 1 + (pressing ? Math.round(press) : -1);
      R(c, px, y, 2, 3, CL); R(c, px - 1, y, 1, 3, "#b8644a"); R(c, px + 2, y, 1, 3, "#b8644a");
    });
    if (press > 0.75) for (let i = 0; i < 3; i++) R(c, dentX - 3 + i * 3, 13 - Math.round(press * 2) - (i % 2), 1, 1, WHITE);
    [[4, 18], [8, 18], [31, 18], [35, 18]].forEach(([x, y]) => R(c, x, y, 1, 1, WHITE));
  });

  /* Leavening — riding the dough as it rises out of the bowl, then sinks back down */
  defNew("w-leavening", "Leavening", "words", "Leavening…", (c, t) => {
    const p = (t % 4) / 4, k = (1 - Math.cos(p * 2 * PI)) / 2, h = Math.round(2 + k * 7);
    const hw = 9 + Math.round(k * 2);
    dome(c, 20, 17, hw, h, DOUGH);
    [[-5, 0.2], [4, 0.55], [7, 0.85]].forEach(([dx, o]) => { const q = (t * 0.8 + o) % 1; if (q < 0.6) { const top = 17 - Math.round(h * Math.sqrt(Math.max(0, 1 - (dx / (hw + 0.5)) ** 2))); R(c, 20 + dx, top + 1, 1, 1, "#d3c29b"); } });
    const Y = 17 - h - 8 + 1;
    clawd(c, 12, Y, { legs: "none", eyes: k > 0.7 ? "happy" : (p < 0.5 ? "up" : "down"), armL: k > 0.6 ? "up" : "out", armR: k > 0.6 ? "up" : "out" });
    R(c, 7, 16, 27, 1, BLUE); R(c, 8, 17, 25, 3, BLUE2); R(c, 9, 20, 23, 1, BLUE2); R(c, 11, 21, 19, 1, BLUE2);
    R(c, 10, 18, 3, 1, BLUE);
    if (k > 0.85 && st(t, 4, 2)) { glyph(c, G.star, 4, Y + 1, YEL); glyph(c, G.star, 33, Y + 3, YEL); }
  });

  /* Marinating — soaking in a dish of marinade like a hot tub, shades on, getting basted */
  defNew("w-marinating", "Marinating", "words", "Marinating…", (c, t) => {
    const p = t % 4, bob = Math.round(Math.sin(t * 2) * 0.6), X = 12, Y = 9 + bob;
    const pour = p > 2 && p < 3.4, tilt = pour ? 1 : 0;
    clawd(c, X, Y, { eyes: "shades", armL: "out", armR: "out" });
    if (pour) for (let y = 5; y < Y; y++) if ((y + st(t, 10, 2)) % 3) R(c, 20, y, 1, 1, CRUST);
    if (pour && p > 2.2) { R(c, 18, Y, 1, 1, CRUST); R(c, 22, Y, 1, 1, CRUST); }
    const lx = 16, ly = p < 1.6 ? -6 + 6 * sm(seg(p, 1.4, 2)) : 2 - 8 * sm(seg(p, 3.4, 3.9));
    const ladleY = Math.round(p < 1.6 ? -6 : p < 3.4 ? -6 + 8 * sm(seg(p, 1.6, 2)) : 2 - 8 * sm(seg(p, 3.4, 3.9)));
    if (ladleY > -5) { line(c, lx - 6, ladleY - 3, lx + 1, ladleY + 1, METAL); R(c, lx + 2, ladleY + tilt, 4, 2, METAL); R(c, lx + 3 + tilt, ladleY + 2, 2, 1, METAL); }
    R(c, 3, 16, 34, 5, BROWN); R(c, 3, 16, 34, 1, CRUST);
    for (let x = 3; x < 37; x += 4) if ((x + Math.floor(t * 4)) % 8 < 4) R(c, x, 16, 2, 1, BROWN);
    R(c, 2, 15, 1, 7, GLASS); R(c, 37, 15, 1, 7, GLASS); R(c, 3, 21, 34, 1, GLASS);
    alpha(c, 0.25, () => R(c, 3, 17, 34, 1, WHITE));
    const b = i => Math.round(Math.sin(t * 2 + i * 1.3));
    R(c, 5, 15 + b(0), 3, 1, STEM); R(c, 6, 14 + b(0), 1, 1, LEAF);
    R(c, 31, 15 + b(1), 3, 1, STEM); R(c, 32, 14 + b(1), 1, 1, LEAF);
    R(c, 9, 15 + b(2), 1, 1, EYE); R(c, 28, 15 + b(3), 1, 1, EYE); R(c, 34, 16 + b(4), 1, 1, EYE);
    R(c, 25, 15 + b(5), 2, 1, WHITE);
    for (let i = 0; i < 3; i++) { const q = (t * 0.9 + i / 3) % 1; alpha(c, 1 - q, () => R(c, 6 + i * 12 + Math.round(Math.sin(q * 6)), 15 - Math.round(q * 4), 1, 1, YEL)); }
  });

  /* Onioning — peeling a giant onion layer by layer, tears spraying out like sprinklers */
  defNew("w-onioning", "Onioning", "words", "Onioning…", (c, t) => {
    const p = t % 5, X = 1, Y = Y0, OC = "#7F77DD", OL = "#AFA9EC";
    const peels = [0.9, 1.7, 2.5, 3.3], n = peels.filter(v => p > v).length;
    let ox = 30, r = [7, 6, 5, 4, 3][n], oy = 21 - r;
    if (p > 3.9 && p < 4.4) { const k = seg(p, 3.9, 4.4); ox = 30 + k * 14; oy = 18 - Math.sin(k * PI) * 10 - k * 8; r = 3; }
    if (p >= 4.4) { r = 7; ox = 30 + Math.round(14 * (1 - sm(seg(p, 4.4, 5)))); oy = 21 - r; }
    ox = Math.round(ox); oy = Math.round(oy);
    if (p < 4.4 || p >= 4.4) {
      disc(c, ox, oy, r, OC);
      for (let dy = -r + 1; dy < r; dy++) { const w = Math.round(Math.sqrt(r * r - dy * dy) * 0.5); R(c, ox - w, oy + dy, 1, 1, OL); R(c, ox + w, oy + dy, 1, 1, OL); }
      R(c, ox, oy - r - 1, 1, 1, CRUST); R(c, ox, oy - r - 2, 1, 1, CRUST);
    }
    peels.forEach(pk => {                            // each peeled layer flips away
      const q = seg(p, pk, pk + 0.6); if (q <= 0 || q >= 1) return;
      const px = 30 + q * 10, py = 12 - Math.sin(q * PI) * 10;
      glyph(c, st(t, 8, 2) ? [".##.", "#..#"] : ["#..#", ".##."], px, py, OC);
    });
    const crying = p < 4.4 ? Math.min(3, n) + 1 : Math.max(0, Math.round(4 * (1 - seg(p, 4.4, 5))));
    const reach = peels.some(pk => p > pk - 0.25 && p < pk + 0.05);
    clawd(c, X, Y, { eyes: crying ? "closed" : "open", armR: reach ? "up" : "out" });
    for (let i = 0; i < crying * 2; i++) {
      const q = (t * 1.5 + i / (crying * 2)) % 1, s = i % 2 ? 1 : -1, ex = s < 0 ? X + 4 : X + 11;
      R(c, ex + s * q * 7, Y + 2 - 6 * q + 14 * q * q, 1, 1, BLUE);
    }
    const pw = Math.round((p < 4.4 ? 2 + n * 3 : 14 * (1 - seg(p, 4.4, 5))));
    if (pw > 0) R(c, X + 8 - pw / 2, 21, pw, 1, BLUE);
  });

  /* Proofing — dough rising under a checked tea towel; the poke test springs back, ✓, off to the oven */
  defNew("w-proofing", "Proofing", "words", "Proofing…", (c, t) => {
    const p = t % 5, X = 3, Y = Y0;
    const bx = Math.round(p < 4.2 ? 24 : p < 4.6 ? 24 + 18 * sm(seg(p, 4.2, 4.6)) : 42 - 18 * sm(seg(p, 4.6, 5)));
    const fresh = p >= 4.6, rise = fresh ? 0 : sm(p / 2.4), h = 1 + rise * 5;
    R(c, bx - 1, 17, 16, 1, BLUE); R(c, bx, 18, 14, 3, BLUE2); R(c, bx + 2, 21, 10, 1, BLUE2);
    const cx = bx + 7, poked = p > 3.0 && p < 4.2, dent = poked ? (p < 3.4 ? 2 : 1) : 0;
    for (let dx = -8; dx <= 8; dx++) {
      let hh = Math.round(h * Math.sqrt(Math.max(0, 1 - (dx / 8.5) ** 2)));
      if (dx === -5 || dx === -4) hh = Math.max(1, hh - dent);
      const top = 17 - hh;
      for (let y = top; y <= 17 + (Math.abs(dx) > 6 ? 2 : 0); y++) R(c, cx + dx, y, 1, 1, ((Math.floor((cx + dx) / 2) + y) % 2) ? RED : WHITE);
    }
    const reach = Math.round(sm(seg(p, 2.6, 3.0)) * (1 - sm(seg(p, 3.5, 3.8))) * 5);
    const happy = p > 3.4 && p < 4.4;
    clawd(c, X, Y, { eyes: happy ? "happy" : (p < 2.4 ? "right" : "down"), legs: p < 2.4 ? st(t, 2, 2) : 0 });
    if (reach > 0) R(c, X + 16, Y + 4, reach, 1, CL);
    if (happy) glyph(c, G.check, cx - 2, 17 - Math.round(h) - 7, LEAF);
  });

  /* Sautéing — pan toss; one bit lands on his head, and the next toss he nods it back in */
  defNew("w-sauteing", "Sautéing", "words", "Sautéing…", (c, t) => {
    const P = 0.8, n = Math.floor(t / P) % 3, q = (t % P) / P, X = 3, Y = Y0;
    const dy = q < 0.15 ? -Math.round(sm(q / 0.15) * 2) : -Math.round((1 - sm(seg(q, 0.15, 0.4))) * 2);
    R(c, 20, 19, 16, 3, POT); R(c, 20, 19, 16, 1, RIM);
    for (let x = 22; x < 34; x += 2) R(c, x, 17 + st(t + x * 0.07, 9, 2), 1, 2 - st(t + x * 0.07, 9, 2), st(t + x, 5, 2) ? BLUE2 : BLUE);
    const head = [X + 7, Y - 2];
    const veg = [[AMBER, 23], [LEAF, 25], [RED, 27], [YEL, 29], [LEAF, 31]];
    const pieces = veg.map(([col, x0], i) => {
      const k = seg(q, 0.1, 0.85), H = 5 + (i % 3) * 2;
      let x = x0 + Math.sin(k * PI) * (i - 2), y = 14 + dy - H * 4 * k * (1 - k);
      if (i === 2 && n === 1) { x = x0 + (head[0] - x0) * k; y = (14 + dy) + (head[1] - 14 - dy) * k - 12 * 4 * k * (1 - k); }
      if (i === 2 && n === 2) { const j = seg(q, 0.3, 0.9); x = head[0] + (x0 - head[0]) * j; y = head[1] + (14 + dy - head[1]) * j - 9 * 4 * j * (1 - j); }
      return [col, x, y];
    });
    const lookUp = (n === 1 && q > 0.7) || (n === 2 && q < 0.5);
    clawd(c, X, Y + (n === 2 && q > 0.2 && q < 0.35 ? 1 : 0), { eyes: lookUp ? "up" : "right", squash: n === 2 && q > 0.2 && q < 0.35 ? 1 : 0 });
    pieces.forEach(([col, x, y]) => R(c, x, y, 2, 1, col));
    line(c, X + 16, Y + 4, 21, 15 + dy, DARK);
    R(c, 21, 15 + dy, 13, 1, POT); R(c, 22, 16 + dy, 11, 1, DARK); R(c, 21, 14 + dy, 1, 1, POT); R(c, 33, 14 + dy, 1, 1, POT);
    steam(c, 23, 11 + dy, t, 3, 4, 5);
  });

  /* Seasoning — one shake per season: snow, blossom, sunshine, falling leaves */
  defNew("w-seasoning", "Seasoning", "words", "Seasoning…", (c, t) => {
    const SEA = 1.4, TOT = SEA * 4, p = t % TOT, s = Math.floor(p / SEA), into = (p % SEA) / SEA;
    const GND = [WHITE, LEAF, STEM, CRUST];
    R(c, 0, 22, 40, 1, mix(GND[(s + 3) % 4], GND[s], into * 3));
    alpha(c, s === 2 ? Math.min(1, into * 4, (1 - into) * 4) : 0, () => { disc(c, 5, 4, 2, YEL); if (st(t, 4, 2)) { R(c, 1, 4, 1, 1, YEL); R(c, 9, 4, 1, 1, YEL); R(c, 5, 0, 1, 1, YEL); R(c, 5, 8, 1, 1, YEL); } });
    const X = 8, Y = Y0, j = st(t, 8, 2);
    clawd(c, X, Y, { eyes: ["wide", "happy", "shades", "closed"][s], armR: "up" });
    if (s === 0 && st(t, 12, 2)) R(c, X - 1, Y + 3, 1, 1, BLUE);
    const sx = X + 17, sy = 3 + j;                 // upside-down shaker, shaking
    R(c, sx, sy, 5, 7, WHITE); R(c, sx, sy + 7, 5, 2, METAL); R(c, sx + 1, sy + 8, 1, 1, INK); R(c, sx + 3, sy + 8, 1, 1, INK);
    R(c, X + 14, Y - 2, 3, 1, CL);
    const L = 1.6;
    for (let i = 0; i < 22; i++) {
      const o = rnd(i + 1), a = (t + o * L) % L, te = t - a, se = Math.floor(((te % TOT) + TOT) % TOT / SEA);
      const vx = (rnd(i + 40) - 0.35) * 22, x = sx + 2 + vx * a + (se === 1 || se === 3 ? Math.sin(a * 6 + i) * 1.5 : 0), y = sy + 10 + 4 * a + 3 * a * a;
      if (y > 21 || x < 0 || x > 39) continue;
      const col = [WHITE, "#ED93B1", YEL, [AMBER, CRUST, RED][i % 3]][se];
      if (se === 2 && st(t + i * 0.1, 6, 2)) continue;
      R(c, x, y, se === 3 ? 2 : 1, 1, col);
    }
  });

  /* Simmering — sat on a low flame with a lid on his head, the lid rattling and puffing */
  defNew("w-simmering", "Simmering", "words", "Simmering…", (c, t) => {
    const X = X0, Y = 8, q = t % 1.5, rattle = q > 1.0 && q < 1.3, lift = rattle && st(t, 12, 2) ? 1 : 0;
    R(c, 4, 19, 32, 3, POT); R(c, 4, 19, 32, 1, RIM); R(c, X + 2, 18, 12, 1, DARK);
    R(c, 31, 20, 3, 2, METAL); R(c, 31, 20, 1, 1, INK);
    for (let x = X + 3; x <= X + 12; x += 3) R(c, x, 17, 1, 1, st(t + x * 0.1, 6, 2) ? BLUE2 : BLUE);
    clawd(c, X, Y, { legs: "none", eyes: "closed", armL: "out", armR: "out" });
    const lx = rattle ? (st(t, 12, 2) ? 1 : -1) : 0;
    R(c, X + 1 + lx, Y - 1 - lift, 14, 1, METAL); R(c, X + 3 + lx, Y - 2 - lift, 10, 1, METAL); R(c, X + 7 + lx, Y - 3 - lift, 2, 1, INK);
    if (rattle) { R(c, X - 1, Y - 2, 1, 1, GREY); R(c, X + 16, Y - 2, 1, 1, GREY); }
    for (let i = 0; i < 2; i++) { const k = ((t * 0.6) + i / 2) % 1; alpha(c, 1 - k, () => { R(c, X - 1 - Math.round(k * 3), Y - 2 - Math.round(k * 6), 1, 1, GREY); R(c, X + 16 + Math.round(k * 3), Y - 2 - Math.round(k * 6), 1, 1, GREY); }); }
    for (let i = 0; i < 4; i++) { const k = ((t * 0.7) + i / 4) % 1, bx = [X + 1, X + 14, X - 1, X + 16][i]; if (k < 0.8) glyph(c, G.bubble, bx, 16 - Math.round(k * 4) - 1, BLUE); }
  });

  /* Stewing — sulking in the stew pot, arms crossed, a little storm cloud overhead */
  defNew("w-stewing", "Stewing", "words", "Stewing…", (c, t) => {
    const X = X0, Y = 8;
    for (let i = 0; i < 8; i++) R(c, 8 + i * 3, 21 - st(t + i * 0.17, 7, 2), 1, 1 + st(t + i * 0.17, 7, 2), i % 2 ? AMBER : RED);
    R(c, 6, 13, 29, 1, BROWN);
    clawd(c, X, Y, { eyes: "open", armL: "none", armR: "none" });
    R(c, X + 3, Y, 1, 1, EYE); R(c, X + 4, Y + 1, 2, 1, EYE); R(c, X + 12, Y, 1, 1, EYE); R(c, X + 10, Y + 1, 2, 1, EYE);   // cross brows
    R(c, X + 4, Y + 5, 8, 1, "#b8644a"); R(c, X + 2, Y + 4, 2, 2, CL); R(c, X + 12, Y + 4, 2, 2, CL);
    const b = i => Math.round(Math.sin(t * 2.5 + i * 1.7) * 0.6);
    R(c, 7, 12 + b(0), 2, 1, AMBER); R(c, 10, 13 + b(1), 2, 2, DOUGH); R(c, 29, 12 + b(2), 2, 2, DOUGH); R(c, 32, 13 + b(3), 2, 1, AMBER); R(c, 26, 13 + b(4), 1, 1, LEAF);
    R(c, 5, 14, 31, 6, POT); R(c, 4, 14, 33, 1, RIM); R(c, 2, 15, 2, 2, RIM); R(c, 37, 15, 2, 2, RIM); R(c, 6, 20, 29, 1, POT);
    const cy = 0, cx = X + 4;
    glyph(c, G.cloud, cx, cy + 1, "#5f5e5a"); R(c, cx + 1, cy, 2, 1, "#5f5e5a"); R(c, cx + 4, cy, 2, 1, "#5f5e5a");
    if (st(t, 1.5, 3) === 2 && st(t, 10, 2)) { line(c, cx + 4, 4, cx + 3, 5, YEL); R(c, cx + 3, 5, 1, 1, YEL); R(c, cx + 2, 6, 1, 1, YEL); }
    for (let i = 0; i < 3; i++) { const q = (t * 1.6 + i / 3) % 1; R(c, cx + 1 + i * 2, 4 + Math.round(q * 3), 1, 1, BLUE); }
    for (let i = 0; i < 2; i++) { const q = (t * 0.7 + i / 2) % 1; if (q < 0.7) glyph(c, G.bubble, i ? 30 : 7, 11 - Math.round(q * 4), CRUST); }
  });

  /* Tempering — the thermometer climbs and Clawd loses his temper; he blows it back down to the mark */
  defNew("w-tempering", "Tempering", "words", "Tempering…", (c, t) => {
    const p = t % 4.2, X = 3, Y = Y0;
    const lvl = p < 1.4 ? 10 - 6 * sm(p / 1.4) : p < 2.8 ? 4 + 6 * sm((p - 1.4) / 1.4) : 10;
    const heat = (10 - lvl) / 6, L = Math.round(lvl);
    R(c, 29, 2, 3, 15, GLASS); R(c, 30, 3, 1, 13, DARK); R(c, 30, L, 1, 16 - L, RED);
    for (let y = 4; y < 16; y += 2) R(c, 32, y, 1, 1, GREY);
    R(c, 32, 10, 2, 1, LEAF); R(c, 27, 10, 2, 1, LEAF);
    R(c, 23, 16, 15, 1, "#6b4423"); R(c, 25, 16, 2, 1, "#8a5a2b");
    R(c, 23, 17, 15, 2, METAL); R(c, 24, 19, 13, 1, METAL); R(c, 26, 20, 9, 1, METAL); R(c, 28, 21, 5, 1, METAL);
    const blowing = p >= 1.4 && p < 2.8, happy = p >= 2.8 && p < 3.9;
    clawd(c, X + (heat > 0.6 && st(t, 14, 2) ? 1 : 0), Y, { color: mix(CL, RED, heat * 0.85), eyes: happy ? "happy" : blowing ? "closed" : (heat > 0.45 ? "wide" : "right"), armR: happy ? "up" : "out", squash: blowing && st(t, 3, 2) ? 1 : 0 });
    if (heat > 0.5 && !blowing) steam(c, X + 5, Y - 1, t * 1.6, 3, 3, 6);
    if (blowing) for (let i = 0; i < 3; i++) { const q = (t * 1.8 + i / 3) % 1; alpha(c, 1 - q * 0.7, () => glyph(c, G.puff, X + 17 + Math.round(q * 8), Y + 2 - Math.round(q * 3), WHITE)); }
    if (happy && st(t, 4, 2)) glyph(c, G.star, 34, 7, YEL);
  });

  /* Whisking — egg in, whisk to stiff peaks, the bowl-over-the-head test… and splat */
  defNew("w-whisking", "Whisking", "words", "Whisking…", (c, t) => {
    const p = t % 4.4, X = X0, Y = 10;
    const fh = p < 0.4 ? 0 : p < 2.2 ? seg(p, 0.4, 2.0) : p < 3.2 ? 1 : 0;
    const whisk = p >= 0.4 && p < 2.2, overhead = p >= 2.4 && p < 3.9;
    const lift = p >= 2.2 && p < 2.4 ? seg(p, 2.2, 2.4) : p >= 3.9 ? 1 - seg(p, 3.9, 4.3) : overhead ? 1 : 0;
    const splat = p >= 3.35 && p < 4.4;
    const bowlRows = [[0, 22], [0, 22], [1, 20], [2, 18], [4, 14]];
    const bowl = (by, inv, sx = 0) => bowlRows.forEach(([ins, w], j) => R(c, 9 + sx + ins, inv ? by + 4 - j : by + j, w, 1, j === 0 ? BLUE : BLUE2));
    const foamUp = (base, k) => { if (k <= 0) return; dome(c, 20, base, 6, Math.round(k * 3), WHITE); if (k > 0.8) { R(c, 20, base - 4, 1, 1, WHITE); R(c, 21, base - 5, 1, 1, WHITE); } };
    const armsUp = overhead || (lift > 0.3);
    clawd(c, X, Y + (splat && p < 3.5 ? 1 : 0), { eyes: whisk ? "down" : overhead ? (splat ? (p < 3.8 ? "closed" : "happy") : "up") : p < 0.4 ? "up" : "happy", armL: armsUp ? "up" : "out", armR: armsUp ? "up" : (whisk ? "out" : "out"), squash: splat && p < 3.5 ? 1 : 0 });
    if (lift > 0 && lift < 1) { const by = Math.round(17 - lift * 13), sx = Math.round(Math.sin(lift * PI) * 17); c.save(); c.translate(sx, 0); foamUp(by, fh); c.restore(); bowl(by, false, sx); }
    else if (lift >= 1) {                            // upside down over his head; the meringue clings… then lets go
      bowl(2, true);
      if (!splat) { const k = 1, d = 3; for (let dx = -6; dx <= 6; dx++) { const hh = Math.round(d * Math.sqrt(1 - (dx / 6.5) ** 2)); if (hh > 0) R(c, 20 + dx, 7, 1, hh, WHITE); } R(c, 20, 10, 1, 1, WHITE); }
      if (p > 2.6 && p < 3.3 && st(t, 4, 2)) glyph(c, G.star, 33, 3, YEL);
    } else { bowl(17, false); foamUp(17, fh); }
    if (splat) {
      const q = seg(p, 3.9, 4.4), w = Math.round(6 - q * 6);
      if (p < 3.45) { const fy = Math.round(7 + seg(p, 3.35, 3.45) * 2); dome(c, 20, fy + 3, 6, 3, WHITE); }
      else if (w > 0) { dome(c, 20, Y, w, 2, WHITE); if (q < 0.3) { R(c, X + 2, Y, 1, 2, WHITE); R(c, X + 13, Y, 1, 3, WHITE); } }
      if (q > 0 && q < 1) for (let i = 0; i < 4; i++) R(c, 20 + (i - 1.5) * q * 14, Y - 2 - Math.sin(q * PI) * 5, 1, 1, WHITE);
    }
    if (p < 0.4) { const ey = Math.round(-4 + seg(p, 0, 0.25) * 9); glyph(c, [".##.", "#..#", ".##."], 18, ey, WHITE); if (p > 0.25) R(c, 20, 13 + Math.round(seg(p, 0.25, 0.4) * 3), 1, 1, WHITE); }
    if (whisk) {
      const f = st(t, 14, 3), wx = 21 + (st(t, 7, 2) ? 1 : 0);
      glyph(c, [["#...#", "#...#", ".#.#.", "..#.."], [".#.#.", ".#.#.", ".#.#.", "..#.."], ["..#..", "..#..", "..#..", "..#.."]][f], wx, 13, METAL);
      line(c, wx + 2, 12, X + 15, Y + 4, INK);
      if (st(t, 6, 2)) { R(c, 14, 12, 1, 1, WHITE); R(c, 29, 13, 1, 1, WHITE); }
    }
  });

  /* Zesting — lemon on the microplane, zest snowing down, then a squirt right in the eye */
  defNew("w-zesting", "Zesting", "words", "Zesting…", (c, t) => {
    const p = t % 4, X = 2, LEM = YEL;
    const hit = p > 2.75 && p < 3.4, Y = Y0 - (hit && p < 3.1 ? 2 : 0);
    const rubbing = p < 2.5, rb = (p * 1.2 + 0.075) % 1, k = rubbing ? (rb < 0.5 ? rb * 2 : 2 - rb * 2) : 0.15;
    clawd(c, X, Y, { eyes: hit ? "x" : (p >= 3.4 && p < 3.8 ? "happy" : "right"), legs: hit && p < 3.1 ? 3 : 0, armL: hit ? "up" : "out" });
    line(c, X + 16, Y + 4, 21, 16, INK);
    for (let o = 0; o < 2; o++) line(c, 22, 16 + o, 37, 20 + o, METAL);
    for (let i = 0; i < 7; i++) R(c, 23 + i * 2, 17 + Math.round(i * 0.55), 1, 1, INK);
    let lx = 24 + k * 9, ly = 11 + k * 2.4;
    if (p >= 3.4 && p < 3.7) { const q = seg(p, 3.4, 3.7); lx += q * 14; ly -= Math.sin(q * PI * 0.6) * 14 + q * 6; }
    if (p >= 3.7) { const q = sm(seg(p, 3.7, 4)); lx = 24 + 0.15 * 9; ly = -8 + (11 + 0.15 * 2.4 + 8) * q; }
    lx = Math.round(lx); ly = Math.round(ly);
    glyph(c, [".####.", "######", "######", ".####."], lx, ly, LEM); R(c, lx - 1, ly + 1, 1, 2, AMBER); R(c, lx + 6, ly + 1, 1, 2, AMBER);
    const worn = p < 3.7 ? seg(p, 0, 2.6) : 0;
    [[1, 3], [4, 3], [2, 2], [3, 3], [5, 2]].forEach(([dx, dy], i) => { if (worn > (i + 1) / 6) R(c, lx + dx, ly + dy, 1, 1, WHITE); });
    for (let i = 0; i < 6; i++) { const q = (t * 1.4 + i / 6) % 1, zx = 25 + rnd(i + Math.floor(t * 1.4 + i / 6) * 7) * 10; if (rubbing || q < 0.5) alpha(c, 1 - q * 0.6, () => R(c, zx + Math.sin(q * 8 + i), 18 + Math.round(zx - 23) * 0.27 + q * 4, 1, 1, i % 2 ? LEM : AMBER)); }
    if (p > 2.6 && p < 2.8) { const q = seg(p, 2.6, 2.8); for (let i = 0; i < 3; i++) R(c, lx - 1 + (X + 11 - lx + 1) * (q - i * 0.12), ly + 1 + (Y + 2 - ly - 1) * (q - i * 0.12) - Math.sin((q - i * 0.12) * PI) * 3, 1, 1, LEM); }
    if (hit) { const z = st(t, 8, 2); [[-3, -2], [17, -2], [-3, 8], [17, 8], [7, -4]].forEach(([dx, dy], i) => { if ((i + z) % 2) R(c, X + dx, Y + dy, dx === 7 ? 1 : 2, dx === 7 ? 2 : 1, LEM); }); }
  });
})();


/* ---- word batch: lab ---- */
/* =====================================================================
   Word batch: lab — science, alchemy, magic and number-crunching words
   ===================================================================== */
(() => {
  const PURP = "#7F77DD", LILAC = "#AFA9EC", PALE = "#EEEDFE", GOLD = "#FAC775", AMBER = "#EF9F27";
  const MINT = "#5DCAA5", LEAF = "#97C459", FERN = "#639922", SKY = "#85B7EB", BLUE = "#378ADD", ICE = "#B5D4F4";
  const DARK = "#444441", COAL = "#2c2c2a", GREY = "#888780", SLATE = "#5f5e5a", RED = "#E24B4A", PINK = "#ED93B1";
  const CARD = "#C9A26B", CARD2 = "#8a5a2b", BROWN = "#854F0B";
  const ease = k => k * k * (3 - 2 * k);
  const cl01 = k => Math.max(0, Math.min(1, k));
  const seg = (p, a, b) => cl01((p - a) / (b - a));
  const STAR = [".#.", "#.#", ".#."];
  const puffAt = (c, x, y, k) => alpha(c, 1 - k, () => {   // a quick white poof centred on x, y
    const r = 2 + k * 6;
    for (let i = 0; i < 8; i++) { const a = i * Math.PI / 4; glyph(c, G.puff, x - 2 + Math.cos(a) * r, y - 1 + Math.sin(a) * r * 0.6, WHITE); }
    glyph(c, G.cloud, x - 3, y - 1, WHITE);
  });

  /* ---------- Brewing: witch's cauldron ---------- */
  defNew("w-brewing", "Brewing", "words", "Brewing…", (c, t) => {
    const X = 3, Y = Y0, a = t * 3.2, sx = Math.round(30 + Math.cos(a) * 4);
    const f = st(t, 6, 2);                                                 // fire under the pot
    R(c, 27, 21, 6, 1, f ? AMBER : GOLD); R(c, 28 + f, 20, 2, 1, RED); R(c, 31 - f, 20, 1, 1, AMBER);
    R(c, 23, 13, 14, 1, MINT); R(c, 25 + ((Math.floor(t * 5)) % 9), 13, 2, 1, "#9FE1CB");
    line(c, X + 16, Y + 4, sx, 13, WOOD); line(c, X + 16, Y + 3, sx, 12, WOOD);
    glyph(c, [".##############.", "################", "################", "################", "################",
              ".##############.", "..############..", "...##........##."], 22, 14, COAL);
    R(c, 22, 13, 1, 1, SLATE); R(c, 37, 13, 1, 1, SLATE); R(c, 23, 15, 1, 3, SLATE);
    for (let i = 0; i < 3; i++) {                                         // goo bubbles rise and pop
      const q = (t * 0.9 + i / 3) % 1, n = Math.floor(t * 0.9 + i / 3), bx = 24 + Math.round(rnd(n * 3 + i) * 10);
      if (q < 0.7) { const by = 12 - Math.round(q / 0.7 * 6); R(c, bx, by, q > 0.35 ? 2 : 1, q > 0.35 ? 2 : 1, MINT); }
      else { const k = (q - 0.7) / 0.3; alpha(c, 1 - k, () => { [[-1, -1], [2, -1], [-1, 2], [2, 2]].forEach(([dx, dy]) => R(c, bx + dx * (1 + k), 6 + dy * (1 + k), 1, 1, MINT)); }); }
    }
    const big = (t % 3) > 2.5;
    clawd(c, X, Y, { eyes: big ? "happy" : "right" });
    glyph(c, ["......#.....", ".....##.....", "....####....", "....####....", "...######...", "############"], X + 2, Y - 6, "#534AB7");
    R(c, X + 5, Y - 2, 6, 1, GOLD);
  });

  /* ---------- Crystallizing: amethyst spikes grow around him, then shatter ---------- */
  defNew("w-crystallizing", "Crystallizing", "words", "Crystallizing…", (c, t) => {
    const p = (t % 4.5) / 4.5, X = X0, Y = Y0;
    const spike = (x, h) => { if (h < 1) return; const top = 22 - h;
      R(c, x + 1, top, 1, 1, PALE); if (h > 1) { R(c, x, top + 1, 3, h - 1, LILAC); R(c, x, top + 1, 1, h - 1, PALE); R(c, x + 2, top + 1, 1, h - 1, PURP); } };
    const grow = seg(p, 0.08, 0.5), shatter = p > 0.68 && p < 0.72;
    const back = [[X - 1, 12], [X + 4, 15], [X + 9, 16], [X + 14, 13]], front = [[X - 4, 7], [X + 1, 6], [X + 6, 5], [X + 11, 6], [X + 17, 8]];
    if (p < 0.68) back.forEach(([x, h], i) => spike(x, Math.round(h * ease(cl01(grow * 1.3 - i * 0.08)))));
    const stuck = p > 0.4 && p < 0.68;
    const hop = p > 0.75 && p < 0.95 ? Math.round(Math.sin(seg(p, 0.75, 0.95) * Math.PI) * 3) : 0;
    clawd(c, X + (stuck && st(t, 10, 2) && p > 0.55 ? 1 : 0), Y - hop, {
      eyes: p < 0.12 ? "down" : p < 0.68 ? "wide" : p < 0.75 ? "x" : p < 0.97 ? "happy" : "open",
      armL: p > 0.75 && p < 0.95 ? "up" : "out", armR: p > 0.75 && p < 0.95 ? "up" : "out", legs: hop ? 3 : 0 });
    if (p < 0.68) front.forEach(([x, h], i) => spike(x, Math.round(h * ease(cl01(grow * 1.3 - 0.1 - i * 0.07)))));
    if (stuck && st(t, 3, 2)) glyph(c, STAR, X + [3, 15, 8][Math.floor(t * 3) % 3], [9, 11, 13][Math.floor(t * 3) % 3], WHITE);
    if (p >= 0.68 && p < 0.95) {                                          // shards fly off
      const k = seg(p, 0.68, 0.95);
      alpha(c, 1 - k, () => { for (let i = 0; i < 12; i++) { const a = rnd(i + 3) * Math.PI * 2, d = 4 + k * 14 * (0.5 + rnd(i)); R(c, X + 8 + Math.cos(a) * d, 17 + Math.sin(a) * d * 0.6 + k * k * 6, 2, 1, i % 3 ? LILAC : PALE); } });
    }
    if (shatter) alpha(c, 0.5, () => { R(c, X - 4, 16, 24, 6, WHITE); R(c, X - 4, 8, 3, 8, WHITE); R(c, X + 17, 8, 3, 8, WHITE); });
  });

  /* ---------- Fermenting: dozing next to a jar that fizzes until the lid pops ---------- */
  defNew("w-fermenting", "Fermenting", "words", "Fermenting…", (c, t) => {
    const p = (t % 6) / 6, X = 2, Y = Y0 + 2;
    const pop = p > 0.72 && p < 0.9, press = seg(p, 0.1, 0.72);
    const w = p > 0.5 && p < 0.72 ? Math.round(Math.sin(t * 30) * (p > 0.62 ? 1 : 0.6)) : 0;
    const jx = 25 + w;
    R(c, jx, 10, 12, 12, GLASS); R(c, jx + 1, 11, 10, 10, "#C0DD97"); R(c, jx + 1, 11, 10, 2, "#9FE1CB");
    R(c, jx + 2, 15, 3, 1, FERN); R(c, jx + 6, 17, 4, 1, FERN); R(c, jx + 3, 19, 3, 1, FERN);
    R(c, jx + 1, 12, 1, 8, WHITE);
    const nb = 1 + Math.round(press * 5);
    for (let i = 0; i < nb; i++) { const q = (t * (0.6 + press) + i / nb) % 1; R(c, jx + 2 + Math.round(rnd(i) * 7), 20 - Math.round(q * 8), 1, 1, WHITE); }
    const lift = pop ? Math.round(Math.sin(seg(p, 0.72, 0.9) * Math.PI) * 7) : (p > 0.62 && p < 0.72 && st(t, 12, 2) ? 1 : 0);
    R(c, jx - 1, 8 - lift, 14, 2, METAL); R(c, jx - 1, 9 - lift, 14, 1, GREY);
    if (pop) {                                                            // foam spills over
      const k = seg(p, 0.72, 0.9);
      glyph(c, [".##.###.##.", "###########"], jx + 1, 8 - Math.round(k * 2), WHITE);
      R(c, jx - 1, 9, 2, 2 + Math.round(k * 5), WHITE); R(c, jx + 11, 9, 2, 1 + Math.round(k * 6), WHITE);
      if (k < 0.4) { R(c, jx - 4, 4, 2, 1, GOLD); R(c, jx + 14, 4, 2, 1, GOLD); R(c, jx + 5, 1, 1, 2, GOLD); }
    }
    const awake = p > 0.72 && p < 0.95;
    clawd(c, X, Y - (pop && p < 0.78 ? 2 : 0), { legs: "none", eyes: awake ? (p < 0.82 ? "wide" : "right") : "closed", armL: p > 0.72 && p < 0.8 ? "up" : "out", armR: p > 0.72 && p < 0.8 ? "up" : "out" });
    if (!awake) { const q = (t * 0.6) % 1; alpha(c, 1 - q, () => glyph(c, G.z, X + 15 + Math.round(q * 3), Y - 4 - Math.round(q * 6), GREY)); }
  });

  /* ---------- Ionizing: shuffles in socks on the carpet, then ZAP on the doorknob ---------- */
  defNew("w-ionizing", "Ionizing", "words", "Ionizing…", (c, t) => {
    const p = (t % 4.5) / 4.5;
    R(c, 0, 22, 40, 2, "#993C1D"); for (let x = 1; x < 40; x += 3) R(c, x, 22, 1, 1, "#b8644a");
    R(c, 33, 3, 7, 19, WOOD); R(c, 33, 3, 1, 19, "#6b4423"); R(c, 34, 13, 2, 2, GOLD);
    let x, legs = 0, eyes = "right", armR = "out", col;
    if (p < 0.55) { x = 3 + Math.round(seg(p, 0, 0.55) * 13); legs = st(t, 5, 2) + 1; }
    else if (p < 0.75) { x = 16; }
    else { x = 16 - Math.round(seg(p, 0.75, 1) * 13); legs = st(t, 4, 2) + 1; eyes = "left"; }
    const charge = p < 0.62 ? Math.floor(seg(p, 0.05, 0.6) * 6) : 0;
    const zap = p > 0.62 && p < 0.75;
    if (p > 0.55 && p < 0.75) armR = "none";
    if (zap) { eyes = "x"; col = st(t, 14, 2) ? WHITE : GOLD; legs = 3; }
    const y = Y0 - (zap ? 1 : 0);
    clawd(c, x, y, { legs, eyes, armR, color: col });
    if (p > 0.55 && p < 0.75) R(c, x + 14, y + 4, 34 - x - 16 + 2, 2, col || CL);
    [[1, -3], [14, -4], [7, -5], [-2, 2], [17, 1], [11, -7]].slice(0, charge).forEach(([dx, dy], i) => {
      const b = st(t + i * 0.13, 6, 2), cx = x + dx, cy = y + dy + b;
      R(c, cx, cy + 1, 3, 1, GOLD); R(c, cx + 1, cy, 1, 3, GOLD);
    });
    if (zap) {
      const j = st(t, 14, 2);
      [[33, 14], [35, 9], [37, 17]].forEach(([zx, zy], i) => { line(c, zx, zy, zx + 2 + j, zy - 3, i % 2 ? WHITE : GOLD); line(c, zx + 2 + j, zy - 3, zx, zy - 5, i % 2 ? WHITE : GOLD); });
      if (j) for (let i = 0; i < 4; i++) R(c, x - 3 + rnd(i + Math.floor(t * 14)) * 22, y - 3 + rnd(i + 7 + Math.floor(t * 14)) * 14, 1, 1, GOLD);
    }
    if (p > 0.75 && p < 0.95) { const q = seg(p, 0.75, 0.95); alpha(c, 1 - q, () => R(c, x + 7, y - 3 - Math.round(q * 6), 1, 2, GREY)); }
  });

  /* ---------- Nucleating: he is the nucleus of an atom ---------- */
  defNew("w-nucleating", "Nucleating", "words", "Nucleating…", (c, t) => {
    const X = X0, Y = Y0 - 1 + (st(t, 2, 2) ? 0 : 1), cx = 20, cy = 15;
    const rings = [[0, 18, 3, 1.6], [0.6, 15, 3, -2.1], [-0.6, 15, 3, 2.6]];
    const eyeHit = (px, py) => (py >= Y + 1 && py <= Y + 4) && ((px >= X + 3 && px <= X + 5) || (px >= X + 10 && px <= X + 12));
    const pt = (r, th) => { const [rot, a, b] = r, ex = Math.cos(th) * a, ey = Math.sin(th) * b; return [Math.round(cx + ex * Math.cos(rot) - ey * Math.sin(rot)), Math.round(cy + ex * Math.sin(rot) + ey * Math.cos(rot))]; };
    const pass = front => rings.forEach((r, i) => {
      for (let k = 0; k < 48; k++) { const th = k / 48 * Math.PI * 2; if ((Math.sin(th) > 0) !== front) continue;
        const [px, py] = pt(r, th); if (!eyeHit(px, py)) R(c, px, py, 1, 1, SLATE); }
      const th = t * r[3] + i * 2, [ex, ey] = pt(r, th);
      if ((Math.sin(((th % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2)) > 0) === front && !eyeHit(ex, ey)) R(c, ex - 1, ey - 1, 2, 2, i === 1 ? MINT : SKY);
    });
    pass(false);
    const [lx] = pt(rings[0], t * rings[0][3]);
    clawd(c, X, Y, { eyes: lx < X + 5 ? "left" : lx > X + 11 ? "right" : "happy", legs: 3 });
    R(c, X + 7, Y + 5, 2, 1, GOLD); R(c, X + 8, Y + 4, 1, 3, GOLD);           // a proud little "+" charge
    R(c, X + 7, Y + 5, 3, 1, GOLD);
    pass(true);
  });

  /* ---------- Osmosing: squeezes through a membrane, one way then back ---------- */
  defNew("w-osmosing", "Osmosing", "words", "Osmosing…", (c, t) => {
    const H = 3, T = (t % H) / H, flip = Math.floor(t / H) % 2;
    for (let i = 0; i < 8; i++) {                                         // water molecules drift through
      const q = (t * 0.35 + rnd(i) ) % 1, y = 3 + Math.round(rnd(i + 5) * 17);
      R(c, Math.round(2 + q * 36), y, 1, 1, i % 2 ? SKY : BLUE);
    }
    c.save(); if (flip) { c.translate(SW, 0); c.scale(-1, 1); }
    const x = Math.round(1 + ease(seg(T, 0.05, 0.8)) * 22), inMem = x + 15 >= 19 && x <= 20;
    clawd(c, x, Y0, { eyes: inMem ? "closed" : T > 0.8 ? "happy" : "right", legs: inMem ? st(t, 6, 2) + 1 : T < 0.8 ? st(t, 4, 2) + 1 : 0,
      armL: T > 0.84 && T < 0.97 ? "up" : "out", armR: T > 0.84 && T < 0.97 ? "up" : "out" });
    for (let y = 1; y < 23; y++) if (y % 3) R(c, 19, y, 2, 1, LILAC);         // dashed membrane (gaps line up with his eyes)
    if (inMem) { R(c, 17, 14 + st(t, 8, 2), 1, 1, WHITE); R(c, 22, 18 - st(t, 8, 2), 1, 1, WHITE); }
    c.restore();
  });

  /* ---------- Percolating: riding the lid of a perking coffee pot ---------- */
  defNew("w-percolating", "Percolating", "words", "Percolating…", (c, t) => {
    const per = 0.7, q = (t % per) / per, k = Math.floor(t / per);
    const bump = q < 0.25 ? Math.round(Math.sin(q / 0.25 * Math.PI) * 2) : 0, perk = q < 0.3;
    glyph(c, ["..########..", ".##########.", "############", "############", "############", "############", "############", "############", ".##########."], 14, 13, METAL);
    R(c, 15, 14, 1, 7, WHITE); R(c, 23, 14, 2, 7, GREY); R(c, 13, 21, 14, 1, SLATE);
    R(c, 26, 15, 3, 1, WOOD); R(c, 28, 15, 1, 5, WOOD); R(c, 26, 19, 3, 1, WOOD);      // handle
    R(c, 12, 15, 2, 1, METAL); R(c, 11, 13, 1, 2, METAL); R(c, 10, 12, 1, 1, METAL);   // spout
    R(c, 13, 12, 14, 1, GREY);
    R(c, 18, 10, 4, 2, GLASS); R(c, 19, 10, 2, 2, perk ? "#854F0B" : "#C9A26B");      // the glass knob he sits on
    for (let i = 0; i < 2; i++) { const s = (t * 0.6 + i / 2) % 1; alpha(c, 1 - s, () => R(c, 9 + i * 2 - Math.round(Math.sin(s * 5)), 10 - Math.round(s * 7), 1, 1, GREY)); }
    clawd(c, 12, 2 - bump, { legs: "none", eyes: bump ? "wide" : "closed", armL: bump ? "up" : "out", armR: bump ? "up" : "out" });
    if (perk) { const s = Math.round(q / 0.3 * 4); [[-1, 1], [1, 1], [-1, 0], [1, 0]].forEach(([d, u], i) => R(c, 20 + d * (3 + s + i % 2 * 2), 9 - s * u - (i > 1 ? 1 : 0), 1, 1, i % 2 ? "#BA7517" : "#854F0B")); }
  });

  /* ---------- Sublimating: freezes into an ice cube, vaporizes straight up, rains back down ---------- */
  defNew("w-sublimating", "Sublimating", "words", "Sublimating…", (c, t) => {
    const p = (t % 5) / 5, X = X0, Y = Y0;
    const frz = seg(p, 0.12, 0.28), vap = seg(p, 0.32, 0.62);
    if (p < 0.65) {
      const cut = Math.round(Y - 1 + vap * 12);
      clip(c, 0, cut, 40, 26, () => {
        clawd(c, X, Y, { eyes: p < 0.12 ? "up" : p < 0.3 ? "wide" : "closed", armL: frz > 0 ? "down" : "out", armR: frz > 0 ? "down" : "out" });
        if (frz > 0) alpha(c, frz * 0.9, () => clawd(c, X, Y, { eyes: p < 0.3 ? "wide" : "closed", color: ICE, armL: "down", armR: "down" }));
        if (frz > 0) alpha(c, frz * 0.8, () => { R(c, X + 1, Y - 1, 14, 1, SKY); R(c, X + 1, Y + 10, 14, 1, SKY); R(c, X + 1, Y - 1, 1, 12, SKY); R(c, X + 14, Y - 1, 1, 12, SKY); R(c, X + 3, Y, 1, 3, WHITE); });
      });
      if (p < 0.12) { const q = seg(p, 0, 0.12); glyph(c, STAR, X + 7, Math.round(-2 + q * 9), WHITE); }
      if (vap > 0 && vap < 1) for (let i = 0; i < 6; i++) {                 // wisps rise from the vanishing top
        const q = (t * 1.5 + i / 6) % 1;
        alpha(c, (1 - q) * 0.9, () => R(c, X + 2 + i * 2 + Math.round(Math.sin(q * 6 + i) * 1.5), cut - 1 - Math.round(q * 9), 1, 2, WHITE));
      }
    }
    if (p > 0.5 && p < 0.92) {                                            // a little cloud with his eyes
      const k = seg(p, 0.5, 0.62), drift = Math.round(Math.sin(t * 2) * 2), cy = 2 + Math.round(seg(p, 0.85, 0.92) * 2);
      alpha(c, k, () => {
        glyph(c, ["...####.....", ".########.#.", "############", "############", ".##########."], X + 2 + drift, cy, WHITE);
        R(c, X + 5 + drift, cy + 2, 1, 1, EYE); R(c, X + 9 + drift, cy + 2, 1, 1, EYE);
      });
      if (p > 0.72) for (let i = 0; i < 4; i++) { const q = (t * 3 + i / 4) % 1; R(c, X + 4 + i * 2 + drift, cy + 5 + Math.round(q * 13), 1, 1, SKY); }
    }
    if (p >= 0.86) {                                                      // condenses and drops back in
      const k = seg(p, 0.86, 0.95);
      clawd(c, X, Math.round(4 + (Y - 4) * k * k), { eyes: k < 1 ? "wide" : "happy", legs: k < 1 ? 3 : 0, armL: k < 1 ? "up" : "out", armR: k < 1 ? "up" : "out" });
    }
  });

  /* ---------- Synthesizing: rocking a synth keyboard ---------- */
  defNew("w-synthesizing", "Synthesizing", "words", "Synthesizing…", (c, t) => {
    const bob = st(t, 4, 2), X = X0, Y = Y0 - 3 + bob, f = st(t, 6, 2);
    const shape = Math.floor(t / 2) % 3;                                 // sine, square, saw
    for (let x = 0; x < 40; x++) {
      const ph = (x + t * 14) / 6;
      const v = shape === 0 ? Math.sin(ph) : shape === 1 ? (Math.sin(ph) > 0 ? 1 : -1) : ((ph / Math.PI) % 2) - 1;
      R(c, x, 5 - Math.round(v * 3), 1, 1, [MINT, PINK, GOLD][shape]);
    }
    clawd(c, X, Y, { eyes: "shades", armL: f ? "down" : "out", armR: f ? "out" : "down" });
    line(c, 8, 22, 12, 20, SLATE); line(c, 32, 22, 28, 20, SLATE); line(c, 12, 22, 8, 20, SLATE); line(c, 28, 22, 32, 20, SLATE);
    R(c, 5, 16, 30, 4, DARK); R(c, 6, 16, 28, 1, COAL);
    [[7, RED], [9, GOLD], [11, MINT]].forEach(([kx, kc], i) => R(c, kx, 16, 1, 1, st(t + i * 0.3, 3, 2) ? kc : SLATE));
    for (let k = 0; k < 14; k++) {
      const hit = (k === Math.floor(rnd(Math.floor(t * 6)) * 14)) || (k === Math.floor(rnd(Math.floor(t * 6) + 40) * 14));
      R(c, 6 + k * 2, 17, 1, 3, hit ? GOLD : WHITE);
    }
    if (st(t, 2, 2)) glyph(c, G.note, 34, 8 + st(t, 4, 2), WHITE); else glyph(c, G.note, 1, 9 - st(t, 4, 2), WHITE);
  });

  /* ---------- Transmogrifying: in the cardboard box as Clawd, out as a frog (and back) ---------- */
  defNew("w-transmogrifying", "Transmogrifying", "words", "Transmogrifying…", (c, t) => {
    const H = 3.2, q = (t % H) / H, half = Math.floor(t / H) % 2;
    const frogIn = half === 1, frogOut = half === 0;
    const who = (x, frog, opt = {}) => {
      if (!frog) return clawd(c, x, Y0, opt);
      const hop = opt.legs === 3 ? 2 : 0;
      clawd(c, x, Y0 - hop, { ...opt, color: LEAF, eyes: "none" });
      [[x + 2, 0], [x + 10, 1]].forEach(([ex]) => { R(c, ex, Y0 - hop - 2, 4, 3, LEAF); R(c, ex + 1, Y0 - hop - 1, 2, 1, WHITE); R(c, ex + 2, Y0 - hop - 1, 1, 1, EYE); });
      R(c, x + 5, Y0 - hop + 5, 6, 1, FERN);
      if (opt.tongue) R(c, x + 14, Y0 - hop + 5, 6, 1, RED);
    };
    const bx = 22, shake = q > 0.3 && q < 0.55 ? st(t, 12, 3) - 1 : 0;
    if (q < 0.3) {                                                       // walks into the box
      const x = Math.round(2 + seg(q, 0.02, 0.28) * 21), f = st(t, 5, 2);
      who(x, frogIn, { eyes: "right", legs: frogIn ? (f ? 3 : 0) : f + 1 });
    } else if (q >= 0.55) {
      const k = seg(q, 0.58, 0.82), x = Math.round(23 - k * 21), f = st(t, 5, 2), moving = k > 0 && k < 1;
      who(x, frogOut, { eyes: moving ? "left" : (q > 0.9 ? "happy" : "down"), legs: moving ? (frogOut ? (f ? 3 : 0) : f + 1) : 0, armL: q > 0.88 ? "up" : "out", tongue: frogOut && q > 0.86 && q < 0.92 });
    }
    const X = bx + shake, Yb = 8;                                         // upside-down box with a dial
    R(c, X, Yb, 18, 14, CARD); R(c, X, Yb, 18, 1, CARD2); R(c, X + 1, Yb + 1, 1, 13, "#d9b884"); R(c, X + 17, Yb + 1, 1, 13, CARD2);
    R(c, X + 1, Yb + 13, 16, 1, CARD2);
    glyph(c, [".###.", "#...#", "#...#", "#...#", ".###."], X + 6, Yb + 3, INK);
    const da = q > 0.3 && q < 0.55 ? t * 12 : 0;
    line(c, X + 8, Yb + 5, X + 8 + Math.round(Math.cos(da - 1.57) * 2), Yb + 5 + Math.round(Math.sin(da - 1.57) * 2), RED);
    R(c, X + 3, Yb + 10, 3, 1, INK); R(c, X + 12, Yb + 10, 3, 1, INK);
    if (q > 0.3 && q < 0.58) for (let i = 0; i < 3; i++) if (st(t + i * 0.1, 8, 2)) glyph(c, STAR, X + 2 + Math.round(rnd(i + Math.floor(t * 8)) * 13), 2 + Math.round(rnd(i + 20 + Math.floor(t * 8)) * 3), [GOLD, PINK, SKY][i]);
  });

  /* ---------- Transmuting: alchemy circle turns a lead lump into a gold statue of himself ---------- */
  defNew("w-transmuting", "Transmuting", "words", "Transmuting…", (c, t) => {
    const p = (t % 4.4) / 4.4, X = 2, Y = Y0;
    const glow = p > 0.3 && p < 0.55;
    const ringCol = glow ? (st(t, 10, 2) ? SKY : WHITE) : SLATE;
    glyph(c, ["....#######....", "..##.......##..", "##...........##", "..##.......##..", "....#######...."], 22, 19, ringCol);
    R(c, 29, 19, 1, 5, ringCol);
    let clap = p < 0.18 ? st(t, 5, 2) : 0;
    const press = p > 0.2 && p < 0.55;
    clawd(c, X, Y, { eyes: press ? "closed" : p > 0.6 ? "happy" : "right", armL: press ? "down" : clap ? "up" : "out", armR: press ? "down" : clap ? "up" : "out" });
    if (clap) R(c, X + 7, Y - 6, 2, 1, GOLD);
    if (press) { R(c, X + 14, Y + 8, 2, 1, CL); line(c, X + 16, Y + 9, 22, 21, glow ? SKY : SLATE); }
    if (glow) for (let i = 0; i < 4; i++) { const k = Math.floor(t * 10) + i, sx = 23 + Math.round(rnd(k) * 13), sy = 19 - Math.round(rnd(k + 9) * 6); line(c, sx, sy, sx + 1, sy - 2, SKY); }
    const LUMP = ["..####..", ".######.", "########"];
    const GOLDIE = [".######.", ".#.##.#.", "########", ".######.", ".#....#."];
    const morph = seg(p, 0.42, 0.55), back = seg(p, 0.88, 0.98);
    if (morph < 1 || back >= 1) glyph(c, LUMP, 26, 19, DARK);
    if (morph > 0 && back < 1) {
      const rise = Math.round(morph * 7), cy = 14 + (7 - rise);
      clip(c, 0, 0, 40, 19 + (back > 0 ? -Math.round(back * 6) : 0) + 3, () => {
        glyph(c, GOLDIE, 26, cy, GOLD); R(c, 28, cy + 1, 1, 1, "#BA7517"); R(c, 31, cy + 1, 1, 1, "#BA7517"); R(c, 27, cy + 2, 1, 1, WHITE);
      });
      R(c, 25, 19, 10, 3, AMBER); R(c, 25, 19, 10, 1, GOLD);
      if (p > 0.58 && p < 0.88 && st(t, 4, 2)) glyph(c, STAR, 33 + st(t, 2, 2), 11, WHITE);
    }
    if (back > 0 && back < 1) puffAt(c, 29, 17, back);
  });

  /* ---------- Enchanting: snake charmer ---------- */
  defNew("w-enchanting", "Enchanting", "words", "Enchanting…", (c, t) => {
    const p = (t % 5) / 5, sw = Math.round(Math.sin(t * 2.5)), X = 2 + sw, Y = Y0 + 2;
    const h = Math.round(14 * (p < 0.25 ? ease(seg(p, 0, 0.25)) : p < 0.8 ? 1 : 1 - ease(seg(p, 0.8, 1))));
    const sx = y => 30 + Math.round(Math.sin(y * 0.45 + t * 2.5) * 2 * Math.min(1, h / 8));
    for (let i = 0; i < h; i++) { const y = 16 - i; R(c, sx(y), y, 2, 1, i % 3 ? LEAF : FERN); }
    if (h > 0) {
      const hx = sx(16 - h), hy = 16 - h - 2;
      R(c, hx - 1, hy, 4, 2, LEAF); R(c, hx, hy, 1, 1, EYE); R(c, hx + 2, hy, 1, 1, EYE);
      if (st(t, 3, 2) && h > 6) { R(c, hx + 1, hy + 2, 1, 1, RED); R(c, hx, hy + 3, 1, 1, RED); R(c, hx + 2, hy + 3, 1, 1, RED); }
    }
    glyph(c, [".#########.", "###########", "###########", "###########", ".#########."], 26, 17, "#BA7517");
    R(c, 26, 16, 11, 1, BROWN); [18, 20].forEach(y => R(c, 27, y, 9, 1, BROWN));
    R(c, 0, 22, 22, 1, "#993C1D");
    clawd(c, X, Y, { legs: "none", eyes: "closed", armR: "none" });
    R(c, X + 13, Y + 5, 2, 2, CL);
    R(c, X + 14, Y + 5, 6, 1, WOOD); R(c, X + 19, Y + 4, 2, 3, GOLD);
    const q = (t * 0.8) % 1, q2 = (t * 0.8 + 0.5) % 1;
    alpha(c, 1 - q, () => glyph(c, G.note, X + 18 + Math.round(q * 4), Y - 2 - Math.round(q * 8), WHITE));
    alpha(c, 1 - q2, () => glyph(c, G.heartS, X + 20 + Math.round(q2 * 3), Y - 1 - Math.round(q2 * 8), PINK));
  });

  /* ---------- Transfiguring: a sparkle swirl turns him into a teacup and back ---------- */
  defNew("w-transfiguring", "Transfiguring", "words", "Transfiguring…", (c, t) => {
    const p = (t % 5) / 5, X = X0, Y = Y0;
    const swirl = (k, r0) => { for (let i = 0; i < 6; i++) { const a = t * 7 + i * Math.PI / 3, r = r0 * (1 - k) + 3;
      glyph(c, i % 2 ? STAR : [".", "#"], X + 7 + Math.round(Math.cos(a) * r * 1.3), Y + 4 + Math.round(Math.sin(a) * r * 0.7), i % 3 === 0 ? GOLD : i % 3 === 1 ? PURP : PINK); } };
    const cup = p >= 0.32 && p < 0.72;
    if (!cup) {
      const back = p >= 0.72 && p < 0.96, dazed = back && p < 0.85;
      clawd(c, X, Y, { eyes: p < 0.18 ? "up" : p < 0.32 ? "wide" : dazed ? "down" : "happy", armL: back && !dazed ? "up" : "out", armR: back && !dazed ? "up" : "out" });
    } else {
      const hop = st(t, 3, 2) && p > 0.42 && p < 0.62 ? 1 : 0, y = Y + 2 - hop;
      R(c, X - 1, 21, 18, 1, WHITE); R(c, X + 1, 20, 14, 1, WHITE);
      glyph(c, ["##############", "##############", "##############", "##############", ".############.", "..##########..", "...########..."], X + 1, y + 1, CL);
      R(c, X + 15, y + 2, 2, 1, CL); R(c, X + 16, y + 2, 1, 4, CL); R(c, X + 15, y + 5, 2, 1, CL);
      R(c, X + 1, y + 1, 14, 1, "#854F0B");
      R(c, X + 4, y + 3, 1, 2, EYE); R(c, X + 11, y + 3, 1, 2, EYE);
      for (let i = 0; i < 2; i++) { const q = (t * 0.7 + i / 2) % 1; alpha(c, 1 - q, () => R(c, X + 5 + i * 5 + Math.round(Math.sin(q * 6)), y - 1 - Math.round(q * 7), 1, 2, GREY)); }
    }
    if (p > 0.12 && p < 0.32) swirl(seg(p, 0.12, 0.32), 9);
    if (p > 0.55 && p < 0.72) swirl(seg(p, 0.55, 0.72), 9);
    if (p >= 0.3 && p < 0.42) puffAt(c, X + 8, Y + 4, seg(p, 0.3, 0.42));
    if (p >= 0.7 && p < 0.82) puffAt(c, X + 8, Y + 4, seg(p, 0.7, 0.82));
  });

  /* ---------- Quantumizing: Schrödinger's boxes — he's in both until you look ---------- */
  defNew("w-quantumizing", "Quantumizing", "words", "Quantumizing…", (c, t) => {
    const H = 2.4, q = (t % H) / H, n = Math.floor(t / H), pick = rnd(n * 7 + 1) < 0.5 ? 0 : 1;
    const BX = [2, 22], top = 14;
    const looking = q > 0.38 && q < 0.92, open = q > 0.48 && q < 0.9;
    if (!open) BX.forEach((bx, i) => {                                   // ghost of him flickers in both
      const a = 0.45 + 0.3 * Math.abs(Math.sin(t * 6 + i * 1.6));
      clip(c, 0, 0, 40, top, () => alpha(c, a, () => clawd(c, bx, top - 7 + (i ? st(t, 5, 2) : 1 - st(t, 5, 2)), { eyes: "wide", color: ICE, armL: "up", armR: "up" })));
    });
    if (open) {
      const rise = Math.round(Math.sin(seg(q, 0.48, 0.9) * Math.PI) * 6) + 1, bx = BX[pick];
      clip(c, 0, 0, 40, top + 1, () => clawd(c, bx, top - rise, { eyes: rise > 4 ? "happy" : "wide", armL: "up", armR: "up" }));
      const o = BX[1 - pick];
      if (rise > 4) { R(c, o + 7, top - 3, 1, 1, GREY); R(c, o + 9, top - 4, 1, 1, GREY); }
    }
    BX.forEach((bx, i) => {
      R(c, bx, top + 1, 16, 7, DARK); R(c, bx, top + 1, 16, 1, SLATE);
      glyph(c, G.q, bx + 7, top + 2, i === pick && open ? GREY : GOLD);
      const lidOpen = open && i === pick;
      if (lidOpen) R(c, bx - 1, top - 8, 1, 9, SLATE); else R(c, bx - 1, top, 18, 1, SLATE);
      if (open && i !== pick) R(c, bx - 1, top, 18, 1, SLATE);
    });
    if (looking) {                                                       // the observer's eye
      const k = seg(q, 0.38, 0.48), hgt = Math.max(1, Math.round(k * 3));
      R(c, 17, 3, 6, 1, WHITE); R(c, 16, 4, 8, hgt, WHITE); R(c, 17, 4 + hgt, 6, 1, WHITE);
      if (k > 0.6) R(c, 19 + (pick ? 1 : -1), 4, 2, Math.min(2, hgt), EYE);
    }
  });

  /* ---------- Coalescing: four little helpers merge into one big Clawd ---------- */
  defNew("w-coalescing", "Coalescing", "words", "Coalescing…", (c, t) => {
    const p = (t % 4.6) / 4.6, home = [0, 9, 23, 32], f = st(t, 5, 2);
    const inK = ease(seg(p, 0.02, 0.32)), outK = ease(seg(p, 0.8, 0.98));
    if (p < 0.4 || p >= 0.8) {
      const k = p < 0.4 ? inK : 1 - outK;
      home.forEach((hx, i) => {
        const x = Math.round(hx + (16 - hx) * k), hop = p > 0.32 && p < 0.4 ? Math.round(Math.sin(seg(p, 0.32, 0.4) * Math.PI) * 3) : 0;
        mini(c, x, 17 - hop - (i % 2 && k > 0.95 ? 1 : 0), (k > 0 && k < 1) ? f : 0);
      });
    }
    if (p >= 0.38 && p < 0.82) {
      const grow = seg(p, 0.4, 0.5), shrink = seg(p, 0.72, 0.8);
      const sq = Math.round(6 * (1 - grow) + 6 * shrink);
      clawd(c, X0, Y0, { squash: sq, eyes: sq > 3 ? "closed" : "happy", armL: p > 0.52 && p < 0.7 ? "up" : "out", armR: p > 0.52 && p < 0.7 ? "up" : "out" });
    }
    const flash = (a, b) => { if (p >= a && p < b) { const k = seg(p, a, b); alpha(c, 1 - k, () => { for (let i = 0; i < 10; i++) { const an = i / 10 * Math.PI * 2, r = 6 + k * 10; R(c, 20 + Math.cos(an) * r * 1.3, 16 + Math.sin(an) * r * 0.7, 1, 1, i % 2 ? GOLD : WHITE); } }); } };
    flash(0.38, 0.5); flash(0.78, 0.88);
  });

  /* ---------- Combobulating: his scrambled slices click back into place ---------- */
  defNew("w-combobulating", "Combobulating", "words", "Combobulating…", (c, t) => {
    const p = (t % 4.2) / 4.2, X = X0, Y = Y0;
    const bands = [[Y - 1, 5, 7], [Y + 4, 4, -6], [Y + 8, 4, 5]];          // [top, height, scrambled offset]
    const snapAt = [0.2, 0.34, 0.48];
    const done = p >= 0.5 && p < 0.86;
    bands.forEach(([by, bh, off], i) => {
      let o;
      if (p < 0.86) { const k = ease(seg(p, snapAt[i] - 0.1, snapAt[i])); o = Math.round(off * (1 - k)); if (k === 0) o += st(t + i * 0.1, 8, 2) * (i % 2 ? -1 : 1); }
      else o = Math.round(off * ease(seg(p, 0.86, 0.98)));
      clip(c, 0, by, 40, bh, () => clawd(c, X + o, Y, { eyes: done ? "happy" : "wide", armL: done && p > 0.55 && p < 0.8 ? "up" : "out", armR: done && p > 0.55 && p < 0.8 ? "up" : "out" }));
      if (p > snapAt[i] && p < snapAt[i] + 0.05) { R(c, X - 2, by + 1, 1, 1, WHITE); R(c, X + 17, by + 1, 1, 1, WHITE); R(c, X - 3, by + 2, 1, 1, GOLD); R(c, X + 18, by + 2, 1, 1, GOLD); }
    });
    if (done) glyph(c, G.check, X + 20, Y - 4, MINT);
    else if (p < 0.2 || p >= 0.9) { R(c, X + 6, Y - 6, 1, 1, GOLD); glyph(c, G.q, X + 7, Y - 8 + st(t, 3, 2), GOLD); }
    if (p > 0.84 && p < 0.92) { R(c, X - 5, Y + 2, 4, 1, GREY); R(c, X + 19, Y + 6, 4, 1, GREY); }
  });

  /* ---------- Hashing: cranks a meat grinder — pages in, #s and digits out ---------- */
  defNew("w-hashing", "Hashing", "words", "Hashing…", (c, t) => {
    const X = 0, Y = Y0, a = t * 5, HASH = [".#.#.", "#####", ".#.#.", "#####", ".#.#."];
    const hx = 19 + Math.round(Math.cos(a) * 3), hy = 12 + Math.round(Math.sin(a) * 3);
    const pq = (t % 2.4) / 2.4;                                          // a page of text drops into the hopper
    if (pq < 0.5) clip(c, 0, 0, 40, 7, () => { const py = Math.round(-6 + pq / 0.5 * 10); R(c, 22, py, 6, 7, WHITE); [1, 3, 5].forEach(d => R(c, 23, py + d, 4, 1, GREY)); });
    glyph(c, ["##########", ".########.", "..######..", "...####..."], 20, 5, METAL); R(c, 21, 5, 8, 1, GREY);
    R(c, 20, 9, 11, 6, METAL); R(c, 20, 9, 11, 1, WHITE); R(c, 20, 14, 11, 1, GREY);
    R(c, 31, 10, 2, 4, GREY);                                            // nozzle
    R(c, 23, 15, 4, 7, SLATE); R(c, 21, 21, 8, 1, SLATE);
    line(c, 20, 12, hx, hy, DARK); R(c, hx - 1, hy - 1, 2, 2, WOOD);
    clawd(c, X, Y + (Math.sin(a) > 0 ? 1 : 0), { eyes: "right", armR: "none" });
    line(c, X + 14, Y + 4, hx - 1, hy, CL); line(c, X + 14, Y + 5, hx - 1, hy + 1, CL);
    const P = 0.8, q = (t % P) / P, k = Math.floor(t / P);               // the hash squeezes out and drops
    const g = rnd(k * 5) < 0.4 ? HASH : DIG[Math.floor(rnd(k * 3 + 1) * 10)], col = g === HASH ? GOLD : LEAF;
    const x = Math.round(28 + seg(q, 0, 0.35) * 6), y = Math.round(10 + seg(q, 0.35, 0.7) ** 2 * 7);
    alpha(c, 1 - seg(q, 0.8, 1), () => clip(c, 33, 0, 7, 26, () => glyph(c, g, x, y, col)));
    if (q > 0.7 && q < 0.8) { R(c, 33, 22, 1, 1, col); R(c, 38, 22, 1, 1, col); }
  });

  /* ---------- Reticulating: points, and a city grid of splines draws itself ---------- */
  defNew("w-reticulating", "Reticulating", "words", "Reticulating…", (c, t) => {
    const p = (t % 5) / 5, X = 1, Y = Y0, O = [29, 7], u = [3, 1.6], v = [-3, 1.6], N = 3;
    const fade = p > 0.88 ? 1 - seg(p, 0.88, 1) : 1;
    const lines = [];
    for (let i = 0; i <= N; i++) lines.push([[O[0] + i * u[0], O[1] + i * u[1]], v]);
    for (let j = 0; j <= N; j++) lines.push([[O[0] + j * v[0], O[1] + j * v[1]], u]);
    const draw = seg(p, 0.05, 0.6) * lines.length;
    alpha(c, fade, () => {
      lines.forEach(([s, d], i) => {
        const k = cl01(draw - i); if (k <= 0) return;
        const wob = (1 - k) * 2;                                         // each spline wiggles, then snaps straight
        const steps = 12;
        for (let m = 0; m <= Math.round(steps * k); m++) {
          const f = m / steps, px = s[0] + d[0] * N * f, py = s[1] + d[1] * N * f + Math.sin(f * 9 + t * 8) * wob;
          R(c, px, py, 1, 1, MINT);
        }
        if (k < 1) { const f = k; R(c, s[0] + d[0] * N * f, s[1] + d[1] * N * f - 1, 1, 1, WHITE); }
      });
      if (p > 0.62) {                                                    // tiny buildings pop up in the cells
        const cells = [[0, 0], [1, 2], [2, 1], [0, 2], [2, 2], [1, 0]];
        cells.slice(0, Math.min(6, Math.floor(seg(p, 0.62, 0.8) * 6) + 1)).forEach(([a, b], i) => {
          const cx = Math.round(O[0] + (a + 0.5) * u[0] + (b + 0.5) * v[0]), cy = Math.round(O[1] + (a + 0.5) * u[1] + (b + 0.5) * v[1]);
          const hh = 2 + (i % 3);
          R(c, cx - 1, cy - hh + 1, 2, hh, [PINK, SKY, GOLD][i % 3]); R(c, cx - 1, cy - hh + 1, 2, 1, WHITE);
        });
      }
    });
    const prog = seg(p, 0.05, 0.85);
    R(c, 21, 23, 18, 2, DARK); R(c, 21, 23, Math.round(18 * prog), 2, MINT);
    clawd(c, X, Y, { eyes: p > 0.8 && p < 0.95 ? "happy" : "right", armR: p < 0.62 ? "up" : "out", armL: st(t, 2, 2) && p > 0.62 && p < 0.88 ? "up" : "out" });
  });

  /* ---------- Churning: pumps a butter churn until butter pops out ---------- */
  defNew("w-churning", "Churning", "words", "Churning…", (c, t) => {
    const p = (t % 4) / 4, X = 4, Y = Y0;
    const pump = p < 0.7 ? Math.sin(t * Math.PI * 2 * 1.75) : 0;           // seven strokes, then butter
    const hy = 4 + Math.round((pump + 1) * 2.5);
    glyph(c, ["..######..", ".########.", ".########.", ".########.", "##########", "##########", "##########", "##########", "##########", "##########"], 24, 12, WOOD);
    [14, 19].forEach(y => R(c, 24, y, 10, 1, METAL)); R(c, 25, 13, 1, 8, "#C9A26B");
    R(c, 25, 11, 8, 1, "#6b4423");
    R(c, 28, hy, 2, 11 - hy, "#C9A26B"); R(c, 25, hy, 8, 1, WOOD);
    if (p < 0.7 && pump > 0.6) { R(c, 26 - st(t, 10, 2), 9, 1, 1, WHITE); R(c, 32 + st(t, 10, 2), 9, 1, 1, WHITE); }
    clawd(c, X, Y + (pump > 0.3 ? 1 : 0), { eyes: p > 0.72 && p < 0.97 ? "happy" : pump > 0 ? "closed" : "right", armR: "none" });
    line(c, X + 14, Y + 4 + (pump > 0.3 ? 1 : 0), 25, hy + 1, CL); line(c, X + 14, Y + 5 + (pump > 0.3 ? 1 : 0), 25, hy + 2, CL);
    if (p > 0.7 && p < 0.97) {                                             // a pat of butter jumps out onto the lid
      const k = seg(p, 0.7, 0.8), by = Math.round(8 - Math.sin(k * Math.PI) * 5);
      R(c, 30, by, 4, 2, GOLD); R(c, 30, by, 4, 1, "#FFE3A3");
      if (p > 0.8 && st(t, 4, 2)) glyph(c, STAR, 34, 4, WHITE);
    }
  });

  /* ---------- Crunching: tosses numbers up like popcorn and crunches them ---------- */
  defNew("w-crunching", "Crunching", "words", "Crunching…", (c, t) => {
    const P = 1.2, q = (t % P) / P, n = Math.floor(t / P), X = X0 - 2, Y = Y0;
    const d = DIG[Math.floor(rnd(n + 11) * 10)], col = [GOLD, LEAF, SKY, PINK][n % 4];
    const chomp = q > 0.62 && q < 0.8;
    const open = q > 0.4 && q <= 0.62;
    clawd(c, X, Y + (chomp ? 1 : 0), { eyes: chomp ? "happy" : q > 0.2 ? "up" : "right", armR: q < 0.18 ? "up" : "out", squash: chomp ? 1 : 0 });
    const my = Y + 5 + (chomp ? 1 : 0);
    if (open) { R(c, X + 6, my, 4, 3, EYE); R(c, X + 7, my + 2, 2, 1, RED); } else R(c, X + 6, my + 1, 4, 1, EYE);
    if (q < 0.62) {                                                      // arc from his paw up and into his mouth
      const k = seg(q, 0.08, 0.6), x = Math.round(X + 15 + (X + 6.5 - (X + 15)) * k), y = Math.round(Y - 6 - Math.sin(k * Math.PI) * 6 + k * (my - 2 - (Y - 6)));
      clip(c, 0, 0, 40, open ? my + 1 : 26, () => glyph(c, d, x, y, col));
    }
    if (q > 0.62 && q < 0.95) {                                          // crumbs
      const k = seg(q, 0.62, 0.95);
      alpha(c, 1 - k, () => { for (let i = 0; i < 6; i++) { const s = i < 3 ? -1 : 1; R(c, X + 8 + s * (3 + k * (4 + i % 3 * 3)), my + Math.round(k * k * 8) - (i % 3) + 1, 1, 1, col); } });
      if (k < 0.4) { R(c, X - 3, Y + 1, 2, 1, WHITE); R(c, X + 17, Y + 1, 2, 1, WHITE); R(c, X - 2, Y - 1, 1, 1, WHITE); R(c, X + 17, Y - 1, 1, 1, WHITE); }
    }
    const nx = DIG[Math.floor(rnd(n + 12) * 10)];                        // the next number, waiting in his paw
    if (q > 0.6) glyph(c, nx, X + 16, Y + 1, [GOLD, LEAF, SKY, PINK][(n + 1) % 4]);
  });
})();


/* ---- word batch: party ---- */
/* Status words — dancing, mischief, silly and wandering words */
(() => {
  const YEL = "#FAC775", GREY = "#888780", RED = "#E24B4A", BLUE = "#85B7EB", DBLUE = "#378ADD", DARK = "#444441",
        BRN = "#BA7517", DBRN = "#854F0B", TEAL = "#5DCAA5", PINK = "#ED93B1", PURP = "#7F77DD", LIL = "#AFA9EC",
        GRN = "#97C459", DGRN = "#639922", ORG = "#EF9F27", COAL = "#2c2c2a", MID = "#5f5e5a", PAPER = "#ece9e1";
  const lerp = (a, b, k) => a + (b - a) * k;
  const sparkle = (c, x, y, col) => { R(c, x, y - 1, 1, 3, col); R(c, x - 1, y, 3, 1, col); };

  /* ---------- Dancing ---------- */

  defNew("w-beboppin", "Beboppin'", "words", "Beboppin'…", (c, t) => {
    // Beret + shades, slapping a pair of bongos in a bebop rhythm.
    const X = X0, s = "LRLLR.RL"[st(t, 6, 8)], bob = st(t, 3, 2), top = Y0 + bob;
    clawd(c, X, Y0, { eyes: "shades", squash: bob, armL: s === "L" ? "down" : "out", armR: s === "R" ? "down" : "out" });
    R(c, X + 4, top - 2, 9, 1, INK); R(c, X + 3, top - 1, 11, 1, INK); R(c, X + 9, top - 3, 1, 1, INK);   // beret
    const drum = (dx, w, hit) => {
      R(c, dx, 19, w, 1, hit ? YEL : WHITE); R(c, dx, 20, w, 1, BRN); R(c, dx + 1, 21, w - 2, 1, DBRN);
      if (hit) { R(c, dx - 2, 17, 1, 1, YEL); R(c, dx + w + 1, 17, 1, 1, YEL); R(c, dx + Math.floor(w / 2), 16, 1, 1, YEL); }
    };
    drum(X - 3, 6, s === "L"); drum(X + 13, 6, s === "R");
    for (let i = 0; i < 2; i++) { const q = (t * 0.8 + i / 2) % 1; alpha(c, Math.min(1, (1 - q) * 2), () => glyph(c, G.note, i ? 34 : 2, 14 - Math.round(q * 12), i ? BLUE : YEL)); }
  });

  defNew("w-choreographing", "Choreographing", "words", "Choreographing…", (c, t) => {
    // Counts "5, 6, 7, 8!" with a baton, then three little dancers run the routine.
    const k = t * 2.5, beat = Math.floor(k) % 8, ph = k % 1, X = 0, Y = Y0;
    const n = [5, 6, 7, 8, 1, 2, 3, 4][beat];
    alpha(c, 1 - ph * 0.5, () => glyph(c, DIG[n], X + 6, 3, beat < 4 ? YEL : WHITE));
    const up = beat % 2 === 0;
    clawd(c, X, Y, { eyes: "right", armR: up ? "up" : "out", squash: ph < 0.2 ? 1 : 0 });
    if (up) { line(c, X + 15, Y - 1, X + 18, Y - 5, WHITE); R(c, X + 18, Y - 6, 1, 1, RED); }
    else { line(c, X + 16, Y + 4, X + 20, Y + 1, WHITE); R(c, X + 21, Y, 1, 1, RED); }
    [16, 24, 32].forEach((mx, i) => {
      let h = 0;
      if (beat >= 4) { const b = beat - 4; if (b === i || b === 3) h = Math.round(Math.sin(ph * Math.PI) * 3); }
      mini(c, mx, 17 - h, h ? 1 : 0);
    });
  });

  defNew("w-grooving", "Grooving", "words", "Grooving…", (c, t) => {
    // Riding a spinning record, headphones on, swaying in the groove.
    R(c, 0, 20, 40, 2, MID); R(c, 0, 20, 40, 1, GREY);                              // turntable
    R(c, 8, 18, 24, 1, COAL); R(c, 4, 19, 32, 1, COAL); R(c, 17, 18, 6, 1, RED);    // record + label
    for (let k = 0; k < 3; k++) R(c, 4 + Math.floor((t * 22 + k * 11) % 32), 19, 2, 1, MID);
    R(c, 37, 11, 1, 9, METAL); line(c, 37, 11, 33, 16, METAL); R(c, 32, 16, 2, 1, WHITE);  // tonearm
    const sway = [0, 1, 0, -1][st(t, 3, 4)], bob = st(t, 3, 2), X = X0 + sway, Y = 8;
    clawd(c, X, Y, { eyes: st(t, 0.75, 2) ? "happy" : "closed", squash: bob, armL: sway > 0 ? "up" : "out", armR: sway < 0 ? "up" : "out" });
    const top = Y + bob;
    R(c, X + 2, top - 1, 12, 1, INK); R(c, X + 1, top, 1, 1, INK); R(c, X + 14, top, 1, 1, INK);
    R(c, X + 1, top + 1, 2, 3, RED); R(c, X + 13, top + 1, 2, 3, RED);              // headphones
  });

  defNew("w-jitterbugging", "Jitterbugging", "words", "Jitterbugging…", (c, t) => {
    // Swing dance: rock-step hand in hand, then he flips his partner over his head.
    const H = 2.4, T = t % H, side = Math.floor(t / H) % 2, X = 12, Y = Y0;
    const A = side ? 3 : 29, B = side ? 29 : 3;                                     // partner's start and end
    const partner = (mx, my, q) => turn(c, mx + 4, my + 2, q, () => {
      mini(c, mx, my, st(t, 4, 2));
      R(c, mx + 2, my - 1, 1, 1, PINK); R(c, mx + 4, my - 1, 1, 1, PINK); R(c, mx + 3, my - 1, 1, 1, "#D4537E");
    });
    if (T < 1.4) {
      const f = st(t, 4, 2), h = f ? 1 : 0;
      clawd(c, X + (f ? 1 : -1), Y, { eyes: side ? "left" : "right", legs: f + 1, armL: side ? "out" : "up", armR: side ? "up" : "out" });
      partner(A + (f ? 1 : -1), 17 - h, 0);
      R(c, side ? A + 9 : A - 1, 18 - h, 1, 1, CL);                                 // holding hands
    } else {
      const k = (T - 1.4) / 1, mx = lerp(A, B, k), my = 17 - Math.pow(Math.sin(k * Math.PI), 0.5) * 15;
      const q = k >= 1 ? 0 : (side ? 4 - Math.floor(k * 4) : Math.floor(k * 4)) % 4;
      clawd(c, X, Y, { eyes: "up", armL: "up", armR: "up", squash: k < 0.15 ? 2 : 0 });
      partner(Math.round(mx), Math.round(my), q);
      if (k > 0.2 && k < 0.8) { R(c, X - 3, Y + 2, 2, 1, MID); R(c, X + 17, Y + 2, 2, 1, MID); }
    }
  });

  defNew("w-razzle-dazzling", "Razzle-dazzling", "words", "Razzle-dazzling…", (c, t) => {
    // Spotlight, sequins and jazz hands — the whole body sparkles.
    alpha(c, 0.14, () => { for (let y = 0; y < 22; y++) { const w = 3 + Math.round(y * 0.55); R(c, 20 - w, y, w * 2, 1, YEL); } });
    alpha(c, 0.35, () => R(c, 6, 22, 28, 1, YEL));
    const j = st(t, 10, 2), X = X0, Y = Y0;
    clawd(c, X, Y, { eyes: st(t, 1, 2) ? "happy" : "wide", armL: "up", armR: "up" });
    [X - 1 + j, X + 15 - j].forEach(hx => { R(c, hx, Y - 2, 1, 1, CL); R(c, hx + 2, Y - 2, 1, 1, CL); });   // wiggling fingers
    for (let i = 0; i < 10; i++) {                                                  // sequins on the body
      const sx = X + 2 + Math.floor(rnd(i) * 12), sy = Y + 5 + Math.floor(rnd(i + 9) * 3);
      if (st(t + rnd(i + 20), 5, 2)) R(c, sx, sy, 1, 1, i % 2 ? WHITE : YEL);
    }
    for (let i = 0; i < 6; i++) {                                                   // twinkles all around
      const s = t * 1.6 + i / 6, n = Math.floor(s), q = s % 1;
      let x = 2 + Math.floor(rnd(n * 13 + i) * 36), y = 2 + Math.floor(rnd(n * 7 + i + 3) * 17);
      if (x > X - 2 && x < X + 18 && y > Y - 3) x = x < 20 ? X - 4 : X + 20;
      const col = i % 2 ? WHITE : YEL;
      if (q < 0.25 || q > 0.75) R(c, x, y, 1, 1, col); else sparkle(c, x, y, col);
    }
  });

  defNew("w-razzmatazzing", "Razzmatazzing", "words", "Razzmatazzing…", (c, t) => {
    // Top hat and cane under chasing marquee lights: strut, cane twirl, hat tip.
    const ch = st(t, 8, 3);
    let i = 0;
    for (let x = 1; x < 40; x += 3, i++) { R(c, x, 0, 1, 1, (i + ch) % 3 ? DBRN : YEL); R(c, 39 - x, 25, 1, 1, (i + ch) % 3 ? DBRN : YEL); }
    for (let y = 3; y < 25; y += 3, i++) { R(c, 39, y, 1, 1, (i + ch) % 3 ? DBRN : YEL); R(c, 0, 25 - y, 1, 1, (i + ch) % 3 ? DBRN : YEL); }
    const p = (t % 3.2) / 3.2, Y = Y0;
    let X = X0, o = { eyes: "right" }, hat = 0, cane = 0;
    if (p < 0.45) { const f = st(t, 4, 2); X = X0 + Math.round(Math.sin(p / 0.45 * Math.PI * 2) * 2); o = { eyes: "right", legs: f + 1 }; }
    else if (p < 0.65) { cane = 1 + st(t, 10, 4); o = { eyes: "happy" }; }
    else if (p < 0.92) { hat = 1; o = { eyes: "closed", armL: "up" }; }
    clawd(c, X, Y, o);
    if (hat) {                                                                       // hat lifted in the left hand
      R(c, X - 1, Y - 2, 10, 1, INK); R(c, X + 1, Y - 6, 6, 4, INK); R(c, X + 1, Y - 3, 6, 1, RED);
      glyph(c, G.star, X + 17, Y - 6, st(t, 6, 2) ? WHITE : YEL);
    } else { R(c, X + 3, Y - 1, 10, 1, INK); R(c, X + 5, Y - 5, 6, 4, INK); R(c, X + 5, Y - 2, 6, 1, RED); }
    const hx = X + 16, hy = Y + 5;                                                   // cane from the right hand
    if (!cane || cane === 1) { R(c, hx, hy - 1, 1, 7, WHITE); R(c, hx - 1, hy - 1, 1, 1, WHITE); R(c, hx, hy + 6, 1, 1, RED); }
    else if (cane === 2) { line(c, hx - 3, hy + 3, hx + 3, hy - 3, WHITE); R(c, hx + 3, hy - 3, 1, 1, RED); }
    else if (cane === 3) { R(c, hx - 3, hy, 7, 1, WHITE); R(c, hx + 3, hy, 1, 1, RED); }
    else { line(c, hx - 3, hy - 3, hx + 3, hy + 3, WHITE); R(c, hx + 3, hy + 3, 1, 1, RED); }
  });

  defNew("w-shimmying", "Shimmying", "words", "Shimmying…", (c, t) => {
    // Fringe skirt, shoulders a-blur, shimmying all the way down and back up.
    const down = Math.round(pong((t % 2.4) / 2.4) * 3), j = st(t, 12, 2) ? 1 : -1, a = st(t, 6, 2);
    const X = X0 + j, Y = Y0, wd = Math.floor(down / 2);
    clawd(c, X, Y, { squash: down, eyes: "happy", armL: a ? "up" : "down", armR: a ? "down" : "up" });
    R(c, X + 2 - wd, Y + 7, 12 + wd * 2, 1, ORG);                                   // fringe belt
    [2 - wd, 4, 7, 8, 11, 13 + wd].forEach((i, n) => R(c, X + i - (n % 2 ? j : 0), Y + 8, 1, 1, n % 2 ? YEL : ORG));
    [4, 7, 8, 11].forEach(i => R(c, X + i - j, Y + 9, 1, 1, YEL));
    R(c, X - 4 - wd, Y + 3, 1, 3, MID); R(c, X + 19 + wd, Y + 3, 1, 3, MID);
    R(c, X - 6 - wd, Y + 4, 1, 1, MID); R(c, X + 21 + wd, Y + 4, 1, 1, MID);
  });

  defNew("w-sock-hopping", "Sock-hopping", "words", "Sock-hopping…", (c, t) => {
    // Shoes off by the door, hopping in white socks on a checkered floor by the jukebox.
    for (let i = 0; i < 10; i++) for (let r = 0; r < 2; r++) R(c, i * 4, 22 + r * 2, 4, 2, (i + r) % 2 ? DARK : GLASS);
    R(c, 0, 20, 4, 2, WHITE); R(c, 1, 20, 2, 1, INK); R(c, 4, 20, 4, 2, WHITE); R(c, 5, 20, 2, 1, INK);   // saddle shoes
    const jc = [RED, YEL, BLUE, TEAL], cs = st(t, 6, 4);                            // jukebox
    R(c, 31, 8, 7, 1, DBRN); R(c, 30, 9, 9, 13, DBRN);
    for (let y = 9; y < 22; y++) { R(c, 30, y, 1, 1, jc[(y + cs) % 4]); R(c, 38, y, 1, 1, jc[(y + cs) % 4]); }
    R(c, 32, 10, 5, 4, st(t, 3, 2) ? YEL : ORG); R(c, 32, 16, 5, 4, MID);
    for (let y = 16; y < 20; y += 2) R(c, 32, y, 5, 1, GREY);
    const q = (t * 0.6) % 1; alpha(c, 1 - q, () => glyph(c, G.note, 26, 6 - Math.round(q * 6), YEL));
    const k = st(t, 5, 4), legs = [1, 0, 2, 0][k], X = 9 + [0, 0, 1, 1][k], Y = Y0 - (legs ? 1 : 0);
    clawd(c, X, Y, { eyes: "happy", legs, squash: legs ? 0 : 1, armL: k < 2 ? "up" : "out", armR: k < 2 ? "out" : "up" });
    socks(c, X, Y, legs);
  });

  defNew("w-vibing", "Vibing", "words", "Vibing…", (c, t) => {
    // Sitting back in shades by a lava lamp, gently swaying, good vibes rising.
    alpha(c, 0.12 + 0.05 * Math.sin(t * 2), () => R(c, 27, 5, 12, 16, "#7F77DD"));
    R(c, 31, 9, 4, 9, "#534AB7"); R(c, 32, 8, 2, 1, "#534AB7");
    for (let k = 0; k < 3; k++) { const by = 16 - Math.round(((t * 1.5 + k * 2.6) % 8)); R(c, 31 + (k % 2) * 2, Math.max(9, by), 2, 2, PINK); }
    R(c, 32, 6, 2, 2, GREY); R(c, 31, 18, 4, 1, GREY); R(c, 30, 19, 6, 3, GREY);   // lamp cap and base
    const sw = Math.round(Math.sin(t * 1.6)), X = 7 + sw, Y = 14;
    clawd(c, X, Y, { eyes: "shades", legs: "none", armL: "out", armR: sw > 0 ? "up" : "out" });
    for (let i = 0; i < 2; i++) {
      const q = (t * 0.45 + i / 2) % 1, y = Y - 3 - Math.round(q * 10);
      alpha(c, Math.min(1, (1 - q) * 1.6), () => { for (let x = 0; x < 9; x++) R(c, X + 4 + x, y + Math.round(Math.sin(x * 0.9 + t * 4)), 1, 1, LIL); });
    }
  });

  /* ---------- Mischief and silliness ---------- */

  defNew("w-flibbertigibbeting", "Flibbertigibbeting", "words", "Flibbertigibbeting…", (c, t) => {
    // Flits from spot to spot, never stops chattering, eyes darting everywhere.
    const pts = [4, 20, 10, 22, 6, 17], seg = 0.45, k = t / seg, i = Math.floor(k) % 6, ph = k % 1;
    const a = pts[i], b = pts[(i + 1) % 6], hop = ph < 0.55;
    const X = Math.round(hop ? lerp(a, b, ph / 0.55) : b), lift = hop ? Math.round(Math.sin(ph / 0.55 * Math.PI) * 4) : 0, Y = Y0 - lift;
    const dart = ["left", "up", "right", "wide"][st(t, 7, 4)];
    clawd(c, X, Y, { eyes: hop ? (b > a ? "right" : "left") : dart, legs: hop ? 3 : 0, armL: hop && st(t, 10, 2) ? "up" : "out", armR: hop && !st(t, 10, 2) ? "up" : "out" });
    const bx = X + 2, by = 1;                                                        // chatter bubble
    R(c, bx + 1, by, 10, 6, WHITE); R(c, bx, by + 1, 12, 4, WHITE); R(c, bx + 3, by + 6, 2, 1, WHITE); R(c, bx + 3, by + 7, 1, 1, WHITE);
    const n = Math.floor(t * 9);
    for (let r = 0; r < 2; r++) { let x = bx + 2; while (x < bx + 10) { const w = 1 + Math.floor(rnd(n * 5 + r * 3 + x) * 3); R(c, x, by + 2 + r * 2, Math.min(w, bx + 10 - x), 1, INK); x += w + 1; } }
  });

  defNew("w-hullaballooing", "Hullaballooing", "words", "Hullaballooing…", (c, t) => {
    // Pot on his head, banging a wooden spoon on another pot — a right racket.
    const X = 5, hit = st(t, 4, 2) === 1, Y = Y0 - (hit ? 1 : 0);
    const py = hit ? 16 : 17;
    R(c, 25, py, 8, 5, METAL); R(c, 24, py, 10, 1, GLASS); R(c, 23, py + 1, 1, 1, METAL); R(c, 34, py + 1, 1, 1, METAL);
    if (hit) R(c, 25, 21, 8, 1, MID);
    clawd(c, X, Y, { eyes: hit ? "wide" : "happy", legs: hit ? 3 : 0, armL: hit ? "up" : "out", armR: "out" });
    R(c, X + 3, Y - 3, 10, 3, METAL); R(c, X + 2, Y - 1, 12, 1, GLASS); R(c, X + 13, Y - 3, 4, 1, METAL);   // pot helmet
    if (hit) { line(c, X + 16, Y + 5, 26, py - 1, WOOD); R(c, 26, py - 1, 3, 1, WOOD); }
    else { line(c, X + 16, Y + 4, X + 18, Y - 4, WOOD); R(c, X + 18, Y - 6, 2, 2, WOOD); }
    if (hit) {
      [[-4, -2], [4, -2], [-6, 1], [6, 1], [0, -5]].forEach(([dx, dy]) => line(c, 29 + dx, py - 3 + dy, 29 + dx * 1.6, py - 3 + dy * 1.6, YEL));
      glyph(c, G.bang, 36, 6, RED); glyph(c, G.bang, 38, 8, RED);
    }
  });

  defNew("w-shenaniganing", "Shenaniganing", "words", "Shenaniganing…", (c, t) => {
    // Sets down a banana peel, a little friend slips on it, Clawd can't stop giggling.
    const p = (t % 5) / 5, X = 1, PEEL = ["..#..", ".###.", "#.#.#"];
    const laugh = p > 0.32 && p < 0.86;
    clawd(c, X, Y0 - (laugh ? st(t, 8, 2) : 0), {
      eyes: laugh ? "happy" : "right", legs: laugh && st(t, 8, 2) ? 3 : 0,
      armL: laugh ? "down" : "out", armR: p > 0.9 ? "out" : laugh ? "down" : "out" });
    if (laugh && st(t, 4, 2)) { R(c, X + 17, Y0 - 1, 1, 2, YEL); R(c, X + 19, Y0, 1, 2, YEL); }
    if (p < 0.3) {                                                                   // friend walks in
      const mx = Math.round(lerp(40, 18, p / 0.3));
      glyph(c, PEEL, 19, 19, YEL); R(c, 21, 18, 1, 1, DBRN); mini(c, mx, 17, st(t, 6, 2));
    } else if (p < 0.5) {                                                            // whoops
      const k = (p - 0.3) / 0.2;
      turn(c, Math.round(lerp(19, 23, k)) + 4, Math.round(17 - Math.sin(k * Math.PI) * 8) + 2, Math.min(2, Math.floor(k * 3)), () => mini(c, Math.round(lerp(19, 23, k)), Math.round(17 - Math.sin(k * Math.PI) * 8), 0));
      glyph(c, PEEL, Math.round(lerp(19, 38, k)), Math.round(lerp(19, -6, k)), YEL);
    } else if (p < 0.72) {                                                           // flat on its back, seeing stars
      turn(c, 27, 19, 2, () => mini(c, 23, 17, 0));
      for (let i = 0; i < 3; i++) { const a = t * 5 + i * 2.1; R(c, 27 + Math.round(Math.cos(a) * 4), 15 + Math.round(Math.sin(a) * 1), 1, 1, i ? YEL : WHITE); }
    } else if (p < 0.92) {
      mini(c, Math.round(lerp(23, 41, (p - 0.72) / 0.2)), 17, st(t, 6, 2));
    }
    if (p >= 0.92) { const k = (p - 0.92) / 0.08; glyph(c, PEEL, 19, Math.round(lerp(15, 19, k)), YEL); R(c, 21, Math.round(lerp(14, 18, k)), 1, 1, DBRN); }
  });

  defNew("w-gallivanting", "Gallivanting", "words", "Gallivanting…", (c, t) => {
    // Skipping with a sticker-covered suitcase while landmarks of the world roll by.
    const land = [
      x => { line(c, x, 21, x + 3, 7, GREY); line(c, x + 6, 21, x + 3, 7, GREY); R(c, x + 1, 15, 5, 1, GREY); R(c, x + 3, 5, 1, 2, GREY); },
      x => { line(c, x + 2, 21, x + 3, 10, DBRN); R(c, x, 9, 7, 1, DGRN); R(c, x - 1, 10, 2, 1, DGRN); R(c, x + 6, 10, 2, 1, DGRN); R(c, x + 2, 8, 3, 1, DGRN); },
      x => { for (let r = 0; r < 9; r++) R(c, x + 4 - r, 13 + r, r * 2 + 1, 1, DBRN); },
    ];
    alpha(c, 0.55, () => land.forEach((fn, k) => fn(Math.round((((k * 22 - t * 11) % 66) + 66) % 66) - 12)));
    R(c, 0, 22, 40, 1, DARK);
    for (let i = 0; i < 5; i++) R(c, Math.round((((i * 8 - t * 22) % 40) + 40) % 40), 23, 3, 1, MID);
    const h = Math.round(Math.abs(Math.sin(t * Math.PI * 2)) * 3), X = 9, Y = Y0 - h;
    clawd(c, X, Y, { eyes: "happy", legs: h > 1 ? st(t, 2, 2) + 1 : 0, armL: h > 1 ? "up" : "out", armR: "out" });
    R(c, X + 16, Y + 5, 2, 1, DBRN); R(c, X + 14, Y + 6, 6, 4, BRN);                // suitcase
    R(c, X + 15, Y + 7, 1, 1, RED); R(c, X + 18, Y + 8, 1, 1, TEAL); R(c, X + 17, Y + 6, 1, 1, WHITE);
  });

  defNew("w-fiddle-faddling", "Fiddle-faddling", "words", "Fiddle-faddling…", (c, t) => {
    // Sawing away at a fiddle — the notes come out wonky and every so often it squeaks.
    const p = (t % 2.4) / 2.4, squeak = p > 0.7 && p < 0.85, X = 6, Y = Y0;
    const s = Math.round(Math.sin(t * 9) * 2);
    clawd(c, X + (squeak ? st(t, 16, 2) : 0), Y, { eyes: squeak ? "x" : "closed", armR: "down" });
    const vx = X + 15, vy = Y;                                                       // fiddle at his chin
    line(c, vx + 5, vy + 2, vx + 11, vy - 1, WOOD); line(c, vx + 5, vy + 3, vx + 11, vy, WOOD); R(c, vx + 11, vy - 2, 2, 2, DBRN);
    glyph(c, [".###.", "#####", ".###.", "#####", "#####", ".###."], vx, vy, BRN);
    R(c, vx + 1, vy + 3, 1, 2, DBRN); R(c, vx + 3, vy + 3, 1, 2, DBRN);
    line(c, vx - 1 + s, vy + 8 - s, vx + 6 + s, vy - 3 - s, WHITE);                 // the bow
    for (let i = 0; i < 3; i++) {
      const q = (t * 0.7 + i / 3) % 1, nx = vx + 10 + Math.round(q * 4 + Math.sin(q * 14 + i) * 1.5), ny = vy - 4 - Math.round(q * 9);
      alpha(c, Math.min(1, (1 - q) * 2), () => glyph(c, i === 1 ? [".##", ".#.", "##."] : G.note, nx, ny, i === 1 ? LIL : YEL));
    }
    if (squeak) { line(c, vx + 3, vy - 2, vx + 1, vy - 5, RED); line(c, vx + 6, vy - 1, vx + 8, vy - 4, RED); }
  });

  defNew("w-whatchamacalliting", "Whatchamacalliting", "words", "Whatchamacalliting…", (c, t) => {
    // Holds out a baffling doohickey, turns it over; the name almost comes to him… then doesn't.
    const X = 3, Y = Y0, p = (t % 4) / 4, flip = p > 0.52 && p < 0.62;
    clawd(c, X, Y, { eyes: ["right", "up", "right", "up", "right", "wide", "up", "right"][Math.floor(p * 8)], armR: "out", armL: "down" });
    const gx = X + 16, gy = Y + 1;
    turn(c, gx + 4, gy + 1, flip ? 2 : 0, () => {
      R(c, gx, gy, 8, 4, PURP); R(c, gx + 1, gy + 1, 2, 2, st(t, 3, 2) ? RED : GRN); R(c, gx + 5, gy + 1, 2, 1, YEL);
      R(c, gx + 8, gy + 1, 2, 1, METAL); R(c, gx + 9, gy + 2, 1, 2, METAL);          // crank
      glyph(c, ["#.", ".#", "#.", ".#"], gx + 3, gy - 4, METAL);                       // spring
      if (st(t, 10, 2)) R(c, gx, gy - 5, 8, 1, TEAL); else R(c, gx + 3, gy - 5, 2, 1, TEAL);
    });
    const bx = 5;                                                                      // thought bubble
    R(c, bx + 9, 10, 1, 1, WHITE);
    R(c, bx + 1, 0, 9, 9, WHITE); R(c, bx, 1, 11, 7, WHITE);
    if (p < 0.4 || p >= 0.85) glyph(c, G.q, bx + 4, 2, INK);
    else if (p < 0.7) { const on = p < 0.6 || st(t, 10, 2); glyph(c, G.bulb, bx + 3, 1, on ? YEL : GLASS); glyph(c, G.bulbBase, bx + 4, 6, GREY); }
    else { glyph(c, G.bulb, bx + 3, 1, GLASS); glyph(c, G.bulbBase, bx + 4, 6, GREY); R(c, bx + 2, 2, 1, 1, MID); }
  });

  defNew("w-dilly-dallying", "Dilly-dallying", "words", "Dilly-dallying…", (c, t) => {
    // Heads for the finish flag, stops to smell a flower, then wanders off after a butterfly.
    R(c, 37, 9, 1, 13, METAL); R(c, 38, 9, 2, 3, RED);
    R(c, 30, 16, 1, 6, DGRN); R(c, 31, 19, 1, 1, GRN); glyph(c, G.flower, 29, 13, PINK); R(c, 30, 14, 1, 1, YEL);
    const p = (t % 6) / 6, Y = Y0;
    let X, o;
    if (p < 0.22) { X = Math.round(lerp(2, 12, p / 0.22)); o = { eyes: "right", legs: st(t, 4, 2) + 1 }; }
    else if (p < 0.55) { X = 12; o = { eyes: "closed", squash: p > 0.3 && p < 0.5 ? 1 : 0 }; }
    else if (p < 0.92) { X = Math.round(lerp(12, 2, (p - 0.55) / 0.37)); o = { eyes: "up", legs: st(t, 4, 2) + 1, armL: "up" }; }
    else { X = 2; o = { eyes: "left" }; }
    clawd(c, X, Y, o);
    if (p > 0.28 && p < 0.55) for (let i = 0; i < 2; i++) {
      const q = ((p - 0.28) / 0.27 * 2 + i / 2) % 1; alpha(c, 1 - q, () => glyph(c, G.heartS, 23 + i * 3, 12 - Math.round(q * 8), PINK));
    }
    if (p > 0.45 && p < 0.97) {                                                     // butterfly
      const k = (p - 0.45) / 0.52, bx = Math.round(lerp(30, -4, k)), by = 9 + Math.round(Math.sin(k * 18) * 2);
      glyph(c, st(t, 8, 2) ? ["#.#", "###"] : ["...", ".#.", ".#."], bx, by, LIL);
    }
  });

  /* ---------- Wandering ---------- */

  defNew("w-scampering", "Scampering", "words", "Scampering…", (c, t) => {
    // Scampering flat out on a hamster wheel and going nowhere.
    const cx = 20, cy = 11, r = 11, a0 = t * 3;
    line(c, cx, cy, 11, 22, MID); line(c, cx, cy, 29, 22, MID);
    for (let k = 0; k < 4; k++) { const a = a0 + k * Math.PI / 4; line(c, cx - Math.cos(a) * 10, cy - Math.sin(a) * 10, cx + Math.cos(a) * 10, cy + Math.sin(a) * 10, DARK); }
    const f = st(t, 12, 2);
    clawd(c, 12, 11 - f, { eyes: "right", legs: f + 1, armL: f ? "out" : "down", armR: f ? "down" : "out" });
    for (let i = 0; i < 3; i++) R(c, 9 - ((i * 2 + st(t, 10, 2)) % 3), 14 + i * 2, 2, 1, WHITE);
    const sq = (t * 0.8) % 1; alpha(c, 1 - sq, () => R(c, 29, 10 + Math.round(sq * 4), 1, 2, BLUE));
    for (let k = 0; k < 90; k++) { const a = k / 90 * Math.PI * 2; R(c, cx + Math.cos(a) * r, cy + Math.sin(a) * r, 1, 1, GREY); }
    for (let k = 0; k < 10; k++) { const a = a0 + k * Math.PI / 5; R(c, cx + Math.cos(a) * r, cy + Math.sin(a) * r, 1, 1, WHITE); }
    R(c, cx - 1, cy - 1, 2, 2, METAL);
  });

  defNew("w-scurrying", "Scurrying", "words", "Scurrying…", (c, t) => {
    // Low to the ground, out of the mouse hole, grabs the cheese and scurries back in.
    const CHEESE = ["....###", "..#####", "#######", "#######"];
    const cheese = (x, y) => { glyph(c, CHEESE, x, y, YEL); R(c, x + 2, y + 2, 1, 1, BRN); R(c, x + 5, y + 1, 1, 1, BRN); R(c, x + 4, y + 3, 1, 1, BRN); };
    R(c, 2, 11, 7, 1, MID); R(c, 1, 12, 1, 1, MID); R(c, 9, 12, 1, 1, MID); R(c, 10, 13, 1, 9, MID);   // mouse hole
    R(c, 2, 12, 7, 1, COAL); R(c, 0, 13, 10, 9, COAL); R(c, 0, 12, 1, 1, MID);
    R(c, 0, 22, 40, 1, DARK);
    const p = (t % 4) / 4, Y = Y0;
    let X, eyes, carry = false, run = true;
    if (p < 0.12) { X = Math.round(lerp(-20, -6, p / 0.12)); eyes = "right"; }
    else if (p < 0.22) { X = -6; eyes = st(t, 4, 2) ? "left" : "right"; run = false; }
    else if (p < 0.42) { X = Math.round(lerp(-6, 16, (p - 0.22) / 0.2)); eyes = "right"; }
    else if (p < 0.5) { X = 16; eyes = "wide"; run = false; carry = p > 0.46; }
    else if (p < 0.8) { X = Math.round(lerp(16, -20, (p - 0.5) / 0.3)); eyes = "left"; carry = true; }
    else { X = -20; eyes = "left"; run = false; }
    if (!carry) { if (p < 0.8 || p > 0.86) cheese(31, p < 0.8 ? 18 : Math.round(lerp(-4, 18, Math.min(1, (p - 0.86) / 0.06)))); }
    clawd(c, X, Y, { squash: 4, eyes, legs: run ? st(t, 14, 2) + 1 : 0 });
    if (carry) cheese(X + 5, Y + 1);
    if (run && p < 0.8) for (let i = 0; i < 2; i++) { const d = eyes === "left" ? 1 : -1; R(c, X + (d > 0 ? 19 + i * 3 : -4 - i * 3), 20 - i, 2, 1, GREY); }
  });

  defNew("w-meandering", "Meandering", "words", "Meandering…", (c, t) => {
    // Drifting down a winding river in a rubber ring, wherever the current takes him.
    for (let x = 0; x < 40; x++) { const top = 15 + Math.round(Math.sin(x * 0.22 + t * 0.9) * 1.5 + Math.sin(x * 0.07 - t * 0.5)); R(c, x, top, 1, 19 - top, DGRN); }
    for (let i = 0; i < 4; i++) { const rx = Math.round((((i * 11 - t * 4) % 44) + 44) % 44) - 2; R(c, rx, 13, 1, 4, GRN); R(c, rx + 1, 12, 1, 2, GRN); }
    const X = 12 + Math.round(Math.sin(t * Math.PI / 3) * 8), dir = Math.cos(t * Math.PI / 3), Y = 12 + Math.round(Math.sin(t * 2.4) * 0.6);
    clawd(c, X, Y, { eyes: Math.abs(dir) < 0.5 ? "closed" : dir > 0 ? "right" : "left", legs: "none", armL: "up", armR: "out" });
    R(c, 0, 19, 40, 7, DBLUE);
    for (let i = 0; i < 6; i++) R(c, Math.round((((i * 7 + t * 5) % 42) + 42) % 42) - 2, 20 + (i % 3) * 2, 3, 1, BLUE);
    R(c, X - 1, Y + 6, 18, 3, PINK); R(c, X, Y + 5, 16, 1, PINK);                    // rubber ring
    for (let s = 0; s < 18; s += 6) R(c, X - 1 + ((s + Math.floor(t * 3)) % 18), Y + 6, 2, 3, WHITE);
  });

  defNew("w-wandering", "Wandering", "words", "Wandering…", (c, t) => {
    // Lost behind a big unfolded map: walks one way, looks around, turns the map, tries the other.
    const p = (t % 6) / 6, Y = Y0;
    const [X] = path([[4, 0, 0], [20, 0, 0.3], [20, 0, 0.5], [4, 0, 0.8], [4, 0, 1]], p);
    const walking = (p < 0.3) || (p > 0.5 && p < 0.8), x = Math.round(X);
    const look = ["left", "right", "up", "left"][st(t, 3, 4)];
    clawd(c, x, Y, { eyes: walking ? "down" : look, legs: walking ? st(t, 4, 2) + 1 : 0 });
    const flipping = (p > 0.4 && p < 0.44) || p > 0.92 && p < 0.96, flipped = p >= 0.42 && p < 0.94;
    if (flipping) { R(c, x + 7, Y + 4, 2, 5, PAPER); }
    else {
      R(c, x + 1, Y + 4, 14, 5, PAPER); R(c, x + 5, Y + 4, 1, 5, GLASS); R(c, x + 10, Y + 4, 1, 5, GLASS);
      const m = dx => flipped ? x + 14 - dx : x + 1 + dx;
      R(c, m(2), Y + 5, 1, 2, GRN); R(c, m(3), Y + 6, 1, 2, GRN); R(c, m(11), Y + 5, 1, 1, DBLUE); R(c, m(12), Y + 5, 1, 2, DBLUE);
      [[1, 7], [3, 8], [5, 7], [7, 6], [9, 7], [11, 6]].forEach(([dx, dy]) => R(c, m(dx), Y + dy - 1, 1, 1, RED));
      R(c, m(12), Y + 7, 1, 1, RED);
    }
    if (!walking && !flipping) glyph(c, G.q, x + 7, Y - 7, YEL);
  });
})();


/* ---- word batch: mind ---- */
/* Status-word batch: thinking, confusion, imagining and talking words */
(() => {
  const disc = (c, cx, cy, r, col) => {
    for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++)
      if (dx * dx + dy * dy <= r * r + r * 0.8) R(c, cx + dx, cy + dy, 1, 1, col);
  };
  const ease = k => k < 0 ? 0 : k > 1 ? 1 : k * k * (3 - 2 * k);
  const PINK = "#ED93B1", RED = "#E24B4A", GOLD = "#FAC775", GREEN = "#639922", SKY = "#85B7EB";

  /* Cogitating — cogs turning over his head */
  defNew("w-cogitating", "Cogitating", "words", "Cogitating…", (c, t) => {
    const X = X0, Y = Y0;
    const gear = (cx, cy, r, n, a, col) => {
      disc(c, cx, cy, r, col);
      for (let k = 0; k < n; k++) {
        const an = a + k * 2 * Math.PI / n;
        for (let d = r + 1; d <= r + 2; d++) R(c, Math.round(cx + Math.cos(an) * d), Math.round(cy + Math.sin(an) * d), 1, 1, col);
      }
      R(c, cx, cy, 1, 1, "#444441");
    };
    const a = t * 2;
    gear(17, 6, 3, 7, a, METAL);
    gear(25, 4, 2, 5, -a * 7 / 5 + 0.4, GOLD);
    const q = (t * 0.8) % 1;
    alpha(c, 1 - q, () => glyph(c, G.puff, 30 + q * 4, 3 - q * 3, "#888780"));
    clawd(c, X, Y, { eyes: st(t, 0.7, 2) ? "up" : "left", armR: "up" });
  });

  /* Considering — turning a ring to consider every side (con-side-ring) */
  defNew("w-considering", "Considering", "words", "Considering…", (c, t) => {
    const X = 6, Y = Y0, a = t * 2.2, cx = X + 15, cy = Y - 4;
    const w = Math.abs(Math.cos(a)) * 3;
    for (let k = 0; k < 28; k++) {
      const an = k * 2 * Math.PI / 28;
      R(c, Math.round(cx + Math.cos(an) * w), Math.round(cy + Math.sin(an) * 3), 1, 1, GOLD);
    }
    R(c, cx - 1, cy - 5, 3, 2, "#5DCAA5"); R(c, cx, cy - 6, 1, 1, "#9FE1CB");
    const face = Math.abs(Math.cos(a)) > 0.9;
    if (face) glyph(c, G.star, cx + 4, cy - 7, WHITE);
    clawd(c, X, Y, { eyes: face ? "wide" : "up", armR: "up", armL: st(t, 0.6, 2) ? "down" : "out" });
  });

  /* Contemplating — seen from behind, sitting on a rock watching the sun go down and come back up */
  defNew("w-contemplating", "Contemplating", "words", "Contemplating…", (c, t) => {
    const p = (t % 6) / 6, sy = 6 + Math.round(ease(pong(p)) * 13), H = 16;
    if (sy > 13) for (let i = 0; i < 5; i++) if (st(t + i * 0.4, 1.5, 2)) R(c, 22 + rnd(i) * 17, 1 + rnd(i + 9) * 9, 1, 1, WHITE);
    clip(c, 0, 0, 40, H, () => disc(c, 31, sy, 3, "#EF9F27"));
    R(c, 0, H, 40, 6, "#185FA5");
    for (let r = 0; r < 3; r++) {
      const wv = Math.max(0, 7 - r * 2 - Math.max(0, sy - 12)), off = st(t + r * 0.3, 2, 2);
      if (sy < H + 2 && wv > 0) R(c, 31 - wv / 2 + off, H + 1 + r * 2, wv, 1, "#EF9F27");
      R(c, 3 + r * 6 + off, H + 2 + r * 2, 3, 1, "#378ADD");
    }
    R(c, 0, 19, 22, 4, "#5f5e5a"); R(c, 1, 18, 19, 1, "#5f5e5a"); R(c, 2, 18, 4, 1, "#888780");
    const sigh = (t % 6) > 4.5 && (t % 6) < 5 ? 1 : 0;
    clawd(c, 4, 10 + sigh, { eyes: "none", legs: "none", squash: sigh });
  });

  /* Deliberating — a judge in a curly wig weighs it up, then bangs the gavel */
  defNew("w-deliberating", "Deliberating", "words", "Deliberating…", (c, t) => {
    const X = 8, Y = Y0, p = (t % 3) / 3, bang = p > 0.8 && p < 0.92;
    clawd(c, X, Y, { eyes: bang ? "closed" : ["left", "right", "up"][st(t, 1.2, 3)], armR: bang ? "out" : "up" });
    // wig
    R(c, X + 2, Y - 2, 12, 2, WHITE);
    [3, 6, 9, 12].forEach(dx => R(c, X + dx, Y - 3, 2, 1, WHITE));
    for (let r = 0; r < 4; r++) { R(c, X + 1, Y + r * 2, 2, 1, WHITE); R(c, X + 13, Y + r * 2, 2, 1, WHITE); }
    for (let r = 0; r < 4; r++) { R(c, X + 2, Y + r * 2 + 1, 1, 1, "#d3d1c7"); R(c, X + 13, Y + r * 2 + 1, 1, 1, "#d3d1c7"); }
    // bench
    R(c, X - 4, 18, 26, 1, "#854F0B"); R(c, X - 3, 19, 24, 3, WOOD); R(c, X + 6, 20, 4, 1, GOLD);
    R(c, X + 18, 17, 6, 1, "#412402");
    if (bang) {
      R(c, X + 16, 16, 4, 1, WOOD); R(c, X + 20, 13, 2, 4, "#854F0B");
      R(c, X + 18, 13, 1, 2, WHITE); R(c, X + 23, 13, 1, 2, WHITE); R(c, X + 24, 15, 1, 1, WHITE);
    } else {
      R(c, X + 16, Y - 1, 3, 1, WOOD); R(c, X + 19, Y - 3, 2, 4, "#854F0B");
    }
  });

  /* Mulling — business in the front, party in the back: a mullet in the breeze */
  defNew("w-mulling", "Mulling", "words", "Mulling…", (c, t) => {
    const X = X0 - 2, nod = st(t, 1.6, 2), Y = Y0 + nod, H1 = "#854F0B", H2 = "#BA7517";
    for (let r = 0; r < 9; r++) {
      const len = 2 + Math.round(r * 0.8 + Math.sin(t * 4 - r * 0.6) * (r / 8) * 1.5);
      R(c, X + 13, Y - 1 + r, len + 1, 1, H1);
      if (r > 1 && r < 7) R(c, X + 14, Y - 1 + r, Math.max(1, len - 2), 1, H2);
    }
    clawd(c, X, Y, { eyes: nod ? "closed" : "up", armR: "down" });
    R(c, X + 2, Y - 2, 13, 2, H1); [3, 6, 9, 12].forEach(dx => R(c, X + dx, Y - 3, 1, 1, H1));
    R(c, X + 4, Y - 2, 3, 1, H2); R(c, X + 13, Y, 2, 2, H1);
    const q = (t * 0.6) % 1;
    alpha(c, 1 - q, () => R(c, X - 2 - q * 3, Y - 2 - q * 6, 2, 1, "#888780"));
  });

  /* Thinking — a think tank: the cannon fires thought bubbles */
  defNew("w-thinking", "Thinking", "words", "Thinking…", (c, t) => {
    const p = (t % 2.5) / 2.5, rec = p < 0.08 ? 1 : 0, bob = st(t, 6, 2) && p > 0.08 ? 1 : 0;
    clip(c, 0, 0, 40, 16 + bob, () => clawd(c, 9, 8 + bob, { eyes: p < 0.12 ? "wide" : "up", armL: "out", armR: "out" }));
    const TK = "#3B6D11";
    R(c, 6, 15 + bob, 22, 1, "#97C459"); R(c, 4, 16 + bob, 26, 3, GREEN);
    R(c, 29 - rec, 15 + bob, 8, 2, TK);
    R(c, 3, 19, 28, 3, "#444441"); R(c, 2, 20, 30, 1, "#444441");
    for (let i = 0; i < 7; i++) R(c, 4 + ((i * 4 + Math.floor(t * 8)) % 28), 20, 1, 1, "#888780");
    if (p < 0.08) { glyph(c, G.puff, 37, 14, WHITE); }
    if (p < 0.4) {
      const q = p / 0.4, x = 37 - q * 7, y = 14 - Math.sin(q * Math.PI / 2) * 11;
      glyph(c, G.bubble, x, y, WHITE);
    } else {
      const q = (p - 0.4) / 0.6;
      alpha(c, q < 0.75 ? 1 : (1 - q) * 4, () => {
        glyph(c, [".#######.", "#########", "#########", "#########", ".#######."], 27, 0, WHITE);
        R(c, 30, 4, 1, 2, WHITE);
        const k = Math.min(3, Math.floor(q * 6));
        for (let i = 0; i < k; i++) R(c, 29 + i * 2, 2, 1, 1, EYE);
      });
    }
  });

  /* Befuddling — a shell game: he picks the wrong cup every time */
  defNew("w-befuddling", "Befuddling", "words", "Befuddling…", (c, t) => {
    const T = t % 6, X = 1, Y = Y0, SL = [21, 28, 35], CUP = [".###.", "#####", "#####", "#####"];
    const SW_ = [[0, 1], [1, 2], [0, 2], [1, 2], [0, 1], [0, 2]];
    const pos = [0, 1, 2];
    const cx = [0, 0, 0], cy = [0, 0, 0];
    let lifted = -1, lift = 0, moving = -1, mq = 0;
    for (let i = 0; i < 6; i++) if (T >= 0.8 + i * 0.4) {
      if (T < 0.8 + (i + 1) * 0.4) { moving = i; mq = (T - 0.8 - i * 0.4) / 0.4; break; }
      const [a, b] = SW_[i], ia = pos.indexOf(a), ib = pos.indexOf(b); pos[ia] = b; pos[ib] = a;
    }
    for (let k = 0; k < 3; k++) { cx[k] = SL[pos[k]]; cy[k] = 18; }
    if (moving >= 0) {
      const [a, b] = SW_[moving], ia = pos.indexOf(a), ib = pos.indexOf(b), e = ease(mq);
      cx[ia] = SL[a] + (SL[b] - SL[a]) * e; cy[ia] = 18 - Math.round(Math.sin(e * Math.PI) * 3);
      cx[ib] = SL[b] + (SL[a] - SL[b]) * e;
    }
    const ball = pos[1], guess = (ball + 1) % 3;
    const up = (a, b) => T >= a && T < b ? Math.round(Math.sin(Math.min(1, (T - a) / (b - a) * 1.6) * Math.PI / 2) * 4 * Math.min(1, (b - T) / 0.15)) : 0;
    let showBall = false;
    if (T < 0.8) { lifted = 1; lift = up(0, 0.8); showBall = true; }
    else if (T >= 3.8 && T < 4.6) { lifted = pos.indexOf(guess); lift = up(3.8, 4.6); }
    else if (T >= 4.7 && T < 5.6) { lifted = 1; lift = up(4.7, 5.6); showBall = true; }
    if (showBall) R(c, SL[ball] + 2 - (T < 0.8 ? 1 : 1), 20, 2, 2, GOLD);
    R(c, 18, 22, 22, 1, "#444441");
    for (let k = 0; k < 3; k++) glyph(c, CUP, cx[k], cy[k] - (k === lifted ? lift : 0), RED), R(c, cx[k], cy[k] + 3 - (k === lifted ? lift : 0), 5, 1, "#993C1D");
    let eyes = "right", armR = "out", pt = 0;
    if (T >= 0.8 && T < 3.2) eyes = st(t, 5, 2) ? "right" : "left";
    if (T >= 3.2 && T < 4.6) { pt = Math.min(3, Math.floor((T - 3.2) / 0.1)); eyes = "right"; }
    if (T >= 4.0 && T < 4.6) eyes = "wide";
    if (T >= 4.7 && T < 5.8) eyes = st(t, 6, 2) ? "left" : "right";
    clawd(c, X, Y, { eyes, armR, squash: T >= 5 && T < 5.8 ? 1 : 0 });
    if (pt) R(c, X + 16, Y + 4, pt, 2, CL);
  });

  /* Discombobulating — he turns into a sliding puzzle and his tiles shuffle round */
  defNew("w-discombobulating", "Discombobulating", "words", "Discombobulating…", (c, t) => {
    const T = t % 5, X = X0, Y = Y0, S = [[0, 0], [8, 0], [8, 5], [0, 5]];
    let step = 0, f = 0;
    if (T >= 1.2) { const k = (T - 1.2) / 0.9; step = Math.min(4, Math.floor(k)); f = step < 4 ? ease(Math.min(1, (k - step) / 0.35)) : 0; }
    const whole = step === 0 || (step === 4);
    const eyes = whole ? (T > 4.8 || T < 0.4 ? "happy" : "open") : "wide";
    const shake = T > 0.8 && T < 1.2 ? st(t, 16, 2) : 0;
    for (let i = 0; i < 4; i++) {
      const a = S[(i + step) % 4], b = S[(i + step + 1) % 4];
      const dx = X + shake + a[0] + (b[0] - a[0]) * f, dy = Y + a[1] + (b[1] - a[1]) * f;
      clip(c, Math.round(dx), Math.round(dy), 8, 5, () => clawd(c, Math.round(dx) - S[i][0], Math.round(dy) - S[i][1], { eyes }));
    }
    if (!whole) {
      R(c, X - 1, Y - 1, 18, 1, "#888780"); R(c, X - 1, Y + 10, 18, 1, "#888780");
      R(c, X - 1, Y - 1, 1, 12, "#888780"); R(c, X + 16, Y - 1, 1, 12, "#888780");
      if (st(t, 4, 2)) { R(c, X + 19, Y - 2, 1, 1, GOLD); R(c, X - 3, Y + 8, 1, 1, GOLD); }
      else { R(c, X + 18, Y + 9, 1, 1, GOLD); R(c, X - 3, Y, 1, 1, GOLD); }
    }
  });

  /* Flummoxing — hands stuck in a Chinese finger trap */
  defNew("w-flummoxing", "Flummoxing", "words", "Flummoxing…", (c, t) => {
    const X = X0, Y = Y0, p = (t % 2.4) / 2.4, s = ease(p < 0.45 ? p / 0.45 : p < 0.65 ? 1 : 1 - (p - 0.65) / 0.35);
    const L = Math.round(8 + s * 14), h = 3 - Math.round(s * 2), cx = X + 8, ty = Y + 5 + Math.floor((3 - h) / 2);
    clawd(c, X, Y, { eyes: s > 0.5 ? "closed" : "down", armL: "none", armR: "none" });
    const x0 = cx - Math.floor(L / 2);
    if (x0 - 2 < X) R(c, x0 - 2, Y + 5, X + 2 - (x0 - 2), 2, CL);
    if (x0 + L + 2 > X + 14) R(c, X + 14, Y + 5, x0 + L - X - 12, 2, CL);
    R(c, x0 - 2, Y + 5, 2, 2, CL); R(c, x0 + L, Y + 5, 2, 2, CL);
    for (let i = 0; i < L; i++) for (let r = 0; r < h; r++) R(c, x0 + i, ty + r, 1, 1, (i + r) % 2 ? "#BA7517" : GOLD);
    if (s > 0.6) { R(c, X + 15, Y - 2, 1, 2, SKY); R(c, X, Y - 1, 1, 2, SKY); }
  });

  /* Kerfuffling — a cartoon scuffle cloud with limbs poking out */
  defNew("w-kerfuffling", "Kerfuffling", "words", "Kerfuffling…", (c, t) => {
    const cxx = 20 + Math.round(Math.sin(t * 1.3) * 4), cyy = 13, f = Math.floor(t * 10);
    const P = [[0, 0, 6], [-6, 2, 4], [6, 2, 4], [-3, -4, 4], [4, -4, 4], [0, 5, 4]];
    for (let i = 0; i < 5; i++) { const q = (t * 2 + i / 5) % 1; alpha(c, 1 - q, () => R(c, cxx - 9 + i * 4 + (i % 2 ? q : -q) * 4, 21 - q * 2, 2, 1, "#888780")); }
    const limb = (k, col) => {
      const an = rnd(Math.floor(t * 5) * 3 + k) * Math.PI * 2;
      for (let d = 9; d <= 12; d++) R(c, cxx + Math.cos(an) * d - 1, cyy + Math.sin(an) * d * 0.75 - 1, 2, 2, col);
    };
    P.forEach(([dx, dy, r], i) => disc(c, cxx + dx + Math.round(rnd(f + i * 7) * 2 - 1), cyy + dy + Math.round(rnd(f + i * 3 + 1) * 2 - 1), r + 1, "#888780"));
    P.forEach(([dx, dy, r], i) => disc(c, cxx + dx + Math.round(rnd(f + i * 7) * 2 - 1), cyy + dy + Math.round(rnd(f + i * 3 + 1) * 2 - 1), r, "#d3d1c7"));
    for (let k = 0; k < 3; k++) limb(k, k === 2 ? WHITE : CL);
    if (st(t, 10, 3) === 0) limb(5, CL);
    const ex = cxx - 4 + Math.round(rnd(Math.floor(t * 3)) * 3), ey = cyy - 2 + Math.round(rnd(Math.floor(t * 3) + 5) * 3);
    R(c, ex, ey, 1, 2, EYE); R(c, ex + 5, ey, 1, 2, EYE);
    for (let k = 0; k < 2; k++) {
      const sa = rnd(Math.floor(t * 4) + k * 11) * Math.PI * 2;
      glyph(c, G.star, cxx + Math.cos(sa) * 11 - 1, cyy + Math.sin(sa) * 8 - 1, GOLD);
    }
  });

  /* Topsy-turvying — the whole world flips upside down, then rights itself */
  defNew("w-topsy-turvying", "Topsy-turvying", "words", "Topsy-turvying…", (c, t) => {
    const p = (t % 5) / 5;
    let ang = 0;
    if (p < 0.3) ang = 0; else if (p < 0.4) ang = ease((p - 0.3) / 0.1) * Math.PI;
    else if (p < 0.8) ang = Math.PI; else if (p < 0.9) ang = Math.PI + ease((p - 0.8) / 0.1) * Math.PI; else ang = 0;
    const flipped = p >= 0.4 && p < 0.8;
    c.save(); c.translate(20, 13); c.rotate(ang); c.translate(-20, -13);
    R(c, 0, 22, 40, 1, "#888780");
    [4, 7, 26].forEach(x => { R(c, x, 21, 1, 1, "#97C459"); R(c, x + 1, 20, 1, 2, "#97C459"); });
    R(c, 33, 16, 2, 6, WOOD); disc(c, 34, 13, 3, GREEN);
    glyph(c, G.cloud, 3, 3, WHITE);
    disc(c, 30, 4, 1, GOLD);
    clawd(c, 10, Y0, { eyes: flipped ? "wide" : "happy", armL: flipped ? "up" : "out", armR: flipped ? "up" : "out", legs: 0 });
    if (flipped) {
      const q = ((t % 5) / 5 - 0.42) / 0.36;
      if (q > 0 && q < 1) { R(c, 9, Y0 - 1 - q * 8, 1, 2, SKY); R(c, 26, Y0 + 1 - ((q * 1.4) % 1) * 9, 1, 2, SKY); }
    }
    c.restore();
  });

  /* Cerebrating — a big pink brain on top, crackling with ideas */
  defNew("w-cerebrating", "Cerebrating", "words", "Cerebrating…", (c, t) => {
    const X = X0, Y = Y0 + 1, pulse = st(t, 2.5, 2), B = [
      "..####.#####..",
      ".######.######",
      "##############",
      "##############",
      ".############.",
    ];
    clawd(c, X, Y, { eyes: pulse ? "wide" : "up", armL: "up", armR: "up" });
    glyph(c, B, X + 1, Y - 5 - pulse, pulse ? "#F4C0D1" : PINK);
    [[3, 2], [4, 1], [5, 2], [6, 2], [9, 3], [10, 2], [11, 3], [7, 1], [2, 3], [12, 1]].forEach(([dx, dy]) => R(c, X + 1 + dx, Y - 5 - pulse + dy, 1, 1, "#D4537E"));
    if (pulse) {
      const bolt = (x, y, s) => { R(c, x, y, 1, 2, GOLD); R(c, x + s, y + 2, 1, 2, GOLD); R(c, x, y + 4, 1, 2, GOLD); };
      bolt(X - 3, Y - 8, 1); bolt(X + 18, Y - 8, -1); bolt(X + 8, Y - 12, 1);
    }
  });

  /* Envisioning — his eyes project a dream onto the sky: a castle on a cloud */
  defNew("w-envisioning", "Envisioning", "words", "Envisioning…", (c, t) => {
    const X = 1, Y = Y0, p = (t % 5) / 5, a = p < 0.15 ? p / 0.15 : p < 0.8 ? 1 : 1 - (p - 0.8) / 0.2;
    alpha(c, 0.18 * a, () => {
      c.fillStyle = GOLD; c.beginPath(); c.moveTo(X + 13, Y + 2); c.lineTo(23, 1); c.lineTo(39, 1); c.lineTo(39, 20); c.lineTo(23, 20); c.lineTo(X + 13, Y + 4); c.closePath(); c.fill();
    });
    alpha(c, a * (st(t, 12, 5) ? 1 : 0.7), () => {
      glyph(c, G.cloud, 24, 15, WHITE); glyph(c, G.cloud, 30, 15, WHITE);
      const P2 = "#AFA9EC", P3 = "#7F77DD";
      R(c, 27, 9, 10, 6, P2); R(c, 25, 6, 3, 9, P2); R(c, 36, 6, 3, 9, P2);
      [25, 27, 36, 38].forEach(x => R(c, x, 5, 1, 1, P2));
      [29, 31, 33].forEach(x => R(c, x, 8, 1, 1, P2));
      R(c, 31, 12, 2, 3, P3); R(c, 26, 8, 1, 1, P3); R(c, 37, 8, 1, 1, P3);
      R(c, 31, 3, 1, 6, WHITE); R(c, 32, 3 + st(t, 4, 2), 3, 2, RED);
    });
    clawd(c, X, Y, { eyes: a > 0.9 ? "happy" : "right" });
    if (a > 0.5 && a < 1) { R(c, X + 13, Y + 1, 1, 1, GOLD); }
  });

  /* Imagining — his shadow on the wall is a roaring T-rex */
  defNew("w-imagining", "Imagining", "words", "Imagining…", (c, t) => {
    const p = (t % 3) / 3, roar = p > 0.55 && p < 0.9, X = 2, Y = Y0;
    alpha(c, 0.22, () => { R(c, 18, 1, 21, 20, GOLD); R(c, 17, 2, 1, 18, GOLD); R(c, 39, 2, 1, 18, GOLD); });
    const DX = 19, DY = 4 + (roar ? 0 : st(t, 2, 2));
    const D = roar ? [
      "...........######.",
      "..........########",
      "..........##.#####",
      "..........#######.",
      "..........####....",
      "..........###.....",
      "..........####.###",
      ".........########.",
      "#.......#######.##",
      "##.....##########.",
      ".##...##########..",
      "..##.##########...",
      "...###########....",
      "....####...###....",
      "....###.....##....",
      "....##......##....",
      "...###.....###....",
    ] : [
      "..........#######.",
      ".........#########",
      ".........##.######",
      ".........#########",
      ".........######...",
      ".........########.",
      "........######....",
      "........#######...",
      "#......#######.#..",
      "##....#########.#.",
      ".##..##########...",
      "..##.##########...",
      "...###########....",
      "....####...###....",
      "....###.....##....",
      "....##......##....",
      "...###.....###....",
    ];
    glyph(c, D, DX, DY, "#2c2c2a");
    if (roar) {
      R(c, DX + 11, DY + 2, 1, 1, RED);
      for (let i = 0; i < 3; i++) R(c, 37, DY + 3 + i * 2 + st(t, 8, 2), 2, 1, WHITE);
    }
    clawd(c, X, Y, { eyes: roar ? "closed" : "right", armL: roar ? "up" : "out", armR: roar ? "up" : "out" });
  });

  /* Manifesting — wishes hard and sparkles spiral in to conjure a present */
  defNew("w-manifesting", "Manifesting", "words", "Manifesting…", (c, t) => {
    const X = 3, Y = Y0, p = (t % 4) / 4, gx = 29, gy = 13;
    const here = p > 0.42 && p < 0.92, hop = p > 0.45 && p < 0.55 ? 2 : 0;
    if (p < 0.4) {
      const q = p / 0.4;
      for (let i = 0; i < 6; i++) {
        const an = i * Math.PI / 3 + q * 4, d = (1 - q) * 12 + 1;
        R(c, gx + Math.cos(an) * d, gy + Math.sin(an) * d * 0.8, 1, 1, i % 2 ? GOLD : "#AFA9EC");
      }
    } else if (p < 0.47) {
      glyph(c, [".#.#.", "..#..", "#####", "..#..", ".#.#."].map(r => r), gx - 2, gy - 2, WHITE);
    }
    if (here) {
      const bob = Math.round(Math.sin(t * 4) * 0.6), fade = p > 0.85 ? 1 - (p - 0.85) / 0.07 : 1;
      alpha(c, fade, () => {
        R(c, gx - 3, gy - 2 + bob, 7, 6, "#7F77DD"); R(c, gx, gy - 2 + bob, 1, 6, GOLD); R(c, gx - 3, gy + bob, 7, 1, GOLD);
        R(c, gx - 2, gy - 4 + bob, 2, 2, GOLD); R(c, gx + 1, gy - 4 + bob, 2, 2, GOLD);
        if (st(t, 5, 2)) { R(c, gx + 5, gy - 4, 1, 1, WHITE); R(c, gx - 5, gy + 3, 1, 1, WHITE); }
      });
    }
    clawd(c, X, Y - hop, { eyes: here ? "happy" : "closed", armL: "up", armR: "up", legs: hop ? 3 : 0 });
  });

  /* Bloviating — full of hot air: his speech bubble swells and floats off like a balloon */
  defNew("w-bloviating", "Bloviating", "words", "Bloviating…", (c, t) => {
    const X = 1, Y = Y0, p = (t % 4) / 4, talk = st(t, 6, 2);
    const s = Math.min(1, p / 0.6), w = 5 + Math.round(s * 13), h = 3 + Math.round(s * 6);
    let bx = X + 18, by = Y + 3 - h, free = p >= 0.6;
    if (free) { const q = (p - 0.6) / 0.4; by -= Math.round(q * q * 30); bx += Math.round(Math.sin(q * 6) * 2); }
    R(c, bx + 1, by, w - 2, h, WHITE); R(c, bx, by + 1, w, h - 2, WHITE);
    for (let r = 0; r < Math.floor((h - 1) / 2); r++) {
      const n = Math.max(1, Math.floor((w - 4) / 3));
      for (let k = 0; k < n; k++) if (rnd(r * 5 + k) > 0.25) R(c, bx + 2 + k * 3, by + 1 + r * 2 + 0.5, 2, 1, "#888780");
    }
    if (free) { line(c, bx + Math.floor(w / 2), by + h, bx + Math.floor(w / 2) - 1, by + h + 4, "#888780"); }
    else { R(c, bx - 1, by + h - 1, 1, 1, WHITE); R(c, bx - 2, by + h, 1, 1, WHITE); }
    clawd(c, X, Y, { eyes: "closed", armR: talk ? "up" : "out", armL: talk ? "out" : "down" });
  });

  /* Pontificating — in a tall mitre at the lectern, finger raised */
  defNew("w-pontificating", "Pontificating", "words", "Pontificating…", (c, t) => {
    const X = 9, Y = Y0, wag = st(t, 3, 2), g = st(t, 0.8, 2);
    clawd(c, X, Y, { eyes: g ? "closed" : "up", armR: "up", armL: "out" });
    R(c, X + 14 + wag, Y - 3, 1, 2, CL);
    [[2, 7, -8], [4, 6, -7], [6, 5, -6], [8, 4, -5], [8, 4, -4], [8, 4, -3], [8, 4, -2], [8, 4, -1]].forEach(([w, dx, dy]) => R(c, X + dx, Y + dy, w, 1, WHITE));
    R(c, X + 7, Y - 7, 2, 7, GOLD); R(c, X + 4, Y - 1, 8, 1, GOLD);
    R(c, X, 18, 16, 1, "#854F0B"); R(c, X + 1, 19, 14, 3, WOOD); R(c, X + 6, 19, 4, 3, "#854F0B");
    if (st(t, 4, 2)) { R(c, X + 19, Y + 1, 3, 1, "#888780"); R(c, X + 19, Y + 4, 4, 1, "#888780"); R(c, X + 19, Y + 7, 3, 1, "#888780"); }
  });

  /* Ruminating — a cow chewing the cud */
  defNew("w-ruminating", "Ruminating", "words", "Ruminating…", (c, t) => {
    const X = X0, Y = Y0, jaw = [0, 1, 0, -1][st(t, 4, 4)];
    R(c, 0, 22, 40, 1, "#3B6D11");
    [3, 8, 30, 35].forEach((x, i) => { R(c, x, 21, 1, 1, "#97C459"); R(c, x + 1, 20 + (i % 2), 1, 2 - (i % 2), "#97C459"); });
    clawd(c, X, Y, { eyes: st(t, 0.5, 2) ? "closed" : "open", legs: 0 });
    R(c, X + 2, Y - 1, 1, 1, "#d3d1c7"); R(c, X + 1, Y - 2, 1, 1, "#d3d1c7");
    R(c, X + 13, Y - 1, 1, 1, "#d3d1c7"); R(c, X + 14, Y - 2, 1, 1, "#d3d1c7");
    R(c, X + 3, Y + 6, 2, 2, WHITE);
    R(c, X + 11, Y + 6, 3, 2, WHITE); R(c, X + 8, Y, 3, 1, WHITE);
    R(c, X + 6 + jaw, Y + 5, 3, 1, "#993C1D");
    R(c, X + 9 + jaw, Y + 5, 3, 1, "#97C459"); R(c, X + 11 + jaw, Y + 4 - (jaw > 0 ? 1 : 0), 1, 1, "#97C459");
    R(c, X + 7, Y + 7, 2, 1, "#444441"); R(c, X + 7, Y + 8, 3, 2, GOLD); R(c, X + 8, Y + 10, 1, 1, "#BA7517");
  });

  /* Determining — headband on, pushing a huge boulder with grim determination */
  defNew("w-determining", "Determining", "words", "Determining…", (c, t) => {
    const X = 4, Y = Y0, f = st(t, 5, 2), bx = 26, by = 15, a = t * 1.6;
    R(c, 0, 22, 40, 1, "#888780");
    for (let i = 0; i < 6; i++) R(c, 40 - ((i * 8 + t * 6.5) % 44), 23, 2, 1, "#5f5e5a");
    disc(c, bx, by, 7, "#888780");
    for (let k = 0; k < 5; k++) {
      const an = a + k * 1.26, d = 2 + (k % 3) * 1.6;
      R(c, Math.round(bx + Math.cos(an) * d), Math.round(by + Math.sin(an) * d), 2, 1, "#5f5e5a");
    }
    for (let i = 0; i < 2; i++) { const q = (t * 1.5 + i / 2) % 1; alpha(c, 1 - q, () => R(c, X + 1 - q * 6, 21 - q * 3, 2, 1, "#888780")); }
    clawd(c, X, Y, { eyes: "open", legs: f + 1, armR: "out", armL: "down" });
    R(c, X + 2, Y, 12, 1, RED);
    const flap = st(t, 6, 2);
    R(c, X, Y + flap, 2, 1, RED); R(c, X - 2, Y + 1 - flap, 2, 1, RED);
    R(c, X + 4, Y + 1, 2, 1, EYE); R(c, X + 10, Y + 1, 2, 1, EYE);
    const q = (t * 1.2) % 1;
    R(c, X + 1 - q * 4, Y - 1 + q * 2, 1, 1, SKY);
  });

  /* Elucidating — squeegees a grimy window until the view is crystal clear */
  defNew("w-elucidating", "Elucidating", "words", "Elucidating…", (c, t) => {
    const X = 4, Y = Y0, T = t % 6, WX = 23, WY = 4, WW = 14, WH = 13, BANDS = [[4, 5], [9, 4], [13, 4]];
    R(c, WX - 1, WY - 1, WW + 2, WH + 2, WOOD);
    R(c, WX, WY, WW, WH, SKY); disc(c, 32, 7, 1, GOLD);
    R(c, WX, 14, WW, 3, GREEN); R(c, WX + 3, 13, 7, 1, GREEN); R(c, WX + 5, 12, 3, 1, GREEN);
    let hx = WX, band = 0, wiping = false;
    const grime = (x0, y0, w, h, a) => alpha(c, a, () => { R(c, x0, y0, w, h, "#854F0B"); for (let i = 0; i < 10; i++) { const px = WX + Math.floor(rnd(i) * WW), py = WY + Math.floor(rnd(i + 20) * WH); if (px >= x0 && px < x0 + w && py >= y0 && py < y0 + h) R(c, px, py, 2, 1, "#5f3a1e"); } });
    if (T < 0.6) grime(WX, WY, WW, WH, 1);
    else if (T < 3.6) {
      band = Math.min(2, Math.floor((T - 0.6) / 1)); const q = Math.min(1, ((T - 0.6) - band * 1) / 0.85);
      hx = WX + Math.round(q * WW); wiping = true;
      BANDS.forEach(([y, h], b) => { if (b > band) grime(WX, y, WW, h, 1); else if (b === band) grime(hx, y, WX + WW - hx, h, 1); });
    } else if (T < 4.6) {
      if (st(t, 5, 2)) { glyph(c, G.star, 26, 5, WHITE); glyph(c, G.star, 33, 11, WHITE); }
      band = 2; hx = WX + WW;
    } else {
      grime(WX, WY, WW, WH, ease((T - 4.6) / 1.2));
      hx = WX + WW - Math.round(ease((T - 4.6) / 1.2) * WW); band = Math.round(2 - ease((T - 4.6) / 1.2) * 2);
    }
    const [hy, hh] = BANDS[band];
    clawd(c, X, Y, { eyes: T >= 3.6 && T < 4.6 ? "happy" : "right", armR: band === 0 ? "up" : "out" });
    const hand = band === 0 ? [X + 15, Y - 1] : [X + 16, Y + 4];
    line(c, hand[0], hand[1], hx - 1, hy + Math.floor(hh / 2), "#444441");
    R(c, hx - 1, hy - (wiping ? 0 : 0), 1, hh, "#2c2c2a"); R(c, hx, hy, 1, hh, METAL);
  });
})();


/* ---- word batch: work ---- */
/* Status words: making, working, building and reading */
(() => {
  const YEL = "#FAC775", ORG = "#EF9F27", RED = "#E24B4A", BLUE = "#85B7EB", DBLUE = "#378ADD", NAVY = "#185FA5";
  const TEAL = "#5DCAA5", GREEN = "#97C459", DGREEN = "#639922", PINK = "#ED93B1", PURP = "#AFA9EC";
  const BROWN = "#854F0B", DARK = "#444441", MGREY = "#5f5e5a", GREY = "#888780";
  const cl = q => Math.max(0, Math.min(1, q));
  const ease = q => { q = cl(q); return q * q * (3 - 2 * q); };
  const disc = (c, cx, cy, r, col) => { for (let dy = -r; dy <= r; dy++) { const w = Math.floor(Math.sqrt(r * r - dy * dy + 0.3)); R(c, cx - w, cy + dy, 2 * w + 1, 1, col); } };
  const ring = (c, cx, cy, r, col, n = 48) => { for (let i = 0; i < n; i++) { const a = i / n * 2 * Math.PI; R(c, cx + Math.cos(a) * r, cy + Math.sin(a) * r, 1, 1, col); } };
  const reach = (c, x0, y0, x1, y1) => { line(c, x0, y0, x1, y1, CL); line(c, x0, y0 + 1, x1, y1 + 1, CL); };   // a stretchy arm
  const mirror = (c, on) => { c.save(); if (on) { c.translate(SW, 0); c.scale(-1, 1); } };

  /* ---------- Composing: writes notes on a music staff with a quill, then they float off and play ---------- */
  defNew("w-composing", "Composing", "words", "Composing…", (c, t) => {
    const p = (t % 4.4) / 4.4, X = 1, Y = Y0;
    for (let i = 0; i < 5; i++) R(c, 20, 5 + i * 2, 19, 1, MGREY);
    R(c, 20, 5, 1, 9, GREY); R(c, 38, 5, 1, 9, GREY);
    const N = [[23, 10], [27, 7], [31, 11], [35, 5]];
    N.forEach(([nx, ny], k) => {
      if (p < 0.18 + 0.14 * k) return;
      const q = cl((p - 0.66 - k * 0.05) / 0.24);
      if (q <= 0) { R(c, nx, ny, 2, 2, WHITE); R(c, nx + 1, ny - 4, 1, 4, WHITE); }
      else alpha(c, 1 - q, () => glyph(c, G.note, nx - 2 + Math.round(Math.sin(q * 9 + k) * 1.5), ny - 4 - q * 12, YEL));
    });
    const writing = p < 0.62;
    if (writing) {
      const k = Math.max(0, Math.min(3, Math.floor((p - 0.04) / 0.14))), [nx, ny] = N[k];
      const k0 = cl(p / 0.05), tx = Math.round(X + 17 + (nx + st(t, 10, 2) - X - 17) * k0), ty = Math.round(Y + 7 + (ny + 1 - Y - 7) * k0);
      clawd(c, X, Y, { eyes: "right", armR: "none" });
      reach(c, X + 14, Y + 4, tx - 3, ty - 3);
      line(c, tx - 3, ty - 3, tx, ty, METAL);
      glyph(c, ["##.", "###", ".##"], tx - 5, ty - 6, WHITE);
    } else {
      const sway = st(t, 3, 2);
      clawd(c, X + sway, Y, { eyes: "happy", armR: sway ? "up" : "out", armL: sway ? "out" : "up" });
    }
  });

  /* ---------- Crafting: snips paper into a chain of little paper Clawds ---------- */
  defNew("w-crafting", "Crafting", "words", "Crafting…", (c, t) => {
    const p = (t % 5) / 5, X = 0, Y = Y0, PX = 19, PY = 15;
    const DOLL = [".####.", ".#..#.", "######", ".####.", ".####.", ".#..#.", ".#..#."];
    if (p < 0.4) {
      R(c, PX, PY, 6, 7, WHITE);
      const sy = 15 + Math.round(pong((p / 0.4 * 3) % 1) * 4), open = st(t, 8, 2);
      glyph(c, open ? ["#...", ".###", "#..."] : ["....", "####", "...."], 16, sy, METAL);
      R(c, 15, sy, 1, 1, RED); R(c, 15, sy + 2, 1, 1, RED);
      for (let i = 0; i < 3; i++) { const q = (t * 1.6 + i / 3) % 1; alpha(c, 1 - q, () => R(c, 18 - i, sy + 1 + q * (20 - sy), 1, 1, WHITE)); }
      clawd(c, X, Y, { eyes: "right" });
    } else {
      let n = p < 0.6 ? 1 + Math.floor(cl((p - 0.42) / 0.18) * 3.99) : 4;
      const out = p > 0.88 ? (p - 0.88) / 0.12 : 0;
      alpha(c, 1 - out, () => {
        for (let i = 0; i < n; i++) {
          const bob = p > 0.6 && st(t, 4, 2) === i % 2 ? 1 : 0;
          glyph(c, DOLL, PX + i * 5, PY - bob - Math.round(out * 6), WHITE);
        }
      });
      if (out > 0) alpha(c, out, () => R(c, PX, PY, 6, 7, WHITE));          // a fresh sheet for next time
      clawd(c, X, Y, { eyes: p > 0.6 ? "happy" : "right", armL: p > 0.6 ? "up" : "out" });
    }
  });

  /* ---------- Creating: conjures a tiny planet between his raised hands ---------- */
  defNew("w-creating", "Creating", "words", "Creating…", (c, t) => {
    const p = (t % 4.5) / 4.5, X = X0, Y = Y0, cx = 20;
    [[3, 3], [36, 6], [6, 15], [33, 17], [12, 2]].forEach(([x, y], i) => { if (st(t + i * 0.37, 2, 2)) R(c, x, y, 1, 1, i % 2 ? PURP : WHITE); });
    let cy = 5, r = 0;
    if (p < 0.2) {
      const q = p / 0.2;
      [[-10, -4], [10, -4], [-9, 5], [9, 5]].forEach(([dx, dy]) => R(c, cx + dx * (1 - q), cy + dy * (1 - q), 1, 1, YEL));
    } else {
      r = Math.round(cl((p - 0.2) / 0.25) * 4);
      if (p > 0.5) cy += Math.round(Math.sin(t * 4));
      if (p > 0.75) cy -= Math.round(ease((p - 0.75) / 0.25) * 15);
      if (r > 0) {
        if (p < 0.5 && st(t, 8, 2)) ring(c, cx, cy, r + 2, YEL, 12);
        disc(c, cx, cy, r, TEAL);
        if (r >= 3) { R(c, cx - 2, cy - 1, 2, 1, DGREEN); R(c, cx + 1, cy + 1, 2, 2, DGREEN); R(c, cx - 1, cy - 3, 2, 1, WHITE); }
        if (r >= 4) line(c, cx - 7, cy + 2, cx + 7, cy - 1, YEL);
      }
    }
    const done = p > 0.5;
    clawd(c, X, Y, { eyes: done ? "happy" : "up", armL: p > 0.8 && st(t, 4, 2) ? "out" : "up", armR: "up" });
  });

  /* ---------- Doodling: tongue-out concentration, scribbling a spiral on a notepad, then tears the page off ---------- */
  const SPIRAL = []; for (let i = 0; i <= 140; i++) { const s = i / 140, a = s * 6 * Math.PI, r = 0.6 + s * 5.4; SPIRAL.push([31 + Math.cos(a) * r, 13.5 + Math.sin(a) * r]); }
  function notePage(c, ox, oy, m) {
    R(c, 21 + ox, 6 + oy, 18, 16, WHITE);
    for (let y = 9; y < 21; y += 3) R(c, 22 + ox, y + oy, 16, 1, "#B5D4F4");
    R(c, 24 + ox, 6 + oy, 1, 16, "#F0997B");
    for (let i = 1; i <= m; i++) line(c, SPIRAL[i - 1][0] + ox, SPIRAL[i - 1][1] + oy, SPIRAL[i][0] + ox, SPIRAL[i][1] + oy, NAVY);
  }
  defNew("w-doodling", "Doodling", "words", "Doodling…", (c, t) => {
    const p = (t % 5) / 5, X = 1, Y = Y0;
    const m = Math.floor(cl(p / 0.68) * 140);
    if (p < 0.85) notePage(c, 0, 0, m);
    else {
      const q = (p - 0.85) / 0.15;
      notePage(c, 0, 0, 0);
      alpha(c, 1 - q, () => notePage(c, Math.round(q * 14), -Math.round(q * 12), 140));
    }
    for (let x = 22; x < 39; x += 3) R(c, x, 5, 1, 2, GREY);
    if (p < 0.68) {
      const [tx0, ty0] = SPIRAL[m], tx = Math.round(tx0), ty = Math.round(ty0);
      clawd(c, X, Y, { eyes: "right", armR: "none" });
      R(c, X + 14, Y + 6, 1, 1, PINK);                                         // tongue poking out in concentration
      reach(c, X + 14, Y + 4, tx - 4, ty - 4);
      R(c, tx, ty, 1, 1, DARK); line(c, tx - 1, ty - 1, tx - 3, ty - 3, ORG); R(c, tx - 4, ty - 4, 1, 1, PINK);
    } else {
      clawd(c, X, Y, { eyes: "happy", armR: p < 0.85 ? "up" : "out" });
    }
  });

  /* ---------- Embellishing: bedazzles himself with gems from a jar, sparkles, then shakes them off ---------- */
  defNew("w-embellishing", "Embellishing", "words", "Embellishing…", (c, t) => {
    const p = (t % 6) / 6, X = 6;
    const GEMS = [[2, 1], [7, 1], [12, 1], [3, 5], [7, 5], [11, 5]], COL = [RED, BLUE, TEAL, YEL, PINK, PURP];
    const shake = p > 0.86 ? (p - 0.86) / 0.14 : 0, jig = shake > 0 && shake < 0.6 ? st(t, 14, 2) * 2 - 1 : 0, Y = Y0;
    R(c, 24, 15, 6, 1, METAL);
    alpha(c, 0.45, () => R(c, 24, 16, 6, 6, "#B5D4F4"));
    [[25, 19, RED], [27, 18, TEAL], [28, 20, YEL], [26, 20, PINK], [25, 17, PURP], [28, 17, BLUE]].forEach(([x, y, col]) => R(c, x, y, 1, 1, col));
    let reaching = false;
    GEMS.forEach((g, k) => { const tk = 0.04 + 0.11 * k; if (p > tk - 0.04 && p < tk + 0.01) reaching = true; });
    clawd(c, X + jig, Y, { eyes: shake ? "closed" : p > 0.7 ? "happy" : reaching ? "right" : "down", armR: reaching ? "down" : p > 0.72 && p < 0.86 ? "up" : "out" });
    GEMS.forEach(([gx, gy], k) => {
      const tk = 0.04 + 0.11 * k;
      if (p < tk) return;
      const q = cl((p - tk) / 0.08), ex = X + gx, ey = Y + gy;
      if (q < 1) { R(c, 25 + (ex - 25) * q, 17 + (ey - 17) * q - Math.sin(q * Math.PI) * 7, 2, 2, COL[k]); return; }
      if (shake > 0) { const f = cl((shake - k * 0.05) / 0.6); alpha(c, 1 - f, () => R(c, ex + jig + (k - 2.5) * f * 2, ey + f * f * 14, 2, 2, COL[k])); return; }
      R(c, ex, ey, 2, 2, COL[k]);
      if (p > 0.7 && st(t + k * 0.13, 5, 3) === 0) R(c, ex, ey, 1, 1, WHITE);
    });
    if (p > 0.7 && p < 0.86) [[X - 2, Y - 2], [X + 17, Y], [X + 8, Y - 4], [X - 3, Y + 7]].forEach(([x, y], i) => { if (st(t + i * 0.2, 4, 2)) glyph(c, G.star, x, y, i % 2 ? YEL : WHITE); });
  });

  /* ---------- Computing: counts on an abacus, bead by bead, then sweeps it clear ---------- */
  const abDigits = n => [n % 5, Math.floor(n / 5) % 5, Math.floor(n / 25) % 5];
  defNew("w-computing", "Computing", "words", "Computing…", (c, t) => {
    const T = t % 4.6, X = 2, Y = Y0, B = 0.26;
    let from, to, e, counting = T < 15 * B;
    if (counting) { const b = Math.floor(T / B); from = abDigits(b); to = abDigits(b + 1); e = ease(((T % B) / B) / 0.4); }
    else { from = abDigits(15); to = abDigits(0); e = ease((T - 15 * B) / 0.6); }
    R(c, 21, 8, 18, 2, WOOD); R(c, 21, 20, 18, 2, WOOD); R(c, 21, 8, 2, 14, WOOD); R(c, 37, 8, 2, 14, WOOD);
    const ROWS = [17, 14, 11], CC = [[TEAL, "#9FE1CB"], [YEL, ORG], [RED, "#F0997B"]];
    ROWS.forEach((ry, r) => {
      R(c, 23, ry, 14, 1, METAL);
      for (let i = 0; i < 5; i++) {
        const pos = d => i < d ? 23 + 2 * i : 27 + 2 * i, x = Math.round(pos(from[r]) + (pos(to[r]) - pos(from[r])) * e);
        R(c, x, ry - 1, 2, 3, CC[r][i % 2]);
      }
    });
    const ch = counting ? [0, 1, 2].find(r => from[r] !== to[r]) : 1, d = Math.min(from[ch], to[ch]);
    const hx = (counting ? 27 + 2 * d : 36 - Math.round(e * 6)) - 1, hy = ROWS[ch] - 1;
    clawd(c, X, Y, { eyes: counting ? "right" : "happy", armR: "none" });
    reach(c, X + 14, Y + 4, hx, hy);
  });

  /* ---------- Doing: ticks off a to-do list one box at a time, cheers, flips to a fresh page ---------- */
  function todo(c, checks) {
    R(c, 22, 7, 14, 14, WHITE);
    [8, 11, 14, 17].forEach((y, k) => {
      R(c, 23, y, 3, 1, DARK); R(c, 23, y + 2, 3, 1, DARK); R(c, 23, y + 1, 1, 1, DARK); R(c, 25, y + 1, 1, 1, DARK);
      R(c, 28, y + 1, [6, 5, 7, 4][k], 1, GREY);
      if (k < checks) glyph(c, G.check, 23, y - 1, DGREEN);
    });
  }
  defNew("w-doing", "Doing", "words", "Doing…", (c, t) => {
    const p = (t % 5) / 5, X = 1, Y = Y0;
    R(c, 21, 5, 16, 17, WOOD); R(c, 26, 4, 6, 2, METAL);
    const checks = [0, 1, 2, 3].filter(k => p >= 0.12 + 0.15 * k).length;
    if (p < 0.85) todo(c, checks);
    else { const q = (p - 0.85) / 0.15, h = Math.round(14 * (1 - q)); todo(c, 0); if (h > 0) clip(c, 22, 7, 14, h, () => todo(c, 4)); R(c, 22, 7 + h, 14, 1, GLASS); }
    R(c, 26, 4, 6, 2, METAL);
    if (p < 0.62) {
      const k = Math.max(0, Math.min(3, Math.floor((p - 0.02) / 0.15))), ty = [8, 11, 14, 17][k] + 1;
      const hop = [0, 1, 2, 3].some(j => p >= 0.12 + 0.15 * j && p < 0.15 + 0.15 * j);
      const tick = cl(((p - 0.02) % 0.15) / 0.1), k0 = cl(p / 0.06);
      const tx = Math.round(X + 16 + (24 + (tick < 0.5 ? -tick * 2 : (tick - 0.5) * 4) - X - 16) * k0), tyy = Math.round(Y + 8 + (ty + (tick < 0.5 ? tick * 2 : 1 - (tick - 0.5) * 4) - Y - 8) * k0);
      clawd(c, X, Y - (hop ? 1 : 0), { eyes: hop ? "happy" : "right", armR: "none" });
      reach(c, X + 14, Y + 4 - (hop ? 1 : 0), tx + 2, tyy - 4);
      line(c, tx, tyy, tx + 2, tyy - 3, DBLUE); R(c, tx, tyy, 1, 1, NAVY);
    } else {
      const b = st(t, 4, 2);
      clawd(c, X, Y - (p < 0.85 ? b : 0), { eyes: "happy", armL: "up", armR: "up" });
    }
  });

  /* ---------- Processing: cranks a grinder — messy scraps go in the top, tidy blocks come out ---------- */
  defNew("w-processing", "Processing", "words", "Processing…", (c, t) => {
    const X = 1, Y = Y0, j = st(t, 12, 2);
    for (let k = 0; k < 2; k++) {
      const ph = (t * 2 + k * 0.5) % 1, by = -4 + ph * 13, bx = 24 + (k ? 3 : 0) + Math.round(Math.sin(ph * 8));
      [[0, 0, RED], [2, 0, BLUE], [1, 1, YEL], [3, 1, PINK], [0, 2, PURP], [2, 2, GREEN], [1, 3, ORG]].forEach(([dx, dy, col], i) => {
        if ((i + k) % 3 !== 2) R(c, bx + ((dx + st(t, 6, 2) * (i % 2)) % 4), by + dy, 1, 1, col);
      });
    }
    for (let r = 0; r < 6; r++) R(c, 20 + r, 4 + r, 13 - 2 * r, 1, METAL);
    R(c, 21 + j, 10, 11, 12, DARK); R(c, 21 + j, 10, 11, 1, MGREY);
    R(c, 24 + j, 13, 3, 2, st(t, 3, 2) ? YEL : MGREY); R(c, 28 + j, 13, 2, 2, st(t, 3, 2) ? MGREY : GREEN);
    R(c, 32, 19, 3, 1, METAL); R(c, 32, 20, 1, 1, METAL);
    for (let k = 0; k < 3; k++) { const x = 33 + ((t * 8) % 4) + k * 4; R(c, x, 20, 2, 2, TEAL); }
    const a = t * 4 * Math.PI, hx = 21 + Math.cos(a) * 3, hy = 15 + Math.sin(a) * 3;
    clawd(c, X, Y, { eyes: "right", armR: "none", squash: st(t, 4, 2) });
    line(c, 21, 15, hx, hy, METAL); R(c, 21, 15, 1, 1, GREY);
    reach(c, X + 14, Y + 4, hx - 1, hy);
    R(c, hx - 1, hy - 1, 2, 2, RED);
  });

  /* ---------- Working: hard hat on, rattling away with a jackhammer, then a breather to mop his brow ---------- */
  defNew("w-working", "Working", "words", "Working…", (c, t) => {
    const p = (t % 4) / 4, X = 12, drill = p < 0.7, j = drill ? st(t, 20, 2) : 0, Y = Y0 - j;
    R(c, 0, 22, 40, 2, MGREY); R(c, 0, 22, 40, 1, GREY);
    const crack = drill ? cl(p / 0.6) : 1 - cl((p - 0.72) / 0.2);
    if (crack > 0) alpha(c, Math.min(1, crack * 2), () => {
      const n = Math.round(crack * 6);
      for (let i = 0; i < n; i++) { R(c, 31 - i, 22 + (i % 2), 1, 1, DARK); R(c, 32 + i, 22 + ((i + 1) % 2), 1, 1, DARK); }
      R(c, 31, 22, 2, 2, "#2c2c2a");
    });
    clawd(c, X, Y, { eyes: drill ? "closed" : p < 0.92 ? "happy" : "right", armR: "up", armL: !drill && p < 0.88 ? "up" : "out" });
    R(c, X + 3, Y - 2, 10, 2, YEL); R(c, X + 1, Y, 14, 1, ORG); R(c, X + 7, Y - 3, 2, 1, YEL);
    const hx = 30 + (drill ? st(t, 20, 2) : 0);
    R(c, X + 14, Y - 1, hx + 4 - X - 14, 1, METAL);
    R(c, hx, Y, 3, 8, DARK); R(c, hx, Y + 1, 3, 1, RED);
    R(c, hx + 1, Y + 8, 1, 22 - (Y + 8), METAL);
    if (drill && p > 0.03) for (let i = 0; i < 4; i++) {
      const q = (t * 3 + i / 4) % 1, dx = (i % 2 ? 1 : -1) * (2 + q * 6 + i);
      R(c, 31 + dx, 21 - Math.sin(q * Math.PI) * (4 + i), 1, 1, i % 2 ? GREY : BROWN);
    }
    if (drill && st(t, 10, 2)) { R(c, hx - 2, Y + 3, 1, 1, WHITE); R(c, hx + 4, Y + 5, 1, 1, WHITE); }
    if (!drill && p < 0.9) {
      const q = (p - 0.7) / 0.2;
      alpha(c, 1 - q, () => { glyph(c, G.puff, 27 - q * 4, 19 - q * 3, GLASS); glyph(c, G.puff, 33 + q * 4, 19 - q * 3, GLASS); });
      alpha(c, 1 - q, () => R(c, X + 1, Y + 1 + q * 6, 1, 1, BLUE));
    }
  });

  /* ---------- Actioning: "Lights, camera, ACTION!" — the clapper snaps, he dive-rolls and strikes a pose ---------- */
  const BURST = ["#...#...#", ".#..#..#.", "..#####..", ".#######.", "#########", ".#######.", "..#####..", ".#..#..#.", "#...#...#"];
  defNew("w-actioning", "Actioning", "words", "Actioning…", (c, t) => {
    const P = 4, p = (t % P) / P, flip = Math.floor(t / P) % 2;
    mirror(c, flip);
    if (p < 0.32) {                                                         // the clapperboard
      const shut = p > 0.2, x = 26, y = 6;
      R(c, x, y, 11, 6, DARK); R(c, x + 1, y + 2, 5, 1, WHITE); R(c, x + 1, y + 4, 8, 1, GREY);
      if (shut) { for (let i = 0; i < 11; i++) R(c, x + i, y - 2, 1, 2, (i >> 1) % 2 ? WHITE : DARK); }
      else for (let i = 0; i < 11; i++) R(c, x + i, y - 2 - Math.round(i * 0.6), 1, 2, (i >> 1) % 2 ? WHITE : DARK);
      if (shut && p < 0.27) [[x - 2, y - 4], [x + 12, y - 3], [x + 5, y - 5]].forEach(([sx, sy]) => R(c, sx, sy, 1, 1, YEL));
    }
    if (p < 0.32) clawd(c, 2, Y0, { eyes: p < 0.2 ? "up" : "right", squash: p > 0.22 ? 1 : 0 });
    else if (p < 0.56) {
      const q = (p - 0.32) / 0.24, x = Math.round(2 + q * 20), h = Math.round(Math.sin(q * Math.PI) * 7), quarter = Math.floor(q * 8);
      turn(c, x + 8, Y0 + 5 - h, quarter, () => clawd(c, x, Y0 - h, { eyes: "closed", legs: 3, armL: "down", armR: "down" }));
      for (let i = 1; i < 3; i++) R(c, x - i * 4, Y0 + 6 - h + i, 2, 1, MGREY);
    } else {
      const q = (p - 0.56) / 0.44;
      if (q < 0.5) alpha(c, 1 - q * 2, () => { glyph(c, BURST, 3, 12, st(t, 10, 2) ? ORG : RED); R(c, 6, 15, 3, 3, YEL); });
      for (let i = 0; i < 3; i++) if (q < 0.6) R(c, 7 + (i - 1) * q * 14, 14 - Math.sin(q * 5) * 4 + i, 1, 1, GREY);
      clawd(c, 22, Y0, { eyes: "shades", armR: "up", armL: q < 0.1 ? "out" : "down" });
      if (q > 0.2 && st(t, 5, 2)) R(c, 39, Y0 - 2, 1, 1, WHITE);
    }
    c.restore();
  });

  /* ---------- Actualizing: dreams of a star, and the dream pops into a real one over his head ---------- */
  const STAR = ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", "##...##"];
  defNew("w-actualizing", "Actualizing", "words", "Actualizing…", (c, t) => {
    const p = (t % 5) / 5, X = 4, Y = Y0;
    const bubble = (a, fill) => alpha(c, a, () => {
      R(c, 21, 11, 1, 1, WHITE); R(c, 23, 9, 2, 2, WHITE);
      disc(c, 30, 7, 5, WHITE); disc(c, 26, 8, 3, WHITE); disc(c, 34, 8, 3, WHITE);
      const s = st(t, 3, 2);
      STAR.forEach((row, j) => [...row].forEach((ch, i) => {
        if (ch !== "#") return;
        if (j >= 7 - fill) R(c, 27 + i, 4 + j, 1, 1, YEL);
        else if ((i + j + s) % 2 === 0) R(c, 27 + i, 4 + j, 1, 1, DBLUE);
      }));
    });
    if (p < 0.45) {
      bubble(1, p < 0.32 ? 0 : Math.round((p - 0.32) / 0.13 * 7));
      clawd(c, X, Y, { eyes: p < 0.32 ? "closed" : "wide" });
    } else if (p < 0.5) {
      const q = (p - 0.45) / 0.05;
      for (let i = 0; i < 8; i++) { const a = i * Math.PI / 4; R(c, 30 + Math.cos(a) * (4 + q * 6), 7 + Math.sin(a) * (3 + q * 5), 1, 1, WHITE); }
      glyph(c, STAR, 27, 4, YEL);
      clawd(c, X, Y, { eyes: "wide", armL: "up", armR: "up" });
    } else {
      const q = cl((p - 0.5) / 0.12), sx = Math.round(27 + (X + 5 - 27) * ease(q)), sy = Math.round(4 - Math.sin(q * Math.PI) * 3) - (q >= 1 ? Math.round(Math.sin(t * 4)) : 0);
      const out = p > 0.88 ? (p - 0.88) / 0.12 : 0;
      alpha(c, 1 - out, () => {
        glyph(c, STAR, sx, sy, YEL);
        if (q >= 1 && st(t, 5, 2)) { R(c, sx + 3, sy + 2, 1, 1, WHITE); R(c, sx - 2, sy + 1, 1, 1, YEL); R(c, sx + 9, sy + 4, 1, 1, YEL); }
      });
      if (out > 0) bubble(out, 0);
      clawd(c, X, Y, { eyes: "happy", armL: "up", armR: "up" });
    }
  });

  /* ---------- Effecting: a sound-effects pad — each button sets off a POW, a BOING or a ZAP ---------- */
  const BOLT = ["..####", ".####.", ".###..", "######", "..###.", ".###..", ".##...", "##....", "#....."];
  defNew("w-effecting", "Effecting", "words", "Effecting…", (c, t) => {
    const p = (t % 4.2) / 4.2, seg = Math.floor(p * 3), q = (p * 3) % 1, X = 3, Y = Y0;
    const BX = [25, 29, 33], BC = [RED, YEL, BLUE];
    if (seg === 2 && ((q > 0.12 && q < 0.18) || (q > 0.3 && q < 0.34))) alpha(c, 0.25, () => R(c, 0, 0, SW, SH, WHITE));
    const fx = q < 0.12 ? 0 : q > 0.85 ? 1 - (q - 0.85) / 0.15 : 1;
    if (q >= 0.12) alpha(c, fx, () => {
      if (seg === 0) {
        const j = st(t, 12, 2);
        glyph(c, BURST, 26 + j, 4, st(t, 8, 2) ? RED : ORG); R(c, 29 + j, 7, 3, 3, YEL); R(c, 30 + j, 8, 1, 1, WHITE);
      } else if (seg === 1) {
        const ext = Math.round(4 + Math.abs(Math.sin(q * 16)) * 7 * (1 - q)), top = 16 - ext;
        for (let y = 16; y > top; y--) R(c, 29 + ((16 - y) % 2 ? 2 : 0), y, 2, 1, METAL);
        disc(c, 30, top - 2, 2, PINK); R(c, 29, top - 3, 1, 1, WHITE);
      } else {
        glyph(c, BOLT, 28, 5, st(t, 10, 2) ? YEL : WHITE);
        glyph(c, G.cloud, 26, 1, GREY); glyph(c, G.cloud, 30, 2, GREY);
      }
    });
    R(c, 23, 18, 14, 4, DARK); R(c, 23, 18, 14, 1, MGREY);
    const pressed = q > 0.08 && q < 0.25;
    BX.forEach((bx, i) => R(c, bx, i === seg && pressed ? 20 : 19, 3, i === seg && pressed ? 1 : 2, BC[i]));
    const lift = q < 0.1 ? (1 - q / 0.1) * 3 : q < 0.25 ? 0 : Math.min(3, (q - 0.25) * 10);
    clawd(c, X, Y, { eyes: q > 0.15 ? "happy" : "right", armR: "none" });
    reach(c, X + 14, Y + 4, BX[seg] + 1, 18 - Math.round(lift) - 1);
  });

  /* ---------- Bootstrapping: hauls on his own bootstraps, lifts off… then realises and drops ---------- */
  defNew("w-bootstrapping", "Bootstrapping", "words", "Bootstrapping…", (c, t) => {
    const p = (t % 4) / 4, X = X0;
    let h = 0, sq = 0, eyes = "closed", jit = 0;
    if (p < 0.2) { sq = 1; jit = p > 0.08 ? st(t, 14, 2) : 0; }
    else if (p < 0.45) { h = ease((p - 0.2) / 0.25) * 5; jit = st(t, 10, 2); }
    else if (p < 0.7) { h = 5 + Math.round(Math.sin(t * 6) * 0.6); eyes = p < 0.58 ? "closed" : p < 0.64 ? "down" : "wide"; }
    else if (p < 0.78) { const q = (p - 0.7) / 0.08; h = 5 * (1 - q * q); eyes = "wide"; }
    else if (p < 0.88) { sq = p < 0.82 ? 3 : 1; eyes = "x"; }
    else eyes = "open";
    const y = Math.round(Y0 - h), x = X + jit;
    if (h > 0.5) R(c, X + 3, 22, 10, 1, MGREY);
    clawd(c, x, y, { eyes, armL: "up", armR: "up", squash: sq });
    const ty = y + sq;
    line(c, x + 1, ty - 1, x + 3, y + 8, "#C9A26B"); line(c, x + 14, ty - 1, x + 12, y + 8, "#C9A26B");
    R(c, x + 2, y + 8, 5, 2, BROWN); R(c, x + 9, y + 8, 5, 2, BROWN); R(c, x + 7, y + 9, 1, 1, BROWN); R(c, x + 14, y + 9, 1, 1, BROWN);
    if (p > 0.2 && p < 0.6) { const q = (t * 1.5) % 1; alpha(c, 1 - q, () => R(c, x + 16 + q * 3, ty + 1 + q * 5, 1, 1, BLUE)); }
    if (p >= 0.78 && p < 0.86) { const q = (p - 0.78) / 0.08; alpha(c, 1 - q, () => { R(c, X - 2 - q * 4, 21, 2, 1, GREY); R(c, X + 16 + q * 4, 21, 2, 1, GREY); }); }
    if (p >= 0.78 && p < 0.9) [[X + 3, Y0 - 3], [X + 11, Y0 - 4]].forEach(([sx, sy], i) => { if (st(t + i * 0.1, 6, 2)) glyph(c, G.star, sx, sy, YEL); });
  });

  /* ---------- Forging: heats a sword in the forge until it glows, swings it over and quenches it ---------- */
  function sword(c, gx, gy, dir, col) {
    gx = Math.round(gx); gy = Math.round(gy);
    R(c, gx, gy, 2, 1, WOOD);
    R(c, dir < 0 ? gx - 1 : gx + 2, gy - 1, 1, 3, METAL);
    R(c, dir < 0 ? gx - 8 : gx + 3, gy, 7, 1, col);
  }
  defNew("w-forging", "Forging", "words", "Forging…", (c, t) => {
    const p = (t % 5) / 5, X = 12, Y = Y0;
    const HEAT = [GREY, RED, ORG, YEL];
    R(c, 0, 15, 10, 7, "#993C1D"); R(c, 0, 17, 10, 1, "#5f3a1e"); R(c, 0, 19, 10, 1, "#5f3a1e");
    [[3, 15], [7, 15], [1, 18], [5, 18], [8, 20], [3, 20]].forEach(([x, y]) => R(c, x, y, 1, 2, "#5f3a1e"));
    R(c, 1, 14, 8, 1, "#5f3a1e");
    const fn = Math.floor(t * 8);
    for (let i = 0; i < 4; i++) { const h = 2 + Math.floor(rnd(i + fn * 4) * 3); R(c, 1 + i * 2, 14 - h, 2, h, RED); R(c, 1 + i * 2, 15 - Math.ceil(h / 2), 1, Math.ceil(h / 2) - 1, ORG); }
    for (let i = 0; i < 2; i++) { const q = (t * 1.3 + i / 2) % 1; alpha(c, 1 - q, () => R(c, 3 + i * 3 + Math.sin(q * 9) , 10 - q * 8, 1, 1, YEL)); }
    let gx, gy, dir, col, armL = "out", armR = "out", eyes = "left";
    if (p < 0.42) { gx = 10; gy = 13; dir = -1; col = HEAT[Math.min(3, Math.floor(p / 0.42 * 4))]; armL = "up"; }
    else if (p < 0.55) { const q = ease((p - 0.42) / 0.13); gx = 10 + q * 18; gy = 13 - Math.sin(q * Math.PI) * 10; dir = q < 0.5 ? -1 : 1; col = YEL; armL = armR = "up"; eyes = "up"; }
    else if (p < 0.85) { gx = 28; gy = 13 + Math.round(p < 0.6 ? ease((p - 0.55) / 0.05) * 3 : p < 0.7 ? 3 : 3 - ease((p - 0.7) / 0.05) * 3); dir = 1; col = p < 0.6 ? YEL : METAL; armR = "up"; eyes = p < 0.7 ? "right" : "happy"; }
    else { const q = ease((p - 0.85) / 0.15); gx = 28 - q * 18; gy = 13 - Math.sin(q * Math.PI) * 10; dir = q < 0.5 ? 1 : -1; col = GREY; armL = armR = "up"; eyes = "up"; }
    clawd(c, X, Y, { eyes, armL, armR });
    if (col === YEL || col === ORG) alpha(c, 0.3 + st(t, 6, 2) * 0.2, () => R(c, dir < 0 ? gx - 9 : gx + 2, gy - 1, 9, 3, ORG));
    sword(c, gx, gy, dir, col);
    if (p > 0.72 && p < 0.85 && st(t, 5, 2)) R(c, Math.round(gx) + 4 + Math.floor(((p - 0.72) / 0.13) * 6), gy, 1, 1, WHITE);
    R(c, 31, 16, 7, 6, WOOD); R(c, 31, 17, 7, 1, BROWN); R(c, 31, 20, 7, 1, BROWN); R(c, 32, 16, 5, 1, BLUE);
    if (p > 0.58 && p < 0.9) for (let i = 0; i < 3; i++) { const q = ((p - 0.58) * 6 + i / 3) % 1; alpha(c, (1 - q) * (p < 0.82 ? 1 : (0.9 - p) / 0.08), () => glyph(c, G.puff, 31 + i * 2 + Math.sin(q * 6), 13 - q * 10, WHITE)); }
  });

  /* ---------- Forming: shapes a lump of clay into a vase on a potter's wheel — then it slumps ---------- */
  const VASE = [6, 8, 9, 9, 8, 6, 4, 4, 6], LUMP = [9, 9, 7];
  defNew("w-forming", "Forming", "words", "Forming…", (c, t) => {
    const p = (t % 5) / 5, X = 5, Y = Y0, cx = 28, CLAY = "#b8644a";
    R(c, 24, 17, 9, 5, DARK); R(c, 23, 17, 11, 1, MGREY);
    R(c, 21, 16, 15, 1, METAL);
    for (let k = 0; k < 3; k++) R(c, 21 + Math.floor((t * 20 + k * 5) % 15), 16, 1, 1, MGREY);
    let s = 0, lean = 0;
    if (p < 0.12) s = 0;
    else if (p < 0.55) s = ease((p - 0.12) / 0.43);
    else if (p < 0.8) s = 1;
    else if (p < 0.88) { s = 1; lean = Math.sin((p - 0.8) / 0.08 * Math.PI * 3) * (p - 0.8) / 0.08; }
    else if (p < 0.94) s = 1 - ease((p - 0.88) / 0.06);
    const h = Math.round(3 + 6 * s);
    let midL = cx;
    for (let r = 0; r < h; r++) {
      const u = h === 1 ? 0 : r / (h - 1), vw = VASE[Math.round(u * 8)], lw = LUMP[Math.round(u * 2)];
      const w = Math.round(lw + (vw - lw) * s), x = cx - Math.floor(w / 2) + Math.round(lean * r * 0.3);
      R(c, x, 15 - r, w, 1, CLAY);
      R(c, x + Math.floor((t * 10 + r * 1.7) % w), 15 - r, 1, 1, "#993C1D");
      if (r === Math.floor(h / 2)) midL = x;
    }
    const shaping = p < 0.55 || p > 0.94;
    clawd(c, X, Y, { eyes: p < 0.55 || p > 0.94 ? "right" : p < 0.8 ? "happy" : p < 0.9 ? "wide" : "closed", armR: shaping ? "none" : "out" });
    if (shaping) reach(c, X + 14, Y + 4, midL - 1, 15 - Math.floor(h / 2));
    if (p > 0.6 && p < 0.78 && st(t, 4, 2)) glyph(c, G.star, cx + 6, 6, YEL);
  });

  /* ---------- Gitifying: stamps commits onto a scrolling git graph that branches and merges ---------- */
  const GPAT = [0, 0, 1, 1, 1, 0, 0, 0], LX = [25, 32];
  defNew("w-gitifying", "Gitifying", "words", "Gitifying…", (c, t) => {
    const X = 1, Y = Y0, n = t / 0.5, top = Math.floor(n);
    const lane = i => GPAT[((i % 8) + 8) % 8], gy = i => Math.round(19 - (n - i) * 4);
    R(c, LX[0], 0, 1, gy(top) + 1, DBLUE);
    for (let i = top - 7; i <= top; i++) {
      const a = lane(i - 1), b = lane(i);
      if (a || b) line(c, LX[a], gy(i - 1), LX[b], gy(i), GREEN);
    }
    for (let i = top - 7; i <= top; i++) {
      const x = LX[lane(i)], y = gy(i), col = lane(i) ? GREEN : DBLUE;
      glyph(c, [".#.", "###", ".#."], x - 1, y - 1, col); R(c, x, y, 1, 1, WHITE);
      if (!lane(i) && lane(i - 1)) { R(c, x - 2, y, 1, 1, col); R(c, x + 2, y, 1, 1, col); }
    }
    const age = n - top, x = LX[lane(top)], y = gy(top);
    if (age < 0.2) [[-3, 0], [3, 0], [0, -3], [0, 3]].forEach(([dx, dy]) => R(c, x + dx, y + dy, 1, 1, YEL));
    const press = age < 0.12 ? 0 : Math.min(3, (age - 0.12) * 12), sy = Math.round(y - 3 - press);
    clawd(c, X, Y, { eyes: "right", armR: "none", squash: age < 0.1 ? 1 : 0 });
    reach(c, X + 14, Y + 4, x - 2, sy - 3);
    R(c, x - 1, sy - 4, 3, 1, WOOD); R(c, x, sy - 3, 1, 2, WOOD); R(c, x - 1, sy - 1, 3, 1, RED);
  });

  /* ---------- Puttering: putts a golf ball across the green into the hole ---------- */
  defNew("w-puttering", "Puttering", "words", "Puttering…", (c, t) => {
    const p = (t % 4.5) / 4.5, X = 1;
    R(c, 0, 22, 40, 2, DGREEN); R(c, 33, 22, 3, 1, "#173404");
    R(c, 34, 7, 1, 15, METAL); glyph(c, st(t, 3, 2) ? ["###.", "####", "##.."] : ["##..", "####", "###."], 35, 7, RED);
    let hx = 18, y = Y0, eyes = "down", armL = "out";
    if (p < 0.05) hx = 18;
    else if (p < 0.24) hx = 18 - Math.round(ease((p - 0.05) / 0.19) * 4);
    else if (p < 0.27) hx = 14 + Math.round((p - 0.24) / 0.03 * 7);
    else if (p < 0.4) { hx = 21 - Math.round(ease((p - 0.27) / 0.13) * 3); eyes = "right"; }
    else eyes = "right";
    if (p > 0.66 && p < 0.86) { const q = (p - 0.66) / 0.2; y = Y0 - Math.round(Math.abs(Math.sin(q * Math.PI * 2)) * 3); eyes = "happy"; armL = "up"; }
    clawd(c, X, y, { eyes, armL, armR: "down" });
    line(c, X + 15, y + 7, hx, y + 9, GREY); R(c, hx - 1, y + 9, 3, 1, METAL);
    let bx = 20, by = 20, show = true, a = 1;
    if (p >= 0.27 && p < 0.62) { const q = (p - 0.27) / 0.35; bx = 20 + 13 * (1 - (1 - q) * (1 - q)); }
    else if (p >= 0.62 && p < 0.66) { bx = 33; by = 21; }
    else if (p >= 0.66 && p < 0.84) show = false;
    else if (p >= 0.84) { const q = (p - 0.84) / 0.16; by = 20 - Math.round(Math.abs(Math.cos(q * Math.PI * 2.5)) * (1 - q) * 8); a = cl(q * 4); }
    if (show) alpha(c, a, () => R(c, bx, by, 2, 2, WHITE));
    if (p >= 0.62 && p < 0.66) R(c, 33, 22, 3, 1, "#173404");
    if (p > 0.66 && p < 0.82 && st(t, 5, 2)) glyph(c, G.star, 33, 17, YEL);
  });

  /* ---------- Deciphering: turns a cipher wheel until the scrambled note reads "HI!" ---------- */
  const LET = [["#.#", "#.#", "###", "#.#", "#.#"], ["###", ".#.", ".#.", ".#.", "###"], G.bang];
  defNew("w-deciphering", "Deciphering", "words", "Deciphering…", (c, t) => {
    const P = 5, p = (t % P) / P, X = 0, Y = Y0, S = [0.18, 0.36, 0.54];
    R(c, 22, 6, 17, 10, WHITE); R(c, 22, 6, 17, 1, GLASS);
    const LXs = [25, 30, 35];
    LET.forEach((g, k) => {
      const solved = p >= S[k] && p < 0.9;
      if (solved) {
        const bob = p > 0.6 && st(t + k * 0.15, 4, 2) ? 1 : 0;
        glyph(c, g, LXs[k], 8 - bob, p - S[k] < 0.04 ? RED : NAVY);
      } else {
        const seed = Math.floor(t * 12) * 7 + k * 31;
        for (let j = 0; j < 5; j++) for (let i = 0; i < 3; i++) if (rnd(seed + i * 3 + j * 11) > 0.5) R(c, LXs[k] + i, 8 + j, 1, 1, GREY);
      }
    });
    // the wheel spins between solves; its total turn per loop is a whole number of tick steps, so the loop is seamless
    const spin = q => q - S.reduce((s, a) => s + Math.max(0, Math.min(0.05, q - a)), 0) - Math.max(0, Math.min(0.31, q - 0.59));
    const tot = spin(1), a = spin(p) / tot * Math.PI * 2 * 2;
    disc(c, 17, 17, 4, METAL); disc(c, 17, 17, 3, WHITE);
    for (let k = 0; k < 5; k++) { const b = a + k * 2 * Math.PI / 5; line(c, 17, 17, 17 + Math.cos(b) * 2.6, 17 + Math.sin(b) * 2.6, k ? GREY : RED); }
    R(c, 17, 17, 1, 1, DARK); R(c, 17, 12, 1, 1, RED);
    const solvedAll = p > 0.59 && p < 0.9;
    clawd(c, X, Y, { eyes: solvedAll ? "happy" : "right", armL: solvedAll ? "up" : "out" });
  });

  /* ---------- Newspapering: the paper gets thrown at his head, he reads the broadsheet, then tosses it ---------- */
  const roll = (c, x, y) => { R(c, x, y, 5, 2, WHITE); R(c, x + 2, y, 1, 2, RED); };
  defNew("w-newspapering", "Newspapering", "words", "Newspapering…", (c, t) => {
    const p = (t % 5.5) / 5.5, X = X0, Y = Y0;
    if (p < 0.14) {
      const q = p / 0.14;
      clawd(c, X, Y, { eyes: "left" });
      roll(c, 40 - q * (40 - (X + 6)), 3 + q * (Y - 5) - Math.sin(q * Math.PI) * 3);
    } else if (p < 0.36) {
      const q = cl((p - 0.14) / 0.12), bonk = p < 0.22;
      clawd(c, X, Y, { eyes: bonk ? "x" : "down", squash: p < 0.18 ? 2 : 0, armR: p > 0.3 ? "down" : "out" });
      if (bonk) [[X + 2, Y - 4], [X + 12, Y - 5]].forEach(([sx, sy], i) => { if (st(t + i * 0.1, 8, 2)) glyph(c, G.star, sx, sy, YEL); });
      roll(c, X + 6 + q * 11, Y - 3 - Math.sin(q * Math.PI) * 5 + q * (20 - (Y - 3)));
    } else if (p < 0.86) {
      const look = st(t, 1.6, 2) ? "right" : "left";
      clawd(c, X, Y, { eyes: p > 0.72 && p < 0.78 ? "wide" : look, armL: "none", armR: "none" });
      const px = X - 2, py = Y + 4;
      R(c, px, py, 20, 7, WHITE);
      R(c, px + 1, py + 1, 18, 1, DARK);
      R(c, px + 1, py + 3, 7, 1, MGREY); R(c, px + 1, py + 5, 6, 1, GREY);
      R(c, px + 11, py + 3, 7, 3, GREY); R(c, px + 13, py + 4, 3, 1, CL); R(c, px + 13, py + 4, 1, 1, CL);
      R(c, px + 10, py, 1, 7, GLASS);
      if (p > 0.6 && p < 0.68) {
        const q = (p - 0.6) / 0.08, w = Math.round(10 * Math.abs(1 - 2 * q));
        R(c, q < 0.5 ? px + 10 : px + 10 - w, py, w, 7, GLASS);
      }
      R(c, px - 1, py + 2, 2, 2, CL); R(c, px + 19, py + 2, 2, 2, CL);
      if (p > 0.72 && p < 0.8) glyph(c, G.bang, X + 18, Y - 3, YEL);
    } else {
      const q = (p - 0.86) / 0.14;
      clawd(c, X, Y, { eyes: "left", armL: q < 0.3 ? "up" : "out" });
      roll(c, X - q * 22, Y + 2 - Math.sin(q * Math.PI) * 10 - q * 6);
    }
  });

  /* ---------- Herding: walks behind his sheep with a crook and nudges the stray one back in line ---------- */
  function sheep(c, x, y, dir, f) {
    x = Math.round(x); y = Math.round(y);
    glyph(c, [".#####.", "#######", "#######", ".#####."], x, y, WHITE);
    R(c, dir > 0 ? x + 6 : x - 1, y + 1, 2, 3, DARK); R(c, dir > 0 ? x + 7 : x - 1, y + 1, 1, 1, WHITE);
    R(c, x + 1, y + 4, 1, f ? 1 : 2, DARK); R(c, x + 5, y + 4, 1, f ? 2 : 1, DARK);
  }
  defNew("w-herding", "Herding", "words", "Herding…", (c, t) => {
    const p = (t % 4) / 4, X = 0, f = st(t, 6, 2), Y = Y0 - f;
    for (let i = 0; i < 5; i++) { const x = Math.round(((i * 8 + 3 - t * 10) % 40 + 40) % 40); R(c, x, 21, 1, 1, DGREEN); R(c, x + 1, 20, 1, 2, DGREEN); R(c, x + 2, 21, 1, 1, DGREEN); }
    sheep(c, 32, 16 - st(t + 0.15, 6, 2), 1, st(t + 0.15, 6, 2));
    let sx = 24, dir = 1, sf = st(t + 0.3, 6, 2), sy = 16 - sf;
    if (p >= 0.1 && p < 0.35) { sx = 24 - ease((p - 0.1) / 0.25) * 6; dir = -1; }
    else if (p >= 0.35 && p < 0.47) { sx = 18; dir = -1; sf = 0; sy = 16; }
    else if (p >= 0.47 && p < 0.6) { const q = (p - 0.47) / 0.13; sx = 18 + ease(q) * 6; sy = 16 - Math.round(Math.sin(q * Math.PI) * 3); for (let i = 1; i < 3; i++) R(c, sx - 2 - i * 3, sy + i, 2, 1, MGREY); }
    sheep(c, sx, sy, dir, sf);
    if (p > 0.4 && p < 0.5) glyph(c, G.bang, Math.round(sx) + 3, 9, YEL);
    const nudge = p > 0.38 && p < 0.48;
    clawd(c, X, Y, { eyes: nudge ? "right" : p > 0.12 && p < 0.38 ? "right" : "happy", legs: f + 1, armR: "up" });
    const top = nudge ? [X + 20, Y - 3] : [X + 16, Y - 4];
    line(c, X + 15, 21, top[0], top[1], WOOD);
    R(c, top[0], top[1] - 1, 3, 1, WOOD); R(c, top[0] + 2, top[1], 1, 2, WOOD);
  });
})();


/* ---- word batch: nature ---- */
/* =====================================================================
   Word batch — nature, weather, water, swirling and leading-a-group words
   ===================================================================== */
(() => {
  const cl = k => Math.max(0, Math.min(1, k));
  const ease = k => { k = cl(k); return k * k * (3 - 2 * k); };
  const lerp = (a, b, k) => a + (b - a) * k;
  function ell(c, cx, cy, rx, ry, col, n, off = 0) {          // dotted ellipse outline
    for (let i = 0; i < n; i++) { const a = off + i / n * Math.PI * 2; R(c, cx + Math.cos(a) * rx, cy + Math.sin(a) * ry, 1, 1, col); }
  }
  const PINK = "#ED93B1", DPINK = "#D4537E", RED = "#E24B4A", YEL = "#FAC775", ORG = "#EF9F27", BLUE = "#378ADD",
        LBLUE = "#85B7EB", DBLUE = "#185FA5", LEAF = "#97C459", STEM = "#639922", SOIL = "#854F0B", DSOIL = "#6b4423",
        PURP = "#7F77DD", DPURP = "#534AB7", GREY = "#888780", DGREY = "#5f5e5a";

  /* ---------- leading a group ---------- */

  defNew("w-mustering", "Mustering", "words", "Mustering…", (c, t) => {
    // Sergeant Clawd blows the whistle; three helpers march in and fall in line, hop to attention, then march off.
    const p = (t % 5) / 5, X = 0, Y = Y0, slots = [18, 25, 32];
    let blowing = p > 0.85 && p < 0.9;
    slots.forEach((sx, i) => {
      const s = 0.05 + i * 0.15;
      let x = 44, walk = false;
      if (p >= s && p < s + 0.15) { x = 42 - (42 - sx) * ((p - s) / 0.15); walk = true; } else if (p >= s + 0.15) x = sx;
      if (p >= s && p < s + 0.06) blowing = true;
      if (p > 0.85) { x = sx + (p - 0.85) / 0.15 * 26; walk = true; }
      const hop = p > 0.68 && p < 0.84 && st(t, 4, 2) ? 1 : 0;
      if (x < 41) mini(c, Math.round(x), 17 - hop, walk ? st(t + i * 0.1, 6, 2) : 0);
    });
    const salute = p > 0.66 && p < 0.84;
    clawd(c, X, Y, { eyes: salute ? "happy" : "right", armR: salute ? "up" : "down" });
    R(c, X + 3, Y - 3, 10, 3, STEM); R(c, X + 9, Y - 1, 7, 1, "#3B6D11"); R(c, X + 6, Y - 2, 1, 1, YEL);   // drill cap
    R(c, X + 12, Y + 5, 4, 1, METAL);                                                                     // whistle
    if (blowing && st(t, 10, 2)) { R(c, X + 17, Y + 3, 2, 1, WHITE); R(c, X + 17, Y + 7, 2, 1, WHITE); R(c, X + 18, Y + 5, 2, 1, WHITE); }
  });

  defNew("w-orchestrating", "Orchestrating", "words", "Orchestrating…", (c, t) => {
    // Conductor Clawd points the baton at each player on the risers in turn; each one bobs and plays a note of its colour.
    const X = 0, Y = Y0, beat = t * 2.4, k = Math.floor(beat) % 3, ph = beat % 1;
    R(c, 25, 18, 8, 4, WOOD); R(c, 25, 18, 8, 1, "#BA7517"); R(c, 33, 13, 7, 9, WOOD); R(c, 33, 13, 7, 1, "#BA7517");
    const pos = [[17, 17], [25, 13], [32, 8]], cols = [YEL, LBLUE, PINK];
    pos.forEach(([mx, my], i) => {
      const on = i === k && ph < 0.5;
      mini(c, mx, my - (on ? 1 : 0), 0);
      R(c, mx + 3, my + 3 - (on ? 1 : 0), 2, 1, cols[i]);                                   // a coloured bow tie
      const q = (((beat - i) % 3) + 3) % 3;                                                   // beats since its cue
      if (q < 1.2) alpha(c, Math.min(1, (1.2 - q) * 2), () => glyph(c, G.note, mx + 2 + Math.round(Math.sin(q * 5)), my - 6 - Math.round(q * 2), cols[i]));
    });
    const hand = [X + 16, Y - 1], [tx, ty] = [pos[k][0] + 4, pos[k][1] + 1];
    const dx = tx - hand[0], dy = ty - hand[1] - (ph < 0.25 ? 4 : 0), d = Math.hypot(dx, dy);
    line(c, hand[0], hand[1], hand[0] + dx / d * 5, hand[1] + dy / d * 5, WHITE);
    clawd(c, X, Y - (ph < 0.25 ? 1 : 0), { eyes: k === 2 ? "up" : "right", armR: "up", armL: st(t, 2.4, 2) ? "up" : "out" });
  });

  function sheep(c, x, y, faceR, f) {
    glyph(c, [".#.#.#.", "#######", "#######", ".#####."], x, y, WHITE);
    const hx = faceR ? x + 6 : x - 1;
    R(c, hx, y, 2, 3, INK); R(c, faceR ? hx + 1 : hx, y + 1, 1, 1, WHITE);
    R(c, x + 1, y + 4, 1, f ? 1 : 2, INK); R(c, x + 5, y + 4, 1, f ? 2 : 1, INK);
  }
  defNew("w-wrangling", "Wrangling", "words", "Wrangling…", (c, t) => {
    // Cowboy Clawd twirls a lasso, ropes a runaway sheep, and digs his heels in while it tugs.
    const p = (t % 4) / 4, ROPE = "#BA7517", Y = Y0;
    const r = p < 0.5 ? p : p < 0.9 ? 0.5 : p - 0.4, run = 2 * Math.PI * r / 0.6 * 2;
    const caught = p >= 0.5 && p < 0.9, tug = caught ? Math.round(Math.sin(t * 14)) : 0;
    const sx = Math.round(29 + Math.sin(run) * 4) + tug, sy = 16;
    const catchX = Math.round(29 + Math.sin(2 * Math.PI * (0.5 / 0.6) * 2) * 4);
    sheep(c, sx, sy, caught ? true : Math.cos(run) > 0, caught ? st(t, 10, 2) : st(t, 8, 2));
    const X = 1 - (caught ? st(t, 5, 2) : 0);
    const over = [X + 15, Y - 8], target = [catchX + 3, sy + 1];
    let armR = "up";
    if (p < 0.35 || p >= 0.9) {                                              // twirling overhead
      const rx = 3 + Math.round(Math.abs(Math.cos(t * 9)) * 2);
      line(c, X + 15, Y - 1, over[0], over[1] + 1, ROPE); ell(c, over[0], over[1], rx, 1.5, ROPE, 28, t * 9);
    } else if (p < 0.5 || p >= 0.85) {                                       // flying out or coming back
      const q = p < 0.5 ? (p - 0.35) / 0.15 : 1 - (p - 0.85) / 0.05;
      const lx = lerp(over[0], target[0], q), ly = lerp(over[1], target[1], q) - Math.sin(q * Math.PI) * 4;
      armR = q > 0.3 ? "out" : "up";
      line(c, X + 16, armR === "up" ? Y - 1 : Y + 4, lx - 3, ly, ROPE); ell(c, lx, ly, 3.5, 1.2, ROPE, 24);
    } else {                                                                 // got it: rope pulled tight
      armR = "out";
      line(c, X + 16, Y + 4, sx + 2, sy + 1, ROPE); ell(c, sx + 3, sy + 1, 3, 1, ROPE, 20);
    }
    clawd(c, X, Y, { eyes: caught ? (p > 0.75 ? "happy" : "closed") : "right", armR, legs: caught ? st(t, 5, 2) + 1 : 0 });
    cowboyHat(c, X, Y);
  });

  /* ---------- growing things ---------- */

  defNew("w-cultivating", "Cultivating", "words", "Cultivating…", (c, t) => {
    // He walks along hoeing; tidy furrows slide out behind him and sprouts come up in them.
    const X = 12, Y = Y0, off = t * 4, hx = 32, down = st(t, 2.5, 2);
    R(c, 0, 22, 40, 4, SOIL); R(c, 0, 22, hx, 1, DSOIL);
    for (let i = -1; i < 12; i++) {
      const mx = Math.round(i * 4 - (off % 4));
      if (mx > hx - 3) continue;
      R(c, mx, 21, 3, 1, SOIL);
      const d = hx - mx;
      if (d > 10) { const h = d > 20 ? 2 : 1; R(c, mx + 1, 21 - h, 1, h, STEM); if (d > 20) { R(c, mx, 19, 1, 1, LEAF); R(c, mx + 2, 19, 1, 1, LEAF); } }
    }
    for (let j = 0; j < 6; j++) { const px = Math.round(((j * 9 + 5 - off) % 45 + 45) % 45); if (px > hx + 1 && px < 40) R(c, px, 21, 1, 1, DGREY); }
    clawd(c, X, Y, { eyes: "right", legs: st(t, 3, 2) + 1 });
    if (down) {
      line(c, X + 16, Y + 4, hx + 1, 20, WOOD); R(c, hx - 1, 21, 3, 1, METAL);
      for (let i = 0; i < 3; i++) { const q = ((t * 2.5) % 1); R(c, hx - 2 - i * 2 - q * 3, 20 - Math.sin(q * Math.PI) * (3 + i), 1, 1, DSOIL); }
    } else {
      line(c, X + 16, Y + 4, hx + 3, Y - 2, WOOD); R(c, hx + 3, Y - 3, 1, 3, METAL);
    }
  });

  defNew("w-germinating", "Germinating", "words", "Germinating…", (c, t) => {
    // Clawd is the seed: asleep underground, a sprout pushes up from his head and unfolds its leaves, and he wakes up beaming.
    const p = (t % 5) / 5, X = 12, Y = 15;
    R(c, 0, 13, 40, 13, SOIL); R(c, 0, 13, 40, 1, STEM);
    [[3, 17], [7, 23], [33, 16], [36, 22], [30, 24], [5, 20]].forEach(([x, y]) => R(c, x, y, 2, 1, DSOIL));
    R(c, X + 1, Y - 1, 14, 10, "#5f3a1e");
    const g = p < 0.55 ? ease(p / 0.55) : p < 0.9 ? 1 : 1 - ease((p - 0.9) / 0.1);
    const h = Math.round(g * 10);
    if (h > 0) R(c, X + 7, Y - h, 1, h, STEM);
    if (h >= 5) { R(c, X + 5, Y - h + 1, 2, 1, LEAF); R(c, X + 8, Y - h + 1, 2, 1, LEAF); }
    if (h >= 8) { R(c, X + 3, Y - h + 2, 4, 1, LEAF); R(c, X + 8, Y - h + 2, 4, 1, LEAF); R(c, X + 4, Y - h + 1, 1, 1, LEAF); R(c, X + 11, Y - h + 1, 1, 1, LEAF); }
    const rl = Math.round(g * 3);
    [4, 8, 11].forEach((dx, i) => { if (rl > 0) R(c, X + dx + (i - 1) * Math.min(1, rl - 1), Y + 9, 1, rl, "#C9A26B"); });
    const awake = p > 0.42 && p < 0.92;
    clawd(c, X, Y, { eyes: !awake ? "closed" : p < 0.55 ? "up" : "happy", legs: "none", armL: "down", armR: "down" });
    if (!awake && st(t, 1.5, 2)) glyph(c, G.z, X + 17, Y + 1, GREY);
    glyph(c, [".####.", "######", "######", "######", ".####."], 32, 2, YEL);
    if (g > 0.9 && st(t, 4, 2)) { R(c, 30, 4, 1, 1, YEL); R(c, 39, 4, 1, 1, YEL); R(c, 34, 0, 2, 1, YEL); R(c, 34, 8, 2, 1, YEL); }
  });

  defNew("w-pollinating", "Pollinating", "words", "Pollinating…", (c, t) => {
    // Clawd in bee stripes, antennae and buzzing wings, hops flower to flower dusting pollen.
    const fl = [[8, PINK], [20, PURP], [32, "#F0997B"]], route = [0, 1, 2, 1], LEG = 1.1;
    const n = Math.floor(t / LEG), q = (t % LEG) / LEG, from = route[n % 4], to = route[(n + 1) % 4];
    const dwell = q < 0.4, k = dwell ? 0 : ease((q - 0.4) / 0.6);
    const x = Math.round(lerp(fl[from][0], fl[to][0], k)) - 8, y = Math.round(6 - Math.sin(k * Math.PI) * 4) + (dwell ? st(t, 6, 2) : 0);
    fl.forEach(([cx, col], i) => {
      const visited = dwell && i === from;
      R(c, cx, 20, 1, 2, STEM); R(c, cx + 1, 21, 2, 1, LEAF);
      glyph(c, [".#.#.", "#####", "##.##", "#####", ".#.#."], cx - 2, 15 + (visited ? 1 : 0), col);
      R(c, cx, 17 + (visited ? 1 : 0), 1, 1, YEL);
      if (visited) for (let j = 0; j < 4; j++) { const a = t * 3 + j * 1.6, r = 3 + (t * 4 + j) % 3; R(c, cx + Math.cos(a) * r, 16 + Math.sin(a) * r * 0.6, 1, 1, YEL); }
    });
    if (!dwell) for (let j = 1; j < 5; j++) { const kk = ease((q - 0.4 - j * 0.04) / 0.6); if (kk > 0) R(c, lerp(fl[from][0], fl[to][0], kk), 15 - Math.sin(kk * Math.PI) * 4 + j, 1, 1, YEL); }
    const f = st(t, 14, 2);
    alpha(c, 0.85, () => { if (f) { R(c, x + 5, y - 3, 3, 2, WHITE); R(c, x + 8, y - 3, 3, 2, WHITE); } else { R(c, x + 4, y - 1, 3, 1, WHITE); R(c, x + 9, y - 1, 3, 1, WHITE); } });
    clawd(c, x, y, { eyes: dwell ? "happy" : to > from ? "right" : "left", legs: 3, armL: dwell ? "down" : "out", armR: dwell ? "down" : "out" });
    R(c, x + 7, y, 1, 8, INK); R(c, x + 9, y, 1, 8, INK);                     // stripes
    R(c, x + 4, y - 2, 1, 2, INK); R(c, x + 3, y - 3, 1, 1, INK); R(c, x + 11, y - 2, 1, 2, INK); R(c, x + 12, y - 3, 1, 1, INK);
  });

  defNew("w-incubating", "Incubating", "words", "Incubating…", (c, t) => {
    // He sits on a giant egg under a heat lamp; the thermometer climbs until the egg wobbles and he gets excited.
    const p = (t % 5) / 5, wob = p > 0.7 && p < 0.92 ? Math.round(Math.sin(t * 25)) : 0;
    const EGG = ["....######....", "..##########..", ".############.", "##############", "##############", "##############", ".############.", "..##########.."];
    for (let i = 0; i < 3; i++) { const q = (t * 1.5 + i / 3) % 1; alpha(c, 1 - q, () => { R(c, 6 + q * 6, 8 + q * 5, 1, 1, YEL); R(c, 9 + q * 7, 7 + q * 3, 1, 1, YEL); }); }
    R(c, 6, 0, 1, 3, INK); glyph(c, ["..###..", ".#####.", "#######"], 3, 3, DGREY); R(c, 5, 6, 3, 1, st(t, 3, 2) ? YEL : ORG);
    for (let i = 0; i < 2; i++) { const q = (t * 0.8 + i / 2) % 1; alpha(c, 1 - q, () => R(c, (i ? 29 : 10) + Math.round(Math.sin(q * 8)), 18 - q * 8, 1, 2, ORG)); }
    glyph(c, EGG, 13 + wob, 14, WHITE); R(c, 15 + wob, 17, 1, 2, "#ece9e1");
    const excited = p > 0.7 && p < 0.97;
    clawd(c, 12 + wob, 8 - (excited && st(t, 6, 2) ? 1 : 0), { eyes: excited ? (p > 0.8 ? "happy" : "wide") : "closed", legs: "none", armL: "down", armR: "down" });
    const m = p < 0.7 ? Math.round(p / 0.7 * 10) : p < 0.95 ? 10 : Math.round((1 - (p - 0.95) / 0.05) * 10);
    R(c, 35, 6, 3, 13, WHITE); R(c, 36, 7, 1, 11, "#444441"); if (m) R(c, 36, 18 - m, 1, m, RED);
    glyph(c, [".###.", "#####", ".###."], 34, 18, RED);
    [9, 12, 15].forEach(y => R(c, 38, y, 1, 1, GREY));
    if (p > 0.82 && p < 0.97) glyph(c, G.heartS, 30, 4 - Math.round((p - 0.82) * 20), RED);
  });

  defNew("w-nesting", "Nesting", "words", "Nesting…", (c, t) => {
    // Nesting dolls: Clawd's top half lifts off to reveal a smaller Clawd, whose top lifts off to reveal a tiny one.
    const p = (t % 5) / 5, X = X0, Y = Y0, S = Y + 4;
    const L = Math.round(8 * ease(p < 0.5 ? (p - 0.1) / 0.15 : 1 - (p - 0.8) / 0.15));
    const l = L < 8 ? 0 : Math.round(3 * ease(p < 0.5 ? (p - 0.3) / 0.1 : 1 - (p - 0.68) / 0.1));
    if (L > 0) {
      clip(c, 0, Y + 2, 40, S - Y - 2, () => mini(c, X + 4, Y, 0));
      R(c, X + 4, Y + 2, 8, 1, "#b8644a");
      if (l > 0) {
        const b = p > 0.45 && p < 0.62 ? st(t, 6, 2) : 0;
        R(c, X + 6, Y - b, 4, 1, CL); R(c, X + 7, Y - b, 1, 1, EYE); R(c, X + 8, Y - b, 1, 1, EYE); R(c, X + 6, Y + 1 - b, 4, 1, CL);
      }
      clip(c, 0, 0, 40, Y + 2 - l, () => mini(c, X + 4, Y - l, 0));
    }
    clip(c, 0, S, 40, 26 - S, () => clawd(c, X, Y, {}));
    R(c, X + 2, S, 12, 1, "#b8644a");
    clip(c, 0, 0, 40, S - L, () => clawd(c, X, Y - L, { eyes: L > 4 ? "happy" : "open" }));
    if (L > 0 && L < 8 && st(t, 10, 2)) { R(c, X, S - L - 1, 1, 1, WHITE); R(c, X + 15, S - L - 1, 1, 1, WHITE); }
    if (l === 3 && st(t, 3, 2)) glyph(c, G.star, X + 17, Y - 3, YEL);
  });

  defNew("w-unfurling", "Unfurling", "words", "Unfurling…", (c, t) => {
    // He kicks a rolled red carpet, it unrolls across the stage, and he throws a ta-da; then it rolls back up.
    const p = (t % 5) / 5, X = 2, Y = Y0, x0 = 19, x1 = 37;
    const k = ease(p < 0.45 ? (p - 0.1) / 0.35 : 1 - (p - 0.8) / 0.15), rx = Math.round(lerp(x0, x1, k));
    if (rx > x0) { R(c, x0, 20, rx - x0, 2, RED); R(c, x0, 21, rx - x0, 1, "#993C1D"); for (let x = x0 + 1; x < rx; x += 3) R(c, x, 20, 1, 1, YEL); }
    if (k < 0.98) {
      if (k < 0.5) { glyph(c, [".###.", "#####", "#####", "#####", ".###."], rx - 2, 17, RED); R(c, rx, 19, 1, 1, "#993C1D"); R(c, rx - 1, 18, 1, 1, "#993C1D"); }
      else { glyph(c, [".#.", "###", ".#."], rx - 1, 19, RED); R(c, rx, 20, 1, 1, "#993C1D"); }
    } else { R(c, x1, 20, 1, 2, YEL); }
    const kick = p > 0.05 && p < 0.14, tada = p > 0.45 && p < 0.8;
    clawd(c, X, Y, { eyes: tada ? "happy" : "right", legs: kick ? 2 : 0, armL: tada ? "up" : "out", armR: tada ? "up" : "out" });
    if (tada) [[24, 15], [30, 13], [35, 16]].forEach(([x, y], i) => { if ((st(t, 4, 3) + i) % 3) glyph(c, G.star, x, y, i % 2 ? WHITE : YEL); });
  });

  /* ---------- weather and mist ---------- */

  defNew("w-misting", "Misting", "words", "Misting…", (c, t) => {
    // Psst, psst: a spray bottle fills the air with fine mist, and a little rainbow appears in it.
    const p = (t % 5) / 5, X = 1, Y = Y0, PER = 0.8, ox = X + 20, oy = Y + 1;
    const rb = p < 0.25 ? 0 : p < 0.45 ? (p - 0.25) / 0.2 : p < 0.85 ? 1 : (1 - p) / 0.15;
    const bands = [RED, ORG, YEL, LEAF, LBLUE];
    alpha(c, 0.85 * rb, () => bands.forEach((col, i) => { const r = 9 - i; for (let j = 0; j <= r * 4; j++) { const a = j / (r * 4) * Math.PI; R(c, 31 + Math.cos(a) * r, 18 - Math.sin(a) * r * 0.9, 1, 1, col); } }));
    for (let j = 0; j < 3; j++) {
      const age = (t % PER) + j * PER, id = Math.floor(t / PER) - j, d = 17 * (1 - Math.exp(-age * 1.6));
      for (let i = 0; i < 7; i++) {
        const a = (rnd(id * 7 + i) - 0.5) * 0.9, dd = d * (0.6 + rnd(id * 7 + i + 3) * 0.5);
        alpha(c, 1 - age / (PER * 3), () => R(c, ox + Math.cos(a) * dd, oy + Math.sin(a) * dd + age * 1.5, 1, 1, "#B5D4F4"));
      }
    }
    const squeeze = (t % PER) < 0.15;
    clawd(c, X, Y, { eyes: rb > 0.6 ? "happy" : "right" });
    R(c, X + 16, Y + 3, 4, 5, LBLUE); R(c, X + 16, Y + 1, 3, 2, WHITE); R(c, X + 19, Y + 1, 1, 1, WHITE);
    R(c, X + 17, Y + 3, 1, squeeze ? 1 : 2, WHITE);
  });

  defNew("w-nebulizing", "Nebulizing", "words", "Nebulizing…", (c, t) => {
    // Clawd drifts weightless through a slowly swirling pink-and-purple nebula, doing lazy swim strokes.
    for (let i = 0; i < 14; i++) alpha(c, 0.4 + 0.6 * Math.abs(Math.sin(t * 2 + i * 1.7)), () => R(c, Math.round(rnd(i) * 39), Math.round(rnd(i + 20) * 25), 1, 1, WHITE));
    [PURP, PINK, BLUE].forEach((col, b) => {
      const a = t * 0.5 + b * 2.1, bx = 20 + Math.cos(a) * 11, by = 13 + Math.sin(a) * 6;
      alpha(c, 0.26, () => { for (let i = 0; i < 26; i++) { const k = b * 40 + i, r = rnd(k) * 6, an = rnd(k + 9) * 6.28; R(c, bx + Math.cos(an) * r * 1.4, by + Math.sin(an) * r * 0.8, 2, 2, col); } });
    });
    const x = X0 + Math.round(Math.sin(t * 0.9) * 2), y = Y0 - 2 + Math.round(Math.sin(t * 1.3) * 2), sw = st(t, 1.5, 2);
    clawd(c, x, y, { eyes: sw ? "happy" : "up", legs: 3, armL: sw ? "up" : "out", armR: sw ? "out" : "up" });
    if (st(t, 2, 2)) glyph(c, G.star, x + 17, y - 2, YEL); else glyph(c, G.star, x - 4, y + 9, LBLUE);
  });

  defNew("w-billowing", "Billowing", "words", "Billowing…", (c, t) => {
    // Superhero Clawd strikes a pose while a big red cape billows out behind him.
    const X = 17, Y = Y0 - Math.round(Math.abs(Math.sin(t * 1.5)));
    for (let i = 0; i < 6; i++) { const sp = 0.8 + rnd(i) * 0.6, y = 3 + Math.round(rnd(i + 5) * 17), x = 44 - ((t * 30 * sp + rnd(i + 11) * 60) % 60); R(c, x, y, 3, 1, i % 2 ? DGREY : GREY); }
    for (let i = 0; i < 17; i++) {
      const fr = i / 16, wv = Math.sin(t * 7 - i * 0.7) * fr * 2;
      const top = Math.round(Y + 1 - fr * 4 + wv), bot = Math.round(Y + 9 + fr * 1 + wv * 0.5 + Math.sin(t * 5 - i * 0.9) * fr * 1.5);
      R(c, X + 4 - i, top, 1, bot - top, RED); R(c, X + 4 - i, bot - 1, 1, 1, "#993C1D");
    }
    clawd(c, X, Y, { eyes: "right", armL: "down", armR: "up" });
  });

  /* ---------- water ---------- */

  defNew("w-channeling", "Channeling", "words", "Channeling…", (c, t) => {
    // Couch potato Clawd flips TV channels: static, colour bars, a fish, a heart — and himself.
    const X = 1, Y = 10, PER = 0.9, ch = Math.floor(t / PER) % 5, click = (t % PER) < 0.15;
    R(c, 0, 9, 20, 10, DPURP); R(c, 0, 18, 22, 3, PURP); R(c, 19, 15, 3, 6, PURP); R(c, 1, 21, 1, 1, INK); R(c, 20, 21, 1, 1, INK);
    clawd(c, X, Y, { eyes: ch === 4 ? "happy" : ch === 0 ? "wide" : "right", legs: "none", armR: "out" });
    R(c, X + 16, Y + 4, 3, 1, INK); R(c, X + 18, Y + 4, 1, 1, click ? RED : DGREY);
    if (click) [21, 23].forEach(x => R(c, x, Y + 3 - (x - 21) / 2, 1, 1, RED));
    line(c, 30, 7, 27, 2, METAL); line(c, 31, 7, 34, 2, METAL);
    R(c, 23, 7, 16, 13, "#444441"); R(c, 25, 20, 1, 2, INK); R(c, 36, 20, 1, 2, INK);
    R(c, 37, 9, 1, 1, METAL); R(c, 37, 12, 1, 1, METAL);
    const sx = 24, sy = 8, sw = 12, sh = 10;
    if (click) R(c, sx, sy, sw, sh, WHITE);
    else if (ch === 0) { R(c, sx, sy, sw, sh, "#2c2c2a"); const s = Math.floor(t * 12); for (let i = 0; i < 45; i++) R(c, sx + Math.floor(rnd(s * 50 + i) * sw), sy + Math.floor(rnd(s * 50 + i + 99) * sh), 1, 1, i % 2 ? WHITE : GREY); }
    else if (ch === 1) [WHITE, YEL, "#5DCAA5", LEAF, PINK, BLUE].forEach((col, i) => R(c, sx + i * 2, sy, 2, sh, col));
    else if (ch === 2) { R(c, sx, sy, sw, sh, DBLUE); const fx = sx + Math.round(((t * 6) % 18)) - 6; clip(c, sx, sy, sw, sh, () => glyph(c, G.fish.map(r => [...r].reverse().join("")), fx, sy + 4, ORG)); R(c, sx + 3, sy + 2 - st(t, 3, 2), 1, 1, LBLUE); }
    else if (ch === 3) { R(c, sx, sy, sw, sh, "#F4C0D1"); glyph(c, G.heart, sx + 4, sy + 2 + st(t, 5, 2), RED); }
    else { R(c, sx, sy, sw, sh, "#2a2a2d"); mini(c, sx + 2, sy + 3, st(t, 4, 2)); }
  });

  defNew("w-cascading", "Cascading", "words", "Cascading…", (c, t) => {
    // He pours bubbly into the top glass of a champagne tower; it overflows and cascades down, glass by glass.
    const p = (t % 5) / 5, X = 3, Y = Y0, FIZZ = YEL;
    const rows = [[[27, 4]], [[24, 10], [30, 10]], [[21, 16], [27, 16], [33, 16]]];
    const fade = p > 0.9 ? 1 - (p - 0.9) / 0.1 : 1;
    const lv = [cl((p - 0.05) / 0.15), cl((p - 0.22) / 0.18), cl((p - 0.42) / 0.2)];
    rows.forEach((row, ri) => row.forEach(([gx, gy]) => {
      const n = Math.round(lv[ri] * 3);
      alpha(c, fade, () => { for (let j = 0; j < n; j++) R(c, gx + 1, gy + 2 - j, 3, 1, FIZZ); if (n && st(t + gx, 5, 3) === 0) R(c, gx + 2, gy + 2, 1, 1, WHITE); });
      glyph(c, ["#...#", "#...#", "#...#", ".###.", "..#..", ".###."], gx, gy, GLASS);
    }));
    const drip = (x, y0, y1) => { for (let y = y0; y < y1; y++) if ((y + Math.floor(t * 12)) % 2) R(c, x, y, 1, 1, FIZZ); };
    const pouring = p > 0.03 && p < 0.62;
    if (pouring) drip(29, 2, 4 + 3 - Math.round(lv[0] * 3));
    if (lv[0] >= 1 && p < 0.62) { drip(26, 5, 10); drip(32, 5, 10); }
    if (lv[1] >= 1 && p < 0.62) { drip(23, 11, 16); drip(29, 11, 16); drip(35, 11, 16); }
    if (pouring) {
      line(c, X + 16, Y - 2, X + 23, Y - 9, STEM); line(c, X + 17, Y - 2, X + 24, Y - 9, STEM); R(c, X + 24, Y - 10, 2, 1, FIZZ);
    } else { R(c, X + 16, Y + 2, 2, 5, STEM); R(c, X + 16, Y, 2, 2, FIZZ); }
    const done = p > 0.62 && p < 0.92;
    clawd(c, X, Y, { eyes: done ? "happy" : pouring ? "up" : "right", armR: pouring ? "up" : "out", armL: done && st(t, 3, 2) ? "up" : "out" });
    if (done) [[24, 2], [34, 6], [19, 9]].forEach(([x, y], i) => { if ((st(t, 5, 3) + i) % 3) glyph(c, G.star, x, y, i % 2 ? YEL : WHITE); });
  });

  defNew("w-ebbing", "Ebbing", "words", "Ebbing…", (c, t) => {
    // On the beach, Clawd follows the tide as it ebbs out, then scampers back when the wave rolls in.
    const th = t / 4.5 * Math.PI * 2, xe = Math.round(26 + Math.sin(th) * 8);
    R(c, 0, 22, 40, 4, "#C9A26B");
    glyph(c, [".#.", "###"], 31, 20, PINK);                                          // a shell the tide uncovers
    for (let x = Math.max(0, xe); x < 40; x++) {
      const dep = Math.min(3, Math.floor((x - xe) / 3)), top = 21 - dep;
      R(c, x, top, 1, 26 - top, BLUE); R(c, x, top, 1, 1, LBLUE);
    }
    R(c, xe, 20 + Math.round(Math.sin(t * 6)), 1, 2, WHITE); R(c, xe - 1, 21, 1, 1, WHITE);
    const x = Math.round(8 + Math.sin(th - 0.5) * 8), flee = Math.cos(th - 0.5) < 0;
    clawd(c, x, Y0, { eyes: flee ? "wide" : "right", armL: flee ? "up" : "out", armR: flee ? "up" : "out", legs: st(t, flee ? 8 : 4, 2) + 1 });
    if (xe < x + 14) for (let i = 0; i < 3; i++) { const q = (t * 3 + i / 3) % 1; R(c, x + 10 + i * 2, 20 - Math.sin(q * Math.PI) * 3, 1, 1, LBLUE); }
  });

  defNew("w-undulating", "Undulating", "words", "Undulating…", (c, t) => {
    // A rollercoaster on a wavy track: Clawd rides the endless ups and downs, arms up on every drop.
    const sp = 10, h = x => 17 + Math.round(Math.sin((x + t * sp) * 0.2) * 3.5);
    for (let x = 0; x < 40; x++) {
      const w = Math.floor(x + t * sp);
      if (((w % 6) + 6) % 6 === 0) R(c, x, h(x) + 1, 1, 22 - h(x) - 1, DGREY);
    }
    for (let x = 0; x < 39; x++) line(c, x, h(x), x + 1, h(x + 1), METAL);
    const top = h(20) - 4, dropping = h(26) > h(14);
    clawd(c, 12, top - 5, { eyes: dropping ? "happy" : "up", legs: "none", armL: dropping ? "up" : "out", armR: dropping ? "up" : "out" });
    R(c, 11, top, 18, 3, RED); R(c, 11, top + 1, 18, 1, YEL); R(c, 13, top + 3, 2, 1, INK); R(c, 25, top + 3, 2, 1, INK);
  });

  defNew("w-wibbling", "Wibbling", "words", "Wibbling…", (c, t) => {
    // Jelly Clawd on a plate: a spoon pokes him and he wibbles and wobbles until he settles.
    const P = 2.5, T = t % P, poke = 0.35, tau = T - poke, X = 12, Y = Y0;
    const A = tau > 0 ? 2.4 * Math.exp(-tau * 2.2) : 0, sh = tau > 0 ? Math.sin(tau * 16) * A : 0;
    R(c, X - 3, 22, 22, 1, WHITE); R(c, X - 1, 23, 18, 1, GLASS);
    const eyes = tau > 0 && tau < 0.9 ? "wide" : tau >= 0.9 ? "happy" : "right";
    for (let r = Y - 2; r < 22; r++) {
      const dx = Math.round(sh * cl((Y + 10 - r) / 10));
      clip(c, 0, r, 40, 1, () => { clawd(c, X + dx, Y, { eyes, armR: "none" }); R(c, X + 3 + dx, Y + 5, 1, 2, "#F0997B"); });
    }
    const tip = tau < 0 ? X + 14 + (-tau / poke) * 14 : X + 14 + Math.min(1, tau / 0.4) * 14;
    glyph(c, [".##.", "####", ".##."], tip, Y + 3, METAL); R(c, tip + 4, Y + 4, 10, 1, METAL);
  });

  /* ---------- swirling and twisting ---------- */

  defNew("w-swirling", "Swirling", "words", "Swirling…", (c, t) => {
    // Rhythmic-gymnast Clawd twirls a ribbon on a stick; it spirals all the way around him.
    const X = X0, hop = st(t, 4, 2), Y = Y0 - hop, tip = [X + 18, Y - 5];
    const pts = [];
    for (let i = 0; i <= 220; i++) {
      const s = i / 220, th = -t * 5 + s * 9, rr = 8 + s * 7;
      const sp = [20 + Math.cos(th) * rr * 1.3, 15 + Math.sin(th) * rr * 0.55], b = Math.min(1, s * 5);
      pts.push([lerp(tip[0], sp[0], b), lerp(tip[1], sp[1], b), Math.sin(th) < 0 || b < 1, i]);
    }
    const draw = back => pts.forEach(([x, y, bk, i]) => { if (bk === back) R(c, x, y, 1, 1, i % 18 < 9 ? PINK : DPINK); });
    draw(true);
    clawd(c, X, Y, { eyes: "happy", armR: "up", legs: hop ? 1 : 2 });
    line(c, X + 15, Y - 1, tip[0], tip[1], WHITE);
    draw(false);
  });

  defNew("w-twisting", "Twisting", "words", "Twisting…", (c, t) => {
    // Balloon artist: he blows up a long balloon, twists it squeak by squeak into a dog… which then pops.
    const p = (t % 5) / 5, X = 1, Y = Y0, bx = X + 16, by = Y + 3;
    let eyes = "right", armL = "out", armR = "out";
    if (p < 0.45) {
      const L = p < 0.18 ? Math.round(p / 0.18 * 20) : 20, pinches = p < 0.18 ? 0 : Math.floor((p - 0.18) / 0.27 * 5) + 1;
      const jit = pinches ? st(t, 12, 2) : 0, pins = [4, 8, 11, 14, 17].slice(0, pinches);
      for (let i = 0; i < L; i++) {
        const x = bx + i, end = i === 0 || i === L - 1;
        if (pins.includes(i)) R(c, x, by + 1 + jit, 1, 1, DPINK); else R(c, x, by + (end ? 1 : 0) + jit, 1, end ? 1 : 3, PINK);
      }
      if (L > 3) R(c, bx + 2, by + jit, 2, 1, WHITE);
      if (pinches && st(t, 6, 2)) { const px = bx + pins[pins.length - 1]; R(c, px - 1, by - 3, 1, 1, WHITE); R(c, px + 1, by - 3, 1, 1, WHITE); R(c, px, by - 4, 1, 1, WHITE); }
      eyes = pinches ? "down" : "right"; armL = pinches && st(t, 6, 2) ? "down" : "out";
    } else if (p < 0.85) {
      glyph(c, [".##............", "####...........", "#####..........", ".##........##..", ".##........##..", ".############..", ".############..", ".##........##..", ".##........##..", ".##........##.."], 22, 12, PINK);
      [[23, 15], [23, 17], [34, 17], [23, 19], [34, 19], [26, 17], [30, 17]].forEach(([x, y]) => R(c, x, y, 1, 1, DPINK));
      R(c, 23, 13, 1, 1, EYE); R(c, 24, 12, 1, 1, WHITE);
      eyes = "happy"; armL = "up";
      if (p > 0.55 && p < 0.8) glyph(c, G.heartS, 30, 9 - Math.round((p - 0.55) * 16), RED);
    } else if (p < 0.9) {
      const q = (p - 0.85) / 0.05;
      for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2; line(c, 29 + Math.cos(a) * 2, 16 + Math.sin(a) * 2, 29 + Math.cos(a) * (3 + q * 5), 16 + Math.sin(a) * (3 + q * 4), i % 2 ? WHITE : YEL); }
      eyes = "wide"; armL = "up"; armR = "up";
    } else {
      const q = (p - 0.9) / 0.1;
      [[24, 1], [28, -1], [33, 2], [36, 0]].forEach(([x, v], i) => R(c, x + v * q * 3, 12 + q * 9 + (i % 2), 2, 1, PINK));
      eyes = "closed";
    }
    clawd(c, X, Y, { eyes, armL, armR });
  });

  defNew("w-whirlpooling", "Whirlpooling", "words", "Whirlpooling…", (c, t) => {
    // In a rubber ring, Clawd gets swept round and round a swirling whirlpool.
    R(c, 0, 13, 40, 13, DBLUE); R(c, 0, 13, 40, 1, LBLUE);
    [[17, 5, 1.2], [12, 3.5, 1.8], [7, 2, 2.6], [3, 1, 4]].forEach(([rx, ry, sp], i) => {
      const n = Math.round(rx * 4);
      for (let j = 0; j < n; j++) if (j % 8 < 5) { const a = t * sp + j / n * Math.PI * 2; R(c, 20 + Math.cos(a) * rx, 19 + Math.sin(a) * ry, 1, 1, i === 3 ? WHITE : LBLUE); }
    });
    R(c, 18, 19, 5, 1, "#2c2c2a"); R(c, 19, 18, 3, 1, "#2c2c2a");
    const ph = t * 1.8, rx = 20 + Math.cos(ph) * 9, ry = 19 + Math.sin(ph) * 2.5, x = Math.round(rx - 8), y = Math.round(ry - 8);
    for (let j = 1; j < 4; j++) { const a = ph - j * 0.25; alpha(c, 1 - j * 0.25, () => R(c, 20 + Math.cos(a) * 9 + (Math.sin(ph) > 0 ? 8 : -9), 19 + Math.sin(a) * 2.5, 1, 1, WHITE)); }
    const wave = st(t, 2, 2);
    clawd(c, x, y, { eyes: -Math.sin(ph) > 0 ? "right" : "left", legs: "none", armL: wave ? "up" : "out", armR: wave ? "out" : "up" });
    R(c, x - 1, y + 7, 18, 3, YEL); [x + 2, x + 8, x + 14].forEach(sx => R(c, sx, y + 7, 2, 3, RED));
  });
})();



const VERBS = ["Accomplishing", "Actioning", "Actualizing", "Architecting", "Baking", "Beaming", "Beboppin'", "Befuddling", "Billowing", "Blanching", "Bloviating", "Boogieing", "Boondoggling", "Booping", "Bootstrapping", "Brewing", "Bunning", "Burrowing", "Calculating", "Caramelizing", "Cascading", "Catapulting", "Cerebrating", "Channeling", "Choreographing", "Churning", "Clauding", "Coalescing", "Cogitating", "Combobulating", "Composing", "Computing", "Concocting", "Considering", "Contemplating", "Cooking", "Crafting", "Creating", "Crunching", "Crystallizing", "Cultivating", "Deciphering", "Deliberating", "Determining", "Dilly-dallying", "Discombobulating", "Doing", "Doodling", "Drizzling", "Ebbing", "Effecting", "Elucidating", "Embellishing", "Enchanting", "Envisioning", "Fermenting", "Fiddle-faddling", "Finagling", "Flambéing", "Flibbertigibbeting", "Flowing", "Flummoxing", "Fluttering", "Forging", "Forming", "Frolicking", "Frosting", "Gallivanting", "Galloping", "Garnishing", "Generating", "Gesticulating", "Germinating", "Gitifying", "Grooving", "Gusting", "Harmonizing", "Hashing", "Hatching", "Herding", "Honking", "Hullaballooing", "Hyperspacing", "Ideating", "Imagining", "Improvising", "Incubating", "Inferring", "Infusing", "Ionizing", "Jitterbugging", "Julienning", "Kerfuffling", "Kneading", "Leavening", "Levitating", "Lollygagging", "Manifesting", "Marinating", "Meandering", "Metamorphosing", "Misting", "Moonwalking", "Moseying", "Mulling", "Mustering", "Nebulizing", "Nesting", "Newspapering", "Noodling", "Nucleating", "Onioning", "Orbiting", "Orchestrating", "Osmosing", "Perambulating", "Percolating", "Perusing", "Philosophizing", "Photosynthesizing", "Polishing", "Pollinating", "Pondering", "Pontificating", "Pouncing", "Precipitating", "Prestidigitating", "Processing", "Proofing", "Propagating", "Puttering", "Puzzling", "Quantumizing", "Razzle-dazzling", "Razzmatazzing", "Recombobulating", "Reticulating", "Roosting", "Ruminating", "Sautéing", "Scampering", "Schlepping", "Scurrying", "Seasoning", "Shenaniganing", "Shimmying", "Simmering", "Skedaddling", "Sketching", "Slithering", "Smooshing", "Sock-hopping", "Spelunking", "Spinning", "Sprouting", "Stewing", "Sublimating", "Swirling", "Swooping", "Symbioting", "Synthesizing", "Tempering", "Thinking", "Thundering", "Tinkering", "Tomfoolering", "Topsy-turvying", "Transfiguring", "Transmogrifying", "Transmuting", "Twisting", "Undulating", "Unfurling", "Unraveling", "Vibing", "Waddling", "Wandering", "Warping", "Whatchamacalliting", "Whirlpooling", "Whirring", "Whisking", "Wibbling", "Working", "Wrangling", "Zesting", "Zigzagging"];
const VERB_ANIM = {"Baking": "cook", "Blanching": "cook", "Bunning": "cook", "Caramelizing": "cook", "Cooking": "cook", "Drizzling": "cook", "Flambéing": "cook", "Garnishing": "cook", "Julienning": "cook", "Kneading": "cook", "Leavening": "cook", "Marinating": "cook", "Onioning": "cook", "Proofing": "cook", "Sautéing": "cook", "Seasoning": "cook", "Simmering": "cook", "Stewing": "cook", "Tempering": "cook", "Whisking": "cook", "Zesting": "cook", "Beboppin'": "dance", "Boogieing": "dance", "Choreographing": "dance", "Grooving": "dance", "Jitterbugging": "dance", "Moonwalking": "dance", "Razzle-dazzling": "dance", "Razzmatazzing": "dance", "Shimmying": "dance", "Sock-hopping": "dance", "Vibing": "dance", "Brewing": "test", "Concocting": "test", "Crystallizing": "test", "Fermenting": "test", "Ionizing": "test", "Nucleating": "test", "Osmosing": "test", "Percolating": "test", "Sublimating": "test", "Synthesizing": "test", "Transmogrifying": "test", "Transmuting": "test", "Composing": "paint", "Crafting": "paint", "Creating": "paint", "Doodling": "paint", "Embellishing": "paint", "Sketching": "paint", "Finagling": "juggle", "Herding": "juggle", "Mustering": "juggle", "Orchestrating": "juggle", "Wrangling": "juggle", "Cerebrating": "idea", "Envisioning": "idea", "Ideating": "idea", "Imagining": "idea", "Manifesting": "idea", "Befuddling": "puzzled", "Discombobulating": "puzzled", "Flummoxing": "puzzled", "Kerfuffling": "puzzled", "Puzzling": "puzzled", "Topsy-turvying": "puzzled", "Deciphering": "read", "Newspapering": "read", "Perusing": "read", "Hyperspacing": "web", "Orbiting": "web", "Hatching": "spawn", "Incubating": "spawn", "Nesting": "spawn", "Propagating": "spawn", "Cultivating": "water", "Germinating": "water", "Photosynthesizing": "water", "Pollinating": "water", "Sprouting": "water", "Churning": "compact", "Crunching": "compact", "Smooshing": "compact", "Architecting": "stack", "Bootstrapping": "stack", "Forging": "stack", "Forming": "stack", "Gitifying": "carry", "Schlepping": "carry", "Polishing": "sweep", "Thundering": "fireworks", "Computing": "type", "Doing": "type", "Generating": "type", "Processing": "type", "Working": "type"};
Object.assign(VERB_ANIM, {"Moonwalking": "moonwalk", "Hyperspacing": "hyperspace", "Levitating": "levitate", "Photosynthesizing": "photosynth", "Spelunking": "spelunk", "Honking": "honk", "Galloping": "gallop", "Gallivanting": "gallop", "Spinning": "spin", "Whirlpooling": "spin", "Swirling": "spin", "Twisting": "spin", "Hatching": "hatch", "Moseying": "mosey", "Meandering": "mosey", "Wandering": "mosey", "Noodling": "noodle", "Booping": "boop"});
Object.assign(VERB_ANIM, {"Waddling": "waddle", "Burrowing": "burrow", "Catapulting": "catapult", "Prestidigitating": "magic", "Enchanting": "magic", "Transfiguring": "magic", "Metamorphosing": "metamorph", "Unfurling": "metamorph", "Slithering": "slither", "Undulating": "slither", "Wibbling": "slither", "Frosting": "frost", "Roosting": "roost", "Pouncing": "pounce", "Skedaddling": "skedaddle", "Scampering": "skedaddle", "Scurrying": "skedaddle", "Philosophizing": "philosophize", "Pontificating": "philosophize", "Ruminating": "philosophize", "Bloviating": "philosophize", "Clauding": "clauding", "Warping": "warp", "Quantumizing": "warp", "Harmonizing": "harmonize", "Gusting": "gust", "Billowing": "gust", "Pondering": "ponder", "Mulling": "ponder", "Considering": "ponder", "Contemplating": "ponder", "Cogitating": "ponder", "Deliberating": "ponder", "Thinking": "ponder", "Tinkering": "hammer", "Puttering": "hammer", "Frolicking": "hop"});
Object.assign(VERB_ANIM, {"Beaming": "ufo", "Channeling": "ufo", "Swooping": "swoop", "Zigzagging": "zigzag", "Unraveling": "yarn", "Cascading": "surf", "Flowing": "surf", "Ebbing": "surf", "Misting": "umbrella", "Precipitating": "umbrella", "Nebulizing": "umbrella", "Fluttering": "flutter", "Calculating": "calc", "Reticulating": "calc", "Hashing": "calc", "Tomfoolering": "jester", "Shenaniganing": "jester", "Hullaballooing": "jester", "Flibbertigibbeting": "jester", "Lollygagging": "lollipop", "Dilly-dallying": "lollipop", "Gesticulating": "gesticulate", "Elucidating": "gesticulate", "Improvising": "sax", "Whirring": "propeller", "Perambulating": "pram", "Combobulating": "reassemble", "Recombobulating": "reassemble", "Coalescing": "reassemble", "Infusing": "tea", "Boondoggling": "machine", "Fiddle-faddling": "machine", "Whatchamacalliting": "machine", "Inferring": "detective", "Determining": "detective", "Accomplishing": "flag", "Actualizing": "flag", "Actioning": "flag", "Effecting": "flag", "Symbioting": "highfive"});
Object.assign(VERB_ANIM, {"Actioning": "w-actioning", "Actualizing": "w-actualizing", "Effecting": "w-effecting", "Bootstrapping": "w-bootstrapping", "Forging": "w-forging", "Forming": "w-forming", "Baking": "w-baking", "Blanching": "w-blanching", "Bunning": "w-bunning", "Caramelizing": "w-caramelizing", "Drizzling": "w-drizzling", "Flambéing": "w-flambeing", "Garnishing": "w-garnishing", "Julienning": "w-julienning", "Kneading": "w-kneading", "Leavening": "w-leavening", "Marinating": "w-marinating", "Onioning": "w-onioning", "Proofing": "w-proofing", "Sautéing": "w-sauteing", "Seasoning": "w-seasoning", "Simmering": "w-simmering", "Stewing": "w-stewing", "Tempering": "w-tempering", "Whisking": "w-whisking", "Zesting": "w-zesting", "Channeling": "w-channeling", "Beboppin'": "w-beboppin", "Choreographing": "w-choreographing", "Grooving": "w-grooving", "Jitterbugging": "w-jitterbugging", "Razzle-dazzling": "w-razzle-dazzling", "Razzmatazzing": "w-razzmatazzing", "Shimmying": "w-shimmying", "Sock-hopping": "w-sock-hopping", "Vibing": "w-vibing", "Befuddling": "w-befuddling", "Discombobulating": "w-discombobulating", "Flummoxing": "w-flummoxing", "Kerfuffling": "w-kerfuffling", "Topsy-turvying": "w-topsy-turvying", "Billowing": "w-billowing", "Bloviating": "w-bloviating", "Pontificating": "w-pontificating", "Ruminating": "w-ruminating", "Fiddle-faddling": "w-fiddle-faddling", "Whatchamacalliting": "w-whatchamacalliting", "Brewing": "w-brewing", "Crystallizing": "w-crystallizing", "Fermenting": "w-fermenting", "Ionizing": "w-ionizing", "Nucleating": "w-nucleating", "Osmosing": "w-osmosing", "Percolating": "w-percolating", "Sublimating": "w-sublimating", "Synthesizing": "w-synthesizing", "Transmogrifying": "w-transmogrifying", "Transmuting": "w-transmuting", "Hashing": "w-hashing", "Reticulating": "w-reticulating", "Cascading": "w-cascading", "Ebbing": "w-ebbing", "Cerebrating": "w-cerebrating", "Envisioning": "w-envisioning", "Imagining": "w-imagining", "Manifesting": "w-manifesting", "Churning": "w-churning", "Crunching": "w-crunching", "Coalescing": "w-coalescing", "Combobulating": "w-combobulating", "Cogitating": "w-cogitating", "Considering": "w-considering", "Contemplating": "w-contemplating", "Deliberating": "w-deliberating", "Mulling": "w-mulling", "Thinking": "w-thinking", "Composing": "w-composing", "Crafting": "w-crafting", "Creating": "w-creating", "Doodling": "w-doodling", "Embellishing": "w-embellishing", "Computing": "w-computing", "Doing": "w-doing", "Processing": "w-processing", "Working": "w-working", "Cultivating": "w-cultivating", "Germinating": "w-germinating", "Pollinating": "w-pollinating", "Deciphering": "w-deciphering", "Newspapering": "w-newspapering", "Determining": "w-determining", "Dilly-dallying": "w-dilly-dallying", "Elucidating": "w-elucidating", "Enchanting": "w-enchanting", "Transfiguring": "w-transfiguring", "Herding": "w-herding", "Mustering": "w-mustering", "Orchestrating": "w-orchestrating", "Wrangling": "w-wrangling", "Flibbertigibbeting": "w-flibbertigibbeting", "Hullaballooing": "w-hullaballooing", "Shenaniganing": "w-shenaniganing", "Gallivanting": "w-gallivanting", "Gitifying": "w-gitifying", "Incubating": "w-incubating", "Nesting": "w-nesting", "Meandering": "w-meandering", "Wandering": "w-wandering", "Unfurling": "w-unfurling", "Misting": "w-misting", "Nebulizing": "w-nebulizing", "Puttering": "w-puttering", "Quantumizing": "w-quantumizing", "Scampering": "w-scampering", "Scurrying": "w-scurrying", "Undulating": "w-undulating", "Wibbling": "w-wibbling", "Swirling": "w-swirling", "Twisting": "w-twisting", "Whirlpooling": "w-whirlpooling"});

/* ---------- Celebrations for real moments ---------- */
const CONF = ["#F0997B", "#85B7EB", "#5DCAA5", "#FAC775", "#AFA9EC", "#ED93B1"];
function burst(c, t, cx, cy, n) {   // a puff of confetti from one point
  for (let i = 0; i < n; i++) {
    const a = -Math.PI * (0.05 + rnd(i) * 0.9), sp = 8 + rnd(i + 40) * 10;
    const x = cx + Math.cos(a) * sp * t, y = cy + Math.sin(a) * sp * t + 12 * t * t;
    if (y < SH && t < 1.6) alpha(c, 1.6 - t, () => R(c, x, y, 1, 1 + (i % 2), CONF[i % CONF.length]));
  }
}
function tinyBug(c, x, y, f) {
  R(c, x, y, 3, 2, "#2c2c2a"); R(c, x + 1, y - 1, 1, 1, "#E24B4A");
  R(c, x - 1, y + (f ? 1 : 2), 1, 1, "#2c2c2a"); R(c, x + 3, y + (f ? 2 : 1), 1, 1, "#2c2c2a");
}

// Tests pass after failing: Clawd chases the bug, squashes it, and cheers.
defNew("fixed", "Got it!", "done", "Tests pass after failing", (c, t) => {
  const p = t % 3.2, X = 4, Y = Y0;
  if (p < 1.2) {                       // the bug scuttles, Clawd watches it
    const bx = Math.round(34 - p * 8);
    tinyBug(c, bx, 20, st(t, 10, 2));
    clawd(c, X, Y, { eyes: "right", armL: "out", armR: "out" });
  } else if (p < 1.6) {                // jump up and over
    const q = (p - 1.2) / 0.4, jx = Math.round(X + q * 18), jy = Math.round(Y - Math.sin(q * Math.PI) * 6);
    tinyBug(c, 24, 20, st(t, 10, 2));
    clawd(c, jx, jy, { eyes: "down", legs: 3, armL: "up", armR: "up" });
  } else {                             // squash, then cheer
    const q = p - 1.6;
    clawd(c, X + 18, Y - (q > 0.3 ? Math.round(Math.abs(Math.sin(q * 6)) * 2) : 0), { eyes: "happy", squash: q < 0.15 ? 2 : 0, armL: q > 0.3 ? "up" : "out", armR: q > 0.3 ? "up" : "out" });
    if (q < 0.5) [[-3, 0], [17, 0], [-2, -3], [16, -3]].forEach(([dx, dy]) => R(c, X + 18 + dx, 19 + dy, 1, 1, "#f5f4ed"));
    if (q > 0.3) glyph(c, G.check, 6, 6, "#5DCAA5");
  }
});

// Tests fail: a facepalm and a sigh.
defNew("facepalm", "Facepalm", "error", "Tests failed", (c, t) => {
  const p = t % 2.8, X = X0, Y = Y0, palm = p > 0.5 && p < 2.3;
  clawd(c, X, Y, { eyes: palm ? "closed" : "wide", armL: palm ? "none" : "down", armR: "down", squash: palm ? 1 : 0 });
  if (palm) {   // the arm comes up and a darker hand covers the eyes
    const HAND = "#a9553c";
    R(c, X - 1, Y + 4, 2, 3, HAND); R(c, X, Y + 2, 2, 2, HAND); R(c, X + 2, Y + 2, 6, 2, HAND); R(c, X + 3, Y + 4, 4, 1, HAND);
  }
  if (p > 0.9 && p < 2.2) { const q = (p - 0.9) / 1.3; alpha(c, 1 - q, () => R(c, X + 16 + Math.round(q * 4), Y + 4 - Math.round(q * 3), 2, 1, "#B5D4F4")); }
  if (palm) { const x = 30, y = 6; [[0,0],[2,0],[1,1],[0,2],[2,2]].forEach(([dx, dy]) => R(c, x + dx, y + dy, 1, 1, "#E24B4A")); }
});

// Pull request merged: two branches flow together into Clawd, then confetti.
defNew("merged", "Merged!", "done", "Pull request merged", (c, t) => {
  const p = t % 3.4, X = 22, Y = Y0, PUR = "#AFA9EC", GRN = "#5DCAA5";
  line(c, 1, 9, 10, 9, PUR); line(c, 10, 9, 15, 15, PUR);
  line(c, 1, 21, 10, 21, GRN); line(c, 10, 21, 15, 16, GRN);
  line(c, 15, 15, 20, 15, "#f5f4ed"); line(c, 15, 16, 20, 16, "#f5f4ed");
  const q = Math.min(1, p / 1.1);
  if (p < 1.1) {
    const along = (y0) => q < 0.6 ? [1 + q / 0.6 * 9, y0] : [10 + (q - 0.6) / 0.4 * 5, y0 + (15.5 - y0) * (q - 0.6) / 0.4];
    const [ax, ay] = along(9), [bx, by] = along(21);
    R(c, ax - 1, ay - 1, 2, 2, PUR); R(c, bx - 1, by - 1, 2, 2, GRN);
  }
  const hop = p > 1.1 && p < 1.6 ? Math.round(Math.sin((p - 1.1) / 0.5 * Math.PI) * 4) : 0;
  clawd(c, X, Y - hop, { eyes: p > 1.1 ? "happy" : "left", armL: p > 1.1 ? "up" : "out", armR: p > 1.1 ? "up" : "out", legs: hop ? 3 : 0 });
  if (p > 1.1) burst(c, p - 1.1, X + 8, Y - 2, 18);
});

// Many lines changed: Clawd carries a big stack of pages and drops it with a thud.
defNew("bigone", "Big one!", "done", "A big change finished", (c, t) => {
  const p = t % 3, X = 6, Y = Y0, down = p > 1.2;
  const sx = down ? 26 : X + 2, sy = down ? 14 : Y - 9;
  for (let i = 0; i < 7; i++) R(c, sx + (i % 2), sy + i, 10, 1, i % 2 ? "#d3d1c7" : "#f5f4ed");
  if (!down) clawd(c, X + Math.round(p * 4), Y, { eyes: "up", armL: "up", armR: "up", legs: st(t, 6, 2) + 1 });
  else {
    clawd(c, X + 2, Y, { eyes: "happy", armL: "out", armR: "out" });
    const q = p - 1.2;
    if (q < 0.4) [[24, 20], [37, 20], [23, 18], [38, 18]].forEach(([x, y]) => R(c, x, y, 1, 1, "#b4b2a9"));
    if (q > 0.4) for (let i = 0; i < 2; i++) { const r = (q * 0.8 + i / 2) % 1; alpha(c, 1 - r, () => R(c, X + 18 + r * 2, Y + 2 - r * 6, 1, 2, "#85B7EB")); }
  }
});

/* Called from Swift when something good or bad just happened (tests, a merge, a big change):
   plays that animation once, then goes back to whatever fits the mode. */
api.celebrate = id => {
  const a = byId[id]; if (!a) return;
  current = a; clock = 0; shownAt = 0; nextSwap = 4.5;
};

const byId = Object.fromEntries(A.map(a => [a.id, a]));
const pick = l => l[Math.floor(Math.random() * l.length)];

/* What Clawd does when he isn't working */
const MODE_ANIMS = {
  waiting: ["flagjump"],
  done:    ["confetti", "hop", "dance", "trophy", "party", "fireworks", "highfive", "micdrop"],
  idle:    ["sleep"],
  zero:    ["fish"],    // inbox zero: nothing running, nothing to read
  impatient: ["tapfoot"],   // needs you, a few minutes in
  urgent:  ["megaphone"],   // needs you, ten minutes in
  stuck:   ["sweat"],       // same step for a long time
  low:     ["sweat"],       // usage nearly used up
  out:     ["sleep"],       // usage used up: a nap until it resets
  morning: ["coffee"],      // nothing running, before 10am: mixed in with his hobbies
  night:   ["nightcap"],    // nothing running, after 11pm: mixed in with his hobbies
  // nothing running: Clawd enjoys his day off, one hobby after another
  life:    ["fish", "read", "guitar", "bubbles", "telescope", "tea", "surf", "sax", "paint", "water",
            "balloons", "lollipop", "gaming", "headphones", "icecream", "kite", "sunbathe", "skate", "cat", "yawn"],
};
const MODE_WORD = {
  waiting: "Needs you", impatient: "Still waiting…", urgent: "Hey! Over here",
  stuck: "Stuck?", low: "Running low", out: "Napping", done: "Done!", idle: "", zero: "", morning: "", night: "", life: "",
};

let pinned = null;   // follow another Clawd's hobby instead of picking our own
let mode = "idle", current = byId.sleep, clock = 0, last = performance.now(), nextSwap = 0, calm = false, shownAt = 0;
/* Calm set: quieter working animations, swapped less often */
const CALM = ["type", "read", "walk", "look"].filter(id => byId[id]);

function size() {
  const dpr = window.devicePixelRatio || 1;
  const s = (cv.clientWidth || SW) / SW;
  cv.width = Math.round(SW * s * dpr); cv.height = Math.round(SH * s * dpr);
  cv._s = s * dpr; cv._w = cv.clientWidth;
}
function tell(word) {
  if (said) said({ word, mode, anim: current.id });
}
/* Nothing running: hobbies all day. Mornings start with coffee, late nights with a nightcap,
   and those keep coming back now and then between hobbies. */
const RESTING = ["life", "morning", "night"];
function restingPick() {
  const extra = mode === "life" ? [] : MODE_ANIMS[mode];
  if (clock === 0 && extra.length && byId[extra[0]]) return byId[extra[0]];
  const pool = MODE_ANIMS.life.concat(extra, extra, extra).filter(id => byId[id] && id !== (current && current.id));
  return byId[pick(pool)];
}
function swap() {
  if (mode === "working") {
    const w = pick(VERBS);
    current = calm ? byId[pick(CALM)] : (byId[VERB_ANIM[w]] || byId.type);
    // A new one when Claude moves on to its next step (see nextStep), or after a minute on one step.
    shownAt = clock;
    nextSwap = clock + 60;
    tell(w + "…");
  } else if (RESTING.includes(mode) && pinned && byId[pinned]) {
    current = byId[pinned];
    nextSwap = Infinity;
    tell(MODE_WORD[mode]);
  } else if (RESTING.includes(mode)) {
    // a new hobby every 30 seconds, never the same one twice in a row
    current = restingPick();
    nextSwap = clock + 30;
    tell(MODE_WORD[mode]);
  } else {
    current = byId[pick(MODE_ANIMS[mode])];
    nextSwap = Infinity;   // done / needs you / idle: pick one and stay on it
    tell(MODE_WORD[mode]);
  }
}
/* Called from Swift or the settings preview with a mode name */
api.setMode = m => {
  if (!(m in MODE_WORD) && m !== "working") m = "idle";
  if (m === mode) return;
  mode = m; clock = 0; swap();
};
api.setColor = c => { CL = c; };
/* Called from Swift when Claude starts its next step. Steps can come seconds apart,
   so each animation plays for at least 20 seconds first. */
api.nextStep = () => { if (mode === "working" && clock - shownAt >= 20) swap(); };
/* Called from Swift: show the same hobby as the notch Clawd */
api.setAnim = id => {
  pinned = id || null;
  if (RESTING.includes(mode) && pinned && byId[pinned] && current.id !== pinned) { current = byId[pinned]; clock = 0; nextSwap = Infinity; }
};
api.setCalm = on => { calm = !!on; if (mode === "working") swap(); };
function frame(t) {
  if (!cv.isConnected) return;
  if (cv.clientWidth !== cv._w) size();
  clock += Math.max(0, Math.min(0.1, (t - last) / 1000)); last = t;
  if (clock >= nextSwap) swap();
  const c = cv.getContext("2d");
  c.setTransform(1, 0, 0, 1, 0, 0); c.clearRect(0, 0, cv.width, cv.height);
  c.setTransform(cv._s, 0, 0, cv._s, 0, 0);
  current.draw(c, clock);
  requestAnimationFrame(frame);
}
size(); swap(); requestAnimationFrame(frame);
return api;
};
