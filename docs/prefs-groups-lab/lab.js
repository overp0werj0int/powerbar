// Groups lab: the operable Preferences window and the icon picker.
// Globals from the other scripts: LAB (widgets.js), ICONS (icons.js),
// CellModel functions (tokens, place, endPad, radius), IconSearch (index, search).
"use strict";

// ============================ Data =============================
const W = (window.LAB && LAB.widgets) || {};
// Live tokens, read from Hyprland and Omarchy while this lab was made.
const TOKENS = { gapsIn: 4, rounding: 0, rowPad: 12, bar: 38, isl: 0 };
const K = tokens({ bar: TOKENS.bar, spacing: 0, mode: "slots" });
const NAME = { keystroke: "Keystroke", everything: "Everything", workspaces: "Workspaces", scratchpeek: "ScratchPeek",
  crashdesk: "Crash Desk", omapop: "Omapop", "config-sync": "Omarchy Config Sync", omaplug: "Plugin Manager", indicators: "Indicators",
  clock: "Clock", postcard: "Postcard", "system-update": "System Update", "keyboard-layout": "Keyboard Layout", omasettings: "OmaSettings",
  weather: "Weather", hymos: "Hymos", "omaproton-vpn": "OmaProton VPN", "notification-center": "Notification Center",
  "easy-capture": "Easy Capture", omatop: "Omatop", "trackpad-pulse": "Trackpad Pulse", monitor: "Monitor", tray: "Tray", tailscale: "Tailscale",
  "power-manager": "Omarchy Power Manager", network: "Network", bluetooth: "Bluetooth", power: "Power",
  "agent-orchestr": "Agent Orchestrator", sessions: "Sessions", "agent-activity": "Agent Activity", agents: "Agents",
  "local-laya": "Local Laya", audio: "Audio", microphone: "Microphone" };
// Where each widget sits today (shell.json, 4 October 2026), grouped or not.
const PLACE = {
  left: ["keystroke", "everything", "agent-orchestr", "sessions", "agents", "workspaces", "local-laya", "scratchpeek", "agent-activity"],
  center: ["crashdesk", "omapop", "omaplug", "config-sync", "microphone", "postcard", "indicators", "clock", "system-update", "keyboard-layout", "omasettings", "weather", "hymos"],
  right: ["omaproton-vpn", "bluetooth", "monitor", "notification-center", "easy-capture", "trackpad-pulse", "audio", "power-manager", "network", "tray", "tailscale", "power", "omatop"],
};
const ZONE_OF = {}; Object.keys(PLACE).forEach(z => PLACE[z].forEach(k => { ZONE_OF[k] = z; }));
// Your two groups as shell.json holds them. Two of AI's keys point at
// widgets that are no longer in the layout (uninstalled plugins).
function startGroups() {
  return [
    { id: "ai", label: "AI", icon: "󰉋", font: "", image: "", tint: "text", face: "text", tooltip: false, badge: true, badgeMode: "sum",
      memberDisplay: "both", section: "left", visibility: "shown",
      items: ["?pw-mubqvtf4-nb4mmpu754", "agent-orchestr", "agents", "sessions", "?pw-mukam4yj-o1c6ybvjo", "agent-activity", "tailscale", "local-laya"] },
    { id: "audio", label: "Audio", icon: "\uf028", font: "", image: "", tint: "text", face: "both", tooltip: undefined, badge: true, badgeMode: "sum",
      memberDisplay: "both", section: "right", visibility: "shown", items: ["audio", "microphone"] },
  ];
}
function freshState() {
  return { groups: startGroups(), sel: "ai", focus: null, gcur: 0, mcur: 0, acur: 0, lifted: null, liftPos: 0, filter: "",
    dissolving: null, picker: null, newCount: 0 };
}
let ST = freshState();
const view = { opt: "shelf", win: 1180 };
const OPTIONS = { today: { label: "Today" }, list: { label: "List tile" }, shelf: { label: "Group shelf", rec: true } };

// ============================ Helpers ==========================
function el(tag, cls, parent, attrs) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (attrs) for (const k in attrs) {
    if (k === "text") e.textContent = attrs[k];
    else if (k === "style") Object.assign(e.style, attrs[k]);
    else if (k.startsWith("on")) e.addEventListener(k.slice(2), attrs[k]);
    else e.setAttribute(k, attrs[k]);
  }
  if (parent) parent.appendChild(e);
  return e;
}
function chip(host, label, value, good) {
  const c = el("span", "chip" + (good === true ? " good" : good === false ? " bad" : ""), host);
  c.innerHTML = "<b>" + label + "</b>" + value;
}
function applyTheme() {
  const c = (window.LAB && LAB.theme && LAB.theme.colors) || {}, root = document.documentElement.style;
  const rgb = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16)).join(", ");
  if (c.foreground) root.setProperty("--fg", rgb(c.foreground));
  if (c.background) root.setProperty("--bg", rgb(c.background));
  if (c.accent) root.setProperty("--acc", c.accent);
  if (c.red) root.setProperty("--urg", c.red);
}
const group = () => ST.groups.find(g => g.id === ST.sel) || null;
const missing = k => k.startsWith("?");
const title = k => missing(k) ? "Missing widget" : NAME[k] || k;
const side = true; // your bar is on the right edge
const zoneName = z => side ? { left: "Top", center: "Center", right: "Bottom" }[z] : { left: "Left", center: "Center", right: "Right" }[z];
const visName = v => ({ shown: "on the bar", managed: "on demand", hidden: "hidden" })[v];
function members(g) { return g ? g.items : []; }
function grouped() { const s = new Set(); ST.groups.forEach(g => g.items.forEach(k => s.add(k))); return s; }

