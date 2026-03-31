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

// ── GET /api/reports  举报列表（分页 + 状态筛选）──
router.get('/', authenticate, adminOnly, async (req, res) => {
    try {
        const { page = 1, pageSize = 15, status } = req.query;
        const offset = (parseInt(page) - 1) * parseInt(pageSize);
        const params = [];
        let where = '';

        if (status) {
            params.push(status);
            where = `WHERE r.status = $1`;
        }

        const countResult = await db.query(
            `SELECT COUNT(*) FROM reports r ${where}`,
            params
        );
        const total = parseInt(countResult.rows[0].count);

        params.push(parseInt(pageSize));
        params.push(offset);
        const listResult = await db.query(
            `SELECT r.id, r.target_type, r.target_id, r.reason, r.status,
                    r.created_at, r.handled_at,
                    u.username AS reporter_name,
                    h.username AS handler_name
             FROM reports r
             JOIN users u ON r.reporter_id = u.id
             LEFT JOIN users h ON r.handled_by = h.id
             ${where}
             ORDER BY r.created_at DESC
             LIMIT $${params.length - 1} OFFSET $${params.length}`,
            params
        );

        res.json({ code: 0, message: 'success', data: { total, page: parseInt(page), list: listResult.rows } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

// ── PUT /api/reports/:id/handle  处理举报 ──
// action: 'ignore' | 'takedown'（下架商品）| 'freeze'（冻结用户）
router.put('/:id/handle', authenticate, adminOnly, async (req, res) => {
    try {
        const { id } = req.params;
        const { action } = req.body;

        const allowed = ['ignore', 'takedown', 'freeze'];
        if (!allowed.includes(action)) {
            return res.status(400).json({ code: 1, message: '无效操作', data: null });
        }

        // 查举报详情
        const reportResult = await db.query('SELECT * FROM reports WHERE id = $1', [id]);
        if (reportResult.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '举报不存在', data: null });
        }

        const report = reportResult.rows[0];

        if (action === 'takedown' && report.target_type === 'item') {
            await db.query("UPDATE items SET status = 'off', updated_at = NOW() WHERE id = $1", [report.target_id]);
            await logAdmin(db, req.user.id, 'takedown_item', 'item', report.target_id, { via_report: parseInt(id) });
        }

        if (action === 'freeze' && report.target_type === 'user') {
            await db.query('UPDATE users SET status = 0 WHERE id = $1', [report.target_id]);
            await logAdmin(db, req.user.id, 'freeze_user', 'user', report.target_id, { via_report: parseInt(id) });
        }

        await db.query(
            "UPDATE reports SET status = 'processed', handled_by = $1, handled_at = NOW() WHERE id = $2",
            [req.user.id, id]
        );

        if (action === 'ignore') {
            await db.query(
                "UPDATE reports SET status = 'ignored', handled_by = $1, handled_at = NOW() WHERE id = $2",
                [req.user.id, id]
            );
            await logAdmin(db, req.user.id, 'ignore_report', 'report', parseInt(id), null);
        }

        res.json({ code: 0, message: '处理成功', data: null });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '处理失败', data: null });
    }
});

module.exports = router;
