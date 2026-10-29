// Szenen für Icons, Thumbnails und Promo-Videos.
// Jede Szene: (format, t) -> SVG-Markup. format = "icon" (512x512), "thumb" (1920x1080), "video" (1080x1920)
// t = Zeit in Sekunden (für Videos; Standbilder nutzen ein festes t)

const SIZES = { icon: [512, 512], thumb: [1920, 1080], video: [1080, 1920] };

const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const ease = (x) => 1 - Math.pow(1 - clamp(x, 0, 1), 3);
const pop = (x) => {
  x = clamp(x, 0, 1);
  const c1 = 1.70158, c3 = c1 + 1;
  return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2);
};
const fmt = (n) => {
  const s = ["", "K", "M", "B"];
  let i = 0;
  while (n >= 1000 && i < s.length - 1) { n /= 1000; i++; }
  return i === 0 ? String(Math.floor(n)) : n.toFixed(1) + s[i];
};

let uid = 0;
const id = (p) => `${p}${++uid}`;

function defs() {
  return `<defs>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="160%">
      <feDropShadow dx="0" dy="10" stdDeviation="0" flood-color="#000" flood-opacity="0.45"/>
    </filter>
    <filter id="soft" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="18"/>
    </filter>
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="10" result="b"/>
      <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFF36B"/><stop offset="0.55" stop-color="#FFC21A"/><stop offset="1" stop-color="#FF8A00"/>
    </linearGradient>
    <linearGradient id="white" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#D8E6FF"/>
    </linearGradient>
    <linearGradient id="green" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#C6FF7A"/><stop offset="1" stop-color="#2FC24A"/>
    </linearGradient>
    <linearGradient id="rainbow" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#FF4D4D"/><stop offset="0.2" stop-color="#FFB13D"/><stop offset="0.4" stop-color="#FFF04D"/>
      <stop offset="0.6" stop-color="#4DFF7A"/><stop offset="0.8" stop-color="#4DB8FF"/><stop offset="1" stop-color="#C44DFF"/>
    </linearGradient>
  </defs>`;
}

// Großer Spiel-Schriftzug mit dicker Kontur und Schatten
function title(text, x, y, size, opts = {}) {
  const fill = opts.fill || "url(#gold)";
  const stroke = opts.stroke || "#2B1600";
  const rot = opts.rot || 0;
  const scale = opts.scale == null ? 1 : opts.scale;
  const anchor = opts.anchor || "middle";
  const sw = size * (opts.strokeRatio || 0.16);
  return `<g transform="translate(${x} ${y}) rotate(${rot}) scale(${scale})" filter="url(#shadow)">
    <text x="0" y="0" font-family="Lilita One" font-size="${size}" text-anchor="${anchor}" dominant-baseline="middle"
      fill="${fill}" stroke="${stroke}" stroke-width="${sw}" stroke-linejoin="round" paint-order="stroke"
      letter-spacing="${opts.spacing || 0}">${text}</text></g>`;
}

function sunburst(cx, cy, r, c1, c2, rays, rot) {
  let s = `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${c1}"/>`;
  for (let i = 0; i < rays; i++) {
    const a1 = ((i / rays) * 360 + rot) * Math.PI / 180;
    const a2 = (((i + 0.5) / rays) * 360 + rot) * Math.PI / 180;
    s += `<path d="M${cx} ${cy} L${cx + Math.cos(a1) * r} ${cy + Math.sin(a1) * r} L${cx + Math.cos(a2) * r} ${cy + Math.sin(a2) * r}Z" fill="${c2}"/>`;
  }
  return s;
}

function vignette(w, h) {
  const g = id("vg");
  return `<radialGradient id="${g}" cx="50%" cy="50%" r="75%"><stop offset="0.6" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.45"/></radialGradient>
    <rect width="${w}" height="${h}" fill="url(#${g})"/>`;
}

// Klotz-Avatar. (x,y) = Mitte vom Oberkörper, s = Größe einer Einheit (Oberkörper = 2s x 2s)
function avatar(x, y, s, o = {}) {
  const skin = o.skin || "#F5CD30", shirt = o.shirt || "#0D69AC", pants = o.pants || "#7DBB3C";
  const arm = o.arm || [0, 0], leg = o.leg || [0, 0];
  const edge = `stroke="#00000040" stroke-width="0.07"`;
  const face = o.face || "happy";
  let mouth;
  if (face === "wow") mouth = `<ellipse cx="0" cy="-1.32" rx="0.16" ry="0.21" fill="#3A1F12"/>`;
  else if (face === "grin") mouth = `<path d="M-0.38 -1.5 Q0 -1.05 0.38 -1.5 Z" fill="#3A1F12"/><path d="M-0.3 -1.47 L0.3 -1.47 L0.25 -1.4 L-0.25 -1.4Z" fill="#fff"/>`;
  else mouth = `<path d="M-0.34 -1.47 Q0 -1.17 0.34 -1.47" fill="none" stroke="#3A1F12" stroke-width="0.09" stroke-linecap="round"/>`;
  const brows = face === "wow"
    ? `<path d="M-0.42 -2.05 L-0.16 -2.0 M0.16 -2.0 L0.42 -2.05" stroke="#3A1F12" stroke-width="0.07" stroke-linecap="round"/>`
    : "";
  const extra = o.hold || "";
  return `<g transform="translate(${x} ${y}) scale(${s}) rotate(${o.rot || 0})">
    <g transform="rotate(${leg[0]} -0.5 1)"><rect x="-1" y="1" width="1" height="2" rx="0.08" fill="${pants}" ${edge}/></g>
    <g transform="rotate(${-leg[1]} 0.5 1)"><rect x="0" y="1" width="1" height="2" rx="0.08" fill="${pants}" ${edge}/></g>
    <g transform="rotate(${arm[0]} -1.5 -0.85)"><rect x="-2" y="-1" width="1" height="2" rx="0.08" fill="${skin}" ${edge}/></g>
    <rect x="-1" y="-1" width="2" height="2" rx="0.06" fill="${shirt}" ${edge}/>
    <rect x="-1" y="0.7" width="2" height="0.3" fill="#00000022"/>
    <g transform="rotate(${-arm[1]} 1.5 -0.85)"><rect x="1" y="-1" width="1" height="2" rx="0.08" fill="${skin}" ${edge}/>${extra}</g>
    <rect x="-0.68" y="-2.38" width="1.36" height="1.36" rx="0.3" fill="${skin}" ${edge}/>
    <ellipse cx="-0.28" cy="-1.78" rx="0.1" ry="0.16" fill="#1B1B1B"/><ellipse cx="0.28" cy="-1.78" rx="0.1" ry="0.16" fill="#1B1B1B"/>
    <circle cx="-0.25" cy="-1.83" r="0.035" fill="#fff"/><circle cx="0.31" cy="-1.83" r="0.035" fill="#fff"/>
    ${brows}${mouth}
  </g>`;
}

