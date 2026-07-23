const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

const {
  CREATE_SCHEMA_MIGRATIONS_SQL,
  acquireMigrationLock,
  loadMigrations,
  readMigrationRecords,
  releaseMigrationLock,
  schemaMigrationsTableExists,
  validateMigrationRecordSequence,
  validateRecordedMigration,
} = require('./migration-utils');

const dryRun = process.argv.includes('--dry-run');
const unknownArguments = process.argv
  .slice(2)
  .filter((argument) => argument !== '--dry-run');

if (unknownArguments.length > 0) {
  console.error(`Unknown arguments: ${unknownArguments.join(', ')}`);
  process.exitCode = 1;
} else {
  run();
}

function createClient() {
  return new Client({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });
}

const checksByVersion = {
  V001: {
    description: '基础交易表',
    tables: ['users', 'items', 'categories', 'orders'],
  },
  V002: {
    description: '活动基础结构',
    tables: ['activities'],
    columns: { items: ['activity_id'] },
  },
  V003: {
    description: '补贴、代金券与考研资料字段',
    tables: ['vouchers'],
    columns: {
      activities: [
        'subsidy_enabled',
        'subsidy_discount_rate',
        'voucher_min_rate',
        'voucher_max_rate',
        'tagline',
      ],
      items: ['school', 'major', 'exam_year', 'is_landed'],
    },
  },
  V004: {
    description: '校园寄存和租赁基础结构',
    tables: ['storage_services', 'storage_requests', 'rental_items', 'rental_orders'],
  },
  V005: {
    description: '清理及种子数据迁移的结构前置条件',
    tables: ['activities', 'storage_services', 'storage_requests', 'rental_items'],
  },
  V006: {
    description: '寄存与租赁增强字段',
    columns: {
      storage_services: [
        'image_url',
        'remain_capacity',
        'contact_info',
        'location_detail',
        'start_time',
        'end_time',
      ],
      storage_requests: [
        'contact_info',
        'expected_start_time',
        'expected_end_time',
      ],
    },
  },
  V007: {
    description: '租赁联系方式修复',
    columns: { rental_items: ['contact_info'] },
  },
  V008: {
    description: '校园服务审核和寄存订单',
    tables: ['storage_orders'],
    columns: {
      storage_services: ['is_approved'],
      storage_requests: ['is_approved'],
      rental_items: ['is_approved'],
    },
  },
  V009: {
    description: '毕业公益循环结构',
    tables: ['free_apply', 'donation_record'],
    columns: {
      items: ['item_type', 'free_deadline'],
      users: ['charity_points'],
    },
  },
  V010: {
    description: '失物招领结构',
    tables: [
      'lost_found_points',
      'found_items',
      'lost_posts',
      'lf_handovers',
      'user_coupons',
    ],
    columns: {
      found_items: ['longitude', 'latitude'],
      lost_posts: ['longitude', 'latitude'],
    },
  },
  V011: {
    description: '商品期望交易地址',
    columns: {
      items: ['expected_address', 'expected_longitude', 'expected_latitude'],
    },
  },
};

async function tableExists(client, tableName) {
  const result = await client.query(
    `SELECT EXISTS (
       SELECT 1
       FROM information_schema.tables
       WHERE table_schema = current_schema()
         AND table_name = $1
     ) AS exists`,
    [tableName]
  );
  return result.rows[0].exists;
}

async function columnExists(client, tableName, columnName) {
  const result = await client.query(
    `SELECT EXISTS (
       SELECT 1
       FROM information_schema.columns
       WHERE table_schema = current_schema()
         AND table_name = $1
         AND column_name = $2
     ) AS exists`,
    [tableName, columnName]
  );
  return result.rows[0].exists;
}

async function checkVersionStructure(client, migration) {
  const checks = checksByVersion[migration.version];
  if (!checks) {
    return {
      ok: false,
      missing: [`没有为 ${migration.version} 配置 baseline 结构检查规则`],
      description: '未知迁移版本',
    };
  }

  const missing = [];
  for (const tableName of checks.tables || []) {
    if (!(await tableExists(client, tableName))) {
      missing.push(`table ${tableName}`);
    }
  }

  for (const [tableName, columns] of Object.entries(checks.columns || {})) {
    for (const columnName of columns) {
      if (!(await columnExists(client, tableName, columnName))) {
        missing.push(`column ${tableName}.${columnName}`);
      }
    }
  }

  return {
    ok: missing.length === 0,
    missing,
    description: checks.description,
  };
}

async function main() {
  const migrations = loadMigrations();
  const client = createClient();
  let lockAcquired = false;

  await client.connect();

  try {
    await acquireMigrationLock(client);
    lockAcquired = true;

    const migrationTableExists = await schemaMigrationsTableExists(client);
    if (!dryRun && !migrationTableExists) {
      await client.query(CREATE_SCHEMA_MIGRATIONS_SQL);
    }

    const records = migrationTableExists || !dryRun
      ? await readMigrationRecords(client)
      : new Map();
    const localVersions = new Set(migrations.map((migration) => migration.version));
    for (const version of records.keys()) {
      if (!localVersions.has(version)) {
        throw new Error(
          `schema_migrations 中存在本地缺失的版本 ${version}，禁止自动继续`
        );
      }
    }
    validateMigrationRecordSequence(migrations, records);

    const plannedMigrations = [];
    for (const migration of migrations) {
      const record = records.get(migration.version);
      if (record) {
        validateRecordedMigration(migration, record);
        console.log(`[ALREADY BASELINED] ${migration.filename}`);
        continue;
      }

      const result = await checkVersionStructure(client, migration);
      if (!result.ok) {
        console.error(`[MISSING] ${migration.filename} - ${result.description}`);
        console.error(`Required structure not found: ${result.missing.join(', ')}`);
        throw new Error(
          `Baseline stopped at ${migration.version}; later versions were not marked`
        );
      }

      plannedMigrations.push(migration);
      console.log(
        dryRun
          ? `[DRY RUN] would baseline ${migration.filename}`
          : `[VERIFIED] ${migration.filename}`
      );
    }

    if (dryRun) {
      console.log(`Dry run completed. ${plannedMigrations.length} migration(s) would be recorded.`);
      return;
    }

    if (plannedMigrations.length === 0) {
      console.log('No migration records need to be added.');
      return;
    }

    await client.query('BEGIN');
    try {
      for (const migration of plannedMigrations) {
        await client.query(
          `INSERT INTO schema_migrations (version, filename, checksum)
           VALUES ($1, $2, $3)`,
          [migration.version, migration.filename, migration.checksum]
        );
        console.log(`[BASELINED] ${migration.filename}`);
      }
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    }

    console.log('Database baseline completed.');
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

async function run() {
  try {
    await main();
  } catch (error) {
    console.error(`Database baseline failed: ${error.message}`);
    process.exitCode = 1;
  }
}
