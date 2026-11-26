/* The screen every page shares: the live notch in the menu bar, the clock, and the pieces pages borrow to
   draw their own bits of notch (rows, the needs-you card, rings, a Clawd on any canvas).
   Needs engine.js first: that is the app's own Clawd, with every animation. */
(() => {
const byId = Object.fromEntries(A.map(a => [a.id, a]));
const RM = matchMedia("(prefers-reduced-motion: reduce)").matches;
const pick = l => l[Math.floor(Math.random() * l.length)];

/* ---------- pixel stages: one canvas, one animation ---------- */
const stages = [];
class Stage {
  constructor(cv, anim, color) { this.cv = cv; this.anim = anim; this.color = color || "#D97757"; this.t0 = performance.now(); stages.push(this); this.fit(); }
  fit() {
    const r = this.cv.getBoundingClientRect(), dpr = devicePixelRatio || 1;
    this.cv.width = Math.max(1, Math.round(r.width * dpr)); this.cv.height = Math.max(1, Math.round(r.height * dpr));
    let s = Math.min(this.cv.width / SW, this.cv.height / SH); if (s >= 4) s = Math.floor(s);   // small sizes keep their full size
    this.s = s; this.ox = Math.round((this.cv.width - SW * s) / 2); this.oy = Math.round(this.cv.height - SH * s);
  }
  set(anim, color) { if (color) this.color = color; if (byId[anim] && anim !== this.anim) { this.anim = anim; this.t0 = performance.now(); } this.paint(); }
  paint(now) {
    const a = byId[this.anim]; if (!a) return;
    const c = this.cv.getContext("2d");
    c.setTransform(1, 0, 0, 1, 0, 0); c.clearRect(0, 0, this.cv.width, this.cv.height); c.imageSmoothingEnabled = false;
    c.setTransform(this.s, 0, 0, this.s, this.ox, this.oy);
    const keep = CL; CL = this.color;
    try { a.draw(c, RM ? 0.9 : ((now || performance.now()) - this.t0) / 1000); } catch (e) {}
    CL = keep; c.globalAlpha = 1;
  }
}

/* ---------- small drawn things ---------- */
function ring(pct, color, size, w) {
  w = w || 2.25; const r = size / 2 - w / 2 - .5, c = 2 * Math.PI * r;
  return `<svg class="ring" width="${size}" height="${size}" style="--k:${color}" role="img" aria-label="${pct}%"><circle class="tr" cx="${size / 2}" cy="${size / 2}" r="${r}" stroke-width="${w}"/><circle class="v" cx="${size / 2}" cy="${size / 2}" r="${r}" stroke-width="${w}" stroke-dasharray="${c}" stroke-dashoffset="${c * (1 - pct / 100)}"/></svg>`;
}
const check = size => `<svg class="check" width="${size}" height="${size}" viewBox="0 0 18 18" role="img" aria-label="Done"><circle cx="9" cy="9" r="9" fill="var(--green)"/><path d="M5.3 9.4l2.5 2.5 4.9-5.5" fill="none" stroke="#04210c" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
const I = {   // small line icons, drawn here so nothing loads from outside
  branch: '<svg class="ic" viewBox="0 0 12 12" aria-hidden="true"><circle cx="3" cy="2.5" r="1.4"/><circle cx="3" cy="9.5" r="1.4"/><circle cx="9" cy="4" r="1.4"/><path d="M3 3.9v4.2M9 5.4c0 2-2.2 2.3-6 2.4"/></svg>',
  pr: '<svg class="ic" viewBox="0 0 12 12" aria-hidden="true"><circle cx="3" cy="2.5" r="1.4"/><circle cx="3" cy="9.5" r="1.4"/><circle cx="9" cy="9.5" r="1.4"/><path d="M3 3.9v4.2M9 8.1V5.3C9 3.9 8.2 3 6.8 3H5.7M7 1.5 5.5 3 7 4.5"/></svg>',
  flask: '<svg class="ic" viewBox="0 0 12 12" aria-hidden="true"><path d="M4.3 1.4h3.4M5 1.4v3.5L2.5 9.2a.9.9 0 0 0 .8 1.4h5.4a.9.9 0 0 0 .8-1.4L7 4.9V1.4M3.9 7.4h4.2"/></svg>',
  link: '<svg class="ic" viewBox="0 0 12 12" aria-hidden="true"><rect x="1.4" y="1.4" width="9.2" height="9.2" rx="2.3"/><path d="M4.5 7.5l3-3M5 4.4h2.6V7"/></svg>',
  list: '<svg class="ic" viewBox="0 0 12 12" aria-hidden="true"><path d="M4.8 3h5.4M4.8 6h5.4M4.8 9h5.4M1.6 3l.7.7 1.1-1.3M1.6 6l.7.7 1.1-1.3"/><circle cx="2.3" cy="9" r=".5" fill="currentColor"/></svg>',
};

/* ---------- what a row shows: the app's three presets (Settings > Sessions) ---------- */
const PIECES = ["model", "account", "context", "time", "branch", "lines", "pr", "tests", "server", "todo", "helpers", "cost"];
const WORDS_ONLY = ["branch", "lines", "server"];   // no small form, so never "at a glance"
const PLACES = {
  minimal: Object.fromEntries(PIECES.map(k => [k, k === "context" || k === "time" ? "glance" : "off"])),
  balanced: Object.fromEntries(PIECES.map(k => [k, ["context", "time", "pr", "tests", "helpers"].includes(k) ? "glance" : k === "cost" ? "off" : "hover"])),
  everything: Object.fromEntries(PIECES.map(k => [k, WORDS_ONLY.includes(k) ? "hover" : "glance"])),
};
const SAYS_MORE = ["tests", "pr", "todo", "context"];   // an icon says less than the words, so the words still come on hover
const prTone = pr => pr.checks === "passed" ? "g" : pr.checks === "failed" ? "rd" : "y";

/* The details line: every piece set to "On hover", plus the words behind the small ones. */
function details(s, places, keys) {
  const want = k => places[k] === "hover" || (places[k] === "glance" && SAYS_MORE.includes(k)), out = [];
  if (keys) out.push(`<span style="color:rgba(255,255,255,.8)">⌥⌘Y allow · ⌥⌘N deny</span>`);
  if (want("branch") && s.branch) out.push(`<span>${I.branch}${s.branch}</span>`);
  if (want("lines") && s.lines) out.push(`<span><span class="g">${s.lines[0]}</span><span class="rd">${s.lines[1]}</span>· ${s.lines[2]}</span>`);
  if (want("tests") && s.tests) out.push(`<span class="${s.tests.ok ? "g" : "rd"}">${I.flask}${s.tests.text}</span>`);
  if (want("pr") && s.pr) out.push(`<span class="${prTone(s.pr)}">${I.pr}PR #${s.pr.n} · checks ${s.pr.checks}</span>`);
  if (want("server") && s.server) out.push(`<span class="lk">${I.link}${s.server}</span>`);
  if (want("todo") && s.todo) out.push(`<span>${I.list}${s.todo}</span>`);
  if (want("helpers") && s.helpers) out.push(`<span>${s.helpers} helpers at work</span>`);
  if (want("model")) out.push(`<span>${s.model}</span>`);
  if (want("account")) out.push(`<span><i class="dot" style="--k:${s.acct[1]}"></i>${s.acct[0]}</span>`);
  if (want("context")) out.push(`<span>${s.ctx}% full</span>`);
  if (want("time")) out.push(`<span>${s.st === "done" ? (s.age === "now" ? "just now" : s.age + " ago") : "running " + s.age}</span>`);
  if (want("cost") && s.cost) out.push(`<span>${s.cost}</span>`);
  return out.length ? `<div class="det"><div>${out.join("")}</div></div>` : "";
}

/* One session, as the app draws it: a calm row, or a card while it needs you.
   opt.places: what the row shows (default Balanced). opt.show: details without hovering.
   opt.answer(s, "allow" | "always" | "deny"): what the card's buttons do. opt.list: where its Clawd's stage goes. */
function session(s, opt) {
  opt = opt || {};
  const places = opt.places || PLACES.balanced, on = k => places[k] === "glance";
  const anim = s.st === "waiting" ? "flagjump" : s.st === "done" ? (s.party || "confetti") : (VERB_ANIM[s.verb] || "type");
  const pose = `<span class="pose"><canvas aria-hidden="true"></canvas>${on("helpers") && s.helpers ? `<b class="plus" title="${s.helpers} helpers at work">+${s.helpers}</b>` : ""}</span>`;
  const tags = (on("model") ? `<span class="mtag">${s.model}</span>` : "") + (on("account") ? `<span class="mtag"><i class="dot" style="--k:${s.acct[1]}"></i>${s.acct[0]}</span>` : "");
  let end = "";
  if (on("cost") && s.cost) end += `<span class="tm hide-narrow">${s.cost}</span>`;
  if (on("tests") && s.tests) end += `<span class="${s.tests.ok ? "g" : "rd"}" title="Tests: ${s.tests.text}">${I.flask}</span>`;
  if (on("pr") && s.pr) end += `<span class="${prTone(s.pr)}" title="PR #${s.pr.n}: checks ${s.pr.checks}">${I.pr}</span>`;
  if (on("time")) end += `<span class="tm">${s.st === "done" && s.age !== "now" ? s.age + " ago" : s.age}</span>`;
  if (s.st === "done") end += check(18);
  else if (s.st !== "waiting" && on("context")) end += ring(s.ctx, s.ctx >= 90 ? "var(--red)" : s.ctx >= 80 ? "#ff9f0a" : "#fff", 18);

  const el = document.createElement("div");
  if (s.st === "waiting") {
    el.className = "card";
    el.innerHTML = `<div class="chead">${pose}<div class="tx"><div><span class="t">${s.name}</span>${tags}</div><div class="s"><span class="y">Wants to run a command</span></div></div><span class="gl">${end}</span></div>
      <div class="cmd">${s.cmd || "npm test"}</div>
      <div class="acts"><button type="button" class="nbtn" data-a="deny">Deny</button><button type="button" class="nbtn hide-narrow" data-a="always">Always allow</button><button type="button" class="nbtn go" data-a="allow">Allow</button></div>${details(s, places, true)}`;
    el.querySelectorAll(".nbtn").forEach(b => b.addEventListener("click", e => { e.stopPropagation(); if (opt.answer) opt.answer(s, b.dataset.a); }));
  } else {
    const sub = s.st === "done" ? `<span>${s.last ? "“" + s.last + "”" : "Done"}</span>` : `<span>${s.sub}</span>`;
    el.className = "brow" + (s.st === "done" ? " done" : "");
    el.innerHTML = `<div class="qrow">${pose}<div class="tx"><div><span class="t">${s.name}</span>${tags}</div><div class="s">${sub}</div></div><span class="gl">${end}</span></div>${details(s, places, false)}`;
  }
  if (opt.show) el.classList.add("show");
  // No hover on a phone: a tap shows the details instead.
  el.addEventListener("pointerup", e => { if (e.pointerType !== "mouse" && !e.target.closest("button")) el.classList.toggle("show"); });
  el._stage = () => { const st = new Stage(el.querySelector("canvas"), anim, s.color); if (opt.list) { stages.pop(); opt.list.push(st); } return st; };
  return el;
}

/* ---------- what's running: his day on a loop ---------- */
const PLAYABLE = VERBS.filter(w => byId[VERB_ANIM[w]]);
const HOBBIES = [["fish", "Gone fishing"], ["kite", "Flying a kite"], ["gaming", "Gaming"], ["guitar", "Guitar"], ["icecream", "Ice cream"], ["telescope", "Stargazing"],
  ["cat", "Cat time"], ["surf", "Surfing"], ["headphones", "Vibing"], ["tea", "Tea time"], ["skate", "Skating"], ["read", "Reading"], ["sunbathe", "Sunbathing"],
  ["bubbles", "Bubbles"], ["sax", "Jazz hour"], ["paint", "Painting"], ["water", "Gardening"], ["balloons", "Floating"], ["lollipop", "Lollipop"], ["yawn", "Big stretch"]].filter(([id]) => byId[id]);
const CELEBRATE = ["confetti", "trophy", "dance"].filter(id => byId[id]);
const W = "#D97757", H = "#7FB3E0";   // the Work and Home accounts' colours
const PEOPLE = {
  a: { name: "recipe-box", model: "Opus 5.5", acct: ["Work", W], color: "#6AB7D9", ctx: 38, branch: "fix/date-check", lines: ["+48", "−12", "3 files"], todo: "2 of 5 · Fix the date check", cost: "$0.84", cmd: "npm test" },
  b: { name: "trail-map", model: "Sonnet 5.5", acct: ["Home", H], color: "#E8C66A", ctx: 64, branch: "main", lines: ["+212", "−38", "7 files"], server: "localhost:5173", helpers: 2, cost: "$1.12" },
  c: { name: "pixel-garden", model: "Opus 5.5", acct: ["Work", W], color: "#7cc79a", ctx: 83, branch: "sprites", lines: ["+356", "−4", "12 files"], pr: { n: 42, checks: "running" }, cost: "$2.05" },
  d: { name: "budget-bot", model: "Opus 5.5", acct: ["Home", H], color: "#b48ad9", ctx: 92, branch: "fix/rounding", lines: ["+31", "−9", "2 files"], tests: { ok: true, text: "94 passed" }, pr: { n: 88, checks: "passed" }, cost: "$0.47",
       last: "Fixed the rounding bug. All 94 tests pass and the pull request is up." },
};
const verbOf = {};
const S = (id, st, sub, age, extra) => { if (!verbOf[id]) verbOf[id] = pick(PLAYABLE); return Object.assign({}, PEOPLE[id], { id, st, sub, age, verb: verbOf[id] }, extra); };
const SCENES = [
  () => [S("a", "working", "Editing Button.tsx", "2m"), S("b", "working", "Running tests", "5m")],
  () => [S("a", "waiting", "Wants to run npm test", "now", { ask: "Run npm test?" }), S("b", "working", "Running tests", "6m")],
  () => Object.assign([S("a", "working", "Running npm test", "12s", { tests: { ok: false, text: "2 failed" } }), S("b", "working", "Running tests", "7m")],
    { msg: { anim: "facepalm", text: "Tests failed", tone: "bad" } }),
  () => Object.assign([S("a", "working", "Fixing the date check", "1m"), S("c", "working", "Drawing the sprites", "1m")],
    { msg: { anim: "carry", text: "Pushed to main", tone: "" } }),
  () => [S("d", "done", "", "now")],
  () => [],
  () => [],
];
let scene = 0, sessions = SCENES[0](), verb = pick(PLAYABLE), hobby = pick(HOBBIES), party = pick(CELEBRATE);

const notch = document.getElementById("notch"), statusEl = document.getElementById("status"), rowsEl = document.getElementById("rows"), usageEl = document.getElementById("usage");
const main = new Stage(document.getElementById("clawd"), "type");
usageEl.innerHTML = `<span title="Work: 72% of the 5-hour limit left. Resets 3:50 PM.">${ring(72, W, 15, 2)}72%</span><span title="Home: 41% of the 5-hour limit left. Resets 6:10 PM.">${ring(41, H, 15, 2)}41%</span>`;

/* Both wings are as wide as the words need (at least 56 points), so the notch stays centred on the camera. Same rule as the app. */
const measure = document.createElement("canvas").getContext("2d");
/* The little star Claude Code shows while it works: a dot that grows into a star and back. */
const SPIN = ["·", "✢", "✳︎", "✶", "✻", "✽", "✻", "✶", "✳︎", "✢"];
let last = { text: "", extra: 0 };
function fitWings(text, extra) {
  last = { text, extra };
  const u = document.getElementById("clawd").offsetWidth / 48;   // one app point, in pixels (Clawd is 48 points wide)
  measure.font = getComputedStyle(statusEl).font;
  const words = Math.ceil(measure.measureText(text).width / u);
  notch.style.setProperty("--wing", Math.max(56, words + 20 + extra) * u + "px");   // a pill or a spinner takes 18 more
}

let pinned = null;   // an animation another page asked the notch to show
function closed() {
  if (pinned) return pinned;
  const ask = sessions.find(s => s.st === "waiting");
  const phone = innerWidth < 520;   // a phone's menu bar has room for fewer words
  if (ask) return { anim: "flagjump", text: phone ? "Needs you" : ask.ask || "Needs you", tone: "need", color: ask.color };
  if (sessions.msg && byId[sessions.msg.anim]) return Object.assign({ color: sessions[0].color }, sessions.msg);
  const done = sessions.find(s => s.st === "done");
  if (done) return { anim: party, text: "Done", tone: "done", color: done.color };
  const busy = sessions.filter(s => s.st === "working");
  // Working: Clawd's own word for it, and how many sessions are busy when it's more than one.
  if (busy.length) return { anim: VERB_ANIM[verb], text: verb + "…" + (busy.length > 1 && !phone ? " · " + busy.length : ""), tone: "", color: busy[0].color };
  // Nothing running: Clawd has his day off, and the right side shows usage left.
  return { anim: hobby[0], text: "72%", tone: "", color: W };
}
function answer(s, how) {
  s.st = "working"; s.age = "now";
  s.sub = how === "deny" ? "Trying another way" : how === "always" ? "Running npm test (allowed from now on)" : "Running npm test";
  render();
}
function render() {
  const m = closed();
  main.set(m.anim, m.color);
  statusEl.className = "wr" + (m.tone ? " " + m.tone : "");
  statusEl.textContent = "";
  const words = document.createElement("span"); words.textContent = m.text; statusEl.append(words);
  // New words fade in once the notch has grown to fit them, so they're never cut off on the way.
  if (!RM && m.text !== last.text) { words.style.opacity = 0; words.style.transition = "opacity .2s"; setTimeout(() => { words.style.opacity = 1; }, 260); }
  fitWings(m.text, m.tone === "need" ? 18 : 0);
  rowsEl.textContent = ""; stages.length = 1;
  if (!sessions.length) {
    const z = document.createElement("div"); z.className = "zero";
    z.innerHTML = `<canvas aria-hidden="true"></canvas><b>All caught up</b><span>Nothing running. ${hobby[1]} for now.</span><small>Today: 5 sessions · 2h 40m of work · 31 files</small>`;
    rowsEl.append(z);
    new Stage(z.querySelector("canvas"), hobby[0]);
    return;
  }
  // Needs you first, as in the app.
  [...sessions].sort((x, y) => (y.st === "waiting") - (x.st === "waiting")).forEach(s => {
    s.party = party;
    const el = session(s, { answer });
    if (s.st === "done") { el.style.cursor = "pointer"; el.title = "Click to clear"; el.addEventListener("click", e => { e.stopPropagation(); sessions = sessions.filter(x => x !== s); render(); }); }
    rowsEl.append(el); el._stage();
  });
}

/* ---------- open on hover, like the app ---------- */
const hint = document.getElementById("hint");
const touch = matchMedia("(hover: none)").matches;
if (touch && hint) hint.textContent = "Tap the notch.";
let isOpen = false, openTimer, closeTimer;
function setOpen(v) {
  if (v === isOpen) return;
  isOpen = v; notch.classList.toggle("open", v); notch.setAttribute("aria-expanded", String(v));
  requestAnimationFrame(() => stages.forEach(s => { s.fit(); s.paint(); }));
}
notch.addEventListener("pointerenter", e => { if (e.pointerType !== "mouse") return; clearTimeout(closeTimer); openTimer = setTimeout(() => setOpen(true), 90); });
notch.addEventListener("pointerleave", e => { if (e.pointerType !== "mouse") return; clearTimeout(openTimer); closeTimer = setTimeout(() => setOpen(false), 280); });
notch.addEventListener("click", e => { if (e.pointerType !== "mouse" && !e.target.closest(".brow, .card")) setOpen(!isOpen); });
notch.addEventListener("keydown", e => {
  if ((e.key === "Enter" || e.key === " ") && e.target === notch) { e.preventDefault(); setOpen(!isOpen); }
  if (e.key === "Escape") setOpen(false);
});
document.addEventListener("click", e => { if (isOpen && !notch.contains(e.target)) setOpen(false); });
addEventListener("resize", () => { fitWings(last.text, last.extra); stages.forEach(s => { s.fit(); s.paint(); }); });

/* The day moves on by itself, but waits while you're looking inside. */
const dayListeners = [];
render();
if (!RM) {
  setInterval(() => {
    if (isOpen || pinned) return;
    scene = (scene + 1) % SCENES.length;
    if (scene === 0) Object.keys(verbOf).forEach(k => delete verbOf[k]);
    sessions = SCENES[scene](); party = pick(CELEBRATE);
    if (!sessions.length) hobby = pick(HOBBIES.filter(h => h !== hobby));
    render(); dayListeners.forEach(f => f());
  }, 3600);
  setInterval(() => {   // a new status word now and then
    if (isOpen || pinned || !sessions.length || sessions.some(s => s.st !== "working") || sessions.msg) return;
    verb = pick(PLAYABLE.filter(w => w !== verb)); render();
  }, 2600);
  const loop = now => { for (const s of stages) s.paint(now); requestAnimationFrame(loop); };
  requestAnimationFrame(loop);
}

/* ---------- the clock ---------- */
function tick() {
  const d = new Date();
  document.getElementById("date").textContent = d.toLocaleDateString(undefined, { weekday: "short", day: "numeric", month: "short" });
  document.getElementById("time").textContent = d.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" });
}
tick(); setInterval(tick, 15000);

/* ---------- for the pages: their own pixel stages, pieces of notch, and one animation in the real notch ---------- */
window.NB = { A, RM, byId, HOBBIES, PLACES, VERBS: PLAYABLE, VERB_ANIM, ring, check, icons: I, pick,
  /* A Clawd on any canvas. The page paints it (stage.paint(now)) so it can skip the ones off screen. */
  stage(cv, anim, color) { const s = new Stage(cv, anim, color); stages.pop(); return s; },
  /* A sample session ("a" to "d") in a state, and the element that draws it. Call el._stage() once it's in the page. */
  sample: S, session,
  play(anim, text) { pinned = byId[anim] ? { anim, text, tone: "", color: W } : null; render(); },
  stop() { if (pinned) { pinned = null; render(); } },
  /* Show a day off with this hobby in the notch (the strip on the home page). */
  dayOff(h) { hobby = h; sessions = []; scene = SCENES.length - 1; render(); },
  hobby: () => (sessions.length ? null : hobby[0]),
  onDay(f) { dayListeners.push(f); } };
})();
