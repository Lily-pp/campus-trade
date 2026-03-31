const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { generateToken } = require('../utils/jwt');
const { authenticate } = require('../middlewares/auth');

// ── 后台管理员登录 ──────────────────────────────────────────
// POST /api/auth/admin/login
router.post('/admin/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        const result = await db.query(
            "SELECT * FROM users WHERE username = $1 AND role IN ('admin', 'operator')",
            [username]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({ code: 1, message: '用户名或密码错误', data: null });
        }

        const user = result.rows[0];

        if (user.status === 0) {
            return res.status(403).json({ code: 1, message: '账号已被禁用', data: null });
        }

        if (password !== user.password) {
            return res.status(401).json({ code: 1, message: '用户名或密码错误', data: null });
        }

        const token = generateToken(user);
        const { password: _, ...userInfo } = user;

        res.json({ code: 0, message: '登录成功', data: { token, user: userInfo } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '服务器错误', data: null });
    }
});

// ── 前台用户登录 ────────────────────────────────────────────
// POST /api/auth/login
router.post('/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        const result = await db.query(
            "SELECT * FROM users WHERE username = $1 AND role = 'user'",
            [username]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({ code: 1, message: '用户名或密码错误', data: null });
        }

        const user = result.rows[0];

        if (user.status === 0) {
            return res.status(403).json({ code: 1, message: '账号已被禁用', data: null });
        }

        if (password !== user.password) {
            return res.status(401).json({ code: 1, message: '用户名或密码错误', data: null });
        }

        const token = generateToken(user);
        const { password: _, ...userInfo } = user;

        res.json({ code: 0, message: '登录成功', data: { token, user: userInfo } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '服务器错误', data: null });
    }
});

// ── 前台用户注册 ────────────────────────────────────────────
// POST /api/auth/register
router.post('/register', async (req, res) => {
    try {
        const { username, password, real_name, campus } = req.body;

        if (!username || !password) {
            return res.status(400).json({ code: 1, message: '用户名和密码不能为空', data: null });
        }

        if (username.length < 3 || username.length > 20) {
            return res.status(400).json({ code: 1, message: '用户名长度需在 3-20 个字符之间', data: null });
        }

        // 检查用户名是否已存在
        const exists = await db.query('SELECT id FROM users WHERE username = $1', [username]);
        if (exists.rows.length > 0) {
            return res.status(409).json({ code: 1, message: '用户名已被占用', data: null });
        }

        const result = await db.query(
            "INSERT INTO users (username, password, real_name, campus, role) VALUES ($1, $2, $3, $4, 'user') RETURNING id, username, real_name, campus, role, created_at",
            [username, password, real_name || null, campus || null]
        );

        const newUser = result.rows[0];
        const token = generateToken(newUser);

        res.status(201).json({ code: 0, message: '注册成功', data: { token, user: newUser } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '服务器错误', data: null });
    }
});

// ── 获取当前登录用户信息 ────────────────────────────────────
// GET /api/auth/me
router.get('/me', authenticate, async (req, res) => {
    try {
        const result = await db.query(
            'SELECT id, username, real_name, role, campus, avatar, status, created_at FROM users WHERE id = $1',
            [req.user.id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '用户不存在', data: null });
        }

        res.json({ code: 0, message: 'success', data: result.rows[0] });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '服务器错误', data: null });
    }
});

module.exports = router;