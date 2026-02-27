module.exports = [
  {
    ignores: ["node_modules/**"],
  },
  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "commonjs",
    },
    rules: {
      "no-console": "off",
      "no-unused-vars": ["warn", {argsIgnorePattern: "^_"}],
    },
  },
];
