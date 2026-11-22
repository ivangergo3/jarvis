export function preservesWorkspaceStrictness(options) {
  return (
    options.noCheck !== true &&
    options.skipLibCheck !== true &&
    options.skipDefaultLibCheck !== true &&
    (!options.allowJs || options.checkJs === true) &&
    options.strict === true &&
    options.alwaysStrict !== false &&
    options.noUncheckedIndexedAccess === true &&
    options.exactOptionalPropertyTypes === true &&
    [
      'noImplicitAny',
      'strictNullChecks',
      'strictFunctionTypes',
      'strictBindCallApply',
      'strictPropertyInitialization',
      'strictBuiltinIteratorReturn',
      'noImplicitThis',
      'useUnknownInCatchVariables',
    ].every((key) => options[key] !== false)
  );
}
