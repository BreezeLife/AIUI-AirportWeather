<script def>
{ "navigationBarTitleText": "AIR WX", "description": "Read-only airport weather. Raw METAR and optional TAF; choose Nearby or custom ICAO lists. Prefer _blank; _current supported." }
</script>
<script setup>
import wx from 'wx';
import { strings } from '../../lib/i18n.js';
import { ageInfo, reportPages, settings, utcLabel } from '../../lib/model.js';
import { readSettings, saveSettings } from '../../lib/storage.js';
import { createWeatherClient, getPosition } from '../../lib/weather.js';
export default {
  data: { copy: strings('en'), locale: 'en', source: 'list1', includeTaf: false, cards: [], status: '', statusKind: 'idle', fetched: '', selected: 0, note: '' },
  onLoad(query = {}) { this._dead = false; this._visible = false; this._focused = true; this._loaded = false; this._sourceQuery = query.source; this._location = null; this._client = createWeatherClient(wx); const state = readSettings(wx); this._prefs = state.value; if (['en','ja','ko','zh'].includes(query.locale)) this._prefs.locale = query.locale; this.setData({ ...this._prefs, copy: strings(this._prefs.locale), note: state.warning ? strings(this._prefs.locale).storageWarning : '' }); },
  onShow() { this._visible = true; this._client = createWeatherClient(wx); if (!this._loaded) { this._loaded = true; this.load(); } },
  onHide() { this._visible = false; this.cancel(); },
  onUnload() { this._dead = true; this._visible = false; this.cancel(); this._client.close(); },
  onHostFocus() { this._focused = true; }, onHostBlur() { this._focused = false; this.cancel(); },
  active() { return !this._dead && this._visible && this._focused; },
  cancel() { if (this._position) { this._position.cancel(); this._position = null; } this._client.close(); },
  setStatus(status, kind = 'idle') { if (!this._dead) this.setData({ status, statusKind: kind }); },
  async load() {
    if (!this.active()) return;
    this._client.close(); this._client = createWeatherClient(wx);
    const source = this._sourceQuery && ['list1','list2','nearby'].includes(this._sourceQuery) ? this._sourceQuery : this.data.source;
    this.setData({ source });
    if (source === 'nearby') return this.loadNearby();
    const raw = this._prefs[source] || '';
    const codes = raw.split(/[\s,;]+/).filter(Boolean).map(code => code.toUpperCase());
    if (!codes.length) { this.setStatus(this.data.copy.emptyList, 'empty'); return; }
    await this.fetchReports(codes);
  },
  async loadNearby() {
    this.setStatus(this.data.copy.locating, 'loading');
    this._position = getPosition(typeof navigator === 'undefined' ? null : navigator.geolocation);
    try {
      const position = await this._position.promise; this._position = null; if (!this.active()) return;
      const stations = await this._client.nearby(position.lat, position.lon); if (!stations.length) { this.setStatus(this.data.copy.noNearby, 'empty'); return; }
      this._nearby = stations; await this.fetchReports(stations.map(item => item.id), stations);
    } catch (error) { this._position = null; if (!this.active()) return; const key = error.message === 'denied' ? 'denied' : error.message === 'locationTimeout' ? 'locationTimeout' : error.message === 'unavailable' ? 'unavailable' : 'location'; this.setStatus(this.data.copy[key], 'error'); }
  },
  async fetchReports(codes, nearby = []) {
    this.setStatus(this.data.copy.loading, 'loading');
    try {
      const result = await this._client.reports(codes, this.data.includeTaf); if (!this.active()) return;
      const cards = codes.map((id, index) => { const metar = result.metar[id], taf = result.taf[id]; const raw = metar?.raw || ''; const pages = reportPages(raw || this.data.copy.noReport); const tafPages = reportPages(taf?.raw || (this.data.includeTaf ? this.data.copy.noTaf : ''), 36, 4); const age = ageInfo(metar?.time); return { id, distance: nearby[index]?.distance == null ? '' : nearby[index].distance.toFixed(1) + ' NM', name: metar?.name || '', category: metar?.category || '—', time: utcLabel(metar?.time), age: age.minutes == null ? this.data.copy.unknownTime : age.minutes + ' ' + this.data.copy.min, stale: age.stale, future: age.future, metarPages: pages, tafPages, metarPage: 0, tafPage: 0, metarTotal: pages.length, tafTotal: tafPages.length, hasMetar: Boolean(metar), hasTaf: Boolean(taf), includeTaf: this.data.includeTaf }; });
      this.setData({ cards, fetched: utcLabel(result.fetchedAt), selected: 0, note: result.errors.length ? this.data.copy.partial : '', status: result.errors.length ? this.data.copy.partial : this.data.copy.ready, statusKind: result.errors.length ? 'warning' : 'ready' });
    } catch (error) { if (!this.active()) return; const key = error.message === 'timeout' ? 'timeout' : error.message === 'malformed' ? 'malformed' : error.message === 'cancelled' ? 'previousData' : 'network'; this.setStatus(this.data.copy[key], 'error'); }
  },
  chooseSource(event) { const source = event?.currentTarget?.dataset?.source; if (!['list1','list2','nearby'].includes(source) || !this.active()) return; this._sourceQuery = source; this.setData({ source, cards: [] }); this.load(); },
  refresh() { if (this.active()) this.load(); }, retry() { if (this.active()) this.load(); },
  select(event) { const index = Number(event?.currentTarget?.dataset?.index); if (Number.isInteger(index) && index >= 0 && index < this.data.cards.length) this.setData({ selected: index }); },
  page(event) { const direction = event?.currentTarget?.dataset?.direction; const kind = event?.currentTarget?.dataset?.kind; const selected = this.data.selected; const card = this.data.cards[selected]; if (!card) return; const key = kind === 'taf' ? 'tafPage' : 'metarPage'; const total = kind === 'taf' ? card.tafTotal : card.metarTotal; const next = direction === 'next' ? Math.min(total - 1, card[key] + 1) : Math.max(0, card[key] - 1); const cards = this.data.cards.slice(); cards[selected] = { ...card, [key]: next }; this.setData({ cards }); },
  toggleTaf() { if (!this.active()) return; const next = !this.data.includeTaf; this._prefs.includeTaf = next; saveSettings(wx, this._prefs); this.setData({ includeTaf: next }); this.load(); },
  settings() { if (this.active()) wx.navigateTo({ url: '/pages/settings/index' }); },
  back() { if (this.active()) wx.navigateBack({ delta: 1 }); },
  onKeyUp(event) { if (!this.active()) return; if (event.code === 'ArrowRight') this.page({ currentTarget: { dataset: { direction: 'next', kind: 'metar' } } }); if (event.code === 'ArrowLeft') this.page({ currentTarget: { dataset: { direction: 'previous', kind: 'metar' } } }); }
};
</script>
<page>
  <view class="weather">
    <view class="top"><view><text class="eyebrow">AIR WX / {{copy.airport}}</text><text class="title">{{copy.airports}}</text></view><view class="top-actions"><button class="small" bindtap="settings">{{copy.settings}}</button><button class="small" bindtap="back">{{copy.back}}</button></view></view>
    <view class="source-tabs" role="navigation"><button class="source {{source === 'nearby' ? 'selected' : ''}}" data-source="nearby" bindtap="chooseSource">{{copy.nearby}}</button><button class="source {{source === 'list1' ? 'selected' : ''}}" data-source="list1" bindtap="chooseSource">{{copy.list1}}</button><button class="source {{source === 'list2' ? 'selected' : ''}}" data-source="list2" bindtap="chooseSource">{{copy.list2}}</button></view>
    <view class="toolbar"><text class="status {{statusKind}}">{{status}}</text><view class="tool-buttons"><button class="small" bindtap="refresh">{{copy.refresh}}</button><button class="small toggle" bindtap="toggleTaf">{{includeTaf ? copy.tafOn : copy.tafOff}}</button></view></view>
    <view ink:if="{{source === 'nearby'}}" class="subline">{{copy.radius}}</view>
    <view ink:if="{{cards.length === 0}}" class="empty"><text class="empty-title">{{status || copy.idle}}</text><text class="empty-copy">{{statusKind === 'error' ? copy.network : statusKind === 'empty' ? (source === 'nearby' ? copy.noNearby : copy.emptyList) : source === 'nearby' ? copy.privacy : copy.emptyList}}</text><button ink:if="{{statusKind === 'error'}}" class="action" bindtap="retry">{{copy.retry}}</button></view>
    <view ink:else class="body">
      <view class="airport-list" role="navigation"><button class="airport-row {{selected === index ? 'selected-row' : ''}}" ink:for="{{cards}}" ink:key="id" data-index="{{index}}" bindtap="select"><text class="row-id">{{item.id}}</text><text class="row-meta">{{item.distance}} {{item.category}}</text></button></view>
      <view class="report" ink:if="{{cards[selected]}}"><view class="report-head"><view><text class="report-id">{{cards[selected].id}}</text><text class="report-name">{{cards[selected].name}}</text></view><text class="age {{cards[selected].stale ? 'stale' : ''}}">{{cards[selected].stale ? copy.stale : cards[selected].future ? copy.future : cards[selected].age}}</text></view>
        <view class="report-block"><view class="block-head"><text class="block-title">{{copy.metar}}</text><text class="block-time">{{cards[selected].time}}</text></view><text class="raw {{cards[selected].hasMetar ? '' : 'missing'}}">{{cards[selected].metarPages[cards[selected].metarPage]}}</text><view class="pager" role="navigation"><button class="pager-button" data-kind="metar" data-direction="previous" bindtap="page">{{copy.previous}}</button><text>{{copy.part}} {{cards[selected].metarPage + 1}} / {{cards[selected].metarTotal}}</text><button class="pager-button" data-kind="metar" data-direction="next" bindtap="page">{{copy.next}}</button></view></view>
        <view ink:if="{{includeTaf}}" class="report-block taf-block"><view class="block-head"><text class="block-title">{{copy.taf}}</text><text class="block-time">{{cards[selected].hasTaf ? copy.ready : copy.missing}}</text></view><text class="raw {{cards[selected].hasTaf ? '' : 'missing'}}">{{cards[selected].tafPages[cards[selected].tafPage]}}</text><view class="pager" role="navigation"><button class="pager-button" data-kind="taf" data-direction="previous" bindtap="page">{{copy.previous}}</button><text>{{copy.part}} {{cards[selected].tafPage + 1}} / {{cards[selected].tafTotal}}</text><button class="pager-button" data-kind="taf" data-direction="next" bindtap="page">{{copy.next}}</button></view></view>
      </view>
    </view>
    <view class="footer"><text>{{copy.safety}}</text><text>{{copy.fetched}} {{fetched}}</text></view>
  </view>
