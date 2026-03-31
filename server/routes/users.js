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

// GET /api/users  用户列表
router.get('/', authenticate, adminOnly, async (req, res) => {
    try {
        const { page = 1, pageSize = 20, keyword } = req.query;
        const offset = (parseInt(page) - 1) * parseInt(pageSize);
        const params = [];
        let where = '';

        if (keyword) {
            params.push(`%${keyword}%`);
            where = `WHERE (username ILIKE $1 OR real_name ILIKE $1)`;
        }

        const countResult = await db.query(`SELECT COUNT(*) AS count FROM users ${where}`, params);
        const total = parseInt(countResult.rows[0].count);

        params.push(parseInt(pageSize));
        params.push(offset);
        const listResult = await db.query(
            `SELECT id, username, real_name, role, campus, status, created_at
             FROM users ${where}
             ORDER BY created_at DESC
             LIMIT $${params.length - 1} OFFSET $${params.length}`,
            params
        );

        res.json({ code: 0, message: 'success', data: { total, list: listResult.rows } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

// POST /api/users  新增用户（管理员手动添加）
router.post('/', authenticate, adminOnly, async (req, res) => {
    try {
        const { username, password, real_name, role = 'user', campus } = req.body;

        if (!username || !password) {
            return res.status(400).json({ code: 1, message: '用户名和密码不能为空', data: null });
        }

        const exists = await db.query('SELECT id FROM users WHERE username = $1', [username]);
        if (exists.rows.length > 0) {
            return res.status(409).json({ code: 1, message: '用户名已存在', data: null });
        }

        const result = await db.query(
            'INSERT INTO users (username, password, real_name, role, campus) VALUES ($1, $2, $3, $4, $5) RETURNING id',
            [username, password, real_name || null, role, campus || null]
        );

        res.status(201).json({ code: 0, message: '创建成功', data: { id: result.rows[0].id } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '创建失败', data: null });
    }
});

// PUT /api/users/:id/status  启用 / 禁用
router.put('/:id/status', authenticate, adminOnly, async (req, res) => {
    try {
        const { id } = req.params;
        const { status } = req.body;

        if (![0, 1].includes(Number(status))) {
            return res.status(400).json({ code: 1, message: '无效状态值', data: null });
        }
        if (parseInt(id) === req.user.id) {
            return res.status(400).json({ code: 1, message: '不能修改自己的状态', data: null });
        }

        const result = await db.query('UPDATE users SET status = $1 WHERE id = $2', [Number(status), id]);
        if (result.rowCount === 0) {
            return res.status(404).json({ code: 1, message: '用户不存在', data: null });
        }

        res.json({ code: 0, message: Number(status) === 1 ? '已启用' : '已禁用', data: null });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '操作失败', data: null });
    }
});

// DELETE /api/users/:id  删除用户
router.delete('/:id', authenticate, adminOnly, async (req, res) => {
    try {
        const { id } = req.params;

        if (parseInt(id) === req.user.id) {
            return res.status(400).json({ code: 1, message: '不能删除自己', data: null });
        }

        const result = await db.query('DELETE FROM users WHERE id = $1', [id]);
        if (result.rowCount === 0) {
            return res.status(404).json({ code: 1, message: '用户不存在', data: null });
        }

        res.json({ code: 0, message: '删除成功', data: null });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '删除失败', data: null });
    }
});

module.exports = router;
