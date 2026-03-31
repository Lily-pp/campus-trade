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

// ── GET /api/orders  订单列表（分页 + 状态筛选）──
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

// ── GET /api/orders/:id  订单详情 ──
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

// ── PUT /api/orders/:id/status  修改订单状态 ──
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

module.exports = router;
