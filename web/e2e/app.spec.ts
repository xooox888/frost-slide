/**
 * End-to-end: the production build in Chromium. Walks the menus, races a course to the results
 * with the scripted bot driving, and races a few other worlds from a save with every course open.
 * Screenshots of every screen land in `test-results/`, per viewport.
 */
import { expect, test, type Page, type TestInfo } from '@playwright/test';
import { LEVEL_IDS } from '../src/core/models';

/** Page errors and console errors, which must stay empty. */
function watchErrors(page: Page): string[] {
  const problems: string[] = [];
  page.on('pageerror', (error) => problems.push(String(error)));
  page.on('console', (message) => {
    if (message.type() === 'error') problems.push(message.text());
  });
  return problems;
}

async function shot(page: Page, info: TestInfo, name: string): Promise<void> {
  // Let the 0.28 s screen fade finish.
  await page.waitForTimeout(500);
  await page.screenshot({ path: info.outputPath(`${name}.png`) });
}

type Probe = { frostSlide: { engine: { phase: string; raceTime: number }; play: (id: string) => void } };

test('menus: title, course map, settings', async ({ page }, info) => {
  const problems = watchErrors(page);
  await page.goto('/');
  await expect(page.getByRole('heading', { name: /FROST\s*SLIDE/ })).toBeVisible();
  await shot(page, info, 'menu');

  await page.getByRole('button', { name: /Course Map/ }).click();
  await expect(page.getByRole('heading', { name: 'Course Map' })).toBeVisible();
  await shot(page, info, 'course-map');
  await page.getByRole('button', { name: /back/i }).first().click();

  await page.getByRole('button', { name: /Settings/ }).click();
  await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();
  await shot(page, info, 'settings');
  expect(problems).toEqual([]);
});

test('a race from the menu to the results, saved', async ({ page }, info) => {
  const problems = watchErrors(page);
  await page.goto('/?autopilot=expert&speed=8');
  await page.getByRole('button', { name: /^Race/ }).click();
  await expect(page.getByRole('button', { name: 'Pause' })).toBeVisible();
  await shot(page, info, 'race-countdown');

  await page.waitForFunction(() => {
    const engine = (window as unknown as Probe).frostSlide?.engine;
    return engine?.phase === 'racing' && engine.raceTime > 4;
  });
  await page.screenshot({ path: info.outputPath('race.png') });

  await page.getByRole('button', { name: 'Pause' }).click();
  await expect(page.getByRole('dialog')).toBeVisible();
  await shot(page, info, 'pause');
  await page.getByRole('button', { name: /Resume/ }).click();

  await expect(page.getByRole('heading', { name: /Finish|New best!/ })).toBeVisible({ timeout: 200_000 });
  // The stars count up one by one.
  await page.waitForTimeout(3000);
  await page.screenshot({ path: info.outputPath('results.png') });

  const save = await page.evaluate(() => localStorage.getItem('frostslide.save.v1'));
  expect(save).not.toBeNull();
  const records = (JSON.parse(save!) as { records: Record<string, { timesPlayed: number }> }).records;
  expect(records.villageDash?.timesPlayed).toBe(1);
  expect(problems).toEqual([]);
});

test.describe('the other worlds', () => {
  // Software WebGL is slow; the scenery doesn't depend on pixel density.
  test.use({ deviceScaleFactor: 1 });

  test('one course from each world draws', async ({ page }, info) => {
    test.skip(info.project.name !== 'iphone-pro-max', 'Checked on the large viewport only');
    test.setTimeout(480_000);
    const problems = watchErrors(page);
    // A save with every course open, as a player who has finished the game would have.
    await page.addInitScript((ids: readonly string[]) => {
      localStorage.setItem('frostslide.save.v1', JSON.stringify({ unlocked: ids, records: {} }));
    }, LEVEL_IDS);
    await page.goto('/?autopilot=expert&speed=8');
    await expect(page.getByRole('heading', { name: /FROST\s*SLIDE/ })).toBeVisible();

    for (const id of [
      'iceCaveSpiral',
      'auroraNight',
      'tideGate',
      'glacierDrop',
      'owlHollow',
      'steamVeil',
      'neonSlalom',
    ]) {
      await page.evaluate((course) => (window as unknown as Probe).frostSlide.play(course), id);
      await page.waitForFunction(() => {
        const engine = (window as unknown as Probe).frostSlide.engine;
        return engine.phase === 'racing' && engine.raceTime > 5;
      });
      await page.screenshot({ path: info.outputPath(`world-${id}.png`) });
    }
    expect(problems).toEqual([]);
  });
});
