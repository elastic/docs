import { defineConfig } from 'vite';

// Builds the docs' browser resources. `index-v1.js` is the only entry point
// and it imports `styles-v1.pcss`, so one build makes both files:
//
//   docs-v1.js     a classic (IIFE) script, loaded with a plain <script> tag
//   styles-v1.css
//
// The fonts that the CSS refers to land next to them.
//
// Callers pass `--outDir`.
export default defineConfig({
  root: import.meta.dirname,
  base: '/guide/static/',
  publicDir: false,
  // The components use Preact 8, so JSX compiles to `h(...)`.
  oxc: {
    jsx: { runtime: 'classic', pragma: 'h', development: false },
  },
  css: {
    // `precss` turns `&:has(...)` in `heading.pcss` into a selector that
    // lightningcss can't parse. Browsers ignore that rule too, so drop it
    // instead of failing the build.
    lightningcss: { errorRecovery: true },
  },
  build: {
    target: 'baseline-widely-available',
    sourcemap: false,
    emptyOutDir: false,
    // Always emit fonts as files rather than embedding them in the CSS.
    assetsInlineLimit: 0,
    // Docker for Mac doesn't forward file system events from mounted volumes
    // so `build_docs --open` sets CHOKIDAR_USEPOLLING there. Setting `watch`
    // makes `vite build` wait for changes, so only do it under `--watch`.
    watch:
      process.argv.includes('--watch') && process.env.CHOKIDAR_USEPOLLING
        ? { watcher: { usePolling: true } }
        : null,
    cssCodeSplit: false,
    rollupOptions: {
      input: 'docs_js/index-v1.js',
      output: {
        // A classic script, loaded with a plain <script> tag.
        format: 'iife',
        entryFileNames: 'docs-v1.js',
        assetFileNames: (asset) =>
          (asset.names ?? []).some((n) => n.endsWith('.css'))
            ? 'styles-v1.css'
            : '[name][extname]',
      },
    },
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./vitest.setup.js'],
    include: ['docs_js/__tests__/**/*.test.{js,jsx}', '__test__/**/*.test.js'],
  },
});
