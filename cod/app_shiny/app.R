# =============================================================================
# Aplicación Shiny: Optimización de tiempos semafóricos
# -----------------------------------------------------------------------------
# Objetivo específico 5 del proyecto: una aplicación interactiva que permita
# introducir distintas condiciones de flujo vehicular, ejecutar la optimización
# y visualizar la configuración semafórica recomendada y los indicadores.
#
# Requiere el paquete 'shiny' y el archivo cod/modelo_semaforos.R.
# Para ejecutarla:   shiny::runApp("cod/app_shiny")   (o botón "Run App" en RStudio)
# =============================================================================

library(shiny)

# =============================================================================
# 1. MODELO (compartido con el script de análisis)
# =============================================================================
# Está en cod/modelo_semaforos.R. La app busca el archivo un nivel arriba de
# su carpeta (cod/app_shiny/ -> cod/) y, por si acaso, en otras ubicaciones.
ruta_modelo <- c("../modelo_semaforos.R", "cod/modelo_semaforos.R", "modelo_semaforos.R")
ruta_modelo <- ruta_modelo[file.exists(ruta_modelo)][1]
if (is.na(ruta_modelo))
  stop("No se encontró modelo_semaforos.R. Debe estar en la carpeta cod/, ",
       "un nivel arriba de la carpeta de la app.")
source(ruta_modelo, local = TRUE)

# Escenarios predefinidos (los dos primeros son datos reales del MOPT 2023)
ESCENARIOS <- data.frame(
  nombre = c("MOPT mañana (7:30-8:30)", "MOPT tarde (16:30-17:30)",
             "Flujo bajo", "Flujo equilibrado",
             "Predominio Norte-Sur", "Alta demanda"),
  q.NS = c(298, 384, 300, 800, 1300, 1200),
  q.EO = c(955, 699, 250, 800,  400, 1000),
  n.NS = 2, n.EO = 2,
  stringsAsFactors = FALSE
)