// 3D-artiger Block (Isometrie light): Front + Oberseite
function block(x, y, w, h, depth, color, top, opts = {}) {
  const d = depth;
  return `<g ${opts.glow ? 'filter="url(#glow)"' : ""}>
    <path d="M${x} ${y} L${x + d} ${y - d * 0.6} L${x + w + d} ${y - d * 0.6} L${x + w} ${y}Z" fill="${top}"/>
    <path d="M${x + w} ${y} L${x + w + d} ${y - d * 0.6} L${x + w + d} ${y + h - d * 0.6} L${x + w} ${y + h}Z" fill="#00000040"/>
    <path d="M${x + w} ${y} L${x + w + d} ${y - d * 0.6} L${x + w + d} ${y + h - d * 0.6} L${x + w} ${y + h}Z" fill="${color}" opacity="0.75"/>
    <rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${color}"/>
    <rect x="${x}" y="${y + h * 0.7}" width="${w}" height="${h * 0.3}" fill="#00000026"/>
  </g>`;
}

function cloud(x, y, s, op = 0.95) {
  return `<g transform="translate(${x} ${y}) scale(${s})" opacity="${op}" fill="#fff">
    <circle cx="0" cy="0" r="40"/><circle cx="45" cy="-15" r="52"/><circle cx="95" cy="0" r="40"/><rect x="0" y="0" width="95" height="40"/></g>`;
}

function sparkle(x, y, r, color = "#fff", rot = 0) {
  return `<path transform="translate(${x} ${y}) rotate(${rot})" d="M0 ${-r} Q${r * 0.15} ${-r * 0.15} ${r} 0 Q${r * 0.15} ${r * 0.15} 0 ${r} Q${-r * 0.15} ${r * 0.15} ${-r} 0 Q${-r * 0.15} ${-r * 0.15} 0 ${-r}Z" fill="${color}"/>`;
}

function badge(text, x, y, size, bg, rot = 0, scale = 1) {
  const w = text.length * size * 0.58 + size * 1.2;
  const h = size * 1.6;
  return `<g transform="translate(${x} ${y}) rotate(${rot}) scale(${scale})" filter="url(#shadow)">
    <rect x="${-w / 2}" y="${-h / 2}" width="${w}" height="${h}" rx="${h * 0.3}" fill="${bg}" stroke="#2B1600" stroke-width="${size * 0.14}"/>
    <text x="0" y="${size * 0.06}" font-family="Lilita One" font-size="${size}" text-anchor="middle" dominant-baseline="middle" fill="#fff">${text}</text></g>`;
}

// Runde Pets mit Gesicht
function pet(x, y, r, color, opts = {}) {
  const ears = opts.ears === false ? "" : `<path d="M${-r * 0.75} ${-r * 0.45} L${-r * 0.55} ${-r * 1.15} L${-r * 0.15} ${-r * 0.8}Z M${r * 0.75} ${-r * 0.45} L${r * 0.55} ${-r * 1.15} L${r * 0.15} ${-r * 0.8}Z" fill="${color}" stroke="#00000040" stroke-width="${r * 0.05}"/>`;
  return `<g transform="translate(${x} ${y}) rotate(${opts.rot || 0})" ${opts.glow ? 'filter="url(#glow)"' : ""}>
    ${ears}
    <circle r="${r}" fill="${color}" stroke="#00000040" stroke-width="${r * 0.05}"/>
    <ellipse cx="${-r * 0.35}" cy="${-r * 0.35}" rx="${r * 0.3}" ry="${r * 0.18}" fill="#ffffff55" transform="rotate(-30 ${-r * 0.35} ${-r * 0.35})"/>
    <ellipse cx="${-r * 0.32}" cy="${-r * 0.05}" rx="${r * 0.12}" ry="${r * 0.18}" fill="#1B1B1B"/>
    <ellipse cx="${r * 0.32}" cy="${-r * 0.05}" rx="${r * 0.12}" ry="${r * 0.18}" fill="#1B1B1B"/>
    <circle cx="${-r * 0.28}" cy="${-r * 0.12}" r="${r * 0.05}" fill="#fff"/><circle cx="${r * 0.36}" cy="${-r * 0.12}" r="${r * 0.05}" fill="#fff"/>
    <path d="M${-r * 0.18} ${r * 0.25} Q0 ${r * 0.42} ${r * 0.18} ${r * 0.25}" fill="none" stroke="#1B1B1B" stroke-width="${r * 0.07}" stroke-linecap="round"/>
    <ellipse cx="${-r * 0.6}" cy="${r * 0.2}" rx="${r * 0.15}" ry="${r * 0.08}" fill="#FF7FA0" opacity="0.7"/>
    <ellipse cx="${r * 0.6}" cy="${r * 0.2}" rx="${r * 0.15}" ry="${r * 0.08}" fill="#FF7FA0" opacity="0.7"/>
  </g>`;
}

