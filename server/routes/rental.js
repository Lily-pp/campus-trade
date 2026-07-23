const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticate } = require('../middlewares/auth');

const adminOnly = (req, res, next) => {
    if (!['admin','operator'].includes(req.user.role)) return res.status(403).json({ code:1,message:'无权限' });
    next();
};

// ══════════════════════════════════════════
//  具体路径路由（必须在 /:id 之前）
// ══════════════════════════════════════════

// ── GET /api/rental-items  转租物品列表 ──
router.get('/', async (req, res) => {
    try {
        const { page = 1, pageSize = 12, category } = req.query;
        const offset = (parseInt(page) - 1) * parseInt(pageSize);
        const params = [];
        const conditions = ["ri.is_approved = TRUE", "ri.status = 'available'"];
        if (category) { params.push(category); conditions.push(`ri.category = $${params.length}`); }
        const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';
        const countResult = await db.query(`SELECT COUNT(*) FROM rental_items ri ${where}`, params);
        const total = parseInt(countResult.rows[0].count);
        params.push(parseInt(pageSize)); params.push(offset);
        const listResult = await db.query(
            `SELECT ri.*, u.username AS owner_name, u.campus AS owner_campus
             FROM rental_items ri LEFT JOIN users u ON ri.user_id = u.id
             ${where} ORDER BY ri.created_at DESC LIMIT $${params.length-1} OFFSET $${params.length}`, params);
        res.json({ code: 0, message: 'success', data: { total, page: parseInt(page), list: listResult.rows } });
    } catch (error) { console.error(error); res.status(500).json({ code: 1, message: '获取失败', data: null }); }
});

// ── POST /api/rental-items  发布转租物品 ──
router.post('/', authenticate, async (req, res) => {
    try {
        const { title, description, category, rental_price, deposit, min_days, max_days, location, campus, images } = req.body;
        if (!title || !category || rental_price === undefined) return res.status(400).json({ code: 1, message: '标题、分类、日租价格不能为空', data: null });
        const result = await db.query(
            `INSERT INTO rental_items (user_id, title, description, category, rental_price, deposit, min_days, max_days, location, campus, images, status, is_approved)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'pending',FALSE) RETURNING id`,
            [req.user.id, title, description||null, category, parseFloat(rental_price), deposit||null, min_days||1, max_days||null, location||null, campus||null, images?JSON.stringify(images):null]);
        res.status(201).json({ code: 0, message: '发布成功', data: { id: result.rows[0].id } });
    } catch (error) { console.error(error); res.status(500).json({ code: 1, message: '发布失败', data: null }); }
});