# =============================================================================
# SIMULACIÓN VISUAL (JavaScript): animación de la intersección
# =============================================================================
# Motor y controles de la animación (dibuja en un <canvas>). Recibe desde R los
# tiempos de verde recomendados y los flujos, y simula llegadas, filas y semáforos.
JS_SIM <- r"---(
(function (root) {
'use strict';

/* ==========================================================================
   Simulación visual de una intersección semaforizada de dos fases.
   - Motor (Sim): llegadas aleatorias, filas, salida con flujo de saturación,
     semáforos con los tiempos de verde recibidos desde R.
   - Interfaz: controles, dos paneles (comparar planes) y estadísticas.
   ========================================================================== */

// ---------- Constantes de la escena (1 px \u2248 0,15 m) ----------
var K = 1.5;   // factor de escala visual
var W = 1000, H = 680, CX = 500, CY = 340, LANE = 24 * K;
var VMAX = 75 * K, ACC = 18 * K, BRK = 40 * K, GAP = 6 * K, DT = 0.1, START_S = -50 * K, SOFF = 14 * K;

var TIPOS = [
  { n: 'auto',   p: 0.70, len: 28 * K, wid: 14 * K },
  { n: 'camion', p: 0.12, len: 40 * K, wid: 16 * K },
  { n: 'bus',    p: 0.08, len: 46 * K, wid: 17 * K },
  { n: 'moto',   p: 0.10, len: 15 * K, wid: 7 * K }
];
var COLORES_AUTO = ['#d63031', '#c0392b', '#e84c3d', '#2d3436', '#8395a7', '#dfe6e9', '#0984e3', '#6c5ce7'];

function mulberry32(a) {
  return function () {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    var t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

// ---------- Proceso de llegadas (idéntico para dos simulaciones con la misma semilla) ----------
function Llegadas(rate, seed) {
  this.r = mulberry32(seed); this.rate = rate; this.t = 0; this.next = null; this._gen();
}
Llegadas.prototype._gen = function () {
  if (this.rate <= 0) { this.next = null; return; }
  this.t += -Math.log(1 - this.r()) / this.rate;
  var tp = this.r(), acc = 0, tipo = TIPOS[0], i;
  for (i = 0; i < TIPOS.length; i++) { acc += TIPOS[i].p; if (tp <= acc) { tipo = TIPOS[i]; break; } }
  var color = tipo.n === 'auto' ? COLORES_AUTO[Math.floor(this.r() * COLORES_AUTO.length)] : null;
  this.next = { t: this.t, tipo: tipo, color: color };
};
Llegadas.prototype.take = function (hasta) {
  var out = [];
  while (this.next && this.next.t <= hasta) { out.push(this.next); this._gen(); }
  return out;
};

// ---------- Dibujo auxiliar ----------
function rr(ctx, x, y, w, h, r) {
  ctx.beginPath(); ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
}

function dibujarVehiculo(ctx, v, x, y, ang, frenando) {
  var L = v.len, A = v.wid, n = v.tipo.n;
  ctx.save(); ctx.translate(x, y); ctx.rotate(ang);
  ctx.fillStyle = 'rgba(0,0,0,.28)'; rr(ctx, -L / 2 + 1.5, -A / 2 + 2, L, A, 3); ctx.fill();
  if (n === 'auto') {
    ctx.fillStyle = v.color; rr(ctx, -L / 2, -A / 2, L, A, 5); ctx.fill();
    ctx.fillStyle = 'rgba(15,25,35,.78)'; rr(ctx, -L * 0.14, -A / 2 + 2, L * 0.36, A - 4, 2); ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,.22)'; rr(ctx, -L / 2 + 3, -A / 2 + 1, L - 8, 2, 1); ctx.fill();
  } else if (n === 'camion') {
    ctx.fillStyle = '#2a8fa6'; rr(ctx, -L / 2, -A / 2, L * 0.68, A, 2); ctx.fill();
    ctx.fillStyle = '#f2b705'; rr(ctx, L * 0.2, -A / 2 + 1, L * 0.3, A - 2, 3); ctx.fill();
    ctx.fillStyle = 'rgba(15,25,35,.78)'; rr(ctx, L * 0.38, -A / 2 + 3, L * 0.09, A - 6, 1); ctx.fill();
  } else if (n === 'bus') {
    ctx.fillStyle = '#f5a800'; rr(ctx, -L / 2, -A / 2, L, A, 4); ctx.fill();
    ctx.fillStyle = 'rgba(15,25,35,.7)';
    for (var i = -2; i <= 2; i++) { ctx.fillRect(i * (L / 6.2) - 3, -A / 2 + 3, 6, A - 6); }
  } else {
    ctx.fillStyle = '#1f6fe0'; rr(ctx, -L / 2, -A / 2, L, A, 3); ctx.fill();
    ctx.fillStyle = '#222'; ctx.beginPath(); ctx.arc(-1, 0, 3.3, 0, 6.2832); ctx.fill();
    ctx.fillStyle = '#eee'; ctx.beginPath(); ctx.arc(0.5, 0, 2, 0, 6.2832); ctx.fill();
  }
  if (n !== 'moto') {
    ctx.fillStyle = 'rgba(255,240,170,.9)';
    ctx.fillRect(L / 2 - 2, -A / 2 + 1.5, 2, 3); ctx.fillRect(L / 2 - 2, A / 2 - 4.5, 2, 3);
    if (frenando) {
      ctx.fillStyle = '#ff3b30';
      ctx.fillRect(-L / 2, -A / 2 + 1.5, 2.5, 3.2); ctx.fillRect(-L / 2, A / 2 - 4.7, 2.5, 3.2);
    }
  }
  ctx.restore();
}

function dibujarSemaforo(ctx, x, y, luz) {
  ctx.save(); ctx.translate(x, y); ctx.scale(1.2, 1.2);
  ctx.fillStyle = 'rgba(0,0,0,.35)'; rr(ctx, -8, -23, 20, 52, 6); ctx.fill();
  ctx.fillStyle = '#111'; rr(ctx, -10, -26, 20, 52, 6); ctx.fill();
  var col = [['rojo', '#ff2b2b'], ['amarillo', '#ffc61a'], ['verde', '#27e04b']], i;
  for (i = 0; i < 3; i++) {
    var on = luz.c === col[i][0];
    ctx.fillStyle = on ? col[i][1] : '#454545';
    ctx.beginPath(); ctx.arc(0, -16 + i * 16, 6, 0, 6.2832); ctx.fill();
    if (on) { ctx.fillStyle = 'rgba(255,255,255,.55)'; ctx.beginPath(); ctx.arc(-1.8, -17.8 + i * 16, 1.8, 0, 6.2832); ctx.fill(); }
  }
  ctx.font = 'bold 14px sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'bottom';
  ctx.lineWidth = 3; ctx.strokeStyle = '#000'; ctx.fillStyle = '#fff';
  var txt = String(Math.max(0, Math.ceil(luz.rem - 1e-9)));
  ctx.strokeText(txt, 0, -29); ctx.fillText(txt, 0, -29);
  ctx.restore();
}

// ---------- Simulación ----------
// cfg: {qNS,qEO,nNS,nEO,L,s}   plan: {gNS,gEO}
function Sim(cfg, plan, semilla, crearLienzo) {
  this.cfg = cfg; this.gNS = plan.gNS; this.gEO = plan.gEO; this.L = cfg.L;
  this.C = this.gNS + this.gEO + this.L;
  this.LN = Math.max(1, Math.round(cfg.nNS / 2));   // carriles por sentido, calle N-S
  this.LE = Math.max(1, Math.round(cfg.nEO / 2));   // carriles por sentido, calle E-O
  this.semilla = semilla; this.crear = crearLienzo;
  var hV = this.LN * LANE, hH = this.LE * LANE;
  this.hV = hV; this.hH = hH;
  this.geom = {
    O: { fase: 'EO', dx: 1,  dy: 0,  ox: 0,  oy: CY, sStop: CX - hV - SOFF,        largo: W, nl: this.LE },
    E: { fase: 'EO', dx: -1, dy: 0,  ox: W,  oy: CY, sStop: W - (CX + hV + SOFF),   largo: W, nl: this.LE },
    N: { fase: 'NS', dx: 0,  dy: 1,  ox: CX, oy: 0,  sStop: CY - hH - SOFF,        largo: H, nl: this.LN },
    S: { fase: 'NS', dx: 0,  dy: -1, ox: CX, oy: H,  sStop: H - (CY + hH + SOFF),   largo: H, nl: this.LN }
  };
  this.fondo = null;
  this.reset();
}

Sim.prototype.reset = function () {
  var self = this, cfg = this.cfg, ids = ['O', 'E', 'N', 'S'], seeds = { O: 1, E: 2, N: 3, S: 4 };
  this.t = 0; this.accesos = {};
  ids.forEach(function (id) {
    var g = self.geom[id], q = g.fase === 'NS' ? cfg.qNS : cfg.qEO, nF = g.fase === 'NS' ? cfg.nNS : cfg.nEO;
    var a = { id: id, fase: g.fase, dx: g.dx, dy: g.dy, ox: g.ox, oy: g.oy, lx: -g.dy, ly: g.dx,
              sStop: g.sStop, largo: g.largo, nl: g.nl, h: 7200 * g.nl / (cfg.s * nF),
              lanes: [], pend: [], llegadas: new Llegadas(q / 2 / 3600, self.semilla * 10 + seeds[id]) };
    for (var k = 0; k < g.nl; k++) a.lanes.push({ veh: [], ultimo: -1e9 });
    self.accesos[id] = a;
  });
  this.st = { n: 0, suma: 0, nNS: 0, sNS: 0, nEO: 0, sEO: 0, ult: [] };
  this.luces = { NS: this.luz('NS'), EO: this.luz('EO') };
};

Sim.prototype.luz = function (fase) {
  var C = this.C, tau = this.t % C, y = this.L / 2;
  var ini = fase === 'NS' ? 0 : this.gNS + y, g = fase === 'NS' ? this.gNS : this.gEO;
  var rel = ((tau - ini) % C + C) % C;
  if (rel < g) return { c: 'verde', rem: g - rel };
  if (rel < g + y) return { c: 'amarillo', rem: g + y - rel };
  return { c: 'rojo', rem: C - rel };
};

Sim.prototype._spawn = function (a) {
  while (a.pend.length) {
    var p = a.pend[0], best = null, bestN = 1e9, k;
    for (k = 0; k < a.lanes.length; k++) {
      var vs = a.lanes[k].veh, last = vs.length ? vs[vs.length - 1] : null;
      var libre = !last || (last.s - last.len / 2 - GAP >= START_S + p.tipo.len / 2);
      if (libre) {
        var nn = 0; for (var j = 0; j < vs.length; j++) if (!vs[j].cruzo) nn++;
        if (nn < bestN) { bestN = nn; best = k; }
      }
    }
    if (best === null) return;
    a.pend.shift();
    a.lanes[best].veh.push({ s: START_S, v: VMAX, len: p.tipo.len, wid: p.tipo.wid, tipo: p.tipo,
                             color: p.color, tArr: p.t, go: false, cruzo: false, frena: false, lane: best });
  }
};

Sim.prototype.step = function (dt) {
  var t = this.t, self = this;
  this.luces = { NS: this.luz('NS'), EO: this.luz('EO') };
  ['O', 'E', 'N', 'S'].forEach(function (id) {
    var a = self.accesos[id], luz = self.luces[a.fase];
    a.llegadas.take(t + dt).forEach(function (p) { a.pend.push(p); });
    self._spawn(a);
    a.lanes.forEach(function (ln) {
      var vs = ln.veh, i;
      for (i = 0; i < vs.length; i++) {
        var v = vs[i], smax = 1e9;
        if (i > 0) { var l = vs[i - 1]; smax = l.s - l.len / 2 - v.len / 2 - GAP; }
        if (!v.go) {
          var dl = a.sStop - (v.s + v.len / 2);
          if ((i === 0 || vs[i - 1].go) && luz.c === 'verde' && dl <= 110 * K && t - ln.ultimo >= (v.v > 0.92 * VMAX ? 0.7 : a.h)) { v.go = true; ln.ultimo = t; }
          else smax = Math.min(smax, a.sStop - v.len / 2);
        }
        var dist = smax - v.s, vcap = dist <= 0 ? 0 : Math.sqrt(2 * BRK * dist), vt = Math.min(VMAX, vcap);
        if (vt > v.v) v.v = Math.min(vt, v.v + ACC * dt); else v.v = Math.max(vt, v.v - 2 * BRK * dt);
        v.frena = v.v < vt - 1 || v.v < 4;
        v.s += v.v * dt;
        if (v.s > smax) { v.s = smax; v.v = Math.min(v.v, i > 0 ? vs[i - 1].v : 0); }
        if (!v.cruzo && v.go && v.s + v.len / 2 > a.sStop) {
          v.cruzo = true;
          var d = Math.max(0, (t + dt - v.tArr) - (a.sStop - START_S) / VMAX), st = self.st;
          st.n++; st.suma += d; st.ult.push(d); if (st.ult.length > 50) st.ult.shift();
          if (a.fase === 'NS') { st.nNS++; st.sNS += d; } else { st.nEO++; st.sEO += d; }
        }
      }
      while (vs.length && vs[0].s - vs[0].len / 2 > a.largo + 40 * K) vs.shift();
    });
  });
  this.t += dt;
};

Sim.prototype.espera = function () { return this.st.n ? this.st.suma / this.st.n : NaN; };
Sim.prototype.espera50 = function () {
  var u = this.st.ult; if (!u.length) return NaN;
  var s = 0; for (var i = 0; i < u.length; i++) s += u[i]; return s / u.length;
};
Sim.prototype.enFila = function () {
  var out = {};
  for (var id in this.accesos) {
    var a = this.accesos[id], n = a.pend.length;
    a.lanes.forEach(function (ln) { ln.veh.forEach(function (v) { if (!v.cruzo && v.v < 12 * K) n++; }); });
    out[id] = n;
  }
  return out;
};

Sim.prototype._pos = function (a, v) {
  var off = (v.lane + 0.5) * LANE;
  return [a.ox + a.dx * v.s + a.lx * off, a.oy + a.dy * v.s + a.ly * off];
};

// ---------- Fondo (carretera) ----------
Sim.prototype._dibujarFondo = function () {
  var c = this.crear(W, H), ctx = c.getContext('2d'), hV = this.hV, hH = this.hH, rnd = mulberry32(7), x, y, k;
  ctx.fillStyle = '#2f5f36'; ctx.fillRect(0, 0, W, H);
  for (x = 0; x < W; x += 10) for (y = 0; y < H; y += 10) {
    var r = rnd(); ctx.fillStyle = r < 0.33 ? 'rgba(20,60,25,.35)' : (r < 0.55 ? 'rgba(90,150,80,.18)' : 'rgba(0,0,0,0)');
    ctx.fillRect(x, y, 10, 10);
  }
  ctx.fillStyle = '#a9a9a9';                                      // aceras
  ctx.fillRect(0, CY - hH - 9, W, 2 * hH + 18); ctx.fillRect(CX - hV - 9, 0, 2 * hV + 18, H);
  ctx.fillStyle = '#3c4046';                                      // asfalto
  ctx.fillRect(0, CY - hH, W, 2 * hH); ctx.fillRect(CX - hV, 0, 2 * hV, H);
  ctx.fillStyle = '#43474e'; ctx.fillRect(CX - hV, CY - hH, 2 * hV, 2 * hH);
  ctx.fillStyle = '#e9e9e9';                                      // bordes
  ctx.fillRect(0, CY - hH + 1, CX - hV, 2); ctx.fillRect(CX + hV, CY - hH + 1, W - CX - hV, 2);
  ctx.fillRect(0, CY + hH - 3, CX - hV, 2); ctx.fillRect(CX + hV, CY + hH - 3, W - CX - hV, 2);
  ctx.fillRect(CX - hV + 1, 0, 2, CY - hH); ctx.fillRect(CX - hV + 1, CY + hH, 2, H - CY - hH);
  ctx.fillRect(CX + hV - 3, 0, 2, CY - hH); ctx.fillRect(CX + hV - 3, CY + hH, 2, H - CY - hH);
  ctx.fillStyle = '#f0b400';                                      // doble línea amarilla
  [-2.5, 1].forEach(function (o) {
    ctx.fillRect(0, CY + o, CX - hV, 1.6); ctx.fillRect(CX + hV, CY + o, W - CX - hV, 1.6);
    ctx.fillRect(CX + o, 0, 1.6, CY - hH); ctx.fillRect(CX + o, CY + hH, 1.6, H - CY - hH);
  });
  ctx.fillStyle = 'rgba(255,255,255,.75)';                        // líneas entre carriles del mismo sentido
  for (k = 1; k < this.LE; k++) for (x = 0; x < W; x += 22 * K) {
    if (x + 12 * K < CX - hV - 14 * K || x > CX + hV + 14 * K) { ctx.fillRect(x, CY + k * LANE - 1, 12 * K, 2); ctx.fillRect(x, CY - k * LANE - 1, 12 * K, 2); }
  }
  for (k = 1; k < this.LN; k++) for (y = 0; y < H; y += 22 * K) {
    if (y + 12 * K < CY - hH - 14 * K || y > CY + hH + 14 * K) { ctx.fillRect(CX + k * LANE - 1, y, 2, 12 * K); ctx.fillRect(CX - k * LANE - 1, y, 2, 12 * K); }
  }
  var g = this.geom, id, a, i;                                    // cebras y líneas de alto
  ctx.fillStyle = '#f4f4f4';
  var z = 8 * K;
  for (i = 0; i < 2 * hH - z / 2; i += z) {
    ctx.fillRect(CX - hV - 11 * K, CY - hH + i + 2, 8 * K, 4 * K); ctx.fillRect(CX + hV + 3 * K, CY - hH + i + 2, 8 * K, 4 * K);
  }
  for (i = 0; i < 2 * hV - z / 2; i += z) {
    ctx.fillRect(CX - hV + i + 2, CY - hH - 11 * K, 4 * K, 8 * K); ctx.fillRect(CX - hV + i + 2, CY + hH + 3 * K, 4 * K, 8 * K);
  }
  ctx.fillRect(g.O.sStop - 2, CY, 4, hH); ctx.fillRect(W - g.E.sStop - 2, CY - hH, 4, hH);
  ctx.fillRect(CX - hV, g.N.sStop - 2, hV, 4); ctx.fillRect(CX, H - g.S.sStop - 2, hV, 4);
  this.fondo = c;
};

Sim.prototype.draw = function (ctx) {
  if (!this.fondo) this._dibujarFondo();
  ctx.drawImage(this.fondo, 0, 0);
  var self = this, id;
  for (id in this.accesos) {
    var a = this.accesos[id], ang = Math.atan2(a.dy, a.dx);
    a.lanes.forEach(function (ln) {
      ln.veh.forEach(function (v) { var p = self._pos(a, v); dibujarVehiculo(ctx, v, p[0], p[1], ang, v.frena && !v.cruzo); });
    });
  }
  for (id in this.accesos) {
    var b = this.accesos[id], off = b.nl * LANE + 24;
    dibujarSemaforo(ctx, b.ox + b.dx * (b.sStop - 6) + b.lx * off, b.oy + b.dy * (b.sStop - 6) + b.ly * off, this.luces[b.fase]);
  }
};

var API = { Sim: Sim, W: W, H: H, DT: DT };

/* ==========================================================================
   INTERFAZ (solo navegador)
   ========================================================================== */
function iniciarUI() {
  var cont = document.getElementById('sim-root');
  if (!cont || cont.getAttribute('data-listo')) return;
  cont.setAttribute('data-listo', '1');

  var css = '' +
    '.sim-bar{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin-bottom:10px;background:#fff;padding:10px 12px;border-radius:10px;box-shadow:0 1px 3px rgba(0,0,0,.12)}' +
    '.sim-bar label{margin:0 4px 0 0;font-weight:600;font-size:13px}' +
    '.sim-bar select,.sim-bar input[type=number]{padding:3px 6px;border:1px solid #ccc;border-radius:5px}' +
    '.sim-bar input[type=number]{width:62px}' +
    '.sim-btn{border:0;border-radius:6px;padding:6px 12px;font-weight:600;cursor:pointer;color:#fff;background:#2e8b57}' +
    '.sim-btn.sec{background:#5b6b7a}' +
    '.sim-grid{display:flex;flex-wrap:wrap;gap:12px}' +
    '.sim-card{flex:1 1 440px;min-width:300px;background:#fff;border-radius:10px;padding:10px;box-shadow:0 1px 3px rgba(0,0,0,.12)}' +
    '.sim-card canvas{width:100%;height:auto;border-radius:8px;display:block;background:#222}' +
    '.sim-title{display:flex;justify-content:space-between;flex-wrap:wrap;margin-bottom:6px;font-size:14px}' +
    '.sim-title span{color:#666;font-size:12px}' +
    '.sim-stats{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-top:8px}' +
    '.sim-stats div{background:#f4f6f8;border-radius:8px;padding:6px 8px}' +
    '.sim-stats .k{display:block;font-size:11px;color:#666;text-transform:uppercase;letter-spacing:.03em}' +
    '.sim-stats .v{font-size:16px;font-weight:700}' +
    '.sim-stats .big{font-size:22px;color:#2e8b57}' +
    '.sim-res{margin:10px 0;padding:10px 14px;background:#e9f7ef;border-left:4px solid #2e8b57;border-radius:6px;display:none}' +
    '.sim-nota{color:#666;font-size:12px;margin-top:10px}';
  var st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);

  cont.innerHTML = '' +
    '<div class="sim-bar">' +
    ' <span><label for="sim-plan">Plan de semáforo</label><select id="sim-plan">' +
    '  <option value="opt">Optimizada (recomendada)</option><option value="web">Webster (referencia)</option>' +
    '  <option value="eq">Equitativa</option><option value="man">Manual</option></select></span>' +
    ' <span id="sim-man" style="display:none"><label>Verde N-S</label><input id="sim-gns" type="number" min="5" max="150" value="20"> ' +
    '  <label>Verde E-O</label><input id="sim-geo" type="number" min="5" max="150" value="20"></span>' +
    ' <span><label for="sim-vel">Velocidad</label><select id="sim-vel"><option value="1">1×</option><option value="2">2×</option>' +
    '  <option value="5" selected>5×</option><option value="10">10×</option><option value="30">30×</option><option value="60">60×</option></select></span>' +
    ' <button class="sim-btn" id="sim-pp">\u23F8 Pausar</button>' +
    ' <button class="sim-btn sec" id="sim-rs">\u27F2 Reiniciar</button>' +
    ' <button class="sim-btn sec" id="sim-sem">\uD83C\uDFB2 Otro azar</button>' +
    ' <span><input type="checkbox" id="sim-cmp"> <label for="sim-cmp">Comparar con otro plan</label></span>' +
    '</div>' +
    '<div class="sim-res" id="sim-res"></div>' +
    '<div class="sim-grid" id="sim-grid"></div>' +
    '<div class="sim-nota">Los vehículos llegan al azar según el flujo de cada calle (repartido por igual entre sus dos sentidos). ' +
    'Un vehículo sale cada 3600/(flujo de saturación) segundos por carril durante el verde, igual que en el modelo. ' +
    'La espera de la simulación visual puede ser algo mayor que la del modelo porque aquí los vehículos aceleran y frenan.</div>';

  function panel(sfx) {
    return '<div class="sim-card" id="card' + sfx + '"><div class="sim-title"><b id="tit' + sfx + '"></b><span id="sub' + sfx + '"></span></div>' +
      '<canvas id="cv' + sfx + '" width="' + W + '" height="' + H + '"></canvas>' +
      '<div class="sim-stats">' +
      '<div><span class="k">Tiempo simulado</span><span class="v" id="tm' + sfx + '">00:00</span></div>' +
      '<div><span class="k">Espera promedio</span><span class="v big" id="w' + sfx + '">\u2013</span></div>' +
      '<div><span class="k">Últimos 50 veh.</span><span class="v" id="w50' + sfx + '">\u2013</span></div>' +
      '<div><span class="k">Atendidos</span><span class="v" id="n' + sfx + '">0</span></div>' +
      '<div><span class="k">En fila N / S / E / O</span><span class="v" id="q' + sfx + '">\u2013</span></div>' +
      '<div><span class="k">Modelo (validación)</span><span class="v" id="m' + sfx + '">\u2013</span></div>' +
      '</div></div>';
  }
  document.getElementById('sim-grid').innerHTML = panel('A') + panel('B');

  var crear = function (w, h) { var c = document.createElement('canvas'); c.width = w; c.height = h; return c; };
  var E = { cfg: null, planes: null, A: null, B: null, pausado: false, vel: 5, cmp: false, semilla: 2025, acum: 0 };
  var el = function (id) { return document.getElementById(id); };
  var fmt = function (x, d) { return isFinite(x) ? x.toFixed(d).replace('.', ',') : '\u2013'; };

  function plan(clave) {
    var P = E.planes;
    if (clave === 'man') {
      var a = Math.max(5, Math.round(+el('sim-gns').value || 20)), b = Math.max(5, Math.round(+el('sim-geo').value || 20));
      return { gNS: a, gEO: b, nombre: 'Manual', W: null };
    }
    var q = P[clave], nombres = { opt: 'Optimizada', web: 'Webster', eq: 'Equitativa' };
    return { gNS: q.gNS, gEO: q.gEO, nombre: nombres[clave], W: q.W };
  }

  function reconstruir() {
    if (!E.cfg || !E.planes) return;
    var kA = el('sim-plan').value, kB = kA === 'eq' ? 'opt' : 'eq';
    E.pA = plan(kA); E.pB = plan(kB);
    E.A = new Sim(E.cfg, E.pA, E.semilla, crear);
    E.B = new Sim(E.cfg, E.pB, E.semilla, crear);
    var s = ['A', 'B'];
    [E.pA, E.pB].forEach(function (p, i) {
      el('tit' + s[i]).textContent = 'Plan ' + p.nombre;
      el('sub' + s[i]).textContent = 'Verde N-S ' + p.gNS + ' s · Verde E-O ' + p.gEO + ' s · Ciclo ' + (p.gNS + p.gEO + E.cfg.L) + ' s';
      el('m' + s[i]).textContent = p.W == null ? '\u2013' : fmt(p.W, 1) + ' s';
    });
    el('cardB').style.display = E.cmp ? '' : 'none';
    el('sim-res').style.display = 'none';
  }

  function textoTiempo(t) { var m = Math.floor(t / 60), s = Math.floor(t % 60); return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s; }

  function pintarStats(sim, sfx) {
    var q = sim.enFila();
    el('tm' + sfx).textContent = textoTiempo(sim.t);
    el('w' + sfx).textContent = fmt(sim.espera(), 1) + ' s';
    el('w50' + sfx).textContent = fmt(sim.espera50(), 1) + ' s';
    el('n' + sfx).textContent = sim.st.n;
    el('q' + sfx).textContent = q.N + ' / ' + q.S + ' / ' + q.E + ' / ' + q.O;
  }

  function resumen() {
    if (!E.cmp || !E.A || !E.B || E.A.st.n < 40 || E.B.st.n < 40) { el('sim-res').style.display = 'none'; return; }
    var a = E.A.espera(), b = E.B.espera(), d = 100 * (b - a) / b, r = el('sim-res');
    r.style.display = 'block';
    r.innerHTML = 'Hasta ahora, con el plan <b>' + E.pA.nombre + '</b> cada vehículo espera en promedio <b>' + fmt(a, 1) +
      ' s</b> y con el plan <b>' + E.pB.nombre + '</b> <b>' + fmt(b, 1) + ' s</b>: ' +
      (d >= 0 ? '<b>' + fmt(d, 0) + ' % menos</b> espera con el plan ' + E.pA.nombre + '.' :
                '<b>' + fmt(-d, 0) + ' % más</b> espera con el plan ' + E.pA.nombre + '.');
  }

  var ctxA = el('cvA').getContext('2d'), ctxB = el('cvB').getContext('2d');
  var ultimo = null, ultStats = 0;
  function visible() { return cont.offsetParent !== null; }
  function frame(ts) {
    if (ultimo === null) ultimo = ts;
    var dtR = Math.min((ts - ultimo) / 1000, 0.1); ultimo = ts;
    if (E.A && visible()) {
      if (!E.pausado) {
        E.acum += dtR * E.vel;
        var pasos = 0;
        while (E.acum >= DT && pasos < 400) {
          E.A.step(DT); if (E.cmp) E.B.step(DT);
          E.acum -= DT; pasos++;
        }
        if (E.acum > DT) E.acum = 0;
      }
      E.A.draw(ctxA); if (E.cmp) E.B.draw(ctxB);
      if (ts - ultStats > 250) {
        ultStats = ts; pintarStats(E.A, 'A'); if (E.cmp) pintarStats(E.B, 'B'); resumen();
      }
    }
    root.requestAnimationFrame(frame);
  }

  el('sim-plan').onchange = function () { el('sim-man').style.display = this.value === 'man' ? '' : 'none'; reconstruir(); };
  el('sim-gns').onchange = el('sim-geo').onchange = function () { if (el('sim-plan').value === 'man') reconstruir(); };
  el('sim-vel').onchange = function () { E.vel = +this.value; };
  el('sim-pp').onclick = function () { E.pausado = !E.pausado; this.textContent = E.pausado ? '\u25B6 Reanudar' : '\u23F8 Pausar'; };
  el('sim-rs').onclick = reconstruir;
  el('sim-sem').onclick = function () { E.semilla = Math.floor(Math.random() * 100000); reconstruir(); };
  el('sim-cmp').onchange = function () { E.cmp = this.checked; reconstruir(); };

  API.cargar = function (m) {
    E.cfg = { qNS: m.qNS, qEO: m.qEO, nNS: m.nNS, nEO: m.nEO, L: m.L, s: m.s };
    E.planes = m.planes;
    el('sim-gns').value = m.planes.opt.gNS; el('sim-geo').value = m.planes.opt.gEO;
    reconstruir();
  };
  API._E = E;
  root.requestAnimationFrame(frame);

  (function registrar() {
    if (root.Shiny && root.Shiny.addCustomMessageHandler) {
      root.Shiny.addCustomMessageHandler('sim_plan', function (m) { API.cargar(m); });
      if (root.Shiny.setInputValue) root.Shiny.setInputValue('sim_listo', Math.random());
    } else setTimeout(registrar, 100);
  })();
}

if (typeof module !== 'undefined' && module.exports) module.exports = API;
if (typeof document !== 'undefined') {
  root.SimSemaforo = API;
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', iniciarUI);
  else iniciarUI();
}

})(typeof window !== 'undefined' ? window : globalThis);
)---"