</page>
<style>
.weather { width: 100%; height: 100%; box-sizing: border-box; padding: 12px 16px; display: flex; flex-direction: column; background-color: #000; color: #00ff66; }.top { display: flex; flex-direction: row; justify-content: space-between; align-items: flex-start; }.eyebrow { display: block; font-family: monospace; font-size: 10px; line-height: 14px; color: #00bc4b; }.title { display: block; font-size: 25px; line-height: 29px; font-weight: 700; }.top-actions { display: flex; flex-direction: row; }.small { min-height: 29px; height: 29px; font-size: 12px; line-height: 18px; padding: 4px 8px; margin-left: 6px; }.source-tabs { display: flex; flex-direction: row; margin-top: 9px; }.source { flex: 1; min-height: 29px; height: 29px; font-size: 13px; line-height: 18px; padding: 3px; margin-right: 6px; }.source:last-child { margin-right: 0; }.selected { border-color: #00ff66; background-color: #001f0d; font-weight: 700; }.toolbar { display: flex; flex-direction: row; justify-content: space-between; align-items: center; min-height: 34px; margin-top: 7px; border-top: 1px solid #005d2b; border-bottom: 1px solid #005d2b; }.status { font-family: monospace; font-size: 11px; line-height: 18px; color: #00bc4b; }.status.ready { color: #00ff66; }.status.error { color: #ffb000; }.tool-buttons { display: flex; flex-direction: row; }.toggle { color: #00d856; }.subline { font-family: monospace; font-size: 10px; line-height: 16px; color: #00bc4b; }.body { flex: 1; min-height: 0; display: flex; flex-direction: row; margin-top: 8px; }.airport-list { width: 122px; flex-shrink: 0; display: flex; flex-direction: column; overflow: hidden; border-right: 1px solid #005d2b; padding-right: 8px; }.airport-row { width: 100%; min-height: 31px; height: 31px; display: flex; flex-direction: row; justify-content: space-between; align-items: center; border: none; border-bottom: 1px solid #003d1c; padding: 2px 4px; text-align: left; }.selected-row { border-left: 2px solid #00ff66; background-color: #001f0d; }.row-id { font-family: monospace; font-size: 14px; }.row-meta { font-size: 9px; color: #00bc4b; }.report { flex: 1; min-width: 0; padding-left: 11px; display: flex; flex-direction: column; overflow: hidden; }.report-head { display: flex; flex-direction: row; justify-content: space-between; min-height: 32px; }.report-id { font-family: monospace; font-size: 23px; font-weight: 700; }.report-name { display: block; max-width: 170px; overflow: hidden; font-size: 10px; line-height: 14px; color: #00bc4b; }.age { font-family: monospace; font-size: 10px; color: #00d856; }.age.stale { color: #ffb000; }.report-block { margin-top: 7px; border-top: 1px solid #008f39; padding-top: 5px; }.block-head { display: flex; flex-direction: row; justify-content: space-between; }.block-title { font-family: monospace; font-size: 12px; font-weight: 700; }.block-time { font-family: monospace; font-size: 10px; color: #00bc4b; }.raw { display: block; white-space: pre-line; font-family: monospace; font-size: 13px; line-height: 17px; margin-top: 5px; color: #00ff66; }.missing { color: #ffb000; }.pager { display: flex; flex-direction: row; align-items: center; justify-content: space-between; margin-top: 4px; font-family: monospace; font-size: 9px; color: #00bc4b; }.pager-button { min-height: 23px; height: 23px; font-size: 10px; padding: 2px 5px; }.taf-block { margin-top: 9px; }.empty { flex: 1; display: flex; flex-direction: column; justify-content: center; align-items: center; text-align: center; }.empty-title { font-size: 18px; line-height: 24px; }.empty-copy { max-width: 350px; font-size: 12px; line-height: 18px; margin-top: 8px; color: #00bc4b; }.action { margin-top: 12px; padding: 5px 14px; font-size: 13px; }.footer { display: flex; flex-direction: row; justify-content: space-between; font-family: monospace; font-size: 9px; line-height: 14px; color: #00bc4b; margin-top: 7px; }.footer text:first-child { max-width: 270px; }
@media (target: _current) { .weather { padding: 9px 12px; }.title { font-size: 20px; }.top-actions .small:last-child { display: none; }.source-tabs { margin-top: 5px; }.source { font-size: 11px; }.airport-list { width: 90px; }.row-id { font-size: 12px; }.row-meta { display: none; }.report { padding-left: 7px; }.report-id { font-size: 19px; }.raw { font-size: 11px; line-height: 14px; }.taf-block { display: none; }.footer { font-size: 8px; }.footer text:first-child { max-width: 190px; } }
</style>