function egg(x, y, r, color, opts = {}) {
  const crack = opts.crack ? `<path d="M${-r * 0.8} ${-r * 0.1} L${-r * 0.4} ${-r * 0.35} L${-r * 0.1} ${-r * 0.05} L${r * 0.25} ${-r * 0.4} L${r * 0.5} ${-r * 0.1} L${r * 0.8} ${-r * 0.3}" fill="none" stroke="#1B1B1B" stroke-width="${r * 0.06}" stroke-linejoin="round"/>` : "";
  return `<g transform="translate(${x} ${y}) rotate(${opts.rot || 0})" ${opts.glow ? 'filter="url(#glow)"' : ""}>
    <ellipse rx="${r * 0.82}" ry="${r}" fill="${color}" stroke="#00000045" stroke-width="${r * 0.05}"/>
    <circle cx="${-r * 0.3}" cy="${r * 0.2}" r="${r * 0.14}" fill="#ffffff55"/><circle cx="${r * 0.35}" cy="${-r * 0.4}" r="${r * 0.1}" fill="#ffffff55"/>
    <ellipse cx="${-r * 0.32}" cy="${-r * 0.45}" rx="${r * 0.18}" ry="${r * 0.3}" fill="#ffffff88" transform="rotate(25 ${-r * 0.32} ${-r * 0.45})"/>
    ${crack}</g>`;
}

function coin(x, y, r, rot = 0) {
  return `<g transform="translate(${x} ${y}) rotate(${rot})">
    <ellipse rx="${r}" ry="${r}" fill="#E8A200"/><ellipse rx="${r * 0.92}" ry="${r * 0.92}" cx="${-r * 0.05}" fill="url(#gold)"/>
    <text x="${-r * 0.05}" y="${r * 0.08}" font-family="Lilita One" font-size="${r * 1.2}" text-anchor="middle" dominant-baseline="middle" fill="#B36B00">$</text></g>`;
}

function bill(x, y, w, rot = 0) {
  const h = w * 0.45;
  return `<g transform="translate(${x} ${y}) rotate(${rot})">
    <rect x="${-w / 2}" y="${-h / 2}" width="${w}" height="${h}" rx="${w * 0.04}" fill="#5BC85B" stroke="#2E7D32" stroke-width="${w * 0.03}"/>
    <rect x="${-w * 0.42}" y="${-h * 0.36}" width="${w * 0.84}" height="${h * 0.72}" rx="${w * 0.03}" fill="none" stroke="#2E7D32" stroke-width="${w * 0.015}"/>
    <circle r="${h * 0.28}" fill="#8BE08B" stroke="#2E7D32" stroke-width="${w * 0.015}"/>
    <text y="${h * 0.04}" font-family="Lilita One" font-size="${h * 0.42}" text-anchor="middle" dominant-baseline="middle" fill="#2E7D32">$</text></g>`;
}

function fruit(x, y, r, color, opts = {}) {
  const leaf = `<path d="M0 ${-r * 0.9} q${r * 0.4} ${-r * 0.5} ${r * 0.7} ${-r * 0.35} q${-r * 0.3} ${r * 0.4} ${-r * 0.7} ${r * 0.35}Z" fill="#3DBE3D"/>
    <rect x="${-r * 0.05}" y="${-r * 1.15}" width="${r * 0.1}" height="${r * 0.35}" fill="#6B4A2B"/>`;
  return `<g transform="translate(${x} ${y}) rotate(${opts.rot || 0}) scale(${opts.scale == null ? 1 : opts.scale})" ${opts.glow ? 'filter="url(#glow)"' : ""}>
    <circle r="${r}" fill="${color}" stroke="#00000035" stroke-width="${r * 0.05}"/>
    <ellipse cx="${-r * 0.35}" cy="${-r * 0.35}" rx="${r * 0.25}" ry="${r * 0.15}" fill="#ffffff88" transform="rotate(-35 ${-r * 0.35} ${-r * 0.35})"/>
    ${leaf}</g>`;
}

function plant(x, y, s, progress, fruitColor) {
  const h = s * (0.4 + progress * 1.2);
  let out = `<g transform="translate(${x} ${y})">
    <path d="M0 0 C${-s * 0.1} ${-h * 0.4} ${s * 0.1} ${-h * 0.7} 0 ${-h}" stroke="#2F9E2F" stroke-width="${s * 0.12}" fill="none" stroke-linecap="round"/>
    <ellipse cx="${-s * 0.25}" cy="${-h * 0.45}" rx="${s * 0.28 * (0.4 + progress)}" ry="${s * 0.12 * (0.4 + progress)}" fill="#46C246" transform="rotate(-30 ${-s * 0.25} ${-h * 0.45})"/>
    <ellipse cx="${s * 0.25}" cy="${-h * 0.65}" rx="${s * 0.28 * (0.4 + progress)}" ry="${s * 0.12 * (0.4 + progress)}" fill="#46C246" transform="rotate(30 ${s * 0.25} ${-h * 0.65})"/>
    <circle cx="0" cy="${-h}" r="${s * 0.3 * (0.4 + progress)}" fill="#5AD15A"/>`;
  if (progress >= 1 && fruitColor) {
    out += fruit(-s * 0.32, -h * 0.8, s * 0.2, fruitColor) + fruit(s * 0.32, -h * 0.95, s * 0.2, fruitColor) + fruit(0, -h * 1.15, s * 0.2, fruitColor);
  }
  return out + `</g>`;
}

function soil(x, y, w, h) {
  return block(x, y, w, h, h * 0.9, "#7A4B2A", "#9A6338");
}

// ---------------------------------------------------------------------------
// Szenen
// ---------------------------------------------------------------------------
const scenes = {};