# Datos que R envía a la animación: flujos, carriles y los tres planes de verde
mensaje_sim <- function(r) {
  plan <- function(g, res) list(gNS = unname(g["g.NS"]), gEO = unname(g["g.EO"]),
                                W = unname(res["W"]))
  list(qNS = r$esc$q.NS, qEO = r$esc$q.EO, nNS = r$esc$n.NS, nEO = r$esc$n.EO,
       L = r$p$L, s = r$p$s,
       planes = list(opt = plan(r$g.opt, r$res.opt),
                     web = plan(r$g.web, r$res.web),
                     eq  = plan(r$g.eq,  r$res.eq)))
}

# =============================================================================
# 2. INTERFAZ
# =============================================================================
fmt <- function(x, d = 1) format(round(x, d), decimal.mark = ",", nsmall = d)

css <- "
body { background:#f6f7f9; }
.tarjeta { background:#fff; border-radius:10px; padding:14px 10px; text-align:center;
           box-shadow:0 1px 3px rgba(0,0,0,.12); margin-bottom:12px; }
.tarjeta .num { font-size:30px; font-weight:700; line-height:1.1; }
.tarjeta .lab { font-size:12px; color:#666; text-transform:uppercase; letter-spacing:.04em; }
.verde { color:#2e8b57; } .azul { color:#4682b4; } .rojo { color:#e5533d; } .gris { color:#444; }
.caja { background:#fff; border-radius:10px; padding:14px 18px; margin-bottom:12px;
        box-shadow:0 1px 3px rgba(0,0,0,.12); }
.aviso { background:#fff4e5; border-left:4px solid #f0a030; padding:10px 14px;
         border-radius:6px; margin-bottom:12px; }
.semaforo { display:inline-block; width:14px; height:14px; border-radius:50%; margin-right:3px; }
"

ui <- fluidPage(
  tags$head(tags$style(HTML(css))),
  titlePanel(
    div(span(class = "semaforo", style = "background:#e5533d"),
        span(class = "semaforo", style = "background:#f0c030"),
        span(class = "semaforo", style = "background:#2e8b57"),
        "Optimización de tiempos semafóricos")),
  p("Modifique el flujo vehicular y las características de la intersección; ",
    "la aplicación busca el reparto de luz verde que minimiza el tiempo ",
    "promedio de espera de los vehículos."),

  sidebarLayout(
    sidebarPanel(
      width = 3,
      selectInput("preset", "Escenario predefinido",
                  choices = c("Personalizado", ESCENARIOS$nombre),
                  selected = ESCENARIOS$nombre[1]),
      h4("Flujo vehicular (veh/h)"),
      numericInput("q.NS", "Norte-Sur", value = ESCENARIOS$q.NS[1], min = 0, max = 4000, step = 50),
      numericInput("q.EO", "Este-Oeste", value = ESCENARIOS$q.EO[1], min = 0, max = 4000, step = 50),
      h4("Carriles que atiende cada fase"),
      numericInput("n.NS", "Norte-Sur", value = 2, min = 1, max = 6, step = 1),
      numericInput("n.EO", "Este-Oeste", value = 2, min = 1, max = 6, step = 1),
      checkboxInput("avanzado", "Mostrar parámetros avanzados", FALSE),
      conditionalPanel(
        "input.avanzado",
        numericInput("s", "Flujo de saturación (veh/h/carril)", 1800, min = 1000, max = 2400, step = 50),
        numericInput("L", "Transición/despeje por ciclo L (s)", 8, min = 0, max = 30, step = 1),
        numericInput("g_min", "Verde mínimo (s)", 10, min = 5, max = 60, step = 1),
        numericInput("g_max", "Verde máximo (s)", 90, min = 20, max = 180, step = 5),
        numericInput("C_max", "Ciclo máximo (s)", 150, min = 40, max = 240, step = 5),
        numericInput("g_base", "Verde del reparto equitativo (s)", 30, min = 5, max = 90, step = 1),
        numericInput("T_sim", "Duración simulada (s)", 3600, min = 600, max = 7200, step = 600),
        numericInput("n_rep", "Repeticiones de la simulación", 10, min = 2, max = 50, step = 1),
        numericInput("paso", "Paso de la búsqueda (s)", 5, min = 1, max = 10, step = 1),
        numericInput("semilla", "Semilla aleatoria", 2025, step = 1)
      ),
      actionButton("optimizar", "Optimizar", class = "btn-success btn-lg",
                   style = "width:100%; margin-top:8px;"),
      p(style = "color:#777; font-size:12px; margin-top:8px;",
        "Con 10 repeticiones el cálculo tarda unos segundos. ",
        "Más repeticiones dan resultados más estables.")
    ),

    mainPanel(
      width = 9,
      tabsetPanel(
        tabPanel("Simulación visual",
                 br(),
                 p("Animación de la intersección con los tiempos de verde que recomendó la optimización. ",
                   "Presione ", strong("Optimizar"), " para recalcular con otros flujos; la animación se actualiza sola. ",
                   "Use \"Comparar con otro plan\" para ver, con las mismas llegadas de vehículos, la diferencia contra el reparto equitativo."),
                 div(id = "sim-root"),
                 tags$script(HTML(JS_SIM))),
        tabPanel("Resultado recomendado",
                 br(),
                 uiOutput("aviso"),
                 uiOutput("tarjetas"),
                 uiOutput("interpretacion"),
                 h4("Indicadores por configuración"),
                 tableOutput("tabla")),
        tabPanel("Gráficos",
                 br(),
                 h4("Tiempo promedio de espera"),
                 plotOutput("g_espera", height = "300px"),
                 h4("Filas de vehículos durante los primeros 15 minutos"),
                 plotOutput("g_cola", height = "300px"),
                 h4("Mapa de búsqueda"),
                 p("Cada cuadro es una combinación de verde Norte-Sur y Este-Oeste; ",
                   "el color indica el tiempo promedio de espera (más claro = menos espera)."),
                 plotOutput("g_mapa", height = "420px")),
        tabPanel("Cómo funciona",
                 br(),
                 div(class = "caja",
                     h4("La simulación visual"),
                     p("La animación usa los mismos supuestos del modelo: los vehículos llegan al azar según el flujo de cada calle (repartido por igual entre sus dos sentidos), con luz verde salen al ritmo del flujo de saturación y el resto forma fila. Los semáforos funcionan con los tiempos de verde calculados por la optimización, con la cuenta regresiva en cada uno."),
                     h4("El modelo"),
                     p("Una intersección con dos fases: cuando una calle tiene luz verde, la otra espera. ",
                       "Entre fases hay un tiempo de transición L. El ciclo dura ",
                       strong("C = g.NS + g.EO + L"), "."),
                     p("Se simula el período segundo a segundo. Los vehículos llegan al azar según el flujo de ",
                       "cada calle; con verde salen al ritmo del flujo de saturación por carril y el resto ",
                       "forma fila (el primero en llegar es el primero en salir)."),
                     p("El indicador principal es el tiempo promedio de espera ",
                       strong("W = (1/n) Σ wᵢ"), ", donde wᵢ es la espera del vehículo i."),
                     h4("La optimización"),
                     p("Se prueban combinaciones de g.NS y g.EO entre el verde mínimo y el máximo ",
                       "(con ciclo máximo), primero en una rejilla gruesa y luego refinando de 1 en 1 segundo. ",
                       "Se elige la de menor W. La configuración elegida se valida con llegadas nuevas y se compara ",
                       "con un reparto equitativo y con la fórmula de Webster."),
                     h4("Limitaciones"),
                     p("Modelo simplificado: no incluye peatones, giros por separado, accidentes ni coordinación ",
                       "con otras intersecciones. Los resultados sirven para comparar formas de repartir el verde, ",
                       "no para decidir si conviene instalar un semáforo."),
                     p(em("Datos reales: MOPT (2023), informe MOPT-03-05-01-0587-2023, RN 124 con RN 122, San Antonio de Alajuela.")))
        )
      )
    )
  )
)

# =============================================================================
# 3. SERVIDOR
# =============================================================================
server <- function(input, output, session) {

  # Al elegir un escenario predefinido, se rellenan los campos
  observeEvent(input$preset, {
    if (input$preset != "Personalizado") {
      e <- ESCENARIOS[ESCENARIOS$nombre == input$preset, ]
      updateNumericInput(session, "q.NS", value = e$q.NS)
      updateNumericInput(session, "q.EO", value = e$q.EO)
      updateNumericInput(session, "n.NS", value = e$n.NS)
      updateNumericInput(session, "n.EO", value = e$n.EO)
    }
  })

  # Ejecuta la optimización al presionar el botón (y una vez al abrir la app)
  resultado <- eventReactive(input$optimizar, {
    validate(
      need(is.numeric(input$q.NS) && is.numeric(input$q.EO) &&
             input$q.NS >= 0 && input$q.EO >= 0, "Los flujos deben ser números no negativos."),
      need(input$q.NS + input$q.EO > 0, "Al menos una dirección debe tener tránsito."),
      need(input$n.NS >= 1 && input$n.EO >= 1, "Cada fase necesita al menos un carril."),
      need(input$g_min < input$g_max, "El verde mínimo debe ser menor que el máximo."),
      need(2 * input$g_min + input$L <= input$C_max,
           "El ciclo máximo es muy corto para respetar el verde mínimo de ambas fases."),
      need(input$paso >= 1 && input$n_rep >= 1, "Revise paso y repeticiones.")
    )
    esc <- list(q.NS = input$q.NS, q.EO = input$q.EO,
                n.NS = input$n.NS, n.EO = input$n.EO)
    p <- list(s = input$s, L = input$L, g_min = input$g_min, g_max = input$g_max,
              C_max = input$C_max, g_base = input$g_base, T_sim = input$T_sim,
              n_rep = input$n_rep, paso = input$paso, semilla = input$semilla)

    r <- withProgress(message = "Optimizando…", detail = "Probando combinaciones de verde",
                      value = 0, {
      out <- recomendar_semaforo(esc, p, cb = function(f) setProgress(value = f))
      setProgress(value = 1)
      out
    })
    r$esc <- esc; r$p <- p
    r$Y <- esc$q.NS / (p$s * esc$n.NS) + esc$q.EO / (p$s * esc$n.EO)
    r
  }, ignoreNULL = FALSE)

  # --- Envío del plan recomendado a la simulación visual -----------------------
  enviar_plan <- function() {
    r <- tryCatch(resultado(), error = function(e) NULL)
    if (!is.null(r)) session$sendCustomMessage("sim_plan", mensaje_sim(r))
  }
  observeEvent(resultado(), enviar_plan())     # cada vez que se optimiza
  observeEvent(input$sim_listo, enviar_plan()) # cuando la animación está lista

  # --- Avisos -----------------------------------------------------------------
  output$aviso <- renderUI({
    r <- resultado()
    av <- character(0)
    if (r$Y >= 0.95)
      av <- c(av, "La intersección está saturada (carga ≥ 0,95): la demanda es casi igual o mayor que la capacidad y las filas crecen, por lo que ningún reparto de verde elimina la congestión.")
    else if (r$Y >= 0.8)
      av <- c(av, "La intersección está muy cargada (carga ≥ 0,8): pequeñas variaciones del flujo pueden generar filas largas.")
    if (r$res.opt["no_atendidos"] > 0.05 * r$esc$q.NS * r$p$T_sim / 3600 + 0.05 * r$esc$q.EO * r$p$T_sim / 3600)
      av <- c(av, "Una parte importante de los vehículos no alcanza a cruzar durante el período simulado.")
    if (any(r$g.opt == r$p$g_min))
      av <- c(av, paste0("Una de las fases quedó en el verde mínimo permitido (", r$p$g_min,
                         " s). Si el modelo quisiera menos, el límite lo impone la restricción de verde mínimo."))
    if (length(av) == 0) return(NULL)
    div(class = "aviso", lapply(av, function(x) p(x, style = "margin:2px 0;")))
  })

  # --- Tarjetas con la configuración recomendada ------------------------------
  output$tarjetas <- renderUI({
    r <- resultado()
    mejora <- 100 * (r$res.eq["W"] - r$res.opt["W"]) / r$res.eq["W"]
    tar <- function(num, lab, clase)
      column(2, div(class = "tarjeta", div(class = paste("num", clase), num), div(class = "lab", lab)))
    fluidRow(
      tar(paste(r$g.opt["g.NS"], "s"), "Verde Norte-Sur", "azul"),
      tar(paste(r$g.opt["g.EO"], "s"), "Verde Este-Oeste", "rojo"),
      tar(paste(r$res.opt["C"], "s"), "Ciclo total", "gris"),
      column(3, div(class = "tarjeta", div(class = "num verde", paste(fmt(r$res.opt["W"]), "s")),
                    div(class = "lab", "Espera promedio por vehículo"))),
      column(3, div(class = "tarjeta", div(class = "num verde", paste0(fmt(mejora, 0), " %")),
                    div(class = "lab", paste0("Menos espera que ", r$p$g_base, " s / ", r$p$g_base, " s"))))
    )
  })

  # --- Interpretación en lenguaje sencillo ------------------------------------
  output$interpretacion <- renderUI({
    r <- resultado(); e <- r$esc
    pNS <- 100 * e$q.NS / (e$q.NS + e$q.EO)
    mayor <- if (r$g.opt["g.NS"] > r$g.opt["g.EO"]) "Norte-Sur"
             else if (r$g.opt["g.NS"] < r$g.opt["g.EO"]) "Este-Oeste" else NA
    txt <- paste0(
      "Con ", fmt(e$q.NS, 0), " veh/h en Norte-Sur y ", fmt(e$q.EO, 0), " veh/h en Este-Oeste (",
      fmt(pNS, 0), " % y ", fmt(100 - pNS, 0), " % del tránsito), se recomienda dar ",
      r$g.opt["g.NS"], " s de verde a Norte-Sur y ", r$g.opt["g.EO"], " s a Este-Oeste, en un ciclo de ",
      r$res.opt["C"], " s. ",
      if (!is.na(mayor)) paste0("La dirección ", mayor, " recibe más verde porque tiene más demanda por atender. ")
      else "Ambas direcciones reciben el mismo verde porque su demanda es similar. ",
      "Cada vehículo espera en promedio ", fmt(r$res.opt["W"]), " s, frente a ",
      fmt(r$res.eq["W"]), " s con el reparto equitativo y ", fmt(r$res.web["W"]), " s con Webster.")
    div(class = "caja", strong("En palabras simples"), p(txt))
  })

  # --- Tabla de indicadores ---------------------------------------------------
  output$tabla <- renderTable({
    r <- resultado()
    fila <- function(nombre, g, res)
      data.frame(
        `Configuración` = nombre,
        `Verde N-S (s)` = as.character(g["g.NS"]),
        `Verde E-O (s)` = as.character(g["g.EO"]),
        `Ciclo (s)` = as.character(res["C"]),
        `W global (s/veh)` = fmt(res["W"]),
        `W Norte-Sur` = fmt(res["W.NS"]),
        `W Este-Oeste` = fmt(res["W.EO"]),
        `No atendidos (veh)` = fmt(res["no_atendidos"]),
        check.names = FALSE)
    rbind(fila("Optimizada", r$g.opt, r$res.opt),
          fila("Webster (referencia)", r$g.web, r$res.web),
          fila(paste0("Equitativa (", r$p$g_base, "/", r$p$g_base, ")"), r$g.eq, r$res.eq))
  }, striped = TRUE, bordered = TRUE, align = "lrrrrrrr")

  # --- Gráfico: espera por configuración y dirección --------------------------
  output$g_espera <- renderPlot({
    r <- resultado()
    m <- rbind(c(r$res.eq["W"],  r$res.eq["W.NS"],  r$res.eq["W.EO"]),
               c(r$res.web["W"], r$res.web["W.NS"], r$res.web["W.EO"]),
               c(r$res.opt["W"], r$res.opt["W.NS"], r$res.opt["W.EO"]))
    m[is.na(m)] <- 0
    cols <- c("grey70", "goldenrod", "seagreen")
    par(mar = c(3, 4.5, 1, 1), las = 1)
    barplot(m, beside = TRUE, col = cols, names.arg = c("Global", "Norte-Sur", "Este-Oeste"),
            ylab = "Espera promedio (s/veh)", ylim = c(0, max(m) * 1.3))
    legend("top", legend = c("Equitativa", "Webster", "Optimizada"), fill = cols,
           horiz = TRUE, bty = "n")
  })

  # --- Gráfico: filas en el tiempo --------------------------------------------
  output$g_cola <- renderPlot({
    r <- resultado()
    ver <- min(900, r$p$T_sim)
    a <- serie_cola(r$g.opt["g.NS"], r$g.opt["g.EO"], r$esc, r$arr_val, r$p)
    b <- serie_cola(r$g.eq["g.NS"],  r$g.eq["g.EO"],  r$esc, r$arr_val, r$p)
    a <- a[a$t <= ver, ]; b <- b[b$t <= ver, ]
    ymax <- max(a$NS, a$EO, b$NS, b$EO, 1)
    par(mfrow = c(1, 2), mar = c(4, 4.5, 3, 1), las = 1)
    for (dir in c("NS", "EO")) {
      plot(b$t / 60, b[[dir]], type = "l", col = "grey55", lwd = 1.5, ylim = c(0, ymax * 1.05),
           xlab = "Tiempo (min)", ylab = "Vehículos en fila",
           main = if (dir == "NS") "Norte-Sur" else "Este-Oeste")
      lines(a$t / 60, a[[dir]], col = "seagreen", lwd = 2)
      if (dir == "NS")
        legend("topright", legend = c("Equitativa", "Optimizada"),
               col = c("grey55", "seagreen"), lwd = 2, bty = "n", cex = 0.85)
    }
  })

  # --- Gráfico: mapa de búsqueda ----------------------------------------------
  output$g_mapa <- renderPlot({
    r <- resultado()
    rj <- r$rejilla
    gs <- sort(unique(c(rj$g.NS, rj$g.EO)))
    z <- matrix(NA_real_, length(gs), length(gs))
    z[cbind(match(rj$g.NS, gs), match(rj$g.EO, gs))] <- rj$W
    par(mar = c(4.5, 4.5, 1, 1), las = 1)
    image(gs, gs, z, col = hcl.colors(50, "YlOrRd", rev = TRUE),
          xlab = "Verde Norte-Sur (s)", ylab = "Verde Este-Oeste (s)")
    points(r$g.opt["g.NS"], r$g.opt["g.EO"], pch = 4, lwd = 3, cex = 2)
    points(r$g.web["g.NS"], r$g.web["g.EO"], pch = 5, lwd = 2, cex = 1.6)
    points(r$g.eq["g.NS"],  r$g.eq["g.EO"],  pch = 1, lwd = 2, cex = 1.6)
    legend("topright", legend = c("Óptimo", "Webster", "Equitativa"),
           pch = c(4, 5, 1), pt.lwd = 2, bg = "white")
  })
}

shinyApp(ui, server)
