const db = require('../config/db');

async function ensureColumn(tableName, columnName, definition) {
  const { rowCount } = await db.query(
    `SELECT 1 FROM information_schema.columns
     WHERE table_schema = current_schema()
       AND table_name   = $1
       AND column_name  = $2`,
    [tableName, columnName]
  );
  if (rowCount === 0) {
    await db.query(`ALTER TABLE "${tableName}" ADD COLUMN "${columnName}" ${definition}`);
    console.log(`[schema] added column ${tableName}.${columnName}`);
  }
}

async function ensureItemSchema() {
  await ensureColumn('items', 'quantity', 'INTEGER DEFAULT 1');
  await ensureColumn('items', 'is_approved', 'BOOLEAN DEFAULT FALSE');

  await db.query(`
    UPDATE items
    SET is_approved = CASE WHEN status = 'pending' THEN FALSE ELSE TRUE END
    WHERE is_approved IS DISTINCT FROM CASE WHEN status = 'pending' THEN FALSE ELSE TRUE END
  `);

  await db.query(`
    UPDATE items
    SET quantity = 0,
        updated_at = CURRENT_TIMESTAMP
    WHERE status = 'sold'
      AND COALESCE(quantity, 1) <> 0
  `);
}

async function ensureReviewsSchema() {
  await ensureColumn('items', 'avg_rating', 'DECIMAL(3,2)');
  await ensureColumn('items', 'review_count', 'INTEGER DEFAULT 0');

  await db.query(`
    CREATE TABLE IF NOT EXISTS reviews (
      id SERIAL PRIMARY KEY,
      item_id INTEGER NOT NULL,
      order_id INTEGER NOT NULL,
      reviewer_id INTEGER NOT NULL,
      rating SMALLINT NOT NULL,
      content TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(order_id, reviewer_id),
      FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
      FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
      FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);

  await db.query(`CREATE INDEX IF NOT EXISTS idx_reviews_item ON reviews(item_id)`);
}

async function ensureSchema() {
  await ensureItemSchema();
  await ensureReviewsSchema();
}

module.exports = { ensureSchema };