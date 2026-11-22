import hooks from 'eslint-plugin-react-hooks';
import tseslint from 'typescript-eslint';
import {defineConfig, globalIgnores} from 'eslint/config';

export default defineConfig(
  globalIgnores(['!**/node_modules/']),
  {
    files: ['**/*.{js,cjs,mjs,jsx,ts,cts,mts,tsx}'],
    linterOptions: {
      noInlineConfig: true,
      reportUnusedDisableDirectives: 'error',
    },
    languageOptions: {parserOptions: {ecmaFeatures: {jsx: true}}},
    rules: {
      eqeqeq: 'error',
      'no-restricted-syntax': [
        'error',
        {
          selector:
            ':matches(CallExpression, NewExpression)[callee.name="Array"]',
          message: 'Use an array literal or Array.from().',
        },
      ],
      'no-cond-assign': 'error',
      'no-debugger': 'error',
      'no-eval': 'error',
      'no-new-wrappers': 'error',
      'no-var': 'error',
      'one-var': ['error', 'never'],
      'prefer-const': 'error',
    },
  },
  {
    files: ['**/*.{ts,tsx,mts,cts}'],
    extends: [tseslint.configs.recommendedTypeChecked],
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      '@typescript-eslint/ban-ts-comment': [
        'error',
        {
          'ts-check': false,
          'ts-expect-error': true,
          'ts-ignore': true,
          'ts-nocheck': true,
        },
      ],
      '@typescript-eslint/consistent-type-imports': 'error',
      '@typescript-eslint/no-floating-promises': ['error', {ignoreVoid: false}],
      '@typescript-eslint/no-non-null-assertion': 'error',
    },
  },
  {
    files: ['**/*.{js,jsx,ts,tsx,mjs,mts,cjs,cts}'],
    plugins: {'react-hooks': hooks},
    rules: {
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'error',
    },
  },
);