// A widget's face where the bar has never drawn it: Powerbar's fallback glyph.
function face(k, scale, parent) {
  const d = W[k];
  if (d) return el("img", "face", parent, { src: "w/" + k + ".png", alt: "", style: { width: d.w * scale + "px", height: d.h * scale + "px" } });
  const g = el("span", "face", parent, { style: { width: 27 * scale + "px", height: TOKENS.bar * scale + "px", display: "grid", placeItems: "center" } });
  const i = el("i", null, g, { style: { width: "11px", height: "11px", display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1.5px" } });
  for (let n = 0; n < 4; n++) el("b", null, i, { style: { background: "rgb(var(--fg))", borderRadius: "1px" } });
  return g;
}

// ===================== Ink, measured like the bar =====================
const measureCtx = document.createElement("canvas").getContext("2d");
function fontFor(kind) { return kind === "omarchy" ? '12px "omarchy"' : kind === "emoji" ? '12px "Noto Color Emoji", "Apple Color Emoji", sans-serif' : '12px "Bar Mono"'; }
function inkOf(text, kind) {
  measureCtx.font = fontFor(kind);
  const m = measureCtx.measureText(text);
  return { start: -m.actualBoundingBoxLeft, length: m.actualBoundingBoxLeft + m.actualBoundingBoxRight, advance: m.width };
}
const isEmoji = s => /\p{Extended_Pictographic}/u.test(s);
function iconKind(g) { return g.image ? "image" : g.font === "omarchy" ? "omarchy" : isEmoji(g.icon) ? "emoji" : "glyph"; }
// The runs a group's face draws: its icon, its name, or both (two spaces
// apart, as Bar.qml draws "both"). Each run keeps its own font, so the
// Omarchy logo stays the logo next to a name.
function faceRuns(g, faceMode) {
  const f = faceMode || g.face;
  const icon = g.image ? { kind: "image", src: g.image, tint: g.tint, w: 16 } : { kind: iconKind(g), text: g.icon };
  if (f === "glyph") return [icon];
  if (f === "text") return [{ kind: "glyph", text: g.label }];
  return [icon, { kind: "gap", text: "  " }, { kind: "glyph", text: g.label }];
}
function runsInk(runs) {
  let x = 0, start = null, end = 0;
  runs.forEach(r => {
    if (r.kind === "image") { if (start === null) start = x; end = x + r.w; r.x = x; x += r.w; return; }
    const m = inkOf(r.text, r.kind === "gap" ? "glyph" : r.kind);
    r.x = x;
    if (r.kind !== "gap") { if (start === null) start = x + m.start; end = x + m.start + m.length; }
    x += m.advance;
  });
  return { start: start || 0, length: Math.max(0, end - (start || 0)) };
}
// One island holding one face, at the bar's size: the slot from CellModel,
// the bar's end padding, the highlight cell when `lit`.
function drawFace(parent, g, opts) {
  opts = opts || {};
  const runs = faceRuns(g, opts.face);
  const ink = runsInk(runs);
  const glyphy = runs.length === 1 && runs[0].kind !== "glyph" || (runs.length === 1 && runs[0].kind === "glyph" && (opts.face || g.face) === "glyph");
  const p = place(K, ink.length, runs.length === 1 && (opts.face || g.face) === "glyph", true);
  const pad = endPad(K, p.spill);
  const isl = el("span", "island", parent, { style: { width: pad * 2 + p.extent + "px" } });
  if (opts.lit) el("span", "hl", isl, { style: { left: pad + (p.extent - p.cell) / 2 + "px", width: p.cell + "px", background: "rgba(var(--fg), .16)" } });
  const x0 = pad + p.inkStart - ink.start;
  runs.forEach(r => {
    if (r.kind === "gap") return;
    if (r.kind === "image") {
      const s = { left: x0 + r.x + "px", top: (TOKENS.bar - r.w) / 2 + "px", width: r.w + "px", height: r.w + "px" };
      if (r.tint === "text") el("span", "ink mask", isl, { style: s }).style.setProperty("--src", "url(\"" + r.src + "\")");
      else el("img", "ink", isl, { src: r.src, alt: "", style: Object.assign(s, { objectFit: "contain" }) });
      return;
    }
    el("span", "ink" + (r.kind === "omarchy" ? " omarchy" : r.kind === "emoji" ? " emoji" : ""), isl, { text: r.text, style: { left: x0 + r.x + "px" } });
  });
  isl.dataset.extent = p.extent;
  return isl;
}

// ======================= The window =============================
function columnsFor(width) { return width >= 1100 ? 12 : width >= 820 ? 6 : 1; }
function hints() {
  const f = ST.focus;
  if (ST.picker) return [["↑ ↓ ← →", "Move"], ["enter", "Choose"], ["tab", "Source"], ["esc", ST.picker.query ? "Clear search" : "Close"]];
  if (view.opt === "today") return f === "list" ? [["j k", "Choose"], ["n", "New group"], ["x", "Dissolve"], ["enter", "Edit"], ["esc", "Close"]]
    : [["j k", "Move"], ["h l", "Choose"], ["shift+tab", "Groups"], ["esc", "Close"]];
  if (ST.lifted) return [["j k", "Reorder"], ["space", "Drop"], ["esc", "Cancel"]];
  if (f === "groups") return [["h l", "Choose"], ["n", "New group"], ["x", ST.dissolving ? "Again to dissolve" : "Dissolve"], ["enter", "Edit"], ["tab", "Next tile"], ["1-3", "Pages"], ["esc", "Close"]];
  if (f === "drawer") return [["j k", "Choose"], ["space", "Pick up"], ["x", "Remove"], ["tab", "Next tile"], ["esc", "Close"]];
  if (f === "avail") return [["j k", "Choose"], ["enter", "Add to " + (group() ? group().label : "group")], ["type", "Filter"], ["tab", "Next tile"], ["esc", "Close"]];
  if (f === "well") return [["enter", "Change icon"], ["j k", "Move"], ["tab", "Next tile"], ["esc", "Close"]];
  return [["j k", "Move"], ["tab", "Next tile"], ["h l", "Adjust"], ["space", "Toggle"], ["1-3", "Pages"], ["esc", "Close"]];
}
function drawWindow(host, opt, width, opts) {
  opts = opts || {};
  host.textContent = "";
  const pw = el("div", "pw", host, { style: { width: width + "px", height: (opts.height || 790) + "px" } });
  pw.style.setProperty("--r", TOKENS.rounding + "px");
  pw.style.setProperty("--gap", 2 * TOKENS.gapsIn + "px");
  pw.style.setProperty("--pad", TOKENS.rowPad + "px");
  pw.style.setProperty("--bar", TOKENS.bar + "px");
  pw.style.setProperty("--isl", TOKENS.isl + "px");
  pw.style.setProperty("--hlr", radius(K, TOKENS.isl) + "px");
  if (width < 820) pw.style.padding = "14px 16px 10px";
  const head = el("div", "head", pw);
  el("span", "brand", head, { text: "Powerbar" });
  const tabs = el("div", "tabs", head, { role: "tablist" });
  ["Layout", "Groups", "Bar"].forEach((t, i) => {
    const b = el("span", "tab", tabs, { role: "tab", "aria-selected": String(i === 1) });
    el("span", "kc", b, { text: String(i + 1) });
    if (width >= 820 || i === 1) el("span", null, b, { text: t });
  });
  if (width >= 820) { const c = el("span", "close", head); el("span", "kc", c, { text: "esc" }); el("span", null, c, { text: "Close" }); }
  const body = el("div", "body", pw);
  const r = { pw, body, opt, width };
  if (opt === "today") drawToday(body, r);
  else drawBento(body, opt, columnsFor(width), r, opts);
  const foot = el("div", "foot", pw);
  (opts.static ? staticHints(opt) : hints()).forEach(([k, l]) => {
    const s = el("span", null, foot); const ks = el("span", "k", s); k.split(" ").forEach(x => el("span", "kc", ks, { text: x })); el("span", null, s, { text: l });
  });
  r.foot = foot;
  return r;
}
function staticHints(opt) {
  return opt === "today" ? [["j k", "Choose"], ["n", "New group"], ["x", "Dissolve"], ["enter", "Edit"], ["esc", "Close"]]
    : [["h l", "Choose"], ["n", "New group"], ["x", "Dissolve"], ["enter", "Edit"], ["tab", "Next tile"], ["1-3", "Pages"], ["esc", "Close"]];
}

// ---------- Tiles ----------
function tile(grid, ttl, span, cap, key) {
  const t = el("div", "tile", grid, { role: "group", "aria-label": ttl });
  t.style.gridColumn = "span " + span;
  if (key) t.dataset.tile = key;
  const h = el("div", "th", t);
  el("span", null, h, { text: ttl.toUpperCase(), style: { whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" } });
  if (cap) el("span", "cap", h, { text: cap });
  t.head = h;
  return t;
}
function choice(parent, label, options, value, onChoose, opts) {
  opts = opts || {};
  const row = el("div", "crow" + (opts.dim ? " dim" : ""), parent);
  el("span", "l", row, { text: label });
  const set = el("div", "chipset", row, { role: "radiogroup", "aria-label": label, tabindex: "0", "data-ctl": "choice" });
  options.forEach(([v, l]) => el("button", null, set, { text: l, "aria-pressed": String(v === value), tabindex: "-1", onclick: () => { if (!opts.dim) onChoose(v); } }));
  set.addEventListener("keydown", e => {
    const i = options.findIndex(o => o[0] === value);
    if (e.key === "h" || e.key === "ArrowLeft") { if (i > 0 && !opts.dim) onChoose(options[i - 1][0]); e.preventDefault(); e.stopPropagation(); }
    if (e.key === "l" || e.key === "ArrowRight") { if (i < options.length - 1 && !opts.dim) onChoose(options[i + 1][0]); e.preventDefault(); e.stopPropagation(); }
  });
  if (opts.desc) el("span", "d", row, { text: opts.desc });
  return row;
}
function toggle(parent, label, on, onFlip, opts) {
  opts = opts || {};
  const row = el("div", "crow" + (opts.dim ? " dim" : ""), parent);
  el("span", "l", row, { text: label });
  const sw = el("button", "sw", row, { role: "switch", "aria-checked": String(!!on), "aria-label": label, "data-ctl": "toggle", onclick: () => onFlip(!on) });
  sw.addEventListener("keydown", e => { if (e.key === " " || e.key === "Enter") { onFlip(!on); e.preventDefault(); e.stopPropagation(); } });
  if (opts.desc) el("span", "d", row, { text: opts.desc });
  return row;
}
function edit(patch) { const g = group(); if (g) Object.assign(g, patch); rerender(); }

// ---------- The bento page (Group shelf, or List tile) ----------
function drawBento(body, opt, cols, r, opts) {
  const scroll = el("div", "scroll", body);
  const grid = el("div", "bento", scroll); grid.style.setProperty("--cols", cols);
  r.scroll = scroll; r.grid = grid;
  const g = group();
  if (opt === "list") {
    const lt = tile(grid, "Groups", cols === 12 ? 3 : cols, "n New", "groups");
    drawGroupList(lt);
    const gt = drawGroupTile(grid, g, cols === 12 ? 9 : cols, cols === 12 ? 2 : cols === 6 ? 2 : 1);
    drawDrawerTile(grid, g, cols === 12 ? 6 : cols, r);
    drawAvailTile(grid, g, cols === 12 ? 6 : cols);
    capAvail(r, cols);
    return;
  }
  const gs = tile(grid, "Groups", cols, cols > 1 ? "Your groups as the bar draws them" : "", "groups");
  drawGroupShelf(gs);
  if (!g) {
    const e = tile(grid, "No group selected", cols, "", "empty");
    el("p", "sub", e, { text: ST.groups.length ? "Choose a group above." : "No groups yet. A group gathers related widgets behind one icon on the bar. Press n to make your first.", style: { fontSize: "12px", padding: "4px 12px 10px" } });
    return;
  }
  drawGroupTile(grid, g, cols, cols === 12 ? 3 : cols === 6 ? 2 : 1);
  drawDrawerTile(grid, g, cols === 12 ? 7 : cols === 6 ? 3 : 1, r);
  drawAvailTile(grid, g, cols === 12 ? 5 : cols === 6 ? 3 : 1);
  capAvail(r, cols);
}
// The list of widgets scrolls inside its tile; the drawer beside it sets the
// row's height, since it is drawn exactly as it opens.
function capAvail(r, cols) {
  const d = r.pw.querySelector('[data-tile="drawer"]'), a = r.pw.querySelector('[data-tile="avail"]');
  if (!d || !a) return;
  const box = a.querySelector(".avail");
  box.style.maxHeight = "0px";
  const room = d.offsetTop === a.offsetTop ? d.offsetHeight : 260;
  box.style.maxHeight = Math.max(80, room - box.offsetTop - 10) + "px";
}
function focusable(t, key) {
  t.tabIndex = 0; t.dataset.focus = key;
  if (ST.focus === key) t.classList.add("focus-in");
  t.addEventListener("focus", () => { if (ST.focus !== key) { ST.focus = key; rerender(key); } });
  t.addEventListener("keydown", e => onTileKey(e, key));
}
function drawGroupShelf(t) {
  const shelf = el("div", "gshelf", t);
  focusable(t, "groups");
  ST.groups.forEach((g, i) => {
    const c = el("div", "gcard" + (g.id === ST.sel ? " cur" : "") + (ST.dissolving === g.id ? " dissolving" : "") + (g.visibility === "hidden" ? " hiddeng" : ""), shelf,
      { onclick: () => { ST.sel = g.id; ST.dissolving = null; ST.focus = "groups"; rerender("groups"); } });
    drawFace(c, g);
    const n = g.items.filter(k => !missing(k)).length;
    const tx = el("span", "gt", c);
    el("span", "gn", tx, { text: g.label });
    el("span", "gl", tx, { text: ST.dissolving === g.id ? "x again to dissolve" : n + (n === 1 ? " widget, " : " widgets, ") + zoneName(g.section).toLowerCase() + (g.visibility === "shown" ? "" : ", " + visName(g.visibility)) });
  });
  el("div", "gcard new", shelf, { text: "+ New group", onclick: () => newGroup() });
}
function drawGroupList(t) {
  focusable(t, "groups");
  const box = el("div", null, t, { style: { display: "grid", gap: "4px", padding: "2px 6px 4px" } });
  ST.groups.forEach(g => {
    const c = el("div", "gcard" + (g.id === ST.sel ? " cur" : ""), box, { style: { gridTemplateColumns: "auto minmax(0,1fr)", display: "grid", alignItems: "center", gap: "8px" },
      onclick: () => { ST.sel = g.id; rerender("groups"); } });
    drawFace(c, g, { face: "glyph" });
    const txt = el("div", null, c);
    el("div", null, txt, { text: g.label, style: { fontWeight: 700, fontSize: "12px" } });
    el("div", "gl", txt, { text: g.items.filter(k => !missing(k)).length + " widgets, " + zoneName(g.section).toLowerCase() });
  });
}
function drawGroupTile(grid, g, span, c) {
  const n = g.items.filter(k => !missing(k)).length, gone = g.items.length - n;
  const t = tile(grid, g.label, span, n + (n === 1 ? " widget" : " widgets") + (gone ? ", " + gone + " missing" : "") + ", " + visName(g.visibility) + " at " + zoneName(g.section).toLowerCase(), "group");
  const dissolving = ST.dissolving === g.id;
  el("button", "hbtn" + (dissolving ? " urgent" : ""), t.head, { text: dissolving ? "Again to dissolve" : "Dissolve", onclick: () => dissolve() });
  const cols = el("div", "cols", t, { style: { "--c": c } });
  const c1 = el("div", "col", cols), c2 = el("div", "col", cols), c3 = el("div", "col", cols);
  const nr = el("div", "namerow", c1);
  const well = el("button", "well", nr, { "data-focus": "well", "aria-label": "Group icon, Enter to change", onclick: () => openPicker(well) });
  drawFace(well, g, { face: "glyph" });
  well.title = (g.image ? "Your own icon" : iconName(g)) + ". Enter to change";
  well.addEventListener("focus", () => { if (ST.focus !== "well") { ST.focus = "well"; updateFoot(); } });
  well.addEventListener("keydown", e => { if (e.key === "Enter" || e.key === " ") { openPicker(well); e.preventDefault(); e.stopPropagation(); } });
  const nf = el("input", "field", nr, { value: g.label, "aria-label": "Group name", "data-focus": "name", style: { fontWeight: 700, fontSize: "13px" } });
  nf.addEventListener("change", () => { if (nf.value.trim()) edit({ label: nf.value.trim().slice(0, 80) }); });
  nf.addEventListener("keydown", e => { e.stopPropagation(); if (e.key === "Enter") nf.blur(); if (e.key === "Escape") { nf.value = g.label; nf.blur(); } });
  choice(c1, "Show", [["glyph", "Icon"], ["text", "Name"], ["both", "Both"]], g.face, v => edit({ face: v }));
  const hover = g.tooltip === undefined ? g.face === "glyph" : g.tooltip;
  toggle(c1, "Name on hover", hover, v => edit({ tooltip: v }));
  choice(c2, "Zone", ["left", "center", "right"].map(z => [z, zoneName(z)]), g.section, v => edit({ section: v }));
  choice(c2, "Visibility", [["shown", "On the bar"], ["managed", "On demand"], ["hidden", "Hidden"]], g.visibility, v => edit({ visibility: v }));
  toggle(c3, "Badge", g.badge, v => edit({ badge: v }));
  choice(c3, "Counts", [["sum", "Add up"], ["members", "Busy widgets"]], g.badgeMode, v => edit({ badgeMode: v }),
    { dim: !g.badge, desc: !g.badge ? "Turn on the badge to count" : g.badgeMode === "sum" ? "The members' counts added together" : "How many members have something" });
  return t;
}
function iconName(g) {
  const hit = PICK.index.find(i => i.g === g.icon && (i.font || "") === (g.font || ""));
  return hit ? hit.name : "Icon";
}
// The drawer, drawn as it opens: a menu of rows (Name, Both) or a strip of
// icons (Icon), in the bar's surface and rounding, rows one inset apart.
function drawDrawerTile(grid, g, span, r) {
  const menu = g.memberDisplay !== "native";
  const t = tile(grid, "In the drawer", span, "", "drawer");
  focusable(t, "drawer");
  const hs = el("span", "hshow", t.head);
  el("span", null, hs, { text: "Widgets show" });
  choice(hs, "", [["native", "Icon"], ["name", "Name"], ["both", "Both"]], g.memberDisplay, v => edit({ memberDisplay: v }));
  const box = el("div", "drawerbox", t);
  const list = displayList(g);
  r && (r.drawerTile = t);
  if (!list.length) {
    el("p", "sub", box, { text: "Empty. Add widgets from the list beside this, or drag one here.", style: { fontSize: "11.5px", padding: "6px 0 10px" } });
  } else if (menu) {
    const cells = list.map(x => x.k);
    const widest = Math.max(...cells.map(k => (g.memberDisplay === "both" ? K.cell : K.air) + inkOf(title(k), "glyph").advance + 10));
    const m = el("div", "menu", box, { style: { "--mw": Math.min(320, Math.max(4 * K.cell, widest + 2 * K.inset)) + "px" } });
    list.forEach((x, i) => {
      const row = el("div", "mrow" + (x.ph ? " ph" : "") + (missing(x.k) ? " missing" : "") + (!x.ph && !ST.lifted && i === ST.mcur ? " cur" : ""), m,
        { draggable: "true", "data-member": x.k, onclick: () => { ST.mcur = i; ST.focus = "drawer"; rerender("drawer"); } });
      if (g.memberDisplay === "both") { const ic = el("span", "mi", row); if (!missing(x.k)) face(x.k, 1, ic); }
      el("span", "mn", row, { text: title(x.k), style: { paddingLeft: g.memberDisplay === "both" ? "0" : K.air + "px" } });
    });
  } else {
    const s = el("div", "strip", box);
    list.forEach((x, i) => {
      const w = W[x.k] ? W[x.k].w : 27;
      const b = el("span", "slotbox" + (x.ph ? " ph" : "") + (!x.ph && !ST.lifted && i === ST.mcur ? " cur" : ""), s,
        { draggable: "true", "data-member": x.k, style: { width: Math.max(K.cell, w) + "px" }, onclick: () => { ST.mcur = i; ST.focus = "drawer"; rerender("drawer"); } });
      if (!missing(x.k)) face(x.k, 1, b);
    });
  }
  wireDrop(box, "members");
  // The selected member's badge source: read from the live widget, or a
  // property you name.
  const cur = !ST.lifted && list[ST.mcur] && !missing(list[ST.mcur].k) ? list[ST.mcur].k : null;
  const bl = el("div", "badgeline", t);
  if (cur) {
    const known = { "system-update": "updateCount", "notification-center": "unseenCount" }[cur];
    el("span", "t", bl).innerHTML = "Badge from <b>" + title(cur) + "</b>: " + (known ? "<b>" + known + "</b>" : "detected");
    el("input", "field", bl, { placeholder: "Count: detected", "aria-label": "Count property", style: { fontSize: "11px", padding: "4px 7px" } });
    el("input", "field", bl, { placeholder: "Urgent: detected", "aria-label": "Urgent property", style: { fontSize: "11px", padding: "4px 7px" } });
    bl.querySelectorAll("input").forEach(i => i.addEventListener("keydown", e => e.stopPropagation()));
  } else if (list[ST.mcur] && missing(list[ST.mcur].k)) {
    el("span", "t", bl, { text: "This widget is no longer installed. x removes it from the group." });
  }
  return t;
}
function displayList(g) {
  const items = g.items.filter(k => k !== ST.lifted).map(k => ({ k }));
  if (ST.lifted && g.items.includes(ST.lifted)) items.splice(Math.min(ST.liftPos, items.length), 0, { k: ST.lifted, ph: true });
  if (DRAG.over === "members" && DRAG.key && !g.items.includes(DRAG.key)) items.splice(Math.min(DRAG.pos, items.length), 0, { k: DRAG.key, ph: true });
  return items;
}
function availList(g) {
  const used = grouped(), q = ST.filter.trim().toLowerCase();
  const out = [];
  ["left", "center", "right"].forEach(z => PLACE[z].forEach(k => {
    if (used.has(k)) return;
    if (q && !title(k).toLowerCase().includes(q) && !k.includes(q)) return;
    out.push(k);
  }));
  return out;
}
function drawAvailTile(grid, g, span) {
  const list = availList(g);
  const t = tile(grid, "Not in a group", span, list.length + " widgets", "avail");
  focusable(t, "avail");
  const f = el("input", "field", el("div", null, t, { style: { padding: "2px 6px 2px" } }), { value: ST.filter, placeholder: "Filter widgets", "aria-label": "Filter widgets", "data-focus": "filter" });
  f.addEventListener("input", () => { ST.filter = f.value; ST.acur = 0; rerender("filter"); });
  f.addEventListener("keydown", e => { e.stopPropagation(); if (e.key === "ArrowDown") t.focus(); if (e.key === "Escape") { if (f.value) { ST.filter = ""; rerender("filter"); } else t.focus(); } });
  const box = el("div", "avail", t);
  let zone = null;
  list.forEach((k, i) => {
    if (ZONE_OF[k] !== zone) { zone = ZONE_OF[k]; el("span", "zhd", box, { text: zoneName(zone) }); }
    const c = el("span", "wc" + (i === ST.acur ? " cur" : ""), box, { draggable: "true", "data-avail": k, title: "Click to add to " + (g ? g.label : "the group"),
      onclick: () => { if (g) { g.items.push(k); ST.acur = Math.min(ST.acur, list.length - 2); rerender("avail"); } } });
    face(k, 0.8, c);
    el("span", "nm", c, { text: title(k) });
  });
  if (!list.length) el("span", "zhd", box, { text: ST.filter ? "No widgets match." : "Every widget is in a group." });
  wireDrop(box, "avail");
  return t;
}

// ---------- Today: the list beside a scrolling form ----------
const STOCK = ["\u{f024b}", "\u{e900}", "\u{f14fb}", "\u{f028}", "\u{eee8}", "\u{f02cb}", "\u{f036c}", "\u{f036d}", "\u{f0928}", "\u{f0200}", "\u{f092e}", "\u{f00af}", "\u{f00b1}", "\u{f0379}", "\u{f037a}", "\u{f0079}", "\u{f0954}", "\u{f040a}", "\u{f03e4}", "\u{f075a}", "\u{f030c}", "\u{f021}", "\u{f0590}"];
function drawToday(body, r) {
  const wrap = el("div", "t-wrap", body);
  const list = el("div", "t-list", wrap);
  const rows = el("div", "t-rows", list, { tabindex: "0" });
  rows.addEventListener("focus", () => { ST.focus = "list"; updateFoot(); });
  ST.groups.forEach(g => {
    const row = el("div", "t-row" + (g.id === ST.sel ? " cur" : ""), rows, { onclick: () => { ST.sel = g.id; rerender(); } });
    el("span", "gi" + (g.font === "omarchy" ? " omarchy" : ""), row, { text: g.image ? "◆" : g.icon });
    const tx = el("div", null, row);
    el("b", null, tx, { text: g.label });
    el("span", null, tx, { text: g.items.length + " widgets, " + (g.visibility === "managed" ? "in the " : "on the ") + g.section });
  });
  const nb = el("div", "t-new", list); el("span", null, nb, { text: "+ New group" }); el("span", "kc", nb, { text: "n" });
  el("div", "t-sep", wrap);
  const ed = el("div", "t-ed", wrap, { tabindex: "-1" });
  r.scroll = ed;
  const g = group();
  if (!g) return;
  const h = el("div", "hdr", ed);
  el("span", null, el("div", "bd", h), { text: g.face === "text" ? g.label.slice(0, 2) : g.icon });
  el("div", "nf", h, { text: g.label });
  el("h4", null, ed, { text: "Icon" });
  const gr = el("div", "t-grid", ed);
  STOCK.forEach((s, i) => el("span", (i === 1 ? "omarchy" : "") + (s === g.icon ? " sel" : ""), gr, { text: s }));
  el("div", null, ed, { text: "Group", style: { fontSize: "10px", opacity: .55, marginTop: "6px" } });
  el("h4", null, ed, { text: "Placement" });
  todayChoice(ed, "Zone", ["Left", "Center", "Right"], { left: 0, center: 1, right: 2 }[g.section]);
  todayChoice(ed, "Visibility", ["On the bar", "On demand", "Hidden"], ["shown", "managed", "hidden"].indexOf(g.visibility));
  el("h4", null, ed, { text: "On the bar" });
  todayChoice(ed, "Show", ["Icon", "Name", "Both"], ["glyph", "text", "both"].indexOf(g.face));
  todayCard(ed, "Name on hover", "Show the group's name when the pointer rests on its icon");
  todayCard(ed, "Badge", "A live count from the group's widgets, drawn on its icon");
  todayChoice(ed, "Badge counts", ["Add up counts", "Count busy widgets"], 0);
  el("h4", null, ed, { text: "In the drawer" });
  todayChoice(ed, "Widgets show", ["Icon", "Name", "Both"], ["native", "name", "both"].indexOf(g.memberDisplay));
  el("h4", null, ed, { text: "Widgets" });
  el("div", null, ed, { text: "Drag to reorder or move between the lists. Grouped widgets keep their own settings.", style: { fontSize: "11px", opacity: .6, marginBottom: "10px" } });
  const ls = el("div", "t-lists", ed);
  [["In this group", g.items], ["Available", availList(g)]].forEach(([ttl, items]) => {
    const c = el("div", null, ls);
    const lt = el("div", "lt", c); el("span", null, lt, { text: ttl }); el("span", null, lt, { text: String(items.length), style: { opacity: .45 } });
    if (ttl === "Available") el("div", "field", c, { text: "Filter widgets", style: { marginBottom: "8px", opacity: .6, fontSize: "12px" } });
    const fr = el("div", "fr", c);
    if (ttl === "In this group") r.todayMembers = c;
    items.slice(0, 10).forEach(k => { const d = el("div", null, fr); if (!missing(k)) face(k, 0.8, d); el("span", null, d, { text: missing(k) ? "Unavailable widget" : title(k) }); });
  });
  el("h4", null, ed, { text: "Dissolve group" });
  el("div", null, ed, { text: "Its widgets return to the places they had before they were grouped.", style: { fontSize: "11px", opacity: .6 } });
  el("div", "t-new", ed, { text: "Dissolve " + g.label, style: { justifyContent: "flex-start", width: "max-content", margin: "8px 0 20px", padding: "7px 14px" } });
}
function todayChoice(p, l, opts, on) {
  const row = el("div", "t-c", p); el("span", null, row, { text: l });
  const cs = el("div", "chipset", row); opts.forEach((o, i) => el("button", null, cs, { text: o, "aria-pressed": String(i === on), tabindex: "-1" }));
}
function todayCard(p, l, d) {
  const c = el("div", "t-card", p); el("b", null, c, { text: l, style: { fontSize: "12.5px" } }); el("button", "sw", c, { "aria-checked": "true", tabindex: "-1", style: { gridRow: "span 2" } }); el("span", null, c, { text: d });
}

// ======================= Keyboard and pointer =======================
function onTileKey(e, key) {
  if (e.ctrlKey || e.altKey || e.metaKey) return;
  if (e.target !== e.currentTarget) return;
  const g = group();
  const k = e.key;
  let done = true;
  if (key === "groups") {
    const n = ST.groups.length;
    const i = ST.groups.findIndex(x => x.id === ST.sel);
    if (k === "l" || k === "ArrowRight" || (view.opt === "list" && (k === "j" || k === "ArrowDown"))) { if (i < n - 1) { ST.sel = ST.groups[i + 1].id; ST.dissolving = null; } }
    else if (k === "h" || k === "ArrowLeft" || (view.opt === "list" && (k === "k" || k === "ArrowUp"))) { if (i > 0) { ST.sel = ST.groups[i - 1].id; ST.dissolving = null; } }
    else if (k === "n") return newGroup(), e.preventDefault();
    else if (k === "x" || k === "Delete") dissolve();
    else if (k === "Enter") { const w = hero.pw.querySelector(".well"); if (w) { w.focus(); e.preventDefault(); return; } }
    else if (k === "j" || k === "ArrowDown") { stepFocus(1); e.preventDefault(); return; }
    else done = false;
  } else if (key === "drawer" && g) {
    const n = g.items.length;
    if (ST.lifted) {
      if (k === "j" || k === "ArrowDown" || k === "l" || k === "ArrowRight") ST.liftPos = Math.min(n - 1, ST.liftPos + 1);
      else if (k === "k" || k === "ArrowUp" || k === "h" || k === "ArrowLeft") ST.liftPos = Math.max(0, ST.liftPos - 1);
      else if (k === " " || k === "Enter") { const from = g.items.indexOf(ST.lifted); g.items.splice(from, 1); g.items.splice(ST.liftPos, 0, ST.lifted); ST.mcur = ST.liftPos; ST.lifted = null; }
      else if (k === "Escape") ST.lifted = null;
      else done = false;
    } else if (k === "j" || k === "ArrowDown" || k === "l" || k === "ArrowRight") { if (ST.mcur < n - 1) ST.mcur++; else { stepFocus(1); e.preventDefault(); return; } }
    else if (k === "k" || k === "ArrowUp" || k === "h" || k === "ArrowLeft") { if (ST.mcur > 0) ST.mcur--; else { stepFocus(-1); e.preventDefault(); return; } }
    else if (k === " ") { if (g.items[ST.mcur]) { ST.lifted = g.items[ST.mcur]; ST.liftPos = ST.mcur; } }
    else if (k === "x" || k === "Delete") { if (g.items[ST.mcur]) { g.items.splice(ST.mcur, 1); ST.mcur = Math.max(0, Math.min(ST.mcur, g.items.length - 1)); } }
    else done = false;
  } else if (key === "avail" && g) {
    const list = availList(g);
    if (k === "j" || k === "ArrowDown" || k === "l" || k === "ArrowRight") { if (ST.acur < list.length - 1) ST.acur++; else { stepFocus(1); e.preventDefault(); return; } }
    else if (k === "k" || k === "ArrowUp" || k === "h" || k === "ArrowLeft") { if (ST.acur > 0) ST.acur--; else { stepFocus(-1); e.preventDefault(); return; } }
    else if (k === "Enter" || k === " ") { if (list[ST.acur]) { g.items.push(list[ST.acur]); ST.acur = Math.min(ST.acur, list.length - 2); } }
    else if (k.length === 1 && /\S/.test(k)) { ST.filter += k; ST.acur = 0; rerender("filter"); e.preventDefault(); return; }
    else done = false;
  } else done = false;
  if (done) { e.preventDefault(); rerender(key); }
}
// Tab jumps tiles (PrefsBento); j/k at a composite's edge walk the page.
function stepFocus(dir) {
  const stops = [...hero.pw.querySelectorAll("[data-focus], [data-ctl]")];
  const i = stops.indexOf(document.activeElement);
  const next = stops[Math.max(0, Math.min(stops.length - 1, i + dir))];
  if (next) next.focus();
}
function newGroup() {
  ST.newCount++;
  const id = "new-" + ST.newCount;
  ST.groups.push({ id, label: "New group", icon: "󰉋", font: "", image: "", tint: "text", face: "glyph", tooltip: undefined, badge: true, badgeMode: "sum",
    memberDisplay: "native", section: "right", visibility: "shown", items: [] });
  ST.sel = id; ST.dissolving = null;
  rerender();
  const nf = hero.pw.querySelector('[data-focus="name"]');
  if (nf) { nf.focus(); nf.select(); }
}
let dissolveTimer = 0;
function dissolve() {
  const g = group(); if (!g) return;
  if (ST.dissolving !== g.id) { ST.dissolving = g.id; clearTimeout(dissolveTimer); dissolveTimer = setTimeout(() => { ST.dissolving = null; rerender(); }, 3000); rerender(); return; }
  const i = ST.groups.indexOf(g);
  ST.groups.splice(i, 1); ST.dissolving = null;
  ST.sel = ST.groups.length ? ST.groups[Math.min(i, ST.groups.length - 1)].id : null;
  rerender("groups");
}
// Pointer drag between the drawer and the list (HTML drag, one preview).
const DRAG = { key: null, from: null, over: null, pos: 0 };
document.addEventListener("dragstart", e => {
  const m = e.target.closest && e.target.closest("[data-member], [data-avail]");
  if (!m || !hero || !hero.pw.contains(m)) return;
  DRAG.key = m.dataset.member || m.dataset.avail; DRAG.from = m.dataset.member ? "members" : "avail";
  e.dataTransfer.setData("text/plain", DRAG.key); e.dataTransfer.effectAllowed = "move";
});
document.addEventListener("dragend", () => { if (DRAG.key) { DRAG.key = null; DRAG.over = null; rerender(); } });
function wireDrop(box, where) {
  box.addEventListener("dragover", e => {
    if (!DRAG.key) return;
    e.preventDefault();
    let pos = 0;
    if (where === "members") {
      const rows = [...box.querySelectorAll("[data-member]:not(.ph)")];
      const menu = group() && group().memberDisplay !== "native";
      pos = rows.filter(r => { const b = r.getBoundingClientRect(); return menu ? e.clientY > b.top + b.height / 2 : e.clientX > b.left + b.width / 2; }).length;
    }
    if (DRAG.over !== where || DRAG.pos !== pos) { DRAG.over = where; DRAG.pos = pos; rerenderSoon(); }
  });
  box.addEventListener("drop", e => {
    e.preventDefault();
    const g = group(); if (!g || !DRAG.key) return;
    const k = DRAG.key;
    if (where === "members") {
      const at = g.items.indexOf(k);
      if (at >= 0) g.items.splice(at, 1);
      g.items.splice(Math.min(DRAG.pos, g.items.length), 0, k);
    } else if (DRAG.from === "members") g.items.splice(g.items.indexOf(k), 1);
    DRAG.key = null; DRAG.over = null;
    rerender();
  });
}
let soon = 0;
function rerenderSoon() { cancelAnimationFrame(soon); soon = requestAnimationFrame(() => rerender()); }

// ======================= The icon picker =======================
const PICK = { index: index(window.ICONS || { bar: [], logos: [], glyphs: [], emoji: [] }) };
const SOURCES = [["all", "All"], ["bar", "On your bar"], ["omarchy", "Omarchy"], ["emoji", "Emoji"], ["own", "Your own"]];
function sourceOf(i) { return i.source === 0 ? "bar" : i.source === 1 ? "omarchy" : "emoji"; }
function graphemes(s) {
  try { return [...new Intl.Segmenter(undefined, { granularity: "grapheme" }).segment(s)].map(x => x.segment); } catch (e) { return [...s]; }
}
// A pasted or typed single glyph or emoji is offered even when the list lacks it.
function pastedGlyph(q) {
  const t = q.trim(), gs = graphemes(t);
  if (gs.length !== 1) return null;
  const c = gs[0].codePointAt(0);
  return c > 0x2000 ? gs[0] : null;
}
function makePicker(host, target, opts) {
  opts = opts || {};
  const P = { query: "", src: "all", cur: 0, own: null, tint: "text", host, target, opts, flat: [] };
  P.box = el("div", "picker", host, { role: "dialog", "aria-label": "Choose an icon" });
  if (opts.x !== undefined) Object.assign(P.box.style, { left: opts.x + "px", top: opts.y + "px" });
  const h1 = el("div", "ph1", P.box);
  P.input = el("input", "field", h1, { placeholder: "Search " + PICK.index.length.toLocaleString("en") + " icons, or paste one", "aria-label": "Search icons" });
  P.count = el("span", "count", h1);
  P.srcs = el("div", "srcs", P.box, { role: "tablist" });
  P.grid = el("div", "grid", P.box);
  P.foot = el("div", "pf", P.box);
  P.input.addEventListener("input", () => { P.query = P.input.value; P.cur = 0; if (P.src === "own" && !pastedGlyph(P.query)) P.src = "all"; renderPicker(P); });
  P.input.addEventListener("keydown", e => pickerKey(P, e));
  P.box.addEventListener("paste", e => {
    const f = e.clipboardData && e.clipboardData.files && e.clipboardData.files[0];
    if (f) { e.preventDefault(); readOwn(P, f); }
  });
  P.box.addEventListener("dragover", e => { if (e.dataTransfer && [...e.dataTransfer.types].includes("Files")) { e.preventDefault(); if (P.src !== "own") { P.src = "own"; renderPicker(P); } } });
  renderPicker(P);
  return P;
}
function readOwn(P, file) {
  if (!/^image\/(svg\+xml|png)$/.test(file.type)) { P.ownError = "Only SVG or PNG files: " + (file.name || "that file") + " is " + (file.type || "unknown"); P.src = "own"; renderPicker(P); return; }
  if (file.size > 512 * 1024) { P.ownError = file.name + " is " + Math.round(file.size / 1024) + " KB; icons up to 512 KB"; P.src = "own"; renderPicker(P); return; }
  const r = new FileReader();
  r.onload = () => { P.own = { url: r.result, name: file.name, type: file.type }; P.ownError = ""; P.src = "own"; renderPicker(P); };
  r.readAsDataURL(file);
}
function pickerResults(P) {
  if (P.src === "own") return [];
  const t0 = performance.now();
  let list = P.query.trim() ? search(PICK.index, P.query) : PICK.index;
  if (P.src !== "all") list = list.filter(i => sourceOf(i) === P.src);
  P.ms = performance.now() - t0;
  return list;
}
function renderPicker(P) {
  P.srcs.textContent = "";
  SOURCES.forEach(([v, l]) => el("button", null, P.srcs, { text: l, "aria-pressed": String(v === P.src), tabindex: "-1",
    onmousedown: e => e.preventDefault(), onclick: () => { P.src = v; P.cur = 0; renderPicker(P); P.input.focus(); } }));
  P.grid.textContent = "";
  P.flat = [];
  const g = P.target();
  const paste = pastedGlyph(P.query);
  if (P.src === "own") return renderOwn(P, g, paste);
  const list = pickerResults(P);
  P.count.textContent = P.query.trim() ? list.length.toLocaleString("en") + " found" : list.length.toLocaleString("en") + " icons";
  if (paste && !list.some(i => i.g === paste)) {
    const cells = el("div", "cells", P.grid);
    const item = { g: paste, font: "", name: "Pasted", source: 3, pasted: true };
    addCell(P, cells, item, g, "Use " + paste);
  }
  if (!list.length && !paste) { el("div", "empty", P.grid, { text: "No icons match “" + P.query.trim() + "”. Try a simpler word, or paste a glyph or emoji." }); }
  const sections = P.query.trim() ? [["", list]] : [
    ["On your bar", list.filter(i => i.source === 0)], ["Omarchy logos", list.filter(i => i.logo)],
    ["Omarchy", list.filter(i => i.source === 1 && !i.logo)], ["Emoji", list.filter(i => i.source === 2)]].filter(s => s[1].length);
  sections.forEach(([name, items]) => {
    if (name) el("div", "sech", P.grid, { text: name.toUpperCase() });
    const cells = el("div", "cells", P.grid);
    items.forEach(it => addCell(P, cells, it, g));
  });
  P.cur = Math.max(0, Math.min(P.cur, P.flat.length - 1));
  paintCursor(P);
}
function addCell(P, cells, it, g, label) {
  const kind = it.font === "omarchy" ? " omarchy" : isEmoji(it.g) ? " emoji" : "";
  const c = el("span", "ic" + kind + (label ? " use" : "") + (g && !g.image && g.icon === it.g && (g.font || "") === (it.font || "") ? " sel" : ""), cells,
    { title: it.name, role: "option" });
  if (label) { el("span", kind.trim(), c, { text: it.g, style: { fontSize: "17px", fontFamily: kind ? undefined : "var(--mono)" } }); el("span", null, c, { text: label.replace(it.g, "").trim() + " this" }); }
  else c.textContent = it.g;
  const i = P.flat.length;
  P.flat.push({ it, c });
  c.addEventListener("mousedown", e => e.preventDefault());
  c.addEventListener("mouseenter", () => { P.cur = i; paintCursor(P, true); });
  c.addEventListener("click", () => { P.cur = i; choose(P); });
}
function paintCursor(P, fromPointer) {
  P.flat.forEach((f, i) => f.c.classList.toggle("cur", i === P.cur));
  const f = P.flat[P.cur];
  if (f && !fromPointer) {
    const gr = P.grid, top = f.c.offsetTop - gr.offsetTop, bottom = top + f.c.offsetHeight;
    if (top < gr.scrollTop + 4) gr.scrollTop = Math.max(0, top - 30);
    else if (bottom > gr.scrollTop + gr.clientHeight) gr.scrollTop = bottom - gr.clientHeight + 6;
  }
  renderPickFoot(P, f ? f.it : null);
}
// The footer shows the icon under the cursor as the group's face on the bar,
// at 1:1, with its name and where it comes from.
function renderPickFoot(P, it) {
  P.foot.textContent = "";
  const g = P.target();
  if (!it || !g) { el("span", "ds", P.foot, { text: P.src === "own" ? "" : "Nothing under the cursor" }); return; }
  const trial = Object.assign({}, g, { icon: it.g, font: it.font || "", image: "" });
  drawFace(P.foot, trial, { face: g.face === "text" ? "glyph" : g.face });
  const t = el("div", null, P.foot);
  el("div", "nm", t, { text: it.name });
  el("div", "ds", t, { text: it.pasted ? "Pasted, drawn in the bar's font" : it.source === 0 ? "Drawn by a widget on your bar" : it.logo ? "Omarchy's font" : it.source === 1 ? "Used by Omarchy" : "Emoji, keeps its own colours" });
  const kk = el("span", "kk", P.foot); el("span", "kc", kk, { text: "enter" }); el("span", null, kk, { text: "Choose" });
}
function renderOwn(P, g, paste) {
  P.count.textContent = "";
  const d = el("div", "drop" + (P.dragOver ? " over" : ""), P.grid);
  el("span", "big", d, { text: "󰉍" });
  const t = el("div", null, d);
  el("b", null, t, { text: "Drop an SVG or PNG here" });
  el("div", null, t, { text: "or paste one with Ctrl+V: a file copied in your file manager, or a copied image" });
  el("div", null, t, { text: "Up to 512 KB. Powerbar keeps its own copy.", style: { fontSize: "10.5px", opacity: .6, marginTop: "4px" } });
  if (P.ownError) el("div", null, t, { text: P.ownError, style: { color: "var(--urg)", marginTop: "6px" } });
  d.addEventListener("dragover", e => { e.preventDefault(); if (!P.dragOver) { P.dragOver = true; d.classList.add("over"); } });
  d.addEventListener("dragleave", () => { P.dragOver = false; d.classList.remove("over"); });
  d.addEventListener("drop", e => { e.preventDefault(); P.dragOver = false; const f = e.dataTransfer.files[0]; if (f) readOwn(P, f); });
  const pick = el("input", null, d, { type: "file", accept: ".svg,.png,image/svg+xml,image/png", style: { display: "none" } });
  el("button", "kbtn", d, { text: "Choose a file", style: { font: "500 11.5px var(--mono)", color: "rgb(var(--fg))", background: "none", border: "1px solid rgba(var(--fg), .22)", padding: "4px 9px", cursor: "pointer" },
    onclick: () => pick.click() });
  pick.addEventListener("change", () => { if (pick.files[0]) readOwn(P, pick.files[0]); });
  P.foot.textContent = "";
  if (P.own && g) {
    const row = el("div", "ownrow", P.grid);
    drawFace(row, Object.assign({}, g, { image: P.own.url, tint: P.tint }), { face: g.face === "text" ? "glyph" : g.face });
    const cs = el("div", null, row);
    el("div", null, cs, { text: P.own.name, style: { fontSize: "12px", fontWeight: 700, marginBottom: "4px" } });
    const set = el("div", "chipset", cs, { style: { justifyContent: "flex-start" } });
    [["text", "Text colour"], ["own", "Its own colours"]].forEach(([v, l]) => el("button", null, set, { text: l, "aria-pressed": String(P.tint === v),
      onmousedown: e => e.preventDefault(), onclick: () => { P.tint = v; renderPicker(P); } }));
    el("div", null, cs, { text: P.tint === "text" ? "Drawn in the bar's text colour, like your other icons" : "Keeps its colours; they won't follow Light or Dark", style: { fontSize: "10.5px", opacity: .6, marginTop: "3px" } });
    const kk = el("span", "kk", P.foot); el("span", "kc", kk, { text: "enter" }); el("span", null, kk, { text: "Use " + P.own.name });
  } else el("span", "ds", P.foot, { text: "Your icon is drawn 16 px tall, the bar's glyph size." });
}
function choose(P) {
  const g = P.target(); if (!g) return;
  if (P.src === "own") { if (!P.own) return; Object.assign(g, { image: P.own.url, tint: P.tint, icon: "", font: "" }); }
  else { const f = P.flat[P.cur]; if (!f) return; Object.assign(g, { icon: f.it.g, font: f.it.font || "", image: "" }); }
  if (P.opts.onChosen) P.opts.onChosen();
}
function pickerKey(P, e) {
  const k = e.key;
  e.stopPropagation();
  if (k === "Escape") { e.preventDefault(); if (P.input.value) { P.input.value = ""; P.query = ""; P.cur = 0; renderPicker(P); } else if (P.opts.onClose) P.opts.onClose(); return; }
  if (k === "Enter") { e.preventDefault(); choose(P); return; }
  if (k === "Tab") { e.preventDefault(); const i = SOURCES.findIndex(s => s[0] === P.src); P.src = SOURCES[(i + (e.shiftKey ? SOURCES.length - 1 : 1)) % SOURCES.length][0]; P.cur = 0; renderPicker(P); return; }
  if (P.src === "own" || !P.flat.length) return;
  const moveTo = i => { P.cur = Math.max(0, Math.min(P.flat.length - 1, i)); paintCursor(P); e.preventDefault(); };
  if (k === "ArrowRight") return moveTo(P.cur + 1);
  if (k === "ArrowLeft") return moveTo(P.cur - 1);
  if (k === "ArrowDown" || k === "ArrowUp" || k === "PageDown" || k === "PageUp") {
    const rows = k.startsWith("Page") ? Math.max(1, Math.floor(P.grid.clientHeight / 40)) : 1;
    const dir = k === "ArrowDown" || k === "PageDown" ? 1 : -1;
    // Visual rows: the nearest cell in the row above or below, across sections.
    let i = P.cur;
    for (let n = 0; n < rows; n++) i = verticalNeighbour(P, i, dir);
    return moveTo(i);
  }
}
function verticalNeighbour(P, i, dir) {
  const c = P.flat[i].c, top = c.offsetTop, left = c.offsetLeft;
  let rowTop = null, best = i, bestDx = Infinity;
  for (let j = i + dir; j >= 0 && j < P.flat.length; j += dir) {
    const o = P.flat[j].c;
    if (o.offsetTop === top) continue;
    if (rowTop === null) rowTop = o.offsetTop;
    if (o.offsetTop !== rowTop) break;
    const dx = Math.abs(o.offsetLeft - left);
    if (dx < bestDx) { bestDx = dx; best = j; }
  }
  return best;
}
function openPicker(anchor) {
  const g = group(); if (!g) return;
  const pwR = hero.pw.getBoundingClientRect(), aR = anchor.getBoundingClientRect(), k = hero.k || 1;
  const x = Math.min((aR.left - pwR.left) / k, view.win - 488 - 16), y = Math.min((aR.bottom - pwR.top) / k + 6, 790 - 520 - 50);
  ST.picker = makePicker(hero.pw, group, { x: Math.max(16, x), y: Math.max(60, y),
    onChosen: () => { closePicker(); },
    onClose: () => closePicker() });
  ST.picker.query = "";
  updateFoot();
  ST.picker.input.focus();
}
function closePicker() {
  ST.picker = null;
  ST.focus = "well";
  rerender("well");
}

// =========================== Hero ===========================
let hero = null;
function fit(frame, scaler, width, height) {
  const k = Math.min(1, frame.clientWidth / width);
  scaler.style.transform = "scale(" + k + ")";
  frame.style.height = Math.ceil(height * k) + "px";
  return k;
}
function rerender(focusKey) {
  const frame = document.getElementById("hero-frame"), scaler = document.getElementById("hero-scaler");
  const scrollTop = hero && hero.scroll ? hero.scroll.scrollTop : 0;
  const active = document.activeElement;
  const inHero = hero && hero.pw.contains(active);
  const fk = focusKey || (inHero ? (active.dataset.focus || active.closest("[data-focus]") && active.closest("[data-focus]").dataset.focus) : null);
  hero = drawWindow(scaler, view.opt, view.win, {});
  hero.k = fit(frame, scaler, view.win, 790);
  if (hero.scroll) hero.scroll.scrollTop = scrollTop;
  if (fk) {
    const t = hero.pw.querySelector('[data-focus="' + fk + '"]');
    if (t) { t.focus({ preventScroll: true }); if (fk === "filter") { t.selectionStart = t.selectionEnd = t.value.length; } }
  }
  heroChips(measure(hero, view.opt));
  document.querySelectorAll("#opt button").forEach(b => b.setAttribute("aria-pressed", String(b.dataset.v === view.opt)));
  document.querySelectorAll("#win button").forEach(b => b.setAttribute("aria-pressed", String(Number(b.dataset.v) === view.win)));
}
function updateFoot() {
  if (!hero) return;
  hero.foot.textContent = "";
  hints().forEach(([k, l]) => { const s = el("span", null, hero.foot); const ks = el("span", "k", s); k.split(" ").forEach(x => el("span", "kc", ks, { text: x })); el("span", null, s, { text: l }); });
}
// What each option costs, measured on the drawn window.
function measure(r, opt) {
  const sc = r.scroll;
  const viewport = sc ? sc.clientHeight : 0, content = sc ? sc.scrollHeight : 0;
  let membersTop = 0, tabs = 0, settingsShare = 1;
  const base = sc ? sc.getBoundingClientRect().top : 0, k = r.k || 1;
  if (opt === "today") {
    membersTop = r.todayMembers ? (r.todayMembers.getBoundingClientRect().top - base) / k + sc.scrollTop : 0;
    tabs = 9; // offscreen audit: In this group is the 10th focus stop
    settingsShare = (r.width - 56 - 260 - 41) / (r.width - 56);
  } else {
    const d = r.pw.querySelector('[data-tile="drawer"]');
    membersTop = d ? (d.getBoundingClientRect().top - base) / k + sc.scrollTop : 0;
    const order = [...r.pw.querySelectorAll("[data-tile]")].map(t => t.dataset.tile);
    tabs = Math.max(0, order.indexOf("drawer"));
    const lt = r.pw.querySelector('[data-tile="groups"]');
    settingsShare = opt === "list" && lt ? 1 - (lt.getBoundingClientRect().width / k + 8) / ((r.grid.getBoundingClientRect().width / k) || 1) : 1;
  }
  return { viewport: Math.round(viewport), content: Math.round(content), fits: content <= viewport + 1, membersTop: Math.round(membersTop),
    membersInView: membersTop + 60 <= viewport, tabs, settingsShare, icons: opt === "today" ? 23 : PICK.index.length };
}
function heroChips(m) {
  const host = document.getElementById("hero-chips"); host.textContent = "";
  chip(host, "Page", m.content + " / " + m.viewport + " px", m.fits);
  chip(host, "Group's widgets start at", m.membersTop + " px", m.membersInView);
  chip(host, view.opt === "today" ? "Focus stops before them" : "Tab presses to them", String(m.tabs), m.tabs <= 3);
  chip(host, "Width for settings", Math.round(m.settingsShare * 100) + "%", m.settingsShare >= 0.9);
  chip(host, "Icons to choose from", m.icons.toLocaleString("en") + (view.opt === "today" ? "" : " + your own"), m.icons > 23);
}
function onWindowKey(e) {
  if (!hero || !hero.pw.contains(document.activeElement) || ST.picker) return;
  if (e.ctrlKey || e.altKey || e.metaKey) return;
  const tag = document.activeElement.tagName;
  if (tag === "INPUT") return;
  if (e.key === "Tab") {
    // PrefsBento: Tab jumps to the next tile's first control.
    if (view.opt === "today") return;
    const tiles = [...hero.pw.querySelectorAll("[data-tile]")];
    const cur = tiles.findIndex(t => t.contains(document.activeElement));
    const next = tiles[(cur + (e.shiftKey ? tiles.length - 1 : 1)) % tiles.length];
    const first = next.matches("[data-focus]") ? next : next.querySelector("[data-focus], [data-ctl]");
    if (first) { e.preventDefault(); first.focus(); }
    return;
  }
  if (e.key === "j" || e.key === "k" || e.key === "ArrowDown" || e.key === "ArrowUp") {
    const t = document.activeElement;
    if (t.dataset.ctl || t.dataset.focus === "well") { stepFocus(e.key === "j" || e.key === "ArrowDown" ? 1 : -1); e.preventDefault(); }
  }
}

// ======================= Lab sections =======================
function renderDecisions() {
  const rows = [
    ["Page", "Groups becomes a bento page like Layout and Bar: a Groups shelf (span 12), the selected group's tile (span 12), then In the drawer (7) beside Not in a group (5); 6 + 6 rows at 6 columns, one column below 820 px. Gap 2 × <code>gaps_in</code>, the Bar page's corners and tile titles."],
    ["Groups shelf", "Each group drawn as the bar draws it: its island, its slot from <code>CellModel.place</code>, its face (icon, name or both) in the bar's font, size and text colour at 1:1. A line under it: its widget count and zone. A \"+ New group\" card ends the shelf. h/l choose, n makes a group (name field focused, text selected), x twice dissolves. Replaces the 260 px list."],
    ["Group tile", "Titled with the group's name; caption: count, visibility and zone. Dissolve in the header, asked twice like Reset. The icon well (the face as the bar draws it) opens the picker; the name field beside it. Three columns: Show + Name on hover, Zone + Visibility, Badge + Counts (dimmed with its reason while the badge is off). The editor's 64 × 56 wallpaper preview goes."],
    ["In the drawer", "The drawer drawn exactly as it opens, since Preferences closes it: a menu (Name, Both) in the bar's surface and rounding, rows one inset apart, the menu width rule (<code>ManagedModel.menuWidth</code>); or a strip of icons (Icon). Widgets show sits above it. One Tab stop: j/k choose, Space lifts to reorder, x removes. The selected member's badge source (Count, Urgent property) sits under the drawer. Members whose widget was uninstalled leave the group by themselves (see Uninstalled widgets)."],
    ["Not in a group", "Every widget not in a group, by zone, as icon and name (Layout's other shelves). Typing filters; Enter or a click adds to the selected group; drag works both ways with one preview (Layout's drop outline)."],
    ["Icon picker", "A popover from the icon well. Sources: On your bar (glyphs your widgets draw), Omarchy (its font's logo and AI tools, plus the 284 glyphs Omarchy's shell and menus use), Emoji (Omarchy's 1,870 with keywords), Your own. About 2,170 in all; the full Nerd Font is left out. Focus stays in the search field; arrows walk the grid; Enter chooses; Tab changes source; Esc clears, then closes. The footer draws the icon under the cursor as the group's face at 1:1."],
    ["Your own icon", "Drop an SVG or PNG (up to 512 KB) on the picker, choose a file, or paste one (a copied file, or a copied image through <code>wl-paste</code>, as Omarchy's clipboard does). Powerbar copies it to <code>~/.local/share/powerbar/icons/</code>. Colour is a choice: Text colour (default; tinted like the bar's own icons) or Its own colours. A pasted single glyph or emoji is offered as \"Use this\"."],
    ["Config", "New group keys: <code>iconFont</code> (<code>\"omarchy\"</code> or absent), <code>iconImage</code> (a file path), <code>iconTint</code> (<code>\"text\"</code> default, or <code>\"own\"</code>). <code>icon</code> keeps the glyph. Existing groups need no migration."],
    ["Fixes on the way", "\"Both\" draws the icon and the name as two runs, each in its own font (today the Omarchy logo next to a name turns into the Nerd Font's <code>dev-cobol</code>, which shares U+E900). The <code>parent.width</code> TypeError in the member list goes with the list."],
  ];
  rows.push(
    ["Built: symmetry", "<strong>Amended when locked (4 October):</strong> In the drawer and Not in a group are equal halves (6 + 6 at 12 columns, 3 + 3 at 6). Their controls sit in the tile headers, mirroring each other: Widgets show chips on the left, the filter field on the right. Below each: a well of the same height (the drawer's sets it; the list scrolls inside) and a one-line footer at the same height (the member's badge source; how to add)."],
    ["Built: group tile", "A 3 × 3 grid of equal columns whose rows line up, every row the bar's height (38 px): icon and name, Show, Name on hover | Zone, Visibility, what it means | Badge, Counts, what it counts. Filled column by column, so a one-column window reads in the same order. The icon well is the bar's island with the bar's own hover and focus cell."],
    ["Uninstalled widgets", "<strong>Amended 4 October:</strong> Powerbar removes them itself. A member whose key is no longer in the layout is left out whenever groups are read (<code>GroupsModel.groups</code>), and <code>shell.json</code> is cleaned in one write when such keys are found. Nothing to do in Preferences; no missing rows. Your AI group's two dead keys went this way."],
    ["Built: fit", "Offscreen at 1180 × 790 with your shell.json: 614 of 654 px, no scrolling; all 13 focus stops reachable; no warnings. Picker search: 1.2 ms over 2,167 icons in Qt's engine."]);
  const tb = document.getElementById("decision-rows");
  rows.forEach(([a, b]) => { const tr = el("tr", null, tb); el("td", null, tr, { text: a }); el("td", null, tr).innerHTML = b; });
}
function renderFindings() {
  const rows = [
    ["The editor is 1,227 px tall in a 654 px view", "GroupsPreferences.qml:238 PrefsForm, maxContentWidth 720", "Bench AUDIT page 2: viewport 654, content 1227, scrolls"],
    ["The group's widgets come into view after 453 px of scrolling; Dissolve after 573", "Widgets section, :353; Dissolve, :446", "Bench focus stops 10 (In this group, scroll 453) and 13 (Dissolve, scroll 573) of 13"],
    ["A 260 px list column holds two groups", ":81, preferredWidth 260 + 20 spacing + 1 px rule", "23% of the 1,124 px page; rows show an accent-coloured glyph, not the face the bar draws"],
    ["The icon is one of 23 stock glyphs, always open", "IconGrid.qml, GroupsModel.icons", "Takes about 150 px of the page; no search, no emoji, no own icon"],
    ["A preview that is neither the bar nor 1:1", ":247 BarBackdrop 64 × 56, glyph at Style.font.iconLarge (18 px)", "The bar draws the face at 12 px; a name face shows only its first two letters"],
    ["\"Both\" draws the icon in the label's font", "Bar.qml:4884 and LayoutEditor.qml:127: font = Style.font.family unless face is glyph", "U+E900 is the Omarchy logo in the omarchy font and dev-cobol in JetBrainsMono Nerd Font"],
    ["Member lists are fixed 300 px boxes", ":623 preferredHeight 300", "AI's 8 members need 280 px; Audio's 2 leave 230 px empty"],
    ["Missing members show as \"Unavailable widget\"", ":22", "AI holds 2 keys whose plugins are no longer in your layout"],
    ["A member's badge settings appear only while its list has focus", ":409 visible: !!memberList.current", "The section jumps in and out as focus moves"],
    ["A TypeError at startup", ":650 width: parent.width inside RetainedList's factory", "\"Cannot read property 'width' of null\" in the dnd bench (handoff)"],
  ];
  const tb = document.getElementById("findings-rows");
  rows.forEach(r => { const tr = el("tr", null, tb); r.forEach((c, i) => el("td", i === 1 ? "mono" : null, tr, { text: c, style: i === 1 ? { whiteSpace: "normal", fontFamily: "var(--mono)", fontSize: "12px" } : {} })); });
}
function renderRule() {
  const f = document.getElementById("formulas");
  const rows = [
    ["columns = 12 | 6 | 1 by card width ≥ 1100 | ≥ 820", "12", "The Bar page's grid (BentoModel)."],
    ["gap = 2 × gaps_in", 2 * TOKENS.gapsIn + " px", "Hyprland's gap between windows."],
    ["face slot = CellModel.place(ink, glyph)", K.cell + " px cell", "Each group on the shelf and in the icon well, as the bar places it; island ends = endPad."],
    ["menu row = bar − 2 × inset, rows one inset apart", (TOKENS.bar - 2 * K.inset) + " px", "The drawer menu as ManagedDrawer draws it, width min(320, max(4 × cell, widest + 2 × inset))."],
    ["picker = 488 × 520, cell 38", "12 per row", "Above the page, anchored under the icon well, kept inside the card."],
    ["own icon = fits 16 × 16 (GLYPH_INK)", "16 px", "The bar's glyph size, so CellModel gives it a glyph cell."],
  ];
  rows.forEach(([a, v, p]) => { const r = el("div", "r", f); el("span", "f", r, { text: a }); el("span", "v", r, { text: v }); el("p", null, r, { text: p }); });
}
function renderPickerSection() {
  const host = document.getElementById("picker-host");
  const demo = { g: Object.assign({}, startGroups()[0]) };
  let P = null;
  const mount = () => {
    host.textContent = "";
    P = makePicker(host, () => demo.g, { x: 0, y: 0, onChosen: () => { renderPickerChips(demo.g, P); mount(); P.input.focus(); }, onClose: () => { P.input.value = ""; P.query = ""; renderPicker(P); } });
    renderPickerChips(demo.g, P);
  };
  mount();
  const src = document.getElementById("source-rows");
  const I = window.ICONS;
  [
    ["On your bar", I.bar.length, "The glyph each widget draws (<code>~/.cache/powerbar/glyphs.json</code>), named by the widget", I.bar.slice(0, 6).map(b => b.g)],
    ["Omarchy logos", I.logos.length, "Omarchy's own font: its logo and AI tools (Codex, Cursor, Ollama, opencode…)", I.logos.slice(0, 6).map(l => String.fromCodePoint(l[0])), "omarchy"],
    ["Omarchy", I.glyphs.length, "Every Nerd Font glyph in Omarchy's shell, menus and configs, named from the bar font's own glyph names", I.glyphs.slice(0, 6).map(r => String.fromCodePoint(r.c))],
    ["Emoji", I.emoji.length, "Omarchy's emoji picker data (<code>shell/plugins/emojis/emojis.json</code>), with its keywords", I.emoji.slice(0, 6).map(e => e.e), "emoji"],
    ["Your own", "any", "An SVG or PNG you drop or paste, or a glyph or emoji you paste", []],
  ].forEach(([a, n, b, ex, kind]) => {
    const tr = el("tr", null, src);
    const td = el("td", null, tr); el("div", null, td, { text: a });
    const gx = el("div", "gx" + (kind ? " " + kind : ""), td, { text: ex.join(" ") });
    el("td", "mono", tr, { text: typeof n === "number" ? n.toLocaleString("en") : n });
    el("td", null, tr).innerHTML = b;
  });
  const sr = document.getElementById("search-rules");
  [["every word must start a word of the name", "", "Names are split on spaces, hyphens and underscores, so \"volume up\", volume_up and volume-up are the same (Notion's rule)."],
   ["exact 4, starts 3, inside 1 (3+ letters)", "", "Each query word scores its best match; the first word of a name gets +0.5."],
   ["− 0.05 per word in the name", "", "Short names first: \"robot\" before \"robot excited\"."],
   ["ties: your bar, Omarchy, emoji", "", "Then the order the source has (Omarchy's by how often it uses a glyph)."],
   ["one glyph or emoji pasted", "Use this", "Offered first even when it isn't in any list."]].forEach(([a, v, p]) => { const r = el("div", "r", sr); el("span", "f", r, { text: a }); el("span", "v", r, { text: v }); el("p", null, r, { text: p }); });
  const tb = document.getElementById("search-rows");
  let worst = 0;
  ["ai", "audio", "mic", "music", "folder", "robot", "code", "cloud", "game", "brain"].forEach(q => {
    const t0 = performance.now(); const res = search(PICK.index, q); const ms = performance.now() - t0; worst = Math.max(worst, ms);
    const tr = el("tr", null, tb);
    el("td", "mono", tr, { text: q });
    el("td", "mono", tr, { text: String(res.length) });
    const td = el("td", null, tr);
    res.slice(0, 7).forEach(i => { el("span", "gx" + (i.font === "omarchy" ? " omarchy" : isEmoji(i.g) ? " emoji" : ""), td, { text: i.g, title: i.name }); el("span", null, td, { text: " " + i.name.split(" ").slice(0, 2).join(" ") + "   ", style: { color: "var(--muted)", fontSize: "12px" } }); });
    el("td", "mono", tr, { text: ms.toFixed(2) + " ms" });
  });
  document.getElementById("search-note").textContent = "Timed in this browser over " + PICK.index.length.toLocaleString("en") + " icons; slowest " + worst.toFixed(2) + " ms. Qt's JavaScript engine is several times slower than a browser's, which still leaves each keystroke well inside a frame. The picker's grid is a GridView, so only the cells in view exist.";
}
function renderPickerChips(g, P) {
  const host = document.getElementById("picker-chips"); host.textContent = "";
  chip(host, "Icons", PICK.index.length.toLocaleString("en"), null);
  chip(host, "Chosen in this demo", g.image ? "your own image" : g.icon + "  " + iconName(g), null);
  chip(host, "Searches over", "names, widget names, emoji keywords", null);
}
function renderCompare() {
  const host = document.getElementById("compare-rows");
  const saved = { opt: view.opt, focus: ST.focus };
  ST.focus = null;
  ["today", "list", "shelf"].forEach(opt => {
    const row = el("div", "cmp-row", host);
    const n = el("div", "name", row);
    el("h3", null, n, { text: OPTIONS[opt].label + (OPTIONS[opt].rec ? ", recommended" : "") });
    el("p", null, n, { text: opt === "today" ? "The list beside a scrolling form." : opt === "list" ? "Today's list as a tile, settings beside it, drawer and list below." : "Groups as the bar draws them; settings, drawer and list below." });
    const fr = el("div", "frame", row); const sc = el("div", "scaler", fr);
    const r = drawWindow(sc, opt, 1180, { static: true });
    r.k = fit(fr, sc, 1180, 790);
    const m = measure(r, opt);
    const ch = el("div", "chips", n);
    chip(ch, "Page", m.content + " / " + m.viewport, m.fits);
    chip(ch, "Widgets at", m.membersTop + " px", m.membersInView);
    chip(ch, "Settings width", Math.round(m.settingsShare * 100) + "%", m.settingsShare >= 0.9);
  });
  ST.focus = saved.focus;
}
function renderKeys() {
  const rows = [
    ["Groups shelf", "h l", "Choose a group (the tile below follows)"],
    ["Groups shelf", "n", "New group: added at the end, its name field focused with the text selected"],
    ["Groups shelf", "x x", "Dissolve the group (asked twice within 3 s); its widgets go back where they were"],
    ["Groups shelf", "enter", "Into the group tile, on the icon well"],
    ["Icon well", "enter space", "Open the icon picker"],
    ["Group tile", "j k, h l, space", "Walk the controls, change a choice, flip a switch (PrefsForm)"],
    ["In the drawer", "j k", "Choose a member (h l on a strip)"],
    ["In the drawer", "space, j k, space", "Pick up, move, drop. Esc puts it back"],
    ["In the drawer", "x", "Remove from the group; it returns to its place on the bar"],
    ["Not in a group", "j k, enter", "Choose a widget, add it to the group"],
    ["Not in a group", "type", "Filter by name; Esc clears the filter"],
    ["Picker", "type, ↑ ↓ ← →", "Search; walk the grid across sections (focus stays in the field)"],
    ["Picker", "enter, tab, esc", "Choose; next source; clear the search, then close"],
    ["Picker", "ctrl+v", "Paste an image, a copied file, or a glyph or emoji"],
    ["Anywhere", "tab, shift+tab, 1-3, esc", "Next or previous tile, pages, close (innermost first)"],
  ];
  const tb = document.getElementById("key-rows");
  rows.forEach(([a, k, b]) => { const tr = el("tr", null, tb); el("td", null, tr, { text: a }); const td = el("td", null, tr); k.split(", ").forEach(x => el("span", "k", td, { text: x })); el("td", null, tr, { text: b }); });
}
function renderCases() {
  const host = document.getElementById("cases");
  const pwVars = s => { s.style.setProperty("--bar", TOKENS.bar + "px"); s.style.setProperty("--hlr", "0px"); s.style.setProperty("--isl", "0px"); };
  const card = (h, p, draw) => { const c = el("div", "case", host); el("h3", null, c, { text: h }); el("p", null, c, { text: p }); const s = el("div", "stage", c); pwVars(s); draw(s); };
  const ai = startGroups()[0], audio = startGroups()[1];
  card("The Omarchy logo next to a name", "With \"Both\", the icon and the name draw as two runs, each in its own font. Left: today, the logo's code point in the label font draws dev-cobol. Right: proposed.", s => {
    const bad = el("span", "island", s, { style: { width: "86px" } }); el("span", "ink", bad, { text: "  AI", style: { left: "12px" } });
    drawFace(s, Object.assign({}, ai, { icon: "", font: "omarchy", face: "both" }));
  });
  card("An emoji as the face", "Emoji keep their own colours on the bar, whatever the theme, and the picker says so. They get a glyph cell like any icon.", s => {
    drawFace(s, Object.assign({}, ai, { icon: "🤖", font: "", face: "glyph" }));
    drawFace(s, Object.assign({}, ai, { icon: "🤖", font: "", face: "both" }));
  });
  card("Your own image, both colour choices", "Text colour fills the image's shape with the bar's text colour (left), so a multicolour icon becomes its silhouette: the tick is gone. Its own colours draws it as is (right). That is why the colour is a choice, not a guess. Both fit a 16 px square.", s => {
    const svg = "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><circle cx="8" cy="8" r="7" fill="#e5a50a"/><path d="M5 8.5l2 2 4-5" stroke="#26a269" stroke-width="2" fill="none"/></svg>');
    drawFace(s, Object.assign({}, ai, { image: svg, tint: "text", face: "glyph" }));
    drawFace(s, Object.assign({}, ai, { image: svg, tint: "own", face: "glyph" }));
  });
  card("Uninstalled widgets", "Superseded on 4 October: Powerbar drops members whose widget was uninstalled by itself, so the drawer never shows them. The drawing below is the first draft, with AI's two dead keys.", s => {
    const save = ST.sel; ST.sel = "ai"; const g = startGroups()[0]; const grid = el("div", null, s, { style: { width: "100%" } });
    const t = drawDrawerTile(grid, g, 12, null); t.style.background = "transparent"; t.style.border = "0"; ST.sel = save;
  });
  card("A name face on a side bar", "Your bar is on the right edge. A name wider than the highlight (32 px) can't grow across a side bar, so the bar shows the icon there (Bar.qml:4880). The shelf draws the bar as Preferences does, horizontally, and its line says so.", s => {
    drawFace(s, audio, { face: "both" });
    el("span", null, s, { text: "→ on your side bar", style: { alignSelf: "center", opacity: .6 } });
    drawFace(s, audio, { face: "glyph" });
  });
  card("No groups yet", "The shelf holds only \"+ New group\", and the page says what a group is and what n does.", s => {
    el("div", "gcard new", s, { text: "+ New group", style: { minWidth: "120px" } });
    el("span", null, s, { text: "No groups yet. A group gathers related widgets behind one icon on the bar. Press n to make your first.", style: { opacity: .65, maxWidth: "36ch" } });
  });
}
function renderMotion() {
  const rows = [
    ["Picker opens", "Fades and scales from 0.97 at the icon well, 150 ms, strong ease-out", "Appears at once"],
    ["Picker closes", "Fades, 110 ms", "Disappears at once"],
    ["Group cursor, member cursor", "Fill follows, 90 ms", "Fill moves at once"],
    ["Reorder in the drawer", "Neighbours slide to open the gap, Layout's timing", "Gap and outline shown in place"],
    ["Dissolve asked", "Urgent fill, no movement", "Same"],
    ["Cursor in the picker grid", "None: seen many times per visit", "None"],
  ];
  const tb = document.getElementById("motion-rows");
  rows.forEach(r => { const tr = el("tr", null, tb); r.forEach(c => el("td", null, tr, { text: c })); });
}
function renderSteps() {
  const steps = [
    ["IconSearch.js and its data", "The search model (word starts, scores, source order) with node and qmltestrunner tests; Material glyphs are surrogate pairs, so test in Qt's engine too. <code>tools/omarchy-glyphs.py</code> writes <code>icons/omarchy.json</code> (code point, name, use count) from Omarchy's sources and the bar font's glyph names; regenerate on Omarchy updates."],
    ["IconPicker.qml", "A popover over the Preferences card: TextField with type-to-search, source chips, a GridView with section headers, a footer that draws the face at 1:1. The DropArea for your own icon, plus Ctrl+V through <code>wl-paste --list-types</code>, the way Omarchy's clipboard plugin reads images. Copies the file to <code>~/.local/share/powerbar/icons/</code>."],
    ["Group config and the bar", "<code>GroupsModel</code>: <code>iconFont</code>, <code>iconImage</code>, <code>iconTint</code>. Bar.qml's group button and LayoutEditor's <code>barFace</code> draw the icon and the name as separate runs, each in its own font; an image face goes through MultiEffect colorization for Text colour."],
    ["GroupsPreferences.qml as a bento page", "PrefsForm + PrefsBento: Groups shelf (faces through ShelfModel/CellModel, as Layout), group tile (PrefsTile with Dissolve in the header, compact PrefsChoice/PrefsToggle), In the drawer (ManagedModel menu geometry), Not in a group. One drag state machine shared with Layout. IconGrid.qml goes."],
    ["Audit and live check", "Offscreen: the page fits 654 px at 1180 × 790, every control is reachable by keys, no warnings (the :650 TypeError gone). Live: drop from Nautilus onto the picker (layer-shell drop is unverified), paste an image, an emoji face on a light and a dark theme."],
  ];
  const ol = document.getElementById("steps");
  steps.forEach(([h, p]) => { const li = el("li", null, ol); el("b", null, li, { text: h }); el("p", null, li).innerHTML = p; });
}
function renderSources() {
  const src = [
    ["Nolan Lawson, Building an accessible emoji picker", "https://nolanlawson.com/2020/07/01/building-an-accessible-emoji-picker/", "Focus stays in the search field while arrows move through the grid; Enter picks."],
    ["W3C APG, Combobox pattern", "https://www.w3.org/WAI/ARIA/apg/patterns/combobox/", "A search field with a grid popup: the field keeps focus, the grid takes the active descendant."],
    ["W3C APG, Grid popup example", "https://wai-website.netlify.app/aria/apg/patterns/combobox/examples/grid-combo/", "Enter accepts the highlighted cell and closes the popup."],
    ["Notion API, Emoji and icon", "https://developers.notion.com/reference/emoji-and-icon", "Icon names match regardless of case, spaces, hyphens and underscores."],
    ["Notion help, Customize your page", "https://www.notion.com/help/customize-and-style-your-content", "One picker with Emoji, Icons and your own upload as sources, searchable."],
    ["Bartender 6", "https://www.macbartender.com/Bartender6/", "Menu bar groups: many items behind one customisable icon with quick access."],
    ["Ice", "https://github.com/jordanbaird/Ice", "A bar organiser that edits a live bar rather than a list."],
    ["Omarchy emoji plugin", "", "shell/plugins/emojis: 1,870 emoji with keywords; type-to-filter, arrows, Enter, Esc clears then closes."],
    ["Omarchy clipboard plugin", "", "shell/plugins/clipboard/capture.sh: reads images with wl-paste --list-types and --type."],
    ["Nerd Fonts", "https://www.nerdfonts.com/cheat-sheet", "Glyph names (md-, fa-…) that the bar font carries in its own post table."],
  ];
  const ul = document.getElementById("sources");
  src.forEach(([t, u, p]) => { const li = el("li", null, ul); if (u) el("a", null, li, { href: u, text: t }); else el("b", null, li, { text: t, style: { fontWeight: 600 } }); el("span", null, li, { text: p }); });
}

// =========================== Boot ===========================
(async function boot() {
  applyTheme();
  try { await Promise.all([document.fonts.load('12px "Bar Mono"'), document.fonts.load('12px "omarchy"'), document.fonts.load('700 12px "Bar Mono"')]); } catch (e) {}
  const opt = document.getElementById("opt");
  Object.keys(OPTIONS).forEach(k => el("button", null, opt, { "data-v": k, text: OPTIONS[k].label + (OPTIONS[k].rec ? " ★" : ""), onclick: () => { view.opt = k; ST.picker = null; rerender(); } }));
  document.querySelectorAll("#win button").forEach(b => b.addEventListener("click", () => { view.win = Number(b.dataset.v); ST.picker = null; rerender(); }));
  document.getElementById("reset").addEventListener("click", () => { ST = freshState(); rerender(); });
  const mo = document.getElementById("motion");
  mo.addEventListener("click", () => { const on = mo.getAttribute("aria-pressed") !== "true"; mo.setAttribute("aria-pressed", String(on)); document.documentElement.classList.toggle("no-motion", !on); });
  document.addEventListener("keydown", onWindowKey);
  window.addEventListener("resize", () => { if (hero) hero.k = fit(document.getElementById("hero-frame"), document.getElementById("hero-scaler"), view.win, 790); });
  // State hook for screenshots: #opt=list&win=900&picker=1&q=robot
  const h = new URLSearchParams(location.hash.slice(1));
  if (h.get("opt")) view.opt = h.get("opt");
  if (h.get("win")) view.win = Number(h.get("win"));
  if (h.get("sel")) ST.sel = h.get("sel");
  if (h.get("disp")) ST.groups[0].memberDisplay = h.get("disp");
  rerender();
  if (h.get("picker")) { const w = hero.pw.querySelector(".well"); if (w) { openPicker(w); if (h.get("q")) { ST.picker.input.value = h.get("q"); ST.picker.query = h.get("q"); renderPicker(ST.picker); } if (h.get("src")) { ST.picker.src = h.get("src"); renderPicker(ST.picker); } } }
  renderDecisions(); renderFindings(); renderRule(); renderPickerSection(); renderCompare(); renderKeys(); renderCases(); renderMotion(); renderSteps(); renderSources();
})();
