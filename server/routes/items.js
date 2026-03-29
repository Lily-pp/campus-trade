const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticate } = require('../middlewares/auth');

router.get('/', async (req, res) => {
    try {
        const result = await db.query(`
            SELECT i.*, c.name as category_name 
            FROM items i
            LEFT JOIN categories c ON i.category_id = c.id
            ORDER BY i.created_at DESC
        `);
        
        res.json({
            total: result.rows.length,
            data: result.rows
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: '查询失败' });
    }
});

router.post('/', authenticate, async (req, res) => {
    try {
        const { title, description, price, category_id } = req.body;
        
        const result = await db.query(`
            INSERT INTO items 
            (title, description, price, category_id, user_id, status) 
            VALUES ($1, $2, $3, $4, $5, 'pending')
            RETURNING id
        `, [title, description, price, category_id, req.user.id]);
        
        res.status(201).json({
            message: '创建成功',
            id: result.rows[0].id
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: '创建失败' });
    }
});

router.delete('/:id', authenticate, async (req, res) => {
    try {
        const itemId = req.params.id;
        const userId = req.user.id;
        const userRole = req.user.role;

        console.log('DELETE 请求:', { itemId, userId, userRole });

        // 检查商品是否存在
        const itemResult = await db.query('SELECT id, user_id FROM items WHERE id = $1', [itemId]);
        console.log('查询结果:', itemResult.rows);

        if (itemResult.rows.length === 0) {
            console.log('商品不存在，返回 404');
            return res.status(404).json({ error: '商品不存在' });
        }

        const item = itemResult.rows[0];

        // 普通用户只能删除自己的商品，管理员可以删除任意商品
        if (userRole !== 'admin' && item.user_id !== userId) {
            console.log('无权限删除，返回 403');
            return res.status(403).json({ error: '无权限删除该商品' });
        }

        console.log('开始删除商品');
        await db.query('DELETE FROM items WHERE id = $1', [itemId]);
        console.log('删除成功');
        res.json({ message: '删除成功' });
    } catch (error) {
        console.error('删除失败:', error);
        res.status(500).json({ error: '删除失败' });
    }
});

module.exports = router;