const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticate } = require('../middlewares/auth');

// ── GET /api/cart  获取我的购物车 ──
router.get('/', authenticate, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT c.id AS cart_id, c.created_at AS added_at,
                    i.id, i.title, i.price, i.status,
                    i.user_id AS seller_id,
                    u.username AS seller_name, u.campus AS seller_campus,
                    cat.name AS category_name,
                    (SELECT img.url FROM item_images img WHERE img.item_id = i.id ORDER BY img.sort_order LIMIT 1) AS cover_image
             FROM cart c
             JOIN items i ON c.item_id = i.id
             LEFT JOIN users u ON i.user_id = u.id
             LEFT JOIN categories cat ON i.category_id = cat.id
             WHERE c.user_id = $1
             ORDER BY c.created_at DESC`,
            [req.user.id]
        );
        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

// ── POST /api/cart  加入购物车 ──
router.post('/', authenticate, async (req, res) => {
    try {
        const { item_id } = req.body;
        if (!item_id) {
            return res.status(400).json({ code: 1, message: '缺少 item_id', data: null });
        }

        // 不能加入自己发布的商品
        const itemResult = await db.query('SELECT id, user_id, status FROM items WHERE id = $1', [item_id]);
        if (itemResult.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '商品不存在', data: null });
        }
        if (itemResult.rows[0].user_id === req.user.id) {
            return res.status(400).json({ code: 1, message: '不能购买自己的商品', data: null });
        }
        if (itemResult.rows[0].status !== 'on_sale') {
            return res.status(400).json({ code: 1, message: '该商品当前不可购买', data: null });
        }

        await db.query(
            'INSERT INTO cart (user_id, item_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
            [req.user.id, item_id]
        );

        res.json({ code: 0, message: '已加入购物车', data: null });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '操作失败', data: null });
    }
});

// ── DELETE /api/cart/:item_id  从购物车移除 ──
router.delete('/:item_id', authenticate, async (req, res) => {
    try {
        await db.query(
            'DELETE FROM cart WHERE user_id = $1 AND item_id = $2',
            [req.user.id, req.params.item_id]
        );
        res.json({ code: 0, message: '已从购物车移除', data: null });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '操作失败', data: null });
    }
});

// ── POST /api/cart/checkout  购物车下单（批量） ──
router.post('/checkout', authenticate, async (req, res) => {
    try {
        const { item_ids } = req.body; // [1, 2, 3]
        if (!item_ids || item_ids.length === 0) {
            return res.status(400).json({ code: 1, message: '请选择要购买的商品', data: null });
        }

        const orderIds = [];

        for (const item_id of item_ids) {
            const itemResult = await db.query(
                'SELECT id, user_id, price, status FROM items WHERE id = $1',
                [item_id]
            );

            if (itemResult.rows.length === 0) continue;

            const item = itemResult.rows[0];
            if (item.status !== 'on_sale') continue;
            if (item.user_id === req.user.id) continue;

            // 创建订单
            const orderResult = await db.query(
                `INSERT INTO orders (item_id, buyer_id, seller_id, price, status)
                 VALUES ($1, $2, $3, $4, 'pending') RETURNING id`,
                [item_id, req.user.id, item.user_id, item.price]
            );
            orderIds.push(orderResult.rows[0].id);

            // 从购物车移除
            await db.query(
                'DELETE FROM cart WHERE user_id = $1 AND item_id = $2',
                [req.user.id, item_id]
            );
        }

        res.json({ code: 0, message: `成功下单 ${orderIds.length} 件商品`, data: { order_ids: orderIds } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '下单失败', data: null });
    }
});

module.exports = router;
