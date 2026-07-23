const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticate } = require('../middlewares/auth');

// ══════════════════════════════════════════
//  寄存服务（提供寄存空间）
// ══════════════════════════════════════════

// ── GET /api/storage-services  寄存服务列表（支持多维度筛选）──
router.get('/storage-services', async (req, res) => {
    try {
        const {
            page = 1, pageSize = 12,
            storage_type, campus, status,
            keyword, sort = 'newest'
        } = req.query;

        const offset = (parseInt(page) - 1) * parseInt(pageSize);
        const params = [];
        const conditions = ["ss.is_approved = TRUE"];

        if (storage_type) {
            params.push(storage_type);
            conditions.push(`ss.storage_type = $${params.length}`);
        }
        if (campus) {
            params.push(campus);
            conditions.push(`ss.campus = $${params.length}`);
        }
        if (status) {
            params.push(status);
            conditions.push(`ss.status = $${params.length}`);
        }
        if (keyword) {
            params.push(`%${keyword}%`);
            conditions.push(`ss.title ILIKE $${params.length}`);
        }

        const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';

        const sortMap = {
            newest: 'ss.created_at DESC',
            price_asc: 'ss.price_per_month ASC NULLS LAST',
            price_desc: 'ss.price_per_month DESC NULLS LAST',
            ending_soon: 'ss.end_time ASC NULLS LAST'
        };
        const orderBy = sortMap[sort] || sortMap.newest;

        const countResult = await db.query(`SELECT COUNT(*) FROM storage_services ss ${where}`, params);
        const total = parseInt(countResult.rows[0].count);

        params.push(parseInt(pageSize));
        params.push(offset);
        const listResult = await db.query(
            `SELECT ss.*, u.username AS provider_name, u.campus AS provider_campus, u.real_name AS provider_real_name
             FROM storage_services ss
             LEFT JOIN users u ON ss.user_id = u.id
             ${where}
             ORDER BY ${orderBy}
             LIMIT $${params.length - 1} OFFSET $${params.length}`,
            params
        );

        res.json({ code: 0, message: 'success', data: { total, page: parseInt(page), list: listResult.rows } });
    } catch (error) {
        console.error('获取寄存服务列表失败:', error);
        res.status(500).json({ code: 1, message: '获取寄存服务列表失败', data: null });
    }
});

// ── GET /api/storage-services/:id  寄存服务详情 ──
router.get('/storage-services/:id', async (req, res) => {
    try {
        const result = await db.query(
            `SELECT ss.*, u.username AS provider_name, u.campus AS provider_campus,
                    u.real_name AS provider_real_name, u.avatar AS provider_avatar
             FROM storage_services ss
             LEFT JOIN users u ON ss.user_id = u.id
             WHERE ss.id = $1`,
            [req.params.id]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '寄存服务不存在', data: null });
        }
        res.json({ code: 0, message: 'success', data: result.rows[0] });
    } catch (error) {
        console.error('获取寄存服务详情失败:', error);
        res.status(500).json({ code: 1, message: '获取寄存服务详情失败', data: null });
    }
});

// ── POST /api/storage-services  发布寄存服务 ──
router.post('/storage-services', authenticate, async (req, res) => {
    try {
        const {
            title, description, storage_type, campus, location, location_detail,
            start_time, end_time, price_per_month, capacity,
            contact_info, image_url
        } = req.body;

        if (!title || !storage_type || !campus) {
            return res.status(400).json({ code: 1, message: '标题、寄存类型、校区不能为空', data: null });
        }

        const result = await db.query(
            `INSERT INTO storage_services
                (user_id, title, description, storage_type, campus, location, location_detail,
                 start_time, end_time, price_per_month, capacity, remain_capacity,
                 contact_info, image_url, status, is_approved)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,'pending', FALSE)
             RETURNING id`,
            [
                req.user.id, title, description || null, storage_type,
                campus, location || null, location_detail || null,
                start_time || null, end_time || null,
                price_per_month || null, capacity || 1, capacity || 1,
                contact_info || null, image_url || null
            ]
        );
        res.status(201).json({ code: 0, message: '寄存服务发布成功', data: { id: result.rows[0].id } });
    } catch (error) {
        console.error('发布寄存服务失败:', error);
        res.status(500).json({ code: 1, message: '发布失败', data: null });
    }
});

