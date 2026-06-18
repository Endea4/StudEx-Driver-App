const hideKeyboard = async () => {
  try {
    await driver.pressKeyCode(4);
  } catch {}
  await driver.pause(300);
};

const dismissErrorDialog = async () => {
  try {
    const ok = await $('//android.widget.Button[@content-desc="OK"]');
    if (await ok.isExisting()) {
      await ok.click();
      await driver.pause(500);
    }
  } catch {}
};

describe('StudEx Driver App - Login', () => {
  before(async () => {
    await driver.startActivity('com.studex.driver_app', '.MainActivity');
    await driver.pause(4000);
  });

  it('shows login form elements', async () => {
    const phone = await $('//android.widget.EditText[@password="false"]');
    const pw = await $('//android.widget.EditText[@password="true"]');
    const btn = await $('~sign_in_button');
    expect(await phone.isExisting()).toBe(true);
    expect(await pw.isExisting()).toBe(true);
    expect(await btn.isExisting()).toBe(true);
  });

  it('accepts phone number input', async () => {
    const phone = await $('//android.widget.EditText[@password="false"]');
    await phone.click();
    await phone.clearValue();
    await phone.addValue('6281234567890');
    await hideKeyboard();
  });

  it('accepts password input', async () => {
    const pw = await $('//android.widget.EditText[@password="true"]');
    await pw.click();
    await pw.addValue('password123');
    await hideKeyboard();
  });

  it('taps sign in and handles error dialog', async () => {
    const btn = await $('~sign_in_button');
    await btn.waitForExist({ timeout: 5000 });
    await btn.click();
    await driver.pause(5000);
    await dismissErrorDialog();
  });

  it('shows error on invalid credentials', async () => {
    await driver.startActivity('com.studex.driver_app', '.MainActivity');
    await driver.pause(3000);

    const phone = await $('//android.widget.EditText[@password="false"]');
    if (!await phone.isExisting()) return;

    await phone.click();
    await phone.clearValue();
    await phone.addValue('628999000000');
    await hideKeyboard();

    const pw = await $('//android.widget.EditText[@password="true"]');
    await pw.click();
    await pw.addValue('wrongpass');
    await hideKeyboard();

    const btn = await $('~sign_in_button');
    await btn.waitForExist({ timeout: 5000 });
    await btn.click();
    await driver.pause(8000);

    const error = await $('//android.view.View[@content-desc="Error"]');
    const hasError = await error.isExisting();
    await dismissErrorDialog();

    expect(hasError).toBe(true);
  });
});