// 1) MEGA OBBY ---------------------------------------------------------------
scenes.obby = (fmt0, t) => {
  const [w, h] = SIZES[fmt0];
  const v = fmt0 === "video", ic = fmt0 === "icon";
  let s = defs();
  s += `<linearGradient id="sky1" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2E8BFF"/><stop offset="1" stop-color="#9FE3FF"/></linearGradient>`;
  s += `<rect width="${w}" height="${h}" fill="url(#sky1)"/>`;
  s += `<g opacity="0.25">${sunburst(w * 0.5, h * 0.42, Math.max(w, h), "none", "#ffffff", 18, t * 8)}</g>`;
  s += cloud(w * 0.08 + (t * 20) % 200, h * 0.18, w / 1400) + cloud(w * 0.72 - (t * 15) % 150, h * 0.1, w / 1700);
  // Lava unten
  const lavaY = h * (v ? 0.84 : 0.86);
  s += `<rect x="0" y="${lavaY}" width="${w}" height="${h - lavaY}" fill="#FF5A00"/>`;
  s += `<rect x="0" y="${lavaY}" width="${w}" height="${(h - lavaY) * 0.25}" fill="#FFB000" filter="url(#glow)"/>`;
  for (let i = 0; i < 9; i++) {
    const bx = ((i * 0.13 + t * 0.07) % 1) * w;
    s += `<circle cx="${bx}" cy="${lavaY + (h - lavaY) * 0.45 + Math.sin(t * 3 + i) * 8}" r="${w * 0.012}" fill="#FFD000"/>`;
  }
  // Plattformen-Treppe
  const plats = ic
    ? [[0.04, 0.72, "#FF4D5E"], [0.62, 0.55, "#FFC83A"]]
    : v
      ? [[0.05, 0.82, "#FF4D5E"], [0.55, 0.72, "#FFC83A"], [0.12, 0.62, "#8AC926"], [0.58, 0.52, "#1982C4"]]
      : [[0.03, 0.74, "#FF4D5E"], [0.22, 0.62, "#FFC83A"], [0.42, 0.68, "#8AC926"], [0.62, 0.52, "#1982C4"], [0.8, 0.4, "#6A4C93"]];
  const pw = ic ? w * 0.34 : v ? w * 0.3 : w * 0.13;
  plats.forEach(([px, py, c], i) => {
    const bob = Math.sin(t * 2 + i) * (v ? 10 : 0);
    s += block(px * w, py * h + bob, pw, pw * 0.22, pw * 0.25, c, "#ffffff55");
  });
  // Spinner (Kill-Balken)
  if (!ic) {
    const sx = v ? w * 0.75 : w * 0.16, sy = v ? h * 0.55 : h * 0.56;
    const ang = t * 140 + 20;
    s += `<g transform="translate(${sx} ${sy}) rotate(${ang})" filter="url(#glow)"><rect x="${-w * (v ? 0.18 : 0.08)}" y="-10" width="${w * (v ? 0.36 : 0.16)}" height="20" rx="10" fill="#FF2020"/></g>`;
    s += `<circle cx="${sx}" cy="${sy}" r="16" fill="#333"/>`;
  }
  // Avatar springt
  let ax, ay, as = ic ? 34 : v ? 55 : 62;
  if (v) {
    // springt von Plattform zu Plattform
    const seg = Math.floor(t / 1.6) % (plats.length - 1);
    const k = (t % 1.6) / 1.6;
    const a = plats[seg], b = plats[seg + 1];
    const x0 = a[0] * w + pw / 2, y0 = a[1] * h - as * 3;
    const x1 = b[0] * w + pw / 2, y1 = b[1] * h - as * 3;
    ax = x0 + (x1 - x0) * k;
    ay = y0 + (y1 - y0) * k - Math.sin(k * Math.PI) * h * 0.07;
  } else if (ic) { ax = w * 0.5; ay = h * 0.48; }
  else { ax = w * 0.485; ay = h * 0.45; }
  s += avatar(ax, ay, as, { arm: [150, 150], leg: [25, 30], face: "grin", shirt: "#E63946", pants: "#1D3557" });
  // Titel
  if (ic) {
    s += title("MEGA", w * 0.5, h * 0.17, 120, { rot: -4 });
    s += title("OBBY", w * 0.5, h * 0.86, 130, { rot: 3, fill: "url(#white)" });
  } else if (v) {
    s += title("MEGA OBBY", w * 0.5, h * 0.1, 150, { rot: -3 });
    const hook = t < 3.5 ? "CAN YOU BEAT" : t < 7 ? "LAVA, SPINNERS" : "PLAY FREE NOW";
    const hook2 = t < 3.5 ? "ALL 60 STAGES?" : t < 7 ? "& TRAPS!" : "SEARCH: MEGA OBBY";
    const k = pop((t % 3.5) * 2);
    s += title(hook, w * 0.5, h * 0.19, 90, { fill: "url(#white)", scale: k });
    s += title(hook2, w * 0.5, h * 0.255, 90, { fill: "url(#white)", scale: k });
    const stage = Math.min(60, 1 + Math.floor(t * 6));
    s += badge(`STAGE ${stage}/60`, w * 0.5, h * 0.93, 64, "#2B9348");
  } else {
    s += title("MEGA OBBY", w * 0.36, h * 0.16, 200, { rot: -4 });
    s += title("CAN YOU WIN?", w * 0.8, h * 0.3, 84, { fill: "url(#white)", rot: 5 });
    s += badge("60 STAGES!", w * 0.82, h * 0.8, 70, "#E63946", 6);
  }
  s += vignette(w, h);
  return s;
};