// ── PUT /api/storage-services/:id  更新寄存服务（仅发布者）──
router.put('/storage-services/:id', authenticate, async (req, res) => {
    try {
        const check = await db.query('SELECT user_id FROM storage_services WHERE id = $1', [req.params.id]);
        if (check.rows.length === 0) return res.status(404).json({ code: 1, message: '不存在', data: null });
        if (check.rows[0].user_id !== req.user.id) return res.status(403).json({ code: 1, message: '无权修改', data: null });

        const { status, remain_capacity } = req.body;
        const sets = [], params = [req.params.id];
        if (status) { sets.push(`status = $${params.length + 1}`); params.push(status); }
        if (remain_capacity !== undefined) { sets.push(`remain_capacity = $${params.length + 1}`); params.push(remain_capacity); }

        if (sets.length > 0) {
            sets.push('updated_at = NOW()');
            await db.query(`UPDATE storage_services SET ${sets.join(', ')} WHERE id = $1`, params);
        }
        res.json({ code: 0, message: '更新成功', data: null });
    } catch (error) {
        console.error('更新寄存服务失败:', error);
        res.status(500).json({ code: 1, message: '更新失败', data: null });
    }
});

// ══════════════════════════════════════════
//  寄存需求（寻找寄存空间）
// ══════════════════════════════════════════

// ── GET /api/storage-requests  寄存需求列表 ──
router.get('/storage-requests', async (req, res) => {
    try {
        const { page = 1, pageSize = 12, item_type, campus, status, keyword, sort = 'newest' } = req.query;
        const offset = (parseInt(page) - 1) * parseInt(pageSize);
        const params = [];
        const conditions = ["sr.is_approved = TRUE"];

        if (item_type) { params.push(item_type); conditions.push(`sr.item_type = $${params.length}`); }
        if (campus) { params.push(campus); conditions.push(`sr.campus = $${params.length}`); }
        if (status) { params.push(status); conditions.push(`sr.status = $${params.length}`); }
        if (keyword) { params.push(`%${keyword}%`); conditions.push(`sr.title ILIKE $${params.length}`); }

        const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';
        const sortMap = { newest: 'sr.created_at DESC', budget_asc: 'sr.budget ASC NULLS LAST', budget_desc: 'sr.budget DESC NULLS LAST' };
        const orderBy = sortMap[sort] || sortMap.newest;

        const countResult = await db.query(`SELECT COUNT(*) FROM storage_requests sr ${where}`, params);
        const total = parseInt(countResult.rows[0].count);

        params.push(parseInt(pageSize));
        params.push(offset);
        const listResult = await db.query(
            `SELECT sr.*, u.username AS requester_name, u.campus AS requester_campus
             FROM storage_requests sr
             LEFT JOIN users u ON sr.user_id = u.id
             ${where}
             ORDER BY ${orderBy}
             LIMIT $${params.length - 1} OFFSET $${params.length}`,
            params
        );

        res.json({ code: 0, message: 'success', data: { total, page: parseInt(page), list: listResult.rows } });
    } catch (error) {
        console.error('获取寄存需求列表失败:', error);
        res.status(500).json({ code: 1, message: '获取寄存需求列表失败', data: null });
    }
});

// ── GET /api/storage-requests/:id  寄存需求详情 ──
router.get('/storage-requests/:id', async (req, res) => {
    try {
        const result = await db.query(
            `SELECT sr.*, u.username AS requester_name, u.campus AS requester_campus, u.real_name AS requester_real_name
             FROM storage_requests sr LEFT JOIN users u ON sr.user_id = u.id
             WHERE sr.id = $1`, [req.params.id]
        );
        if (result.rows.length === 0) return res.status(404).json({ code: 1, message: '需求不存在', data: null });
        res.json({ code: 0, message: 'success', data: result.rows[0] });
    } catch (error) {
        console.error('获取需求详情失败:', error);
        res.status(500).json({ code: 1, message: '获取失败', data: null });
    }
});

