const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticate } = require('../middlewares/auth');

// POST /api/favorites 添加收藏
router.post('/', authenticate, async (req, res) => {
    const client = await db.connect();

    try {
        const { item_id } = req.body;

        if (!item_id) {
            return res.status(400).json({ code: 1, message: '缺少 item_id', data: null });
        }

        const itemExists = await client.query('SELECT id FROM items WHERE id = $1', [item_id]);
        if (itemExists.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '商品不存在', data: null });
        }

        await client.query('BEGIN');

        // OpenGauss 对 ON CONFLICT 支持不稳定，这里改为兼容写法。
        const insertResult = await client.query(
            `INSERT INTO favorites (user_id, item_id)
             SELECT $1, $2
             WHERE NOT EXISTS (
                 SELECT 1 FROM favorites WHERE user_id = $1 AND item_id = $2
             )`,
            [req.user.id, item_id]
        );

        if (insertResult.rowCount > 0) {
            await client.query(
                'UPDATE items SET favorites_count = favorites_count + 1 WHERE id = $1',
                [item_id]
            );
        }

        await client.query('COMMIT');

        res.json({
            code: 0,
            message: insertResult.rowCount > 0 ? '收藏成功' : '该商品已收藏',
            data: null
        });
    } catch (error) {
        try {
            await client.query('ROLLBACK');
        } catch (_) {
            // Ignore rollback failures and return the original error.
        }
        console.error(error);
        res.status(500).json({ code: 1, message: '收藏失败', data: null });
    } finally {
        client.release();
    }
});

// DELETE /api/favorites/:item_id 取消收藏
router.delete('/:item_id', authenticate, async (req, res) => {
    try {
        const { item_id } = req.params;

        const result = await db.query(
            'DELETE FROM favorites WHERE user_id = $1 AND item_id = $2',
            [req.user.id, item_id]
        );

        if (result.rowCount === 0) {
            return res.status(404).json({ code: 1, message: '未收藏该商品', data: null });
        }

        await db.query(
            'UPDATE items SET favorites_count = GREATEST(favorites_count - 1, 0) WHERE id = $1',
            [item_id]
        );

        res.json({ code: 0, message: '已取消收藏', data: null });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '取消收藏失败', data: null });
    }
});

// GET /api/favorites/check/:item_id 检查是否已收藏
router.get('/check/:item_id', authenticate, async (req, res) => {
    try {
        const { item_id } = req.params;
        const result = await db.query(
            'SELECT 1 FROM favorites WHERE user_id = $1 AND item_id = $2',
            [req.user.id, item_id]
        );

        res.json({ code: 0, message: 'success', data: { favorited: result.rows.length > 0 } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

// GET /api/favorites 我的收藏列表
router.get('/', authenticate, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT i.id, i.title, i.price, i.status, i.created_at,
                    c.name AS category_name,
                    u.username AS seller_name, u.campus AS seller_campus,
                    f.created_at AS favorited_at
             FROM favorites f
             JOIN items i ON f.item_id = i.id
             LEFT JOIN categories c ON i.category_id = c.id
             LEFT JOIN users u ON i.user_id = u.id
             WHERE f.user_id = $1
             ORDER BY f.created_at DESC`,
            [req.user.id]
        );

        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

module.exports = router;
