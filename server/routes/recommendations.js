const express = require('express');
const router = express.Router();
const db = require('../config/db');

const COVER_SQL = `(SELECT image_url FROM item_images WHERE item_id = i.id ORDER BY sort_order LIMIT 1) AS cover_image`;

// GET /api/recommendations/trending - 热门商品（浏览量前6）
router.get('/trending', async (req, res) => {
  try {
    const result = await db.query(
      `SELECT i.id, i.title, i.price, i.views_count, i.favorites_count,
              c.name AS category_name,
              u.username AS seller_name, u.campus AS seller_campus,
              ${COVER_SQL}
       FROM items i
       LEFT JOIN categories c ON i.category_id = c.id
       LEFT JOIN users u ON i.user_id = u.id
       WHERE i.status = 'on_sale' AND i.is_approved = TRUE
         AND i.created_at >= NOW() - INTERVAL '30 days'
       ORDER BY i.views_count DESC
       LIMIT 4`
    );
    res.json({ code: 0, message: 'success', data: result.rows });
  } catch (e) {
    console.error(e);
    res.status(500).json({ code: 1, message: '查询失败', data: null });
  }
});

// GET /api/recommendations/similar/:itemId - 相关推荐（同分类相近价格）
router.get('/similar/:itemId', async (req, res) => {
  try {
    const { itemId } = req.params;

    const itemRes = await db.query(
      `SELECT category_id, price FROM items WHERE id = $1`,
      [itemId]
    );
    if (itemRes.rows.length === 0) {
      return res.json({ code: 0, message: 'success', data: [] });
    }

    const { category_id, price } = itemRes.rows[0];

    const result = await db.query(
      `SELECT i.id, i.title, i.price, i.views_count,
              c.name AS category_name,
              u.username AS seller_name,
              ${COVER_SQL}
       FROM items i
       LEFT JOIN categories c ON i.category_id = c.id
       LEFT JOIN users u ON i.user_id = u.id
       WHERE i.status = 'on_sale'
         AND i.is_approved = TRUE
         AND i.id != $1
         AND i.category_id = $2
         AND i.price BETWEEN $3 * 0.5 AND $3 * 2.0
       ORDER BY i.views_count DESC
       LIMIT 4`,
      [itemId, category_id, price]
    );
    res.json({ code: 0, message: 'success', data: result.rows });
  } catch (e) {
    console.error(e);
    res.status(500).json({ code: 1, message: '查询失败', data: null });
  }
});

module.exports = router;