// ── PUT /api/storage-requests/:id  更新寄存需求（仅发布者）──
router.put('/storage-requests/:id', authenticate, async (req, res) => {
    try {
        const check = await db.query('SELECT user_id FROM storage_requests WHERE id = $1', [req.params.id]);
        if (check.rows.length === 0) return res.status(404).json({ code: 1, message: '不存在', data: null });
        if (check.rows[0].user_id !== req.user.id) return res.status(403).json({ code: 1, message: '无权修改', data: null });
        const { status, title } = req.body;
        const sets = [], params = [req.params.id];
        if (status) { sets.push(`status = $${params.length + 1}`); params.push(status); }
        if (title) { sets.push(`title = $${params.length + 1}`); params.push(title); }
        if (sets.length > 0) await db.query(`UPDATE storage_requests SET ${sets.join(', ')} WHERE id = $1`, params);
        res.json({ code: 0, message: '更新成功', data: null });
    } catch (error) { console.error(error); res.status(500).json({ code: 1, message: '更新失败', data: null }); }
});

// ── POST /api/storage-requests  发布寄存需求 ──
router.post('/storage-requests', authenticate, async (req, res) => {
    try {
        const { title, description, item_type, campus, location, budget, expected_start_time, expected_end_time, contact_info } = req.body;
        if (!title || !item_type || !campus) {
            return res.status(400).json({ code: 1, message: '标题、物品类型、校区不能为空', data: null });
        }
        const result = await db.query(
            `INSERT INTO storage_requests (user_id, title, description, item_type, campus, location, budget, expected_start_time, expected_end_time, contact_info, status, is_approved)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'pending', FALSE) RETURNING id`,
            [req.user.id, title, description || null, item_type, campus, location || null, budget || null, expected_start_time || null, expected_end_time || null, contact_info || null]
        );
        res.status(201).json({ code: 0, message: '需求发布成功', data: { id: result.rows[0].id } });
    } catch (error) {
        console.error('发布寄存需求失败:', error);
        res.status(500).json({ code: 1, message: '发布失败', data: null });
    }
});

// ── DELETE /api/storage-services/:id  删除寄存服务（管理员）──
router.delete('/storage-services/:id', authenticate, async (req, res) => {
    try {
        const { id } = req.params;
        const check = await db.query('SELECT id FROM storage_services WHERE id = $1', [id]);
        if (check.rows.length === 0) return res.status(404).json({ code: 1, message: '不存在', data: null });
        await db.query('DELETE FROM storage_services WHERE id = $1', [id]);
        res.json({ code: 0, message: '已删除', data: null });
    } catch (error) { console.error(error); res.status(500).json({ code: 1, message: '删除失败', data: null }); }
});

// ── DELETE /api/storage-requests/:id  删除寄存需求（管理员）──
router.delete('/storage-requests/:id', authenticate, async (req, res) => {
    try {
        const { id } = req.params;
        const check = await db.query('SELECT id FROM storage_requests WHERE id = $1', [id]);
        if (check.rows.length === 0) return res.status(404).json({ code: 1, message: '不存在', data: null });
        await db.query('DELETE FROM storage_requests WHERE id = $1', [id]);
        res.json({ code: 0, message: '已删除', data: null });
    } catch (error) { console.error(error); res.status(500).json({ code: 1, message: '删除失败', data: null }); }
});

// ══════════════════════════════════════════
//  寄存订单
// ══════════════════════════════════════════

