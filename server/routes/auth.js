const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { generateToken } = require('../utils/jwt');

router.post('/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        
        const result = await db.query(
            'SELECT * FROM users WHERE username = $1',
            [username]
        );
        
        if (result.rows.length === 0) {
            return res.status(401).json({ error: '用户名或密码错误' });
        }
        
        const user = result.rows[0];
        
        if (password !== user.password) {
            return res.status(401).json({ error: '用户名或密码错误' });
        }
        
        const token = generateToken(user);
        
        const { password: _, ...userInfo } = user;
        
        res.json({
            message: '登录成功',
            token,
            user: userInfo
        });
        
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: '服务器错误' });
    }
});

module.exports = router;