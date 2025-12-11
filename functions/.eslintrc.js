module.exports = {
  env: {
    "es6": true,
    "node": true
  },
  parserOptions: {
    "ecmaVersion": 2021
  },
  extends: [
    "eslint:recommended",
    "google"
  ],
  rules: {
    // Disable or highly relax problematic rules for deployment
    "max-len": "off", // Turn off maximum line length check
    "quotes": ["off"], // Turn off quote style check
    "indent": ["off"], // Turn off indentation check
    "object-curly-spacing": "off", // Turn off object curly spacing check
    "comma-dangle": "off", // Turn off trailing comma check
    "arrow-parens": "off", // Turn off arrow function parens check
    "no-trailing-spaces": "off", // Turn off trailing spaces check

    // Keep essential Firebase Functions rules if you wish, or turn them off too
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error"
    // Add other rules you might want to keep or relax as needed
  }
};
