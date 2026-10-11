import { nearbyBounds, nearbyStations, reportMap, validCoordinate } from './model.js';
const BASE = 'https://aviationweather.gov/api/data/';
export function createWeatherClient(wx) {
  const pending = new Set(); let closed = false;
  function request(resource, query) {
    return new Promise((resolve, reject) => {
      if (closed) { reject(new Error('cancelled')); return; }
      let task, timer, finished = false;
      const finish = (error, value) => {
        if (finished) return;
        finished = true; clearTimeout(timer); pending.delete(cancel);
        if (error) reject(error); else resolve(value);
      };
      const cancel = () => { finish(new Error('cancelled')); try { task?.abort(); } catch (_) {} };
      pending.add(cancel);
      timer = setTimeout(() => { finish(new Error('timeout')); try { task?.abort(); } catch (_) {} }, 12000);
      try {
        task = wx.request({ url: BASE + resource + '?' + query + '&format=json', method: 'GET', timeout: 12000, dataType: 'json',
          success(res) {
            if (res.statusCode === 204) { finish(null, []); return; }
            if (res.statusCode < 200 || res.statusCode >= 300) { finish(new Error('network')); return; }
            try {
              const data = typeof res.data === 'string' ? JSON.parse(res.data) : res.data;
              if (!Array.isArray(data)) throw new Error('malformed');
              finish(null, data);
            } catch (_) { finish(new Error('malformed')); }
          },
          fail(error) { finish(new Error(/timeout/i.test(error?.errMsg || '') ? 'timeout' : 'network')); }
        });
      } catch (_) { finish(new Error('network')); }
    });
  }
  return {
    async reports(codes, includeTaf) {
      const query = 'ids=' + encodeURIComponent(codes.join(','));
      const jobs = [request('metar', query).then(data => reportMap(data, 'metar'))];
      if (includeTaf) jobs.push(request('taf', query).then(data => reportMap(data, 'taf')));
      const results = await Promise.allSettled(jobs);
      if (closed) throw new Error('cancelled');
      const errors = results.filter(item => item.status === 'rejected').map(item => item.reason.message);
      if (errors.length === jobs.length) throw new Error(errors[0]);
      return { metar: results[0].status === 'fulfilled' ? results[0].value : {},
        taf: results[1]?.status === 'fulfilled' ? results[1].value : {}, errors, fetchedAt: Date.now() };
    },
    async nearby(lat, lon) {
      if (!validCoordinate(lat, lon)) throw new Error('location');
      const results = await Promise.all(nearbyBounds(lat, lon).map(bbox => request('stationinfo', 'bbox=' + bbox.map(x => x.toFixed(4)).join(','))));
      if (closed) throw new Error('cancelled');
      return nearbyStations(results.flat(), lat, lon);
    },
    close() { closed = true; for (const cancel of [...pending]) cancel(); }
  };
}
export function getPosition(geolocation) {
  let cancel;
  const promise = new Promise((resolve, reject) => {
    let done = false;
    const finish = (error, position) => { if (done) return; done = true; clearTimeout(timer); if (error) reject(error); else resolve(position); };
    const timer = setTimeout(() => finish(new Error('locationTimeout')), 12000);
    cancel = () => finish(new Error('cancelled'));
    if (!geolocation || typeof geolocation.getCurrentPosition !== 'function') { finish(new Error('unavailable')); return; }
    try {
      geolocation.getCurrentPosition(position => {
        const lat = position?.coords?.latitude, lon = position?.coords?.longitude;
        if (!validCoordinate(lat, lon)) finish(new Error('location')); else finish(null, { lat, lon });
      }, error => finish(new Error(error?.code === 1 ? 'denied' : error?.code === 3 ? 'locationTimeout' : 'location')),
      { enableHighAccuracy: false, timeout: 10000, maximumAge: 0 });
    } catch (_) { finish(new Error('location')); }
  });
  return { promise, cancel() { cancel(); } };
}