// 2) CLICK LEGENDS SIMULATOR ---------------------------------------------------
scenes.clicker = (fmt0, t) => {
  const [w, h] = SIZES[fmt0];
  const v = fmt0 === "video", ic = fmt0 === "icon";
  let s = defs();
  s += `<radialGradient id="bg2" cx="50%" cy="45%" r="70%"><stop offset="0" stop-color="#B05BFF"/><stop offset="1" stop-color="#3A0CA3"/></radialGradient>`;
  s += `<rect width="${w}" height="${h}" fill="url(#bg2)"/>`;
  s += `<g opacity="0.18">${sunburst(w * 0.5, h * (v ? 0.5 : 0.55), Math.max(w, h), "none", "#fff", 20, t * 12)}</g>`;
  // Klick-Button
  const bx = ic ? w * 0.5 : v ? w * 0.5 : w * 0.5, by = ic ? h * 0.56 : v ? h * 0.6 : h * 0.6;
  const br = ic ? 120 : v ? 230 : 200;
  const press = v ? 1 - 0.08 * Math.max(0, Math.sin(t * 20)) : 1;
  s += `<g transform="translate(${bx} ${by}) scale(${press})">
    <ellipse cx="0" cy="${br * 0.22}" rx="${br}" ry="${br * 0.85}" fill="#1E7A1E"/>
    <ellipse cx="0" cy="0" rx="${br}" ry="${br * 0.85}" fill="url(#green)" stroke="#145214" stroke-width="${br * 0.06}"/>
    <ellipse cx="${-br * 0.35}" cy="${-br * 0.4}" rx="${br * 0.3}" ry="${br * 0.15}" fill="#ffffff66"/>
    <text x="0" y="${br * 0.06}" font-family="Lilita One" font-size="${br * 0.5}" text-anchor="middle" dominant-baseline="middle" fill="#fff" stroke="#145214" stroke-width="${br * 0.06}" paint-order="stroke">CLICK!</text></g>`;
  // Cursor-Hand (Pfeil)
  const cs = ic ? 1.1 : 2;
  s += `<g transform="translate(${bx + br * 0.55} ${by + br * 0.35 + (v ? Math.abs(Math.sin(t * 10)) * 20 : 0)}) scale(${cs}) rotate(-15)" filter="url(#shadow)">
    <path d="M0 0 L0 60 L15 47 L26 72 L36 67 L25 43 L44 43 Z" fill="#fff" stroke="#111" stroke-width="5" stroke-linejoin="round"/></g>`;
  // Fliegende +Zahlen
  if (!ic) {
    for (let i = 0; i < (v ? 10 : 7); i++) {
      const k = ((t * 0.8 + i * 0.137) % 1);
      const spots = [[0.3, 0.45], [0.7, 0.42], [0.31, 0.74], [0.69, 0.76], [0.36, 0.6], [0.64, 0.59], [0.5, 0.36]];
      const fx = v ? bx + Math.cos(i * 2.4) * br * (1.1 + k * 0.6) : spots[i][0] * w;
      const fy = v ? by - br * 0.6 - k * h * 0.25 + Math.sin(i) * 40 : spots[i][1] * h;
      const val = v ? fmt(Math.pow(10, 1 + t * 0.9) * (1 + i * 0.3)) : ["+250", "+1.2K", "+50K", "+3.4M", "+800", "+12K", "+99K"][i];
      s += `<g opacity="${v ? 1 - k : 1}">${title(v ? "+" + val : val, fx, fy, v ? 70 : 64, { fill: "url(#gold)", strokeRatio: 0.18 })}</g>`;
    }
  }
  // Pets & Eier
  const pets = ic
    ? [[0.18, 0.26, 50, "#FF9F1C"], [0.83, 0.3, 46, "#4CC9F0"]]
    : v
      ? [[0.18, 0.38, 80, "#FF9F1C"], [0.82, 0.36, 76, "#4CC9F0"], [0.2, 0.82, 70, "#F72585"]]
      : [[0.14, 0.42, 95, "#FF9F1C"], [0.86, 0.45, 90, "#4CC9F0"], [0.82, 0.82, 70, "#F72585"]];
  pets.forEach(([px, py, r, c], i) => {
    s += pet(px * w, py * h + Math.sin(t * 3 + i) * 12, r, c, { rot: Math.sin(t * 2 + i) * 8 });
  });
  if (!ic) {
    s += egg(w * (v ? 0.8 : 0.14), h * (v ? 0.83 : 0.8), v ? 95 : 90, "#FFD60A", { glow: true, crack: v && t > 6, rot: v && t > 5 ? Math.sin(t * 30) * 12 : 0 });
  }
  if (v && t > 6.6) {
    const k = pop((t - 6.6) * 1.8);
    s += `<rect width="${w}" height="${h}" fill="#000" opacity="${0.55 * clamp((t - 6.6) * 2, 0, 1)}"/>`;
    s += `<g opacity="0.5">${sunburst(w / 2, h * 0.5, w * 0.8 * k, "none", "#FFD60A", 16, t * 40)}</g>`;
    s += pet(w / 2, h * 0.5, 180 * k, "#7B2CBF", { glow: true });
    s += title("GALAXY CAT!", w / 2, h * 0.68, 110, { scale: k, fill: "url(#rainbow)" });
    s += title("x200 CLICKS", w / 2, h * 0.75, 80, { scale: k, fill: "url(#white)" });
  }
  // Titel
  if (ic) {
    s += title("CLICK", w * 0.5, h * 0.13, 110, { rot: -4 });
    s += title("LEGENDS", w * 0.5, h * 0.9, 96, { rot: 3, fill: "url(#white)" });
  } else if (v) {
    s += title("CLICK LEGENDS", w * 0.5, h * 0.08, 120, { rot: -3 });
    const hook = t < 3.3 ? "1 CLICK = +1" : t < 6.6 ? "1 CLICK = +" + fmt(Math.pow(10, 1 + t * 0.9)) : "PLAY FREE NOW";
    s += title(hook, w * 0.5, h * 0.17, 96, { fill: "url(#white)", scale: pop((t % 3.3) * 2) });
    if (t >= 6.6) s += badge("SEARCH: CLICK LEGENDS", w * 0.5, h * 0.92, 56, "#F72585");
  } else {
    s += title("CLICK LEGENDS", w * 0.5, h * 0.14, 200, { rot: -3 });
    s += badge("SIMULATOR", w * 0.5, h * 0.27, 64, "#F72585", 2);
    s += badge("PETS + REBIRTHS", w * 0.5, h * 0.92, 56, "#3A86FF");
  }
  s += vignette(w, h);
  return s;
};

