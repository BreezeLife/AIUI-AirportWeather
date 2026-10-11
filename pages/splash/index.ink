<script def>
{ "navigationBarTitleText": "AIR WX", "description": "AIR WX cover. Tap or Enter to start, or wait five visible focused seconds. Raw METAR and optional TAF airport weather viewer. Prefer _blank; _current supported." }
</script>
<script setup>
import wx from 'wx';
import { strings } from '../../lib/i18n.js';
import { readSettings, saveSettings } from '../../lib/storage.js';
export default {
  data: { copy: strings('en'), remaining: 5, note: '' },
  onLoad(query = {}) {
    this._dead = false; this._visible = false; this._focused = true; this._started = false; this._timer = null; this._remaining = 5000; this._since = null;
    const current = readSettings(wx).value;
    const patch = {};
    if (['en', 'ja', 'ko', 'zh'].includes(query.locale)) patch.locale = query.locale;
    if (['list1', 'list2', 'nearby'].includes(query.source)) patch.source = query.source;
    if (query.taf === '1' || query.taf === '0') patch.includeTaf = query.taf === '1';
    saveSettings(wx, { ...current, ...patch });
    this.setData({ copy: strings(patch.locale || current.locale) });
  },
  onShow() { this._visible = true; this.arm(); },
  onHide() { this.suspend(); this._visible = false; },
  onUnload() { this.suspend(); this._dead = true; this._visible = false; },
  onHostFocus() { this._focused = true; this.arm(); },
  onHostBlur() { this.suspend(); this._focused = false; },
  suspend() { if (this._timer !== null) clearTimeout(this._timer); this._timer = null; if (this._since !== null) this._remaining = Math.max(0, this._remaining - Date.now() + this._since); this._since = null; },
  arm() {
    if (this._dead || !this._visible || !this._focused || this._started || this._timer !== null) return;
    this._since = Date.now(); this._timer = setTimeout(() => { this.suspend(); this.setData({ remaining: Math.ceil(this._remaining / 1000) }); if (this._remaining <= 0) this.start(); else this.arm(); }, Math.min(1000, this._remaining));
  },
  start() {
    if (this._dead || !this._visible || !this._focused || this._started) return;
    this._started = true; this.suspend();
    const fail = () => { if (this._dead) return; this._started = false; this._remaining = 5000; this.setData({ remaining: 5, note: this.data.copy.openError }); };
    try { wx.redirectTo({ url: '/pages/weather/index', fail }); } catch (_) { fail(); }
  },
  onKeyUp(event) { if (event.code === 'Enter' && this._visible && this._focused && !this._dead) { event.preventDefault(); this.start(); } }
};
</script>
<page>
  <view class="splash" bindtap="start">
    <view class="edition"><text>FIELD WEATHER / 01</text><text>ROKID AIUI</text></view>
    <view class="center">
      <view class="wordmark"><view class="signal"><view class="bar short"></view><view class="bar mid"></view><view class="bar tall"></view></view><view class="brand"><text class="air">AIR</text><text class="wx">WX.</text></view></view>
      <text class="tagline">{{copy.tagline}}</text>
    </view>
    <view class="start"><text class="prompt">{{copy.tap}}</text><text class="count">{{copy.auto}} {{remaining}}{{copy.seconds}}</text></view>
    <text class="note">{{note || copy.safety}}</text>
  </view>
</page>
<style>
.splash { width: 100%; height: 100%; box-sizing: border-box; padding: 16px 24px 12px; display: flex; flex-direction: column; background-color: #000; color: #00ff66; }
.edition { display: flex; flex-direction: row; justify-content: space-between; font-family: monospace; font-size: 10px; color: #00bc4b; }.center { flex: 1; min-height: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; }.wordmark { display: flex; flex-direction: row; align-items: center; }.signal { height: 92px; display: flex; flex-direction: row; align-items: flex-end; margin-right: 17px; }.bar { width: 10px; margin-right: 5px; background-color: #00ff66; }.short { height: 37px; background-color: #00a842; }.mid { height: 65px; background-color: #00cc52; }.tall { height: 92px; }.brand { display: flex; flex-direction: column; }.air { font-size: 47px; line-height: 46px; font-weight: 700; letter-spacing: 3px; }.wx { font-size: 60px; line-height: 57px; font-weight: 700; }.tagline { font-size: 16px; line-height: 22px; margin-top: 18px; color: #00d856; }.start { display: flex; flex-direction: column; align-items: center; flex-shrink: 0; }.prompt { font-family: monospace; font-size: 22px; line-height: 29px; }.count { font-size: 12px; line-height: 18px; margin-top: 3px; color: #00bc4b; }.note { text-align: center; font-family: monospace; font-size: 10px; line-height: 15px; margin-top: 13px; color: #00bc4b; }
@media (target: _current) { .splash { padding: 12px 16px; }.edition { display: none; }.air { font-size: 32px; line-height: 33px; }.wx { font-size: 41px; line-height: 40px; }.signal { height: 67px; }.short { height: 27px; }.mid { height: 46px; }.tall { height: 67px; }.tagline { margin-top: 10px; font-size: 14px; }.prompt { font-size: 19px; }.note { margin-top: 6px; } }
</style>
