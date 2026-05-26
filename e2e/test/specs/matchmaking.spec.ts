const BACKEND_HOST = process.env.BACKEND_HOST || '100.85.144.5';
const MATCHING_URL = `http://${BACKEND_HOST}:8084`;
const LOCATION_URL = `http://${BACKEND_HOST}:9081`;
const AUTH_URL = `http://${BACKEND_HOST}:9080`;
const TEST_PHONE = '6281234567890';
const TEST_PASSWORD = 'password123';

let driverRefId = '';

const hideKeyboard = async () => {
  try { await driver.pressKeyCode(4); } catch {}
  await driver.pause(300);
};

const doLogin = async () => {
  const phone = await $('//android.widget.EditText[@password="false"]');
  const pw = await $('//android.widget.EditText[@password="true"]');
  const btn = await $('~sign_in_button');
  if (await btn.isExisting()) {
    await phone.click(); await phone.clearValue();
    await phone.addValue(TEST_PHONE);
    await hideKeyboard();
    await pw.click(); await pw.addValue(TEST_PASSWORD);
    await hideKeyboard();
    await btn.click();
    await driver.pause(6000);
  }
};

const dismissErrorDialog = async () => {
  try {
    const ok = await $('//android.widget.Button[@content-desc="OK"]');
    if (await ok.isExisting()) { await ok.click(); await driver.pause(500); }
  } catch {}
};

describe('StudEx Driver App - Matchmaking', () => {
  before(async () => {
    const authRes = await fetch(`${AUTH_URL}/drivers/auth`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: TEST_PHONE, password: TEST_PASSWORD }),
    });
    if (authRes.ok) {
      const authData = await authRes.json() as any;
      driverRefId = authData.driver?.id || '';
    }
  });

  it('enables GPS, streams location, and receives match notification', async () => {
    if (!driverRefId) { expect(true).toBe(false); return; }

    await driver.startActivity('com.studex.driver_app', '.MainActivity');
    await driver.pause(3000);
    await doLogin();
    await dismissErrorDialog();
    await driver.pause(3000);

    const gpsToggle = await $('//android.widget.Switch');
    if (await gpsToggle.isExisting()) {
      const isChecked = await gpsToggle.getAttribute('checked');
      if (isChecked !== 'true') {
        await gpsToggle.click();
        await driver.pause(3000);
      }
    }
    await driver.pause(5000);

    const poolRes = await fetch(`${MATCHING_URL}/match/pool`);
    const pool = await poolRes.json() as Array<{ ref_id: string }>;
    const inPool = pool.some(d => d.ref_id === driverRefId);
    expect(inPool).toBe(true);

    await fetch(`${MATCHING_URL}/match/requests`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        order_id: `E2E-ORDER-${Date.now()}`,
        customer_ref_id: 'e2e-customer',
        pickup_lat: -6.2088,
        pickup_lng: 106.8456,
        max_attempts: 5,
      }),
    });

    await driver.pause(6000);

    const snackbar = await $(
      '//*[contains(@text,"Pesanan") or contains(@content-desc,"Pesanan")]'
    );
    const hasNotification = await snackbar.isExisting();
    expect(hasNotification).toBe(true);
  });
});
