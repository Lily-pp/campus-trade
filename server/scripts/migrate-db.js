const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

const {
  CREATE_SCHEMA_MIGRATIONS_SQL,
  acquireMigrationLock,
  listApplicationTables,
  loadMigrations,
  readMigrationRecords,
  releaseMigrationLock,
  validateMigrationRecordSequence,
  validateRecordedMigration,
} = require('./migration-utils');

function createClient() {
  return new Client({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });
}

async function main() {
  const migrations = loadMigrations();
  const client = createClient();
  let lockAcquired = false;

  await client.connect();

  try {
    await acquireMigrationLock(client);
    lockAcquired = true;
    await client.query(CREATE_SCHEMA_MIGRATIONS_SQL);

    const records = await readMigrationRecords(client);
    if (records.size === 0) {
      const applicationTables = await listApplicationTables(client);
      if (applicationTables.length > 0) {
        throw new Error(
          '检测到已有业务表，但 schema_migrations 没有记录。' +
          '禁止从 V001 自动执行；请先运行 npm run db:baseline:dry 和 npm run db:baseline'
        );
      }
    }

    const localVersions = new Set(migrations.map((migration) => migration.version));
    for (const version of records.keys()) {
      if (!localVersions.has(version)) {
        throw new Error(
          `schema_migrations 中存在本地缺失的版本 ${version}，禁止自动继续`
        );
      }
    }
    validateMigrationRecordSequence(migrations, records);

    for (const migration of migrations) {
      const record = records.get(migration.version);
      if (record) {
        validateRecordedMigration(migration, record);
        console.log(`[SKIPPED] ${migration.filename}`);
        continue;
      }

      console.log(`[EXECUTING] ${migration.filename}`);
      try {
        await client.query('BEGIN');
        await client.query(migration.executableSql);
        await client.query(
          `INSERT INTO schema_migrations (version, filename, checksum)
           VALUES ($1, $2, $3)`,
          [migration.version, migration.filename, migration.checksum]
        );
        await client.query('COMMIT');
        console.log(`[COMPLETED] ${migration.filename}`);
      } catch (error) {
        try {
          await client.query('ROLLBACK');
        } catch (rollbackError) {
          console.error(
            `[ROLLBACK FAILED] ${migration.filename}: ${rollbackError.message}`
          );
        }
        console.error(`[FAILED] ${migration.filename}`);
        console.error(error);
        throw error;
      }
    }

    console.log('Database migrations completed.');
  } finally {
    if (lockAcquired) {
      try {
        await releaseMigrationLock(client);
      } catch (error) {
        console.error(`Failed to release migration lock: ${error.message}`);
      }
    }
    await client.end();
  }
}

main().catch((error) => {
  console.error(`Database migration failed: ${error.message}`);
  process.exitCode = 1;
});
