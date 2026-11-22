import {configDefaults, defineConfig} from 'vitest/config';

export default defineConfig({
  test: {
    include: ['{fixtures,apps,packages}/**/*.vitest.{ts,tsx,mts,js,mjs}'],
    exclude: [...configDefaults.exclude, '**/dist/**'],
  },
});
