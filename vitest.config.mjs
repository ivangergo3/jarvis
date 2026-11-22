import {configDefaults, defineConfig} from 'vitest/config';

export default defineConfig({
  test: {
    include: [
      '{fixtures,apps,packages}/**/*.{test,spec,vitest}.?(c|m)[jt]s?(x)',
    ],
    exclude: [...configDefaults.exclude, '**/dist/**'],
  },
});
