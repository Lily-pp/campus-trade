const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticate } = require('../middlewares/auth');
const { logAdmin } = require('../utils/adminLog');

const adminOnly = (req, res, next) => {
    if (!['admin', 'operator'].includes(req.user.role)) {
        return res.status(403).json({ code: 1, message: '无权限', data: null });
    }
    next();
};

// ══════════════════════════════════════════
//  前台用户路由（必须在 /:id 之前注册）
// ══════════════════════════════════════════

// ── GET /api/orders/my  我的订单（买家）──
router.get('/my', authenticate, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT o.id, o.price, o.status, o.created_at,
                    i.id AS item_id, i.title AS item_title,
                    s.username AS seller_name, s.campus AS seller_campus,
                    (SELECT img.url FROM item_images img WHERE img.item_id = i.id ORDER BY img.sort_order LIMIT 1) AS cover_image
             FROM orders o
             JOIN items i ON o.item_id = i.id
             JOIN users s ON o.seller_id = s.id
             WHERE o.buyer_id = $1
             ORDER BY o.created_at DESC`,
            [req.user.id]
        );
        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

// ── GET /api/orders/sold  我卖出的（卖家）──
router.get('/sold', authenticate, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT o.id, o.price, o.status, o.created_at,
                    i.id AS item_id, i.title AS item_title,
                    b.username AS buyer_name, b.campus AS buyer_campus,
                    (SELECT img.url FROM item_images img WHERE img.item_id = i.id ORDER BY img.sort_order LIMIT 1) AS cover_image
             FROM orders o
             JOIN items i ON o.item_id = i.id
             JOIN users b ON o.buyer_id = b.id
             WHERE o.seller_id = $1
             ORDER BY o.created_at DESC`,
            [req.user.id]
        );
        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

// ── POST /api/orders/buy  直接购买单个商品 ──
router.post('/buy', authenticate, async (req, res) => {
    try {
        const { item_id } = req.body;
        if (!item_id) {
            return res.status(400).json({ code: 1, message: '缺少 item_id', data: null });
        }

        const itemResult = await db.query('SELECT id, user_id, price, status FROM items WHERE id = $1', [item_id]);
        if (itemResult.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '商品不存在', data: null });
        }

        const item = itemResult.rows[0];
        if (item.status !== 'on_sale') {
            return res.status(400).json({ code: 1, message: '该商品当前不可购买', data: null });
        }
        if (item.user_id === req.user.id) {
            return res.status(400).json({ code: 1, message: '不能购买自己的商品', data: null });
        }

        const orderResult = await db.query(
            `INSERT INTO orders (item_id, buyer_id, seller_id, price, status)
             VALUES ($1, $2, $3, $4, 'pending') RETURNING id`,
            [item_id, req.user.id, item.user_id, item.price]
        );

        res.json({ code: 0, message: '下单成功', data: { order_id: orderResult.rows[0].id } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '下单失败', data: null });
    }
});

// ══════════════════════════════════════════
//  后台管理路由
// ══════════════════════════════════════════

