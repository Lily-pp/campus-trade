const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticate } = require('../middlewares/auth');

// ── GET /api/vouchers  我的代金券列表 ──
router.get('/', authenticate, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT v.*, a.name AS activity_name, a.type AS activity_type
             FROM vouchers v
             LEFT JOIN activities a ON v.activity_id = a.id
             WHERE v.user_id = $1
             ORDER BY v.obtained_at DESC`,
            [req.user.id]
        );
        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (error) {
        console.error('获取代金券列表失败:', error);
        res.status(500).json({ code: 1, message: '获取代金券列表失败', data: null });
    }
});

// ── GET /api/vouchers/usable  获取可用代金券（下单时选择）──
router.get('/usable', authenticate, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT v.*, a.name AS activity_name
             FROM vouchers v
             LEFT JOIN activities a ON v.activity_id = a.id
             WHERE v.user_id = $1
               AND v.status = 'unused'
               AND v.expires_at > NOW()
             ORDER BY v.amount DESC`,
            [req.user.id]
        );
        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (error) {
        console.error('获取可用代金券失败:', error);
        res.status(500).json({ code: 1, message: '获取可用代金券失败', data: null });
    }
});

// ── POST /api/vouchers/lottery/:orderId  订单完成抽奖 ──
router.post('/lottery/:orderId', authenticate, async (req, res) => {
    try {
        const { orderId } = req.params;

        // 1. 验证订单属于当前用户
        const orderResult = await db.query(
            `SELECT o.id, o.item_id, o.price, o.status, o.buyer_id,
                    i.activity_id, i.title AS item_title
             FROM orders o
             JOIN items i ON o.item_id = i.id
             WHERE o.id = $1 AND o.buyer_id = $2`,
            [orderId, req.user.id]
        );

        if (orderResult.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '订单不存在', data: null });
        }

        const order = orderResult.rows[0];

        // 2. 检查订单已完成
        if (order.status !== 'completed') {
            return res.status(400).json({ code: 1, message: '订单未完成，无法抽奖', data: null });
        }

        // 3. 检查是否已抽过奖
        const existingVoucher = await db.query(
            'SELECT id FROM vouchers WHERE order_id = $1 AND user_id = $2',
            [orderId, req.user.id]
        );
        if (existingVoucher.rows.length > 0) {
            return res.status(400).json({ code: 1, message: '该订单已抽过奖', data: null });
        }

        // 4. 检查商品是否属于补贴活动
        if (!order.activity_id) {
            return res.status(400).json({ code: 1, message: '该商品不属于官方补贴活动，无法抽奖', data: null });
        }

        const activityResult = await db.query(
            `SELECT id, name, type, subsidy_enabled, voucher_min_rate, voucher_max_rate
             FROM activities WHERE id = $1`,
            [order.activity_id]
        );

        if (activityResult.rows.length === 0 || !activityResult.rows[0].subsidy_enabled) {
            return res.status(400).json({ code: 1, message: '该活动不是官方补贴活动', data: null });
        }

        const activity = activityResult.rows[0];

        // 5. 随机计算代金券金额（5%~10% of order price）
        const minRate = parseFloat(activity.voucher_min_rate) || 0.05;
        const maxRate = parseFloat(activity.voucher_max_rate) || 0.10;
        const randomRate = minRate + Math.random() * (maxRate - minRate);
        const voucherAmount = Math.round(parseFloat(order.price) * randomRate * 100) / 100;

        // 6. 创建代金券（30天有效期）
        const expiresAt = new Date();
        expiresAt.setDate(expiresAt.getDate() + 30);

        const voucherResult = await db.query(
            `INSERT INTO vouchers (user_id, activity_id, order_id, amount, status, expires_at)
             VALUES ($1, $2, $3, $4, 'unused', $5)
             RETURNING *`,
            [req.user.id, activity.id, parseInt(orderId), voucherAmount, expiresAt]
        );

        const voucher = voucherResult.rows[0];

        res.json({
            code: 0,
            message: '抽奖成功',
            data: {
                voucher: {
                    ...voucher,
                    activity_name: activity.name,
                    activity_type: activity.type
                },
                random_rate: Math.round(randomRate * 10000) / 100 + '%',
                order_price: parseFloat(order.price)
            }
        });
    } catch (error) {
        console.error('抽奖失败:', error);
        res.status(500).json({ code: 1, message: '抽奖失败', data: null });
    }
});

// ── PUT /api/vouchers/:id/use  使用代金券（下单时）──
router.put('/:id/use', authenticate, async (req, res) => {
    try {
        const { id } = req.params;
        const { order_id } = req.body;

        // 验证代金券属于当前用户且可用
        const voucherResult = await db.query(
            `SELECT * FROM vouchers WHERE id = $1 AND user_id = $2`,
            [id, req.user.id]
        );

        if (voucherResult.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '代金券不存在', data: null });
        }

        const voucher = voucherResult.rows[0];
        if (voucher.status !== 'unused') {
            return res.status(400).json({ code: 1, message: '代金券已使用或已过期', data: null });
        }
        if (new Date(voucher.expires_at) < new Date()) {
            // 自动标记过期
            await db.query("UPDATE vouchers SET status = 'expired' WHERE id = $1", [id]);
            return res.status(400).json({ code: 1, message: '代金券已过期', data: null });
        }

        // 标记使用
        await db.query(
            `UPDATE vouchers SET status = 'used', used_at = NOW(), used_order_id = $2 WHERE id = $1`,
            [id, order_id || null]
        );

        res.json({ code: 0, message: '代金券已使用', data: { amount: voucher.amount } });
    } catch (error) {
        console.error('使用代金券失败:', error);
        res.status(500).json({ code: 1, message: '使用代金券失败', data: null });
    }
});

module.exports = router;
