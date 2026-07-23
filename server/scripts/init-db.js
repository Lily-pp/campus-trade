const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

async function main() {
  const migrationsDir = path.resolve(__dirname, '..', '..', 'database', 'migrations');
  const migrationFiles = fs.readdirSync(migrationsDir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && path.extname(entry.name).toLowerCase() === '.sql')
    .map((entry) => entry.name)
    .sort((a, b) => a.localeCompare(b, 'en'));

  const client = new Client({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });

  await client.connect();

  try {
    console.log(`Initializing database: ${process.env.DB_NAME}`);

    for (const migrationFile of migrationFiles) {
      const migrationPath = path.join(migrationsDir, migrationFile);

      console.log(`Executing migration: ${migrationFile}`);

      try {
        const sql = fs.readFileSync(migrationPath, 'utf8');
        await client.query(sql);
        console.log(`Completed migration: ${migrationFile}`);
      } catch (error) {
        console.error(`Migration failed: ${migrationFile}`);
        console.error(error);
        throw error;
      }
    }

    const tablesResult = await client.query(
      "SELECT tablename FROM pg_tables WHERE schemaname = current_schema() ORDER BY tablename"
    );
    const usersResult = await client.query(
      'SELECT id, username, role FROM users ORDER BY id'
    );

    console.log('Tables:', tablesResult.rows.map((row) => row.tablename).join(', '));
    console.log('Users:', usersResult.rows);
    console.log('Database initialization completed.');
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error('Database initialization failed:', error);
  process.exit(1);
});
