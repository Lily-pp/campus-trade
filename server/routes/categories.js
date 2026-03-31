const express = require('express');
const router = express.Router();
const db = require('../config/db');

// 获取所有分类
router.get('/', async (req, res) => {
    try {
        const result = await db.query('SELECT * FROM categories ORDER BY parent_id, sort_order');
        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (error) {
        console.error('获取分类失败:', error);
        res.status(500).json({ code: 1, message: '获取分类失败', data: null });
    }
});

// 获取单个分类
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const result = await db.query('SELECT * FROM categories WHERE id = $1', [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '分类不存在', data: null });
        }

        res.json({ code: 0, message: 'success', data: result.rows[0] });
    } catch (error) {
        console.error('获取分类失败:', error);
        res.status(500).json({ code: 1, message: '获取分类失败', data: null });
    }
});

// 创建分类
router.post('/', async (req, res) => {
    try {
        const { name, parent_id = 0, sort_order = 0 } = req.body;

        if (!name) {
            return res.status(400).json({ code: 1, message: '分类名称不能为空', data: null });
        }

        const result = await db.query(
            'INSERT INTO categories (name, parent_id, sort_order) VALUES ($1, $2, $3) RETURNING id',
            [name, parent_id, sort_order]
        );

        res.status(201).json({ code: 0, message: '创建成功', data: { id: result.rows[0].id } });
    } catch (error) {
        console.error('创建分类失败:', error);
        res.status(500).json({ code: 1, message: '创建失败', data: null });
    }
});

// 更新分类
router.put('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const { name, parent_id, sort_order } = req.body;

        const result = await db.query(
            'UPDATE categories SET name = $1, parent_id = $2, sort_order = $3 WHERE id = $4',
            [name, parent_id, sort_order, id]
        );

        if (result.rowCount === 0) {
            return res.status(404).json({ code: 1, message: '分类不存在', data: null });
        }

        res.json({ code: 0, message: '更新成功', data: null });
    } catch (error) {
        console.error('更新分类失败:', error);
        res.status(500).json({ code: 1, message: '更新失败', data: null });
    }
});

// 删除分类
router.delete('/:id', async (req, res) => {
    try {
        const { id } = req.params;

        const childrenResult = await db.query('SELECT id FROM categories WHERE parent_id = $1', [id]);
        if (childrenResult.rows.length > 0) {
            return res.status(400).json({ code: 1, message: '请先删除子分类', data: null });
        }

        const result = await db.query('DELETE FROM categories WHERE id = $1', [id]);

        if (result.rowCount === 0) {
            return res.status(404).json({ code: 1, message: '分类不存在', data: null });
        }

        res.json({ code: 0, message: '删除成功', data: null });
    } catch (error) {
        console.error('删除分类失败:', error);
        res.status(500).json({ code: 1, message: '删除失败', data: null });
    }
});

module.exports = router;