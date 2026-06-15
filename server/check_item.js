const { Client } = require('pg');

const client = new Client({
  host: 'localhost',
  port: 5432,
  user: 'gaussdb',
  password: 'Gauss@123',
  database: 'campus_trade'
});

async function check() {
  try {
    await client.connect();
    console.log('✅ 成功连接到 campus_trade 数据库');

    const res = await client.query(`
      SELECT 
        i.id AS item_id,
        i.title,
        t.name AS tag_name
      FROM items i
      LEFT JOIN item_tags it ON i.id = it.item_id
      LEFT JOIN tags t ON it.tag_id = t.id
      ORDER BY i.id DESC
      LIMIT 10;
    `);

    console.log('查询结果：');
    console.table(res.rows);

  } catch (err) {
    console.error('查询失败:', err.message);
  } finally {
    await client.end();
  }
}

check();