// 3) MONEY TYCOON -----------------------------------------------------------------
scenes.tycoon = (fmt0, t) => {
  const [w, h] = SIZES[fmt0];
  const v = fmt0 === "video", ic = fmt0 === "icon";
  let s = defs();
  s += `<linearGradient id="bg3" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0B8F4A"/><stop offset="1" stop-color="#033D1E"/></linearGradient>`;
  s += `<rect width="${w}" height="${h}" fill="url(#bg3)"/>`;
  s += `<g opacity="0.2">${sunburst(w * 0.5, h * 0.45, Math.max(w, h), "none", "#C6FF7A", 22, t * 10)}</g>`;
  // Villa (wächst im Video)
  const grow = v ? ease((t - 2) / 4) : 1;
  const hx = ic ? w * 0.18 : v ? w * 0.12 : w * 0.52, hy = ic ? h * 0.72 : v ? h * 0.62 : h * 0.78;
  const hw = ic ? w * 0.64 : v ? w * 0.76 : w * 0.42, hh = (ic ? h * 0.32 : v ? h * 0.2 : h * 0.42) * grow;
  if (grow > 0.02) {
    s += block(hx, hy - hh, hw, hh, hw * 0.12, "#F2E8CF", "#FFFFFF");
    const cols = 4, rows = Math.max(1, Math.floor(3 * grow));
    for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
      const wx = hx + hw * (0.08 + c * 0.235), wy = hy - hh + hh * (0.1 + r * 0.3);
      s += `<rect x="${wx}" y="${wy}" width="${hw * 0.14}" height="${hh * 0.2}" fill="#FFE27A" stroke="#7A5C00" stroke-width="4"/>`;
    }
    s += `<path d="M${hx - hw * 0.05} ${hy - hh} L${hx + hw * 0.5} ${hy - hh - hh * 0.45} L${hx + hw * 1.05} ${hy - hh}Z" fill="#C0392B" stroke="#7B1E14" stroke-width="6"/>`;
  }
  // Förderband + Dropper
  if (!ic) {
    const cy = v ? h * 0.74 : h * 0.86, cx0 = v ? w * 0.05 : w * 0.04, cw = v ? w * 0.9 : w * 0.44;
    s += `<rect x="${cx0}" y="${cy}" width="${cw}" height="40" rx="8" fill="#2B2B2B"/>`;
    for (let i = 0; i < 14; i++) {
      const lx = cx0 + ((i / 14) * cw + t * 120) % cw;
      s += `<rect x="${lx}" y="${cy + 6}" width="8" height="28" fill="#555"/>`;
    }
    for (let d = 0; d < 3; d++) {
      const dx = cx0 + cw * (0.15 + d * 0.27);
      s += block(dx - 45, cy - 230, 90, 80, 25, ["#9AA0A6", "#FFC300", "#4CC9F0"][d], "#ffffff66");
      s += `<rect x="${dx - 15}" y="${cy - 150}" width="30" height="16" fill="#222"/>`;
      for (let o = 0; o < 3; o++) {
        const k = ((t * 0.9 + o / 3 + d * 0.21) % 1);
        const oy = cy - 130 + Math.min(k * 2, 1) * 110;
        const ox = dx + Math.max(0, k * 2 - 1) * cw * 0.3;
        s += `<rect x="${ox - 14}" y="${oy - 14}" width="28" height="28" rx="4" fill="${["#C0C0C0", "#FFD700", "#7DF9FF"][d]}" stroke="#00000055" stroke-width="3"/>`;
      }
    }
  }
  // Geld regnet
  const n = ic ? 6 : v ? 16 : 12;
  for (let i = 0; i < n; i++) {
    const k = ((t * 0.25 + i * 0.173) % 1);
    const x = (i * 0.618 % 1) * w;
    const y = ic ? (i * 0.37 % 0.5) * h + 30 : -80 + k * (h + 160);
    s += i % 2 ? bill(x, y, ic ? 90 : 150, (i * 47 + t * 60) % 360) : coin(x, y, ic ? 26 : 42, (i * 30 + t * 90) % 360);
  }
  // Avatar mit Geld
  const ax = ic ? w * 0.5 : v ? w * 0.5 : w * 0.25, ay = ic ? h * 0.47 : v ? h * 0.46 : h * 0.55, as = ic ? 34 : v ? 66 : 70;
  s += avatar(ax, ay, as, { arm: [140, 140], leg: [8, 8], face: "grin", shirt: "#FFC300", pants: "#333", skin: "#F5CD30",
    hold: `<g transform="translate(1.5 1.3) rotate(-140)">${bill(0, 0, 1.6, 0)}</g>` });
  // Titel + Geldanzeige
  const cash = v ? Math.floor(Math.pow(10, 1 + t * 0.6)) : 1000000;
  if (ic) {
    s += title("MONEY", w * 0.5, h * 0.13, 110, { rot: -4, fill: "url(#green)" });
    s += title("TYCOON", w * 0.5, h * 0.9, 100, { rot: 3 });
  } else if (v) {
    s += title("MONEY TYCOON", w * 0.5, h * 0.08, 130, { rot: -3, fill: "url(#green)" });
    s += title("$" + cash.toLocaleString("en-US"), w * 0.5, h * 0.19, 110, { fill: "url(#gold)" });
    const hook = t < 4 ? "START WITH $50..." : t < 7.5 ? "BUILD YOUR EMPIRE!" : "SEARCH: MONEY TYCOON";
    s += title(hook, w * 0.5, h * 0.88, 84, { fill: "url(#white)", scale: pop((t % 4) * 2) });
  } else {
    s += title("MONEY TYCOON", w * 0.5, h * 0.14, 200, { rot: -3, fill: "url(#green)" });
    s += title("$1,000,000", w * 0.73, h * 0.3, 120, { rot: 4 });
  }
  s += vignette(w, h);
  return s;
};

