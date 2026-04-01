/**
 * 迁移脚本：为 items 表添加 quantity 列
 * 执行：node server/scripts/migrate-quantity.js
 */
const db = require('../config/db');

async function migrate() {
    try {
        // 检查列是否存在
        const check = await db.query(
            `SELECT 1 FROM information_schema.columns
             WHERE table_schema = current_schema()
               AND table_name = 'items'
               AND column_name = 'quantity'`
        );
        if (check.rows.length > 0) {
            console.log('quantity 列已存在，跳过迁移');
            process.exit(0);
        }
        await db.query('ALTER TABLE items ADD COLUMN quantity INTEGER DEFAULT 1');
        console.log('✅ 迁移成功：已添加 quantity 列（默认值 1）');
        process.exit(0);
    } catch (e) {
        console.error('❌ 迁移失败:', e.message);
        process.exit(1);
    }
}

migrate();
