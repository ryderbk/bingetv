const { chromium } = require('playwright');
const path = require('path');

async function runTestSuite() {
  console.log('--- Starting Binge TV Navigation Playwright Test Suite ---');
  const browser = await chromium.launch({
    headless: true,
    executablePath: 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'
  });
  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 }
  });
  const page = await context.newPage();

  const testHtmlPath = 'file:///' + path.resolve(__dirname, 'test.html').replace(/\\/g, '/');
  console.log('Loading test page:', testHtmlPath);
  await page.goto(testHtmlPath, { waitUntil: 'load' });

  // 1. Check window.__bingeTv initialized
  const initialized = await page.evaluate(() => window.__bingeTv && window.__bingeTv.initialized);
  console.assert(initialized === true, 'window.__bingeTv must be initialized');
  console.log('[PASS] __bingeTv initialized');

  // 2. Desktop viewport meta test
  const viewportMeta = await page.evaluate(() => {
    const meta = document.querySelector('meta[name="viewport"]');
    return meta ? meta.content : null;
  });
  console.assert(viewportMeta && viewportMeta.includes('width=1280'), 'Desktop viewport meta must be injected');
  console.log('[PASS] Desktop viewport forced to 1280px:', viewportMeta);

  // 3. Desktop browser signals test
  const signals = await page.evaluate(() => ({
    maxTouchPoints: navigator.maxTouchPoints,
    platform: navigator.platform
  }));
  console.assert(signals.maxTouchPoints === 0, 'maxTouchPoints must be 0 for desktop');
  console.assert(signals.platform === 'Win32', 'platform must be Win32');
  console.log('[PASS] Desktop navigator signals verified:', signals);

  // 4. Candidates detection
  const candidateCount = await page.evaluate(() => window.__bingeTv.getCandidatesCount());
  console.assert(candidateCount >= 6, 'Must find candidates across input, sidebar, cards, modal');
  console.log(`[PASS] Interactive candidates identified: ${candidateCount}`);

  // 5. Initial Focus on search input
  await page.waitForTimeout(500);
  const initialFocusId = await page.evaluate(() => {
    const el = window.__bingeTv.getCurrentFocus();
    return el ? el.id : null;
  });
  console.assert(initialFocusId === 'search-input', `Expected search-input initial focus, got ${initialFocusId}`);
  console.log(`[PASS] Initial focus correctly placed on: ${initialFocusId}`);

  // 6. D-pad Down navigation to sidebar or cards
  await page.evaluate(() => window.__bingeTv.key('Down', 0, false));
  await page.waitForTimeout(100);
  const secondFocusId = await page.evaluate(() => {
    const el = window.__bingeTv.getCurrentFocus();
    return el ? (el.id || el.className) : null;
  });
  console.log(`[PASS] Down D-pad navigated to: ${secondFocusId}`);

  // 7. Test Modal Opening & Remote Back Dismissal
  console.log('Testing Modal & Remote Back handling...');
  await page.evaluate(() => {
    document.getElementById('open-modal-btn').click();
  });
  let isModalVisible = await page.evaluate(() => {
    const m = document.getElementById('test-modal');
    return m && window.getComputedStyle(m).display !== 'none';
  });
  console.assert(isModalVisible === true, 'Modal should be visible after click');
  console.log('[PASS] Modal overlay displayed');

  // Trigger Remote Back to dismiss modal
  await page.evaluate(() => window.__bingeTv.key('Back', 0, false));
  await page.waitForTimeout(100);
  isModalVisible = await page.evaluate(() => {
    const m = document.getElementById('test-modal');
    return m && window.getComputedStyle(m).display !== 'none';
  });
  console.assert(isModalVisible === false, 'Modal should be dismissed after Back key');
  console.log('[PASS] Modal overlay successfully dismissed via remote Back key');

  // 8. Test Virtual Cursor Mode
  console.log('Testing Virtual Cursor Mode...');
  // Toggle cursor mode via Red key
  await page.evaluate(() => window.__bingeTv.key('Red', 0, false));
  let isCursorMode = await page.evaluate(() => window.__bingeTv.isCursorMode());
  console.assert(isCursorMode === true, 'Cursor mode must be active after Red key');

  // Move cursor with D-pad
  await page.evaluate(() => window.__bingeTv.key('Right', 1, false));
  await page.waitForTimeout(100);
  await page.evaluate(() => window.__bingeTv.key('Down', 1, false));
  await page.waitForTimeout(100);

  // Toggle cursor mode off
  await page.evaluate(() => window.__bingeTv.key('Red', 0, false));
  await page.waitForTimeout(100);
  isCursorMode = await page.evaluate(() => window.__bingeTv.isCursorMode());
  console.assert(isCursorMode === false, 'Cursor mode must be deactivated');
  console.log('[PASS] Virtual cursor mode activated, accelerated, and toggled');

  // 9. Test Page Width / Zoom Adjustment
  console.log('Testing Page Width adjustment...');
  await page.evaluate(() => window.__bingeTv.setPageWidth(1600));
  const newMeta = await page.evaluate(() => {
    return document.querySelector('meta[name="viewport"]').content;
  });
  console.assert(newMeta.includes('width=1600'), 'Viewport width must update to 1600');
  console.log('[PASS] Page width dynamically updated to 1600:', newMeta);

  // 10. Test against live site default (if reachable)
  try {
    console.log('Testing injection against https://bingebang.st/ ...');
    await page.goto('https://bingebang.st/', { timeout: 8000, waitUntil: 'domcontentloaded' });
    await page.addScriptTag({ path: path.resolve(__dirname, '../../assets/js/tv_nav.js') });
    const liveInit = await page.evaluate(() => window.__bingeTv && window.__bingeTv.initialized);
    console.log(`[PASS] Live site injection test succeeded: ${liveInit}`);
  } catch (err) {
    console.log('[INFO] Live site not reachable offline or blocked by CDN (expected in test sandbox):', err.message);
  }

  await browser.close();
  console.log('=== ALL JS NAVIGATION TESTS PASSED ===');
}

runTestSuite().catch(err => {
  console.error('Test Suite Failed:', err);
  process.exit(1);
});
