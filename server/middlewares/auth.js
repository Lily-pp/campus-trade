const { verifyToken } = require('../utils/jwt');
const db = require('../config/db');

const authenticate = async (req, res, next) => {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: '未登录' });
    }

    const token = authHeader.split(' ')[1];
    const decoded = verifyToken(token);

    if (!decoded) {
        return res.status(401).json({ error: '登录已过期' });
    }

    // 兼容历史 token（user_id）与当前 token（id）字段
    const normalizedId = decoded.id || decoded.user_id;
    if (!normalizedId) {
        return res.status(401).json({ error: '登录状态无效，请重新登录' });
    }

    try {
        const result = await db.query('SELECT id, status FROM users WHERE id = $1', [normalizedId]);
        if (result.rows.length === 0) {
            return res.status(401).json({ error: '账号不存在，请重新登录' });
        }
        if (result.rows[0].status === 0) {
            return res.status(403).json({ error: '账号已被禁用' });
        }
    } catch (err) {
        console.error('[auth] DB check failed:', err.message);
        return res.status(500).json({ error: '服务器错误' });
    }

    req.user = { ...decoded, id: normalizedId };
    next();
};

module.exports = { authenticate };