// ── POST /api/storage-orders  创建寄存预约 ──
router.post('/storage-orders', authenticate, async (req, res) => {
    try {
        const { storage_service_id, item_desc, start_date, end_date } = req.body;
        if (!storage_service_id || !start_date || !end_date) {
            return res.status(400).json({ code: 1, message: '参数不完整', data: null });
        }
        const svc = await db.query('SELECT * FROM storage_services WHERE id = $1', [storage_service_id]);
        if (svc.rows.length === 0) return res.status(404).json({ code: 1, message: '服务不存在', data: null });
        const service = svc.rows[0];
        if (service.user_id === req.user.id) return res.status(400).json({ code: 1, message: '不能预约自己的服务', data: null });

        const days = Math.ceil((new Date(end_date) - new Date(start_date)) / (1000*60*60*24));
        const months = Math.max(1, Math.ceil(days / 30));
        const total = (service.price_per_month || 0) * months;

        const result = await db.query(
            `INSERT INTO storage_orders (storage_service_id, user_id, provider_id, item_desc, start_date, end_date, total_price)
             VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
            [storage_service_id, req.user.id, service.user_id, item_desc || null, start_date, end_date, total]
        );
        res.status(201).json({ code: 0, message: '预约成功', data: { order_id: result.rows[0].id, total_price: total } });
    } catch (error) { console.error(error); res.status(500).json({ code: 1, message: '预约失败', data: null }); }
});

// ── GET /api/storage-orders/my  我的寄存订单 ──
router.get('/storage-orders/my', authenticate, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT so.*, ss.title AS service_title, ss.storage_type,
                    ow.username AS provider_name, rt.username AS renter_name
             FROM storage_orders so
             JOIN storage_services ss ON so.storage_service_id = ss.id
             LEFT JOIN users ow ON so.provider_id = ow.id
             LEFT JOIN users rt ON so.user_id = rt.id
             WHERE so.user_id = $1 OR so.provider_id = $1
             ORDER BY so.created_at DESC`,
            [req.user.id]
        );
        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (error) { console.error(error); res.status(500).json({ code: 1, message: '获取失败', data: null }); }
});

// ── GET /api/storage-orders  管理员查看所有寄存订单 ──
router.get('/storage-orders', authenticate, async (req, res) => {
    try {
        if (!['admin','operator'].includes(req.user.role)) {
            return res.status(403).json({ code: 1, message: '无权限', data: null });
        }
        const result = await db.query(
            `SELECT so.*, ss.title AS service_title,
                    ow.username AS provider_name, rt.username AS renter_name
             FROM storage_orders so
             JOIN storage_services ss ON so.storage_service_id = ss.id
             LEFT JOIN users ow ON so.provider_id = ow.id
             LEFT JOIN users rt ON so.user_id = rt.id
             ORDER BY so.created_at DESC LIMIT 100`
        );
        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (error) { console.error(error); res.status(500).json({ code: 1, message: '获取失败', data: null }); }
});

// ── PUT /api/storage-services/:id/approve  审核寄存服务 ──
router.put('/storage-services/:id/approve', authenticate, async (req, res) => {
    try {
        if (!['admin','operator'].includes(req.user.role)) return res.status(403).json({ code:1,message:'无权限' });
        const { id } = req.params;
        const { approved } = req.body; // true=通过, false=拒绝
        const status = approved ? 'available' : 'rejected';
        const r = await db.query(`UPDATE storage_services SET is_approved=$1, status=$2, updated_at=NOW() WHERE id=$3 RETURNING id`,
            [approved, status, id]);
        if (r.rows.length===0) return res.status(404).json({ code:1,message:'不存在' });
        res.json({ code:0, message: approved?'审核通过':'已拒绝', data:null });
    } catch(e) { console.error(e); res.status(500).json({ code:1,message:'操作失败' }); }
});

// ── PUT /api/storage-requests/:id/approve  审核寄存需求 ──
router.put('/storage-requests/:id/approve', authenticate, async (req, res) => {
    try {
        if (!['admin','operator'].includes(req.user.role)) return res.status(403).json({ code:1,message:'无权限' });
        const { id } = req.params;
        const { approved } = req.body;
        const status = approved ? 'searching' : 'rejected';
        const r = await db.query(`UPDATE storage_requests SET is_approved=$1, status=$2 WHERE id=$3 RETURNING id`,
            [approved, status, id]);
        if (r.rows.length===0) return res.status(404).json({ code:1,message:'不存在' });
        res.json({ code:0, message: approved?'审核通过':'已拒绝', data:null });
    } catch(e) { console.error(e); res.status(500).json({ code:1,message:'操作失败' }); }
});

module.exports = router;
