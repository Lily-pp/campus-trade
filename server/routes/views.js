const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticate } = require('../middlewares/auth');

// ── POST /api/views  写入浏览记录 ──
router.post('/', async (req, res) => {
    try {
        const { item_id } = req.body;

        if (!item_id) {
            return res.status(400).json({ code: 1, message: '缺少 item_id', data: null });
        }

        // 获取登录用户 id（未登录则 null）
        let userId = null;
        const authHeader = req.headers.authorization;
        if (authHeader && authHeader.startsWith('Bearer ')) {
            const { verifyToken } = require('../utils/jwt');
            const decoded = verifyToken(authHeader.split(' ')[1]);
            if (decoded) userId = decoded.id;
        }

        await db.query(
            'INSERT INTO views_log (user_id, item_id) VALUES ($1, $2)',
            [userId, item_id]
        );

        res.json({ code: 0, message: 'success', data: null });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '记录失败', data: null });
    }
});

// ── GET /api/views  我的浏览历史（需登录）──
router.get('/', authenticate, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT DISTINCT ON (vl.item_id)
                    i.id, i.title, i.price, i.status,
                    c.name AS category_name,
                    vl.viewed_at
             FROM views_log vl
             JOIN items i ON vl.item_id = i.id
             LEFT JOIN categories c ON i.category_id = c.id
             WHERE vl.user_id = $1
             ORDER BY vl.item_id, vl.viewed_at DESC`,
            [req.user.id]
        );

        // 按最近浏览时间排序
        const sorted = result.rows.sort((a, b) => new Date(b.viewed_at) - new Date(a.viewed_at));

        res.json({ code: 0, message: 'success', data: sorted });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

module.exports = router;
