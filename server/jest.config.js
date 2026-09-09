module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/test/**/*.test.ts'],
  testTimeout: 15000,
  setupFiles: ['dotenv/config'],
  // maxWorkers: 1 — required because each test file's beforeEach unconditionally truncates
  // shared tables (users, categories, budgets, transactions). Running test files in parallel
  // causes a race: file A's test may depend on data that file B's beforeEach just deleted.
  // Sequential execution ensures all cleanup happens before the next test file starts.
  maxWorkers: 1,
};
