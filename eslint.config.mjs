import hooks from 'eslint-plugin-react-hooks';
import tseslint from 'typescript-eslint';
import {defineConfig, globalIgnores} from 'eslint/config';

// Resolve global loader references through ESLint so local names and ordinary
// object properties stay available. The import check verifies direct calls.
function directCall(node) {
  return node.parent.type === 'CallExpression' && node.parent.callee === node;
}

const commonJSLoader = {
  create(context) {
    return {
      'Program:exit'(program) {
        const scope = context.sourceCode.getScope(program);
        for (const name of ['require', 'module']) {
          const global = scope.set.get(name);
          const references = [
            ...(global && !global.defs.length ? global.references : []),
            ...scope.through.filter((ref) => ref.identifier.name === name),
          ];
          for (const {identifier} of references) {
            if (name === 'require' && directCall(identifier)) continue;
            const member = identifier.parent;
            if (
              name === 'module' &&
              member.type === 'MemberExpression' &&
              member.object === identifier
            ) {
              const property = member.computed
                ? member.property.value
                : member.property.name;
              if (
                property === 'exports' ||
                (property === 'require' && directCall(member))
              )
                continue;
            }
            context.report({
              node: identifier,
              message: 'Use a direct require call or module.exports.',
            });
          }
        }
      },
    };
  },
};

export default defineConfig(
  globalIgnores(['!**/node_modules/']),
  {
    files: ['**/*.{js,cjs,mjs,jsx,ts,cts,mts,tsx}'],
    linterOptions: {
      noInlineConfig: true,
      reportUnusedDisableDirectives: 'error',
    },
    languageOptions: {parserOptions: {ecmaFeatures: {jsx: true}}},
    plugins: {workspace: {rules: {'commonjs-loader': commonJSLoader}}},
    rules: {
      'workspace/commonjs-loader': 'error',
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
      '@typescript-eslint/consistent-type-imports': 'error',
      '@typescript-eslint/no-floating-promises': ['error', {ignoreVoid: false}],
      '@typescript-eslint/no-non-null-assertion': 'error',
    },
  },
  {
    files: ['packages/**/*.{js,mjs}'],
    rules: {
      'no-restricted-globals': [
        'error',
        'module',
        'exports',
        'require',
        '__dirname',
        '__filename',
      ],
    },
  },
  {
    files: ['**/*.cts'],
    rules: {
      '@typescript-eslint/no-require-imports': ['error', {allowAsImport: true}],
    },
  },
  {
    files: ['**/*.{js,jsx,ts,tsx,mjs,mts,cjs,cts}'],
    plugins: {'react-hooks': hooks, '@typescript-eslint': tseslint.plugin},
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
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'error',
    },
  },
);
