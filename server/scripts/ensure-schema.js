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

async function ensureSchema() {
  await ensureItemSchema();
}

module.exports = { ensureSchema };