import { settings } from './model.js';
const KEY = 'air-wx.preferences.v1';
let memory = settings(), sessionOnly = false;
export function readSettings(wx) {
  if (sessionOnly) return { value: { ...memory }, warning: true };
  try {
    const raw = wx.getStorageSync(KEY);
    if (raw) memory = settings(typeof raw === 'string' ? JSON.parse(raw) : raw);
    return { value: { ...memory }, warning: false };
  } catch (_) { return { value: { ...memory }, warning: true }; }
}
export function saveSettings(wx, value) {
  memory = settings(value);
  try { wx.setStorageSync(KEY, JSON.stringify(memory)); sessionOnly = false; return true; }
  catch (_) { sessionOnly = true; return false; }
}
