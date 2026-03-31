const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticate } = require('../middlewares/auth');

const adminOnly = (req, res, next) => {
    if (!['admin', 'operator'].includes(req.user.role)) {
        return res.status(403).json({ code: 1, message: '无权限', data: null });
    }
    next();
};

// ── GET /api/logs  管理员操作日志（分页 + 操作人 + 动作筛选）──
router.get('/', authenticate, adminOnly, async (req, res) => {
    try {
        const { page = 1, pageSize = 20, admin_id, action } = req.query;
        const offset = (parseInt(page) - 1) * parseInt(pageSize);
        const params = [];
        const conditions = [];

        if (admin_id) {
            params.push(parseInt(admin_id));
            conditions.push(`l.admin_id = $${params.length}`);
        }
        if (action) {
            params.push(`%${action}%`);
            conditions.push(`l.action ILIKE $${params.length}`);
        }

        const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';

        const countResult = await db.query(
            `SELECT COUNT(*) FROM admin_logs l ${where}`,
            params
        );
        const total = parseInt(countResult.rows[0].count);

        params.push(parseInt(pageSize));
        params.push(offset);
        const listResult = await db.query(
            `SELECT l.id, l.action, l.target_type, l.target_id, l.detail, l.created_at,
                    u.username AS admin_name, u.role AS admin_role
             FROM admin_logs l
             JOIN users u ON l.admin_id = u.id
             ${where}
             ORDER BY l.created_at DESC
             LIMIT $${params.length - 1} OFFSET $${params.length}`,
            params
        );

        res.json({ code: 0, message: 'success', data: { total, page: parseInt(page), list: listResult.rows } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

module.exports = router;
