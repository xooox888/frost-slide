import type { CapacitorConfig } from '@capacitor/cli';

/**
 * The native iOS shell. Same bundle id as the Swift app, so the web build ships as its update
 * and keeps its App Store listing, reviews and saves.
 */
const config: CapacitorConfig = {
  appId: 'com.frostslide.FrostSlide',
  appName: 'Frost Slide',
  webDir: 'dist',
  // The launch screen's navy (Swift: LaunchBackground 0.07, 0.10, 0.22), so nothing flashes white.
  backgroundColor: '#121a38',
  ios: {
    // A game, not a page: no rubber-band scrolling, no automatic safe-area insets (the CSS
    // handles them with env(safe-area-inset-*)).
    contentInset: 'never',
    scrollEnabled: false,
    preferredContentMode: 'mobile',
    backgroundColor: '#121a38',
  },
  plugins: {
    SplashScreen: {
      // Hidden by the app once the first screen has rendered, so there is no white flash.
      launchAutoHide: false,
      backgroundColor: '#121a38',
      showSpinner: false,
    },
  },
};

export default config;