// ── POST /api/rental-items/orders  创建租赁订单 ──
router.post('/orders', authenticate, async (req, res) => {
    try {
        const { rental_item_id, start_date, end_date } = req.body;
        if (!rental_item_id || !start_date || !end_date) return res.status(400).json({ code: 1, message: '参数不完整', data: null });
        const itemResult = await db.query('SELECT * FROM rental_items WHERE id = $1', [rental_item_id]);
        if (itemResult.rows.length === 0) return res.status(404).json({ code: 1, message: '转租物品不存在', data: null });
        const item = itemResult.rows[0];
        if (item.user_id === req.user.id) return res.status(400).json({ code: 1, message: '不能租赁自己的物品', data: null });
        if (item.status !== 'available') return res.status(400).json({ code: 1, message: '该物品当前不可租赁', data: null });
        const days = Math.ceil((new Date(end_date) - new Date(start_date)) / (1000*60*60*24));
        if (days <= 0) return res.status(400).json({ code: 1, message: '结束日期必须晚于开始日期', data: null });
        const totalPrice = parseFloat(item.rental_price) * days;
        const result = await db.query(
            `INSERT INTO rental_orders (rental_item_id, renter_id, owner_id, start_date, end_date, total_price, deposit)
             VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
            [rental_item_id, req.user.id, item.user_id, start_date, end_date, totalPrice, item.deposit]);
        res.status(201).json({ code: 0, message: '下单成功', data: { order_id: result.rows[0].id, total_price: totalPrice, days } });
    } catch (error) { console.error(error); res.status(500).json({ code: 1, message: '创建订单失败', data: null }); }
});

// ── GET /api/rental-items/orders  管理员查看所有租赁订单 ──
router.get('/orders', authenticate, adminOnly, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT ro.*, ri.title AS item_title, ri.category, ow.username AS owner_name, rt.username AS renter_name
             FROM rental_orders ro JOIN rental_items ri ON ro.rental_item_id = ri.id
             LEFT JOIN users ow ON ro.owner_id = ow.id LEFT JOIN users rt ON ro.renter_id = rt.id
             ORDER BY ro.created_at DESC LIMIT 100`);
        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (error) { console.error(error); res.status(500).json({ code: 1, message: '获取失败', data: null }); }
});

// ── GET /api/rental-items/orders/my  我的租赁订单 ──
router.get('/orders/my', authenticate, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT ro.*, ri.title, ri.category, ow.username AS owner_name, rt.username AS renter_name
             FROM rental_orders ro JOIN rental_items ri ON ro.rental_item_id = ri.id
             LEFT JOIN users ow ON ro.owner_id = ow.id LEFT JOIN users rt ON ro.renter_id = rt.id
             WHERE ro.renter_id = $1 OR ro.owner_id = $1 ORDER BY ro.created_at DESC`, [req.user.id]);
        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (error) { console.error(error); res.status(500).json({ code: 1, message: '获取失败', data: null }); }
});

// ── PUT /api/rental-items/:id/approve  审核转租物品 ──
router.put('/:id/approve', authenticate, adminOnly, async (req, res) => {
    try {
        const { approved } = req.body;
        const status = approved ? 'available' : 'rejected';
        const r = await db.query(`UPDATE rental_items SET is_approved=$1, status=$2 WHERE id=$3 RETURNING id`, [approved, status, req.params.id]);
        if (r.rows.length===0) return res.status(404).json({ code:1,message:'不存在' });
        res.json({ code:0, message: approved?'审核通过':'已拒绝', data:null });
    } catch(e) { console.error(e); res.status(500).json({ code:1,message:'操作失败' }); }
});

// ══════════════════════════════════════════
//  参数化路由（必须在所有具体路径之后）
// ══════════════════════════════════════════

// ── GET /api/rental-items/:id  转租物品详情 ──
router.get('/:id', async (req, res) => {
    try {
        const result = await db.query(
            `SELECT ri.*, u.username AS owner_name, u.campus AS owner_campus, u.real_name AS owner_real_name
             FROM rental_items ri LEFT JOIN users u ON ri.user_id = u.id WHERE ri.id = $1`, [req.params.id]);
        if (result.rows.length === 0) return res.status(404).json({ code: 1, message: '转租物品不存在', data: null });
        res.json({ code: 0, message: 'success', data: result.rows[0] });
    } catch (error) { console.error(error); res.status(500).json({ code: 1, message: '获取失败', data: null }); }
});

// ── PUT /api/rental-items/:id  更新转租物品（仅发布者）──
router.put('/:id', authenticate, async (req, res) => {
    try {
        const check = await db.query('SELECT user_id FROM rental_items WHERE id = $1', [req.params.id]);
        if (check.rows.length === 0) return res.status(404).json({ code: 1, message: '不存在', data: null });
        if (check.rows[0].user_id !== req.user.id) return res.status(403).json({ code: 1, message: '无权修改', data: null });
        const { title, status } = req.body;
        const sets = [], params = [req.params.id];
        if (title) { sets.push(`title = $${params.length+1}`); params.push(title); }
        if (status) { sets.push(`status = $${params.length+1}`); params.push(status); }
        if (sets.length > 0) await db.query(`UPDATE rental_items SET ${sets.join(', ')} WHERE id = $1`, params);
        res.json({ code: 0, message: '更新成功', data: null });
    } catch (error) { console.error(error); res.status(500).json({ code: 1, message: '更新失败', data: null }); }
});

// ── DELETE /api/rental-items/:id  删除转租物品 ──
router.delete('/:id', authenticate, async (req, res) => {
    try {
        const check = await db.query('SELECT id FROM rental_items WHERE id = $1', [req.params.id]);
        if (check.rows.length === 0) return res.status(404).json({ code: 1, message: '不存在', data: null });
        await db.query('DELETE FROM rental_items WHERE id = $1', [req.params.id]);
        res.json({ code: 0, message: '已删除', data: null });
    } catch (error) { console.error(error); res.status(500).json({ code: 1, message: '删除失败', data: null }); }
});

module.exports = router;
