const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticate } = require('../middlewares/auth');

// GET /api/reviews/item/:itemId - 商品评价列表
router.get('/item/:itemId', async (req, res) => {
  try {
    const { itemId } = req.params;
    const result = await db.query(
      `SELECT r.id, r.reviewer_id, r.rating, r.content, r.created_at,
              u.username AS reviewer_name
       FROM reviews r
       JOIN users u ON r.reviewer_id = u.id
       WHERE r.item_id = $1
       ORDER BY r.created_at DESC
       LIMIT 50`,
      [itemId]
    );
    res.json({ code: 0, message: 'success', data: result.rows });
  } catch (e) {
    console.error(e);
    res.status(500).json({ code: 1, message: '查询失败', data: null });
  }
});

// GET /api/reviews/can-review/:itemId - 检查当前用户是否可以评价
router.get('/can-review/:itemId', authenticate, async (req, res) => {
  try {
    const { itemId } = req.params;
    const userId = req.user.id;

    const orderRes = await db.query(
      `SELECT id FROM orders WHERE item_id = $1 AND buyer_id = $2 LIMIT 1`,
      [itemId, userId]
    );
    if (orderRes.rows.length === 0) {
      return res.json({ code: 0, message: 'success', data: { canReview: false, reason: 'no_order' } });
    }

    const orderId = orderRes.rows[0].id;
    const reviewRes = await db.query(
      `SELECT id FROM reviews WHERE order_id = $1 AND reviewer_id = $2`,
      [orderId, userId]
    );
    if (reviewRes.rows.length > 0) {
      return res.json({ code: 0, message: 'success', data: { canReview: false, reason: 'already_reviewed' } });
    }

    res.json({ code: 0, message: 'success', data: { canReview: true, orderId } });
  } catch (e) {
    console.error(e);
    res.status(500).json({ code: 1, message: '查询失败', data: null });
  }
});

// POST /api/reviews - 提交评价

router.post('/', authenticate, async (req, res) => {
    const { item_id, order_id, rating, content } = req.body;
    const reviewer_id = req.user.id;

    try {
        await db.query(
            `INSERT INTO reviews (item_id, order_id, reviewer_id, rating, content)
             VALUES ($1, $2, $3, $4, $5)`,
            [item_id, order_id, reviewer_id, rating, content]
        );

        // 注意：不再需要手动更新 items 表的 review_count 和 avg_rating
        // Trigger 会自动处理！

        res.json({ code: 0, message: '评价成功' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ code: 1, message: '评价失败' });
    }
});

// DELETE /api/reviews/:id - 删除自己的评价
router.delete('/:id', authenticate, async (req, res) => {
  const client = await db.connect();
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const review = await client.query(
      `SELECT item_id FROM reviews WHERE id = $1 AND reviewer_id = $2`,
      [id, userId]
    );
    if (review.rows.length === 0) {
      return res.status(404).json({ code: 1, message: '评价不存在', data: null });
    }
    const itemId = review.rows[0].item_id;

    await client.query('BEGIN');
    await client.query(`DELETE FROM reviews WHERE id = $1`, [id]);
    await client.query(
      `UPDATE items SET
         review_count = (SELECT COUNT(*) FROM reviews WHERE item_id = $1),
         avg_rating   = (SELECT ROUND(AVG(rating)::numeric, 1) FROM reviews WHERE item_id = $1)
       WHERE id = $1`,
      [itemId]
    );
    await client.query('COMMIT');
    res.json({ code: 0, message: '已删除评价', data: null });
  } catch (e) {
    try { await client.query('ROLLBACK'); } catch (_) {}
    console.error(e);
    res.status(500).json({ code: 1, message: '删除失败', data: null });
  } finally {
    client.release();
  }
});

module.exports = router;
