const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticate } = require('../middlewares/auth');

// ── GET /api/messages/conversations  获取会话列表 ──
router.get('/conversations', authenticate, async (req, res) => {
    try {
        const userId = req.user.id;
        // 获取所有会话：按对方用户分组，取最新一条消息
        const result = await db.query(`
            SELECT DISTINCT ON (other_id) 
                other_id,
                u.username AS other_username,
                u.avatar AS other_avatar,
                m.content AS last_message,
                m.created_at AS last_time,
                unread_count
            FROM (
                SELECT 
                    CASE WHEN sender_id = $1 THEN receiver_id ELSE sender_id END AS other_id,
                    id, content, created_at
                FROM messages
                WHERE sender_id = $1 OR receiver_id = $1
                ORDER BY 
                    CASE WHEN sender_id = $1 THEN receiver_id ELSE sender_id END,
                    created_at DESC
            ) m
            LEFT JOIN users u ON u.id = m.other_id
            LEFT JOIN LATERAL (
                SELECT COUNT(*)::int AS unread_count
                FROM messages
                WHERE sender_id = m.other_id AND receiver_id = $1 AND is_read = false
            ) uc ON true
            ORDER BY other_id, m.created_at DESC
        `, [userId]);

        // 按最新消息时间排序
        const conversations = result.rows.sort((a, b) => 
            new Date(b.last_time) - new Date(a.last_time)
        );

        res.json({ code: 0, message: 'success', data: conversations });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '获取会话列表失败', data: null });
    }
});

// ── GET /api/messages/unread-count  获取未读消息总数 ──
router.get('/unread-count', authenticate, async (req, res) => {
    try {
        const result = await db.query(
            'SELECT COUNT(*)::int AS count FROM messages WHERE receiver_id = $1 AND is_read = false',
            [req.user.id]
        );
        res.json({ code: 0, message: 'success', data: { count: result.rows[0].count } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '获取未读数失败', data: null });
    }
});

// ── GET /api/messages/:userId  获取与某用户的聊天记录 ──
router.get('/:userId', authenticate, async (req, res) => {
    try {
        const myId = req.user.id;
        const otherId = parseInt(req.params.userId);

        // 获取聊天记录
        const result = await db.query(`
            SELECT m.*, 
                   s.username AS sender_username, s.avatar AS sender_avatar,
                   r.username AS receiver_username
            FROM messages m
            LEFT JOIN users AS s ON s.id = m.sender_id
            LEFT JOIN users AS r ON r.id = m.receiver_id
            WHERE (m.sender_id = $1 AND m.receiver_id = $2)
               OR (m.sender_id = $2 AND m.receiver_id = $1)
            ORDER BY m.created_at ASC
            LIMIT 200
        `, [myId, otherId]);

        // 将对方发给我的未读消息标为已读
        await db.query(
            'UPDATE messages SET is_read = true WHERE sender_id = $1 AND receiver_id = $2 AND is_read = false',
            [otherId, myId]
        );

        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '获取聊天记录失败', data: null });
    }
});

// ── POST /api/messages  发送消息 ──
router.post('/', authenticate, async (req, res) => {
    try {
        const senderId = req.user.id;
        const { receiver_id, content, item_id } = req.body;

        if (!receiver_id || !content || !content.trim()) {
            return res.status(400).json({ code: 1, message: '消息内容不能为空', data: null });
        }

        if (receiver_id === senderId) {
            return res.status(400).json({ code: 1, message: '不能给自己发消息', data: null });
        }

        // 检查接收者是否存在
        const userCheck = await db.query('SELECT id FROM users WHERE id = $1', [receiver_id]);
        if (userCheck.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '用户不存在', data: null });
        }

        const result = await db.query(
            `INSERT INTO messages (sender_id, receiver_id, content, item_id)
             VALUES ($1, $2, $3, $4) RETURNING *`,
            [senderId, receiver_id, content.trim(), item_id || null]
        );

        res.json({ code: 0, message: '发送成功', data: result.rows[0] });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '发送失败', data: null });
    }
});

// ── PUT /api/messages/read/:userId  标记与某用户的消息为已读 ──
router.put('/read/:userId', authenticate, async (req, res) => {
    try {
        const myId = req.user.id;
        const otherId = parseInt(req.params.userId);

        await db.query(
            'UPDATE messages SET is_read = true WHERE sender_id = $1 AND receiver_id = $2 AND is_read = false',
            [otherId, myId]
        );

        res.json({ code: 0, message: 'success', data: null });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '操作失败', data: null });
    }
});

module.exports = router;
