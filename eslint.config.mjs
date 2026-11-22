import {defineConfig, globalIgnores} from 'eslint/config';

export default defineConfig(globalIgnores(['!**/node_modules/']), {
  files: ['**/*.{js,cjs,mjs,jsx}'],
  linterOptions: {noInlineConfig: true, reportUnusedDisableDirectives: 'error'},
  languageOptions: {parserOptions: {ecmaFeatures: {jsx: true}}},
  rules: {
    'eqeqeq': 'error',
    'no-restricted-syntax': ['error', {
      selector: ':matches(CallExpression, NewExpression)[callee.name="Array"]',
      message: 'Use an array literal or Array.from().',
    }],
    'no-cond-assign': 'error',
    'no-debugger': 'error',
    'no-eval': 'error',
    'no-new-wrappers': 'error',
    'no-var': 'error',
    'one-var': ['error', 'never'],
    'prefer-const': 'error',
  },
});
