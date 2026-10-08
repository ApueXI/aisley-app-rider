// Run only against the synthetic Flutter fixture and an isolated Chromium
// debugging profile. Never attach this driver to a signed-in user browser.
import assert from 'node:assert/strict';
import { writeFile } from 'node:fs/promises';

const debuggerOrigin = 'http://localhost:9334';
const page = await (await fetch(`${debuggerOrigin}/json/new?about:blank`, { method: 'PUT' })).json();
assert.ok(page, 'The isolated browser must have a page');
const socket = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((resolve) => socket.addEventListener('open', resolve, { once: true }));
const pending = new Map();
const errors = [];
let sequence = 0, apiRequests = 0, credentialRequests = 0;
socket.addEventListener('message', (event) => {
  const message = JSON.parse(event.data);
  if (message.id) {
    const operation = pending.get(message.id);
    if (operation) {
      pending.delete(message.id);
      if (message.error) operation.reject(message.error);
      else operation.resolve(message.result);
    }
  }
  if (message.method === 'Runtime.exceptionThrown') errors.push(message.params.exceptionDetails.text);
  if (message.method === 'Network.requestWillBeSent') {
    const request = message.params.request;
    if (request.url.startsWith('https://api.example')) apiRequests++;
    if (Object.keys(request.headers).some((key) => key.toLowerCase() === 'authorization')) credentialRequests++;
  }
});
function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = ++sequence;
    pending.set(id, { resolve, reject });
    socket.send(JSON.stringify({ id, method, params }));
  });
}
async function evaluate(expression) {
  const result = await send('Runtime.evaluate', { expression, returnByValue: true });
  assert.equal(result.exceptionDetails, undefined, 'Fixture inspection must succeed');
  return result.result.value;
}
const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));
async function click(x, y) {
  await send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
  await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
}
async function waitForMap(expectedLongitude) {
  for (let attempt = 0; attempt < 60; attempt++) {
    const result = await evaluate(`(() => {
      const map = globalThis.courierFixtureMap;
      if (!map || !map.isStyleLoaded()) return null;
      const style = map.getStyle();
      const data = style.sources.route?.data;
      const line = data?.geometry?.coordinates ?? data?.features?.[0]?.geometry?.coordinates;
      const raster = style.layers.filter(layer => layer.type === 'raster');
      if (map.listImages().length < 3 || !line || !raster.length) return null;
      const lineIndex = style.layers.findIndex(layer => layer.id === 'route-line');
      const symbols = style.layers.filter(layer => layer.type === 'symbol');
      return {
        expectedGeometry: Math.abs(line.at(-1)[0] - ${expectedLongitude}) < 0.000001,
        markerCount: map.listImages().length,
        renderedMarkers: map.queryRenderedFeatures({layers:symbols.map(layer=>layer.id)}).length,
        rasterCount: raster.length,
        validLayerOrder: raster.every(layer => style.layers.indexOf(layer) < lineIndex) &&
          symbols.every(layer => style.layers.indexOf(layer) > lineIndex),
        zoom: map.getZoom()
      };
    })()`);
    if (result?.expectedGeometry && result.renderedMarkers >= 3) return result;
    await delay(500);
  }
  throw new Error('The synthetic map did not finish rendering within 30 seconds');
}

try {
  await send('Page.enable');
  await send('Runtime.enable');
  await send('Network.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: 780, height: 1000, deviceScaleFactor: 1, mobile: false });
  await send('Page.navigate', { url: 'http://localhost:8766' });
  for (let attempt = 0; attempt < 60; attempt++) {
    if (await evaluate("!!globalThis.maplibregl?.Map && document.querySelectorAll('.maplibregl-canvas').length > 0")) break;
    await delay(500);
  }
  // Capture a fresh real map after the library is loaded. Predefining the
  // namespace would incorrectly trigger the plugin's already-loaded shortcut.
  await evaluate(`globalThis.maplibregl={...globalThis.maplibregl,Map:class extends globalThis.maplibregl.Map {
    constructor(...args){super(...args);globalThis.courierFixtureMap=this;}
  }}; true`);
  await delay(2000);
  await click(390, 543);
  const initial = await waitForMap(121.25);
  assert.equal(initial.validLayerOrder, true, 'Tiles must be below the line and numbered markers');
  assert.ok(initial.rasterCount <= 16, 'Viewport tile count must be bounded');
  await click(155, 445); // Material Zoom in on the fixed fixture layout.
  await delay(1000);
  assert.ok((await evaluate('courierFixtureMap.getZoom()')) > initial.zoom);
  await click(70, 445); // Fit route.
  await delay(1000);
  assert.ok(Math.abs((await evaluate('courierFixtureMap.getZoom()')) - initial.zoom) < 0.1);
  await click(390, 543); // Change fixture geometry.
  const refreshed = await waitForMap(121.3);
  assert.equal(refreshed.validLayerOrder, true);
  const screenshot = await send('Page.captureScreenshot', { format: 'png' });
  await writeFile('build/courier-map-browser.png', Buffer.from(screenshot.data, 'base64'));
  await click(390, 593); // Invalidate fixture session.
  await delay(1000);
  assert.equal(await evaluate("document.querySelectorAll('.maplibregl-canvas').length"), 0, 'Session invalidation removes the platform map');
  assert.equal(apiRequests, 0, 'The SDK must not issue synthetic API requests');
  assert.equal(credentialRequests, 0, 'No browser/SDK resource request receives bearer headers');
  assert.deepEqual(errors, [], 'No uncaught renderer exceptions');
  console.log(JSON.stringify({ initial, refreshed, apiRequests, credentialRequests, sessionCleanup: true }));
} finally {
  socket.close();
  await fetch(`${debuggerOrigin}/json/close/${page.id}`);
}
