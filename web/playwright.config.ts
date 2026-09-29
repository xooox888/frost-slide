import { defineConfig } from '@playwright/test';

/**
 * End-to-end tests: the production build in Chromium, on a small and a large iPhone-sized
 * viewport. WebGL runs on SwiftShader (software), so frame rates here say nothing about phones.
 */
const iphone = (width: number, height: number, scale: number) => ({
  viewport: { width, height },
  deviceScaleFactor: scale,
  isMobile: true,
  hasTouch: true,
});

export default defineConfig({
  testDir: 'e2e',
  timeout: 240_000,
  expect: { timeout: 20_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: 'http://localhost:4173',
    trace: 'retain-on-failure',
    launchOptions: {
      args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
    },
  },
  webServer: {
    // Always tests a fresh production build.
    command: 'npx vite build && npx vite preview --port 4173 --strictPort',
    port: 4173,
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
  projects: [
    { name: 'iphone-se', use: iphone(375, 667, 2) },
    { name: 'iphone-pro-max', use: iphone(430, 932, 3) },
  ],
});
