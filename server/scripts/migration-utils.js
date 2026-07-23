const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const MIGRATION_FILENAME_PATTERN = /^V(\d+)_([A-Za-z0-9][A-Za-z0-9_-]*)\.sql$/;
const MIGRATIONS_DIR = path.resolve(__dirname, '..', '..', 'database', 'migrations');
const MIGRATION_LOCK_ID = 20260723;

const CREATE_SCHEMA_MIGRATIONS_SQL = `
  CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(20) PRIMARY KEY,
    filename VARCHAR(255) NOT NULL,
    checksum VARCHAR(64),
    executed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
  )
`;

function calculateChecksum(content) {
  const normalizedContent = content.replace(/\r\n?/g, '\n');
  return crypto.createHash('sha256').update(normalizedContent, 'utf8').digest('hex');
}

function prepareExecutableSql(content) {
  const normalizedContent = content.replace(/\r\n?/g, '\n');
  const executableSql = normalizedContent.replace(
    /^\s*(?:BEGIN|COMMIT)\s*;\s*(?:--.*)?$/gim,
    ''
  );

  if (/^\s*ROLLBACK\s*;/im.test(executableSql)) {
    throw new Error('迁移文件中不允许包含 ROLLBACK；事务必须由迁移器统一管理');
  }

  return executableSql;
}

function loadMigrations() {
  const entries = fs.readdirSync(MIGRATIONS_DIR, { withFileTypes: true });
  const sqlFiles = entries
    .filter((entry) => entry.isFile() && path.extname(entry.name).toLowerCase() === '.sql')
    .map((entry) => entry.name);

  const invalidFiles = [];
  const migrations = [];

  for (const filename of sqlFiles) {
    const match = MIGRATION_FILENAME_PATTERN.exec(filename);
    if (!match) {
      invalidFiles.push(filename);
      continue;
    }

    const versionNumber = Number(match[1]);
    if (!Number.isSafeInteger(versionNumber) || versionNumber <= 0) {
      invalidFiles.push(filename);
      continue;
    }

    const canonicalVersion = `V${String(versionNumber).padStart(3, '0')}`;
    if (`V${match[1]}` !== canonicalVersion) {
      invalidFiles.push(`${filename} (版本号应写为 ${canonicalVersion})`);
      continue;
    }

    const filePath = path.join(MIGRATIONS_DIR, filename);
    const sql = fs.readFileSync(filePath, 'utf8');
    migrations.push({
      version: canonicalVersion,
      versionNumber,
      filename,
      filePath,
      sql,
      executableSql: prepareExecutableSql(sql),
      checksum: calculateChecksum(sql),
    });
  }

  if (invalidFiles.length > 0) {
    throw new Error(`发现非法迁移文件名：${invalidFiles.join(', ')}`);
  }

  if (migrations.length === 0) {
    throw new Error(`迁移目录中没有有效 SQL 文件：${MIGRATIONS_DIR}`);
  }

  migrations.sort((a, b) => a.versionNumber - b.versionNumber);

  const duplicateVersions = [];
  for (let index = 1; index < migrations.length; index += 1) {
    if (migrations[index - 1].versionNumber === migrations[index].versionNumber) {
      duplicateVersions.push(
        `${migrations[index - 1].filename} / ${migrations[index].filename}`
      );
    }
  }
  if (duplicateVersions.length > 0) {
    throw new Error(`发现重复迁移版本号：${duplicateVersions.join(', ')}`);
  }

  for (let index = 0; index < migrations.length; index += 1) {
    const expectedVersion = index + 1;
    if (migrations[index].versionNumber !== expectedVersion) {
      throw new Error(
        `迁移版本缺失或异常：期望 V${String(expectedVersion).padStart(3, '0')}，` +
        `实际为 ${migrations[index].version} (${migrations[index].filename})`
      );
    }
  }

  return migrations;
}

async function schemaMigrationsTableExists(client) {
  const result = await client.query(
    `SELECT EXISTS (
       SELECT 1
       FROM information_schema.tables
       WHERE table_schema = current_schema()
         AND table_name = 'schema_migrations'
     ) AS exists`
  );
  return result.rows[0].exists;
}

async function readMigrationRecords(client) {
  const result = await client.query(
    `SELECT version, filename, checksum, executed_at
     FROM schema_migrations
     ORDER BY version`
  );
  return new Map(result.rows.map((row) => [row.version, row]));
}

async function listApplicationTables(client) {
  const result = await client.query(
    `SELECT table_name
     FROM information_schema.tables
     WHERE table_schema = current_schema()
       AND table_type = 'BASE TABLE'
       AND table_name <> 'schema_migrations'
     ORDER BY table_name`
  );
  return result.rows.map((row) => row.table_name);
}

function validateRecordedMigration(migration, record) {
  if (record.filename !== migration.filename) {
    throw new Error(
      `历史迁移文件名不一致：${migration.version} 已记录为 ${record.filename}，` +
      `当前文件为 ${migration.filename}`
    );
  }

  if (!record.checksum) {
    throw new Error(
      `历史迁移 ${migration.version} 缺少 checksum，禁止自动继续；请人工核验迁移记录`
    );
  }

  if (record.checksum !== migration.checksum) {
    throw new Error(
      `历史迁移文件已被修改：${migration.filename}\n` +
      `记录 checksum: ${record.checksum}\n` +
      `当前 checksum: ${migration.checksum}\n` +
      '禁止自动继续，请恢复已执行版本的原始文件或进行人工审计'
    );
  }
}

function validateMigrationRecordSequence(migrations, records) {
  let foundMissingVersion = false;

  for (const migration of migrations) {
    if (!records.has(migration.version)) {
      foundMissingVersion = true;
      continue;
    }

    if (foundMissingVersion) {
      throw new Error(
        `迁移记录不连续：${migration.version} 已记录，但存在更早的未记录版本；禁止自动继续`
      );
    }
  }
}

async function acquireMigrationLock(client) {
  await client.query('SELECT pg_advisory_lock($1)', [MIGRATION_LOCK_ID]);
}

async function releaseMigrationLock(client) {
  await client.query('SELECT pg_advisory_unlock($1)', [MIGRATION_LOCK_ID]);
}

module.exports = {
  CREATE_SCHEMA_MIGRATIONS_SQL,
  acquireMigrationLock,
  listApplicationTables,
  loadMigrations,
  readMigrationRecords,
  releaseMigrationLock,
  schemaMigrationsTableExists,
  validateMigrationRecordSequence,
  validateRecordedMigration,
};