// ── GET /api/orders  [后台] 订单列表 ──
router.get('/', authenticate, adminOnly, async (req, res) => {
    try {
        const { page = 1, pageSize = 15, status, keyword } = req.query;
        const offset = (parseInt(page) - 1) * parseInt(pageSize);
        const params = [];
        const conditions = [];

        if (status) {
            params.push(status);
            conditions.push(`o.status = $${params.length}`);
        }
        if (keyword) {
            params.push(`%${keyword}%`);
            conditions.push(`i.title ILIKE $${params.length}`);
        }

        const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';

        const countResult = await db.query(
            `SELECT COUNT(*) FROM orders o JOIN items i ON o.item_id = i.id ${where}`,
            params
        );
        const total = parseInt(countResult.rows[0].count);

        params.push(parseInt(pageSize));
        params.push(offset);
        const listResult = await db.query(
            `SELECT o.id, o.price, o.status, o.remark, o.created_at, o.updated_at,
                    i.id AS item_id, i.title AS item_title,
                    b.id AS buyer_id, b.username AS buyer_name, b.campus AS buyer_campus,
                    s.id AS seller_id, s.username AS seller_name
             FROM orders o
             JOIN items i ON o.item_id = i.id
             JOIN users b ON o.buyer_id = b.id
             JOIN users s ON o.seller_id = s.id
             ${where}
             ORDER BY o.created_at DESC
             LIMIT $${params.length - 1} OFFSET $${params.length}`,
            params
        );

        res.json({ code: 0, message: 'success', data: { total, page: parseInt(page), list: listResult.rows } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

// ── PUT /api/orders/:id/status  [后台] 修改订单状态 ──
router.put('/:id/status', authenticate, adminOnly, async (req, res) => {
    try {
        const { id } = req.params;
        const { status } = req.body;

        const allowed = ['pending', 'completed', 'cancelled'];
        if (!allowed.includes(status)) {
            return res.status(400).json({ code: 1, message: '无效状态值', data: null });
        }

        const result = await db.query(
            'UPDATE orders SET status = $1, updated_at = NOW() WHERE id = $2 RETURNING id',
            [status, id]
        );

        if (result.rowCount === 0) {
            return res.status(404).json({ code: 1, message: '订单不存在', data: null });
        }

        await logAdmin(db, req.user.id, 'update_order_status', 'order', parseInt(id), { status });
        res.json({ code: 0, message: '状态已更新', data: null });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '更新失败', data: null });
    }
});

// ── PUT /api/orders/:id/confirm  确认收货（买家）──
router.put('/:id/confirm', authenticate, async (req, res) => {
    try {
        const { id } = req.params;
        const orderResult = await db.query('SELECT buyer_id, status, item_id FROM orders WHERE id = $1', [id]);

        if (orderResult.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '订单不存在', data: null });
        }
        if (orderResult.rows[0].buyer_id !== req.user.id) {
            return res.status(403).json({ code: 1, message: '无权操作', data: null });
        }
        if (orderResult.rows[0].status !== 'pending') {
            return res.status(400).json({ code: 1, message: '订单状态不允许确认', data: null });
        }

        await db.query("UPDATE orders SET status = 'completed', updated_at = NOW() WHERE id = $1", [id]);
        await db.query("UPDATE items SET status = 'sold', updated_at = NOW() WHERE id = $1", [orderResult.rows[0].item_id]);

        res.json({ code: 0, message: '确认收货成功', data: null });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '操作失败', data: null });
    }
});

// ── PUT /api/orders/:id/cancel  取消订单（买家）──
router.put('/:id/cancel', authenticate, async (req, res) => {
    try {
        const { id } = req.params;
        const orderResult = await db.query('SELECT buyer_id, status, item_id FROM orders WHERE id = $1', [id]);

        if (orderResult.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '订单不存在', data: null });
        }
        if (orderResult.rows[0].buyer_id !== req.user.id) {
            return res.status(403).json({ code: 1, message: '无权操作', data: null });
        }
        if (orderResult.rows[0].status !== 'pending') {
            return res.status(400).json({ code: 1, message: '订单状态不允许取消', data: null });
        }

        await db.query("UPDATE orders SET status = 'cancelled', updated_at = NOW() WHERE id = $1", [id]);
        await db.query("UPDATE items SET status = 'on_sale', updated_at = NOW() WHERE id = $1", [orderResult.rows[0].item_id]);

        res.json({ code: 0, message: '订单已取消', data: null });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '操作失败', data: null });
    }
});

// ── GET /api/orders/:id  [后台] 订单详情（必须放最后）──
router.get('/:id', authenticate, adminOnly, async (req, res) => {
    try {
        const { id } = req.params;
        const result = await db.query(
            `SELECT o.*,
                    i.title AS item_title, i.description AS item_description,
                    b.username AS buyer_name, b.campus AS buyer_campus,
                    s.username AS seller_name, s.campus AS seller_campus
             FROM orders o
             JOIN items i ON o.item_id = i.id
             JOIN users b ON o.buyer_id = b.id
             JOIN users s ON o.seller_id = s.id
             WHERE o.id = $1`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '订单不存在', data: null });
        }

        res.json({ code: 0, message: 'success', data: result.rows[0] });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

module.exports = router;