// 4) DISASTER SURVIVAL -------------------------------------------------------------
scenes.disaster = (fmt0, t) => {
  const [w, h] = SIZES[fmt0];
  const v = fmt0 === "video", ic = fmt0 === "icon";
  // Im Video wechseln die Katastrophen
  const phase = v ? (t < 2.5 ? 0 : t < 5 ? 1 : t < 7.5 ? 2 : 3) : 3;
  const skies = [["#FF7B00", "#5A0F00"], ["#2B3A55", "#0B1220"], ["#3D5A80", "#98C1D9"], ["#FF6B00", "#4A0E0E"]];
  const [c1, c2] = skies[phase];
  let s = defs();
  s += `<linearGradient id="bg4" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${c2}"/><stop offset="1" stop-color="${c1}"/></linearGradient>`;
  s += `<rect width="${w}" height="${h}" fill="url(#bg4)"/>`;
  const shake = v ? Math.sin(t * 50) * 6 : 0;
  // Haus
  const hx = ic ? w * 0.3 : v ? w * 0.22 : w * 0.52, hw = ic ? w * 0.4 : v ? w * 0.56 : w * 0.22;
  const groundY = ic ? h * 0.82 : v ? h * 0.72 : h * 0.85;
  const hh = ic ? h * 0.22 : v ? h * 0.2 : h * 0.36;
  s += `<g transform="translate(${shake} 0)">`;
  s += `<rect x="0" y="${groundY}" width="${w}" height="${h - groundY}" fill="#3B7A2A"/>`;
  s += block(hx, groundY - hh, hw, hh, hw * 0.15, "#E9D8A6", "#F7EBC8");
  s += `<rect x="${hx + hw * 0.4}" y="${groundY - hh * 0.45}" width="${hw * 0.2}" height="${hh * 0.45}" fill="#6B4226"/>`;
  s += `<rect x="${hx + hw * 0.1}" y="${groundY - hh * 0.8}" width="${hw * 0.2}" height="${hh * 0.2}" fill="#90E0EF" stroke="#333" stroke-width="5"/>`;
  s += `<rect x="${hx + hw * 0.7}" y="${groundY - hh * 0.8}" width="${hw * 0.2}" height="${hh * 0.2}" fill="#90E0EF" stroke="#333" stroke-width="5"/>`;
  s += `<rect x="${hx - hw * 0.05}" y="${groundY - hh - 18}" width="${hw * 1.1}" height="22" fill="#9B2226"/>`;
  s += `</g>`;
  // Avatar auf dem Dach, erschrocken
  const as = ic ? 26 : v ? 60 : 60;
  s += avatar(hx + hw * 0.5 + shake, groundY - hh - 18 - as * 3, as, { arm: [160, 160], leg: [10, 10], face: "wow", shirt: "#F4A261", pants: "#264653" });
  // Katastrophen
  const tornadoX = ic ? w * 0.82 : v ? w * (0.85 - (t % 2.5) * 0.04) : w * 0.89;
  if (phase === 0 || phase === 3) {
    // Meteore
    const count = ic ? 3 : 6;
    for (let i = 0; i < count; i++) {
      const k = v ? ((t * 0.7 + i / count) % 1) : 0.3 + (i / count) * 0.5;
      const mx = (0.1 + (i * 0.37) % 0.8) * w + k * w * 0.15;
      const my = -100 + k * h * 0.8;
      const r = ic ? 22 : 40 + (i % 3) * 12;
      s += `<path d="M${mx} ${my} L${mx - r * 4} ${my - r * 5}" stroke="#FFB703" stroke-width="${r * 1.2}" stroke-linecap="round" opacity="0.55" filter="url(#glow)"/>`;
      s += `<circle cx="${mx}" cy="${my}" r="${r}" fill="#6D3B1F" stroke="#FF7B00" stroke-width="${r * 0.25}" filter="url(#glow)"/>`;
    }
  }
  if (phase === 1 || phase === 3) {
    // Tornado
    const ty = ic ? h * 0.15 : h * 0.12, tb = groundY;
    const tw = ic ? 120 : v ? 300 : 320;
    let path = "";
    const layers = 9;
    for (let i = 0; i < layers; i++) {
      const k = i / (layers - 1);
      const yy = ty + (tb - ty) * k;
      const rw = tw * (1 - k * 0.8);
      const ox = Math.sin(t * 4 + k * 5) * 25 * k;
      path += `<ellipse cx="${tornadoX + ox}" cy="${yy}" rx="${rw / 2}" ry="${rw * 0.12}" fill="#7A7A7A" opacity="0.85"/>`;
    }
    s += `<g>${path}</g>`;
  }
  if (phase === 2) {
    // Flut steigt
    const fy = groundY - ease((t - 5) / 2.5) * hh * 0.9;
    s += `<rect x="0" y="${fy}" width="${w}" height="${h - fy}" fill="#2D7DD2" opacity="0.75"/>`;
    for (let i = 0; i < 8; i++) s += `<ellipse cx="${((i / 8) * w + t * 80) % w}" cy="${fy}" rx="70" ry="14" fill="#9BD1FF" opacity="0.8"/>`;
  }
  if (phase === 3 && !ic) {
    // Lava-Spalt
    s += `<path d="M0 ${groundY + 40} Q${w * 0.3} ${groundY + 10} ${w * 0.5} ${groundY + 50} T${w} ${groundY + 30} L${w} ${h} L0 ${h}Z" fill="#FF4800" filter="url(#glow)" opacity="0.9"/>`;
  }
  // Titel
  if (ic) {
    s += title("SURVIVE", w * 0.5, h * 0.12, 104, { rot: -4 });
    s += title("DISASTERS", w * 0.5, h * 0.92, 80, { rot: 2, fill: "url(#white)" });
  } else if (v) {
    s += title("DISASTER SURVIVAL", w * 0.5, h * 0.07, 104, { rot: -3 });
    const names = ["METEOR SHOWER!", "TORNADO!", "FLOOD!", "CAN YOU SURVIVE?"];
    s += title(names[phase], w * 0.5, h * 0.16, 100, { fill: "url(#white)", scale: pop(((t % 2.5)) * 2.5) });
    if (phase === 3) s += badge("PLAY FREE: DISASTER SURVIVAL", w * 0.5, h * 0.93, 50, "#D00000");
    else s += badge("6 DISASTERS", w * 0.5, h * 0.93, 60, "#D00000");
  } else {
    s += title("SURVIVE THE", w * 0.27, h * 0.14, 150, { rot: -4, fill: "url(#white)" });
    s += title("DISASTERS!", w * 0.27, h * 0.29, 190, { rot: -4 });
    s += badge("6 DISASTERS", w * 0.16, h * 0.9, 64, "#D00000", -4);
  }
  s += vignette(w, h);
  return s;
};

