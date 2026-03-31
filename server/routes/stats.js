const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticate } = require('../middlewares/auth');

// GET /api/stats  后台数据统计（需登录）
router.get('/', authenticate, async (req, res) => {
    try {
        const [usersResult, itemsResult, categoriesResult, recentResult] = await Promise.all([
            db.query("SELECT COUNT(*) AS count FROM users WHERE role = 'user'"),
            db.query("SELECT status, COUNT(*) AS count FROM items GROUP BY status"),
            db.query("SELECT COUNT(*) AS count FROM categories"),
            db.query(`
                SELECT i.id, i.title, i.price, i.status, i.created_at,
                       u.username AS seller_name
                FROM items i
                LEFT JOIN users u ON i.user_id = u.id
                ORDER BY i.created_at DESC
                LIMIT 6
            `)
        ]);

        const itemsByStatus = {};
        itemsResult.rows.forEach(row => {
            itemsByStatus[row.status] = parseInt(row.count);
        });
        const totalItems = Object.values(itemsByStatus).reduce((a, b) => a + b, 0);

        res.json({
            code: 0,
            message: 'success',
            data: {
                users: parseInt(usersResult.rows[0].count),
                total_items: totalItems,
                on_sale: itemsByStatus['on_sale'] || 0,
                sold: itemsByStatus['sold'] || 0,
                categories: parseInt(categoriesResult.rows[0].count),
                recent_items: recentResult.rows
            }
        });
    } catch (error) {
        console.error('stats error:', error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

module.exports = router;
