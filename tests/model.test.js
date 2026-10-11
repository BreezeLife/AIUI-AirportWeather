import test from 'node:test';
import assert from 'node:assert/strict';
import { ageInfo, nearbyStations, parseCodes, reportMap, reportPages, distanceNm } from '../lib/model.js';
test('parses bounded distinct ICAO codes', () => { assert.deepEqual(parseCodes('kjfk KJFK RJTT RKSI ZBAA'), { codes: ['KJFK', 'RJTT', 'RKSI', 'ZBAA'], valid: true }); assert.equal(parseCodes('KJFK BAD!').valid, false); });
test('nearby stations filters, deduplicates, sorts and bounds', () => { const data = Array.from({ length: 10 }, (_, i) => ({ icaoId: 'KAA' + String(i), lat: 0.01 * i, lon: 0, siteType: ['METAR'] })); const result = nearbyStations(data, 0, 0); assert.equal(result.length, 8); assert.equal(result[0].distance, 0); });
test('reports reject malformed entries and preserve raw text', () => { const result = reportMap([{ icaoId: 'KJFK', rawOb: 'METAR KJFK 121200Z RMK KEEP', obsTime: 1, fltCat: 'VFR' }, { icaoId: 'BAD', rawOb: 'x' }], 'metar'); assert.equal(result.KJFK.raw, 'METAR KJFK 121200Z RMK KEEP'); assert.equal(result.KJFK.category, 'VFR'); });
test('report pages retain all tokens and age marks old data', () => { const raw = 'METAR KJFK 121200Z 18010KT 10SM CLR 20/10 A3000 RMK TOKEN'; assert.equal(reportPages(raw, 20, 2).join(' ').replaceAll('\n', ' '), raw); assert.equal(ageInfo(Date.now() - 90 * 60000).stale, true); assert(distanceNm(0, 0, 1, 0) > 59); });