// 5) GARDEN GROW -------------------------------------------------------------------
scenes.garden = (fmt0, t) => {
  const [w, h] = SIZES[fmt0];
  const v = fmt0 === "video", ic = fmt0 === "icon";
  let s = defs();
  s += `<linearGradient id="bg5" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4CC9F0"/><stop offset="0.6" stop-color="#B8F2FF"/><stop offset="0.6" stop-color="#57CC5A"/><stop offset="1" stop-color="#2D8A34"/></linearGradient>`;
  s += `<rect width="${w}" height="${h}" fill="url(#bg5)"/>`;
  s += `<circle cx="${w * 0.85}" cy="${h * 0.12}" r="${ic ? 60 : 110}" fill="#FFE45E" filter="url(#glow)"/>`;
  if (!ic) s += cloud(w * 0.1 + (t * 25) % 200, h * 0.15, w / 1500) + cloud(w * 0.55, h * 0.08, w / 2000);
  // Beete
  const rows = ic ? 1 : 2, cols = ic ? 3 : v ? 3 : 5;
  const tileW = ic ? w * 0.24 : v ? w * 0.24 : w * 0.12;
  const startX = ic ? w * 0.1 : v ? w * 0.1 : w * 0.06;
  const baseY = ic ? h * 0.8 : v ? h * 0.78 : h * 0.86;
  const colors = ["#E63946", "#FF8C1A", "#3A5BFF", "#FFD60A", "#FF4FB0"];
  let n = 0;
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const x = startX + c * tileW * 1.18 + (r ? tileW * 0.3 : 0);
      const y = baseY - r * tileW * 0.55;
      s += soil(x, y, tileW, tileW * 0.18);
      const prog = v ? clamp((t - n * 0.35) / 3, 0, 1) : 1;
      s += plant(x + tileW * 0.5, y, tileW * 0.55, prog, colors[n % colors.length]);
      n++;
    }
  }
  // Riesige Rainbow/Golden Frucht
  const fx = ic ? w * 0.5 : v ? w * 0.5 : w * 0.76, fy = ic ? h * 0.42 : v ? h * 0.42 : h * 0.5;
  const fr = ic ? 105 : v ? 190 : 220;
  const showBig = !v || t > 5;
  if (showBig) {
    const k = v ? pop((t - 5) * 1.5) : 1;
    s += `<g opacity="0.55">${sunburst(fx, fy, fr * 2.2 * k, "none", "#FFF6A8", 16, t * 25)}</g>`;
    s += fruit(fx, fy, fr, "url(#rainbow)", { glow: true, scale: k, rot: Math.sin(t * 2) * 6 });
    for (let i = 0; i < 6; i++) {
      const a = i * 1.05 + t * 1.5;
      s += sparkle(fx + Math.cos(a) * fr * 1.35 * k, fy + Math.sin(a) * fr * 1.35 * k, (ic ? 16 : 28) * (0.7 + 0.3 * Math.sin(t * 5 + i)), "#fff", t * 90);
    }
  }
  // Avatar mit Gießkanne
  if (!ic) {
    const ax = v ? w * 0.82 : w * 0.45, ay = v ? h * 0.62 : h * 0.6, as = v ? 55 : 60;
    s += avatar(ax, ay, as, { arm: [10, 70 + Math.sin(t * 4) * 10], leg: [6, 6], face: "grin", shirt: "#2A9D8F", pants: "#6D4C41",
      hold: `<g transform="translate(1.4 1.0)"><rect x="-0.5" y="0" width="1.1" height="0.8" rx="0.15" fill="#9E9E9E"/><path d="M0.6 0.2 L1.4 -0.3" stroke="#9E9E9E" stroke-width="0.18"/></g>` });
  }
  // Titel
  if (ic) {
    s += title("GARDEN", w * 0.5, h * 0.12, 104, { rot: -4, fill: "url(#green)" });
    s += title("GROW", w * 0.5, h * 0.9, 110, { rot: 3 });
  } else if (v) {
    s += title("GARDEN GROW", w * 0.5, h * 0.08, 140, { rot: -3, fill: "url(#green)" });
    const hook = t < 2.5 ? "PLANT A SEED..." : t < 5 ? "WATCH IT GROW..." : t < 7.5 ? "RAINBOW MUTATION!" : "PLAY FREE NOW";
    s += title(hook, w * 0.5, h * 0.17, 92, { fill: "url(#white)", scale: pop((t % 2.5) * 2) });
    if (t > 5) s += badge("WORTH x50!", w * 0.5, h * 0.6, 70, "#7B2CBF", -3, pop((t - 5) * 1.5));
    s += badge("SEARCH: GARDEN GROW", w * 0.5, h * 0.93, 58, "#2B9348");
  } else {
    s += title("GARDEN GROW", w * 0.3, h * 0.15, 170, { rot: -3, fill: "url(#green)" });
    s += title("RAINBOW", w * 0.8, h * 0.13, 100, { rot: 4, fill: "url(#rainbow)" });
    s += title("MUTATION!", w * 0.76, h * 0.88, 110, { rot: -3, fill: "url(#white)" });
  }
  s += vignette(w, h);
  return s;
};

module.exports = { scenes, SIZES };
