exports.shorthands = undefined;

exports.up = (pgm) => {
  // GET /transactions orders by occurred_at desc (see src/routes/transactions.ts)
  // and is 45% of the school-assignment k6 load test's request mix — with
  // 1.2M+ rows and only idx_transactions_user_id (a plain btree on
  // user_id), that query has to sort matching rows on the fly instead of
  // reading them back in order. This composite index lets Postgres read
  // straight off it, in order, without a separate sort step.
  pgm.sql(`
    create index idx_transactions_user_occurred_at
      on transactions (user_id, occurred_at desc);
  `);
};

exports.down = (pgm) => {
  pgm.sql('drop index if exists idx_transactions_user_occurred_at;');
};
