export const MAX_STATIONS = 8;
export const RADIUS_NM = 75;
export const ICAO = /^[A-Z][A-Z0-9]{3}$/;
export function parseCodes(text) {
  const tokens = String(text || '').toUpperCase().trim().split(/[\s,;]+/).filter(Boolean);
  const codes = [...new Set(tokens)];
  return { codes: codes.filter(code => ICAO.test(code)).slice(0, MAX_STATIONS),
    valid: codes.length > 0 && codes.length <= MAX_STATIONS && codes.every(code => ICAO.test(code)) };
}
export function settings(raw = {}) {
  const codes = key => { const result = parseCodes(raw[key]); return result.valid ? result.codes.join(', ') : ''; };
  return {
    locale: ['en', 'ja', 'ko', 'zh'].includes(raw.locale) ? raw.locale : 'en',
    source: ['list1', 'list2', 'nearby'].includes(raw.source) ? raw.source : 'list1',
    list1: raw.list1 === undefined ? 'KJFK, RJTT, RKSI, ZBAA' : codes('list1'),
    list2: codes('list2'), includeTaf: raw.includeTaf === true
  };
}
export function distanceNm(lat1, lon1, lat2, lon2) {
  const rad = value => value * Math.PI / 180;
  const dlat = rad(lat2 - lat1), dlon = rad(lon2 - lon1);
  const a = Math.sin(dlat / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dlon / 2) ** 2;
  return 3440.065 * 2 * Math.atan2(Math.sqrt(Math.min(1, a)), Math.sqrt(Math.max(0, 1 - a)));
}
export function validCoordinate(lat, lon) {
  return Number.isFinite(lat) && Number.isFinite(lon) && Math.abs(lat) <= 90 && Math.abs(lon) <= 180;
}
export function nearbyBounds(lat, lon) {
  const delta = RADIUS_NM / 60;
  const south = Math.max(-90, lat - delta), north = Math.min(90, lat + delta);
  // The parallel closest to a pole needs the widest longitude span.
  const edge = Math.max(Math.abs(south), Math.abs(north));
  const dl = edge >= 89 ? 180 : Math.min(180, delta / Math.cos(edge * Math.PI / 180));
  if (dl >= 180) return [[south, -180, north, 180]];
  if (lon - dl < -180) return [[south, -180, north, lon + dl], [south, lon - dl + 360, north, 180]];
  if (lon + dl > 180) return [[south, lon - dl, north, 180], [south, -180, north, lon + dl - 360]];
  return [[south, lon - dl, north, lon + dl]];
}
export function nearbyStations(data, lat, lon) {
  if (!Array.isArray(data)) throw new Error('malformed');
  const unique = new Map();
  for (const station of data) {
    if (!station || !ICAO.test(station.icaoId || '') || !Array.isArray(station.siteType)
      || !station.siteType.includes('METAR') || !validCoordinate(station.lat, station.lon)) continue;
    const distance = distanceNm(lat, lon, station.lat, station.lon);
    if (distance <= RADIUS_NM) unique.set(station.icaoId, { id: station.icaoId, distance });
  }
  return [...unique.values()].sort((a, b) => a.distance - b.distance || a.id.localeCompare(b.id)).slice(0, MAX_STATIONS);
}
export function reportMap(data, type) {
  if (!Array.isArray(data)) throw new Error('malformed');
  const out = {};
  for (const entry of data) {
    const id = entry?.icaoId, raw = type === 'taf' ? entry?.rawTAF : entry?.rawOb;
    if (!ICAO.test(id || '') || typeof raw !== 'string' || !raw.trim() || raw.length > 20000) continue;
    const time = type === 'taf' ? entry.issueTime : (entry.obsTime || entry.reportTime);
    const ms = typeof time === 'number' ? time * 1000 : Date.parse(time || '');
    const report = { id, raw, time: Number.isFinite(ms) ? ms : null,
      category: ['VFR', 'MVFR', 'IFR', 'LIFR'].includes(entry.fltCat) ? entry.fltCat : '—', name: String(entry.name || '') };
    if (!out[id] || (report.time || 0) > (out[id].time || 0)) out[id] = report;
  }
  return out;
}
export function utcLabel(time) {
  return time == null ? '— UTC' : new Date(time).toISOString().slice(5, 16).replace('T', ' ') + 'Z';
}
export function ageInfo(time, now = Date.now()) {
  if (time == null) return { minutes: null, stale: true, future: false };
  const minutes = Math.floor((now - time) / 60000);
  return { minutes: Math.max(0, minutes), stale: minutes >= 90, future: minutes < -5 };
}
// Keep every non-whitespace token, including RMK. Long tokens split across lines.
export function reportPages(raw, width = 36, rows = 5) {
  const words = String(raw || '').trim().split(/\s+/).filter(Boolean);
  const lines = []; let line = '';
  for (const original of words) {
    let word = original;
    if (line && line.length + 1 + word.length > width) { lines.push(line); line = ''; }
    while (word.length > width) { lines.push(word.slice(0, width)); word = word.slice(width); }
    if (word) line = line ? line + ' ' + word : word;
  }
  if (line) lines.push(line);
  const pages = [];
  for (let i = 0; i < lines.length; i += rows) pages.push(lines.slice(i, i + rows).join('\n'));
  return pages.length ? pages : [''];
}
