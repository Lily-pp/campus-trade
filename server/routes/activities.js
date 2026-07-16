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

// ══════════════════════════════════════════
//  公开接口（用户端）
// ══════════════════════════════════════════

// ── GET /api/activities  获取当前有效活动列表（首页展示）──
router.get('/', async (req, res) => {
    try {
        const result = await db.query(
            `SELECT a.*,
                    (SELECT COUNT(*) FROM items WHERE activity_id = a.id AND status = 'on_sale') AS item_count
             FROM activities a
             WHERE a.is_enabled = TRUE
               AND a.start_time <= NOW()
               AND a.end_time >= NOW()
             ORDER BY a.sort_order DESC, a.id ASC`
        );
        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (error) {
        console.error('获取活动列表失败:', error);
        res.status(500).json({ code: 1, message: '获取活动列表失败', data: null });
    }
});

// ── GET /api/activities/:id  获取活动详情 ──
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const result = await db.query(
            `SELECT a.*,
                    (SELECT COUNT(*) FROM items WHERE activity_id = a.id AND status = 'on_sale') AS item_count
             FROM activities a
             WHERE a.id = $1`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '活动不存在', data: null });
        }

        res.json({ code: 0, message: 'success', data: result.rows[0] });
    } catch (error) {
        console.error('获取活动详情失败:', error);
        res.status(500).json({ code: 1, message: '获取活动详情失败', data: null });
    }
});

// ── GET /api/activities/:id/items  获取活动下的商品列表 ──
router.get('/:id/items', async (req, res) => {
    try {
        const { id } = req.params;
        const {
            page = 1,
            pageSize = 12,
            sort = 'newest'
        } = req.query;

        // 先确认活动存在
        const activityCheck = await db.query('SELECT id FROM activities WHERE id = $1', [id]);
        if (activityCheck.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '活动不存在', data: null });
        }

        const offset = (parseInt(page) - 1) * parseInt(pageSize);
        const params = [parseInt(id)];

        const orderMap = {
            newest: 'i.created_at DESC',
            price_asc: 'i.price ASC',
            price_desc: 'i.price DESC',
            hot: 'i.views_count DESC'
        };
        const orderBy = orderMap[sort] || orderMap.newest;

        // 查总数
        const countResult = await db.query(
            `SELECT COUNT(*) FROM items i WHERE i.activity_id = $1 AND i.status = 'on_sale'`,
            params
        );
        const total = parseInt(countResult.rows[0].count);

        // 查数据（完全复用 items 查询结构）
        params.push(parseInt(pageSize));
        params.push(offset);
        const dataResult = await db.query(
            `SELECT i.id, i.title, i.price, i.status, i.created_at, i.views_count, i.favorites_count,
                    c.name AS category_name,
                    u.username AS seller_name, u.campus AS seller_campus,
                    (SELECT image_url FROM item_images WHERE item_id = i.id ORDER BY sort_order LIMIT 1) AS cover_image
             FROM items i
             LEFT JOIN categories c ON i.category_id = c.id
             LEFT JOIN users u ON i.user_id = u.id
             WHERE i.activity_id = $1 AND i.status = 'on_sale'
             ORDER BY ${orderBy}
             LIMIT $2 OFFSET $3`,
            params
        );

        res.json({
            code: 0,
            message: 'success',
            data: {
                total,
                page: parseInt(page),
                pageSize: parseInt(pageSize),
                list: dataResult.rows
            }
        });
    } catch (error) {
        console.error('获取活动商品列表失败:', error);
        res.status(500).json({ code: 1, message: '获取活动商品列表失败', data: null });
    }
});

// ══════════════════════════════════════════
//  管理后台接口（需要管理员权限）
// ══════════════════════════════════════════

// ── GET /api/activities/all  获取全部活动（后台管理）──
router.get('/all', authenticate, adminOnly, async (req, res) => {
    try {
        const { page = 1, pageSize = 15 } = req.query;
        const offset = (parseInt(page) - 1) * parseInt(pageSize);

        const countResult = await db.query('SELECT COUNT(*) FROM activities');
        const total = parseInt(countResult.rows[0].count);

        const listResult = await db.query(
            `SELECT a.*,
                    u.username AS creator_name,
                    (SELECT COUNT(*) FROM items WHERE activity_id = a.id AND status = 'on_sale') AS item_count,
                    CASE
                        WHEN a.is_enabled = FALSE THEN 'disabled'
                        WHEN NOW() < a.start_time THEN 'upcoming'
                        WHEN NOW() > a.end_time THEN 'ended'
                        ELSE 'active'
                    END AS time_status
             FROM activities a
             LEFT JOIN users u ON a.created_by = u.id
             ORDER BY a.sort_order DESC, a.id ASC
             LIMIT $1 OFFSET $2`,
            [parseInt(pageSize), offset]
        );

        res.json({ code: 0, message: 'success', data: { total, page: parseInt(page), list: listResult.rows } });
    } catch (error) {
        console.error('获取全部活动失败:', error);
        res.status(500).json({ code: 1, message: '获取全部活动失败', data: null });
    }
});

// ── POST /api/activities  新增活动 ──
router.post('/', authenticate, adminOnly, async (req, res) => {
    try {
        const { name, type, description, banner_url, start_time, end_time, sort_order } = req.body;

        if (!name || !type || !start_time || !end_time) {
            return res.status(400).json({ code: 1, message: '活动名称、类型、开始时间、结束时间不能为空', data: null });
        }

        if (new Date(end_time) <= new Date(start_time)) {
            return res.status(400).json({ code: 1, message: '结束时间必须晚于开始时间', data: null });
        }

        const result = await db.query(
            `INSERT INTO activities (name, type, description, banner_url, start_time, end_time, sort_order, created_by)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
             RETURNING id`,
            [name, type, description || null, banner_url || null, start_time, end_time, sort_order || 0, req.user.id]
        );

        await logAdmin(db, req.user.id, 'create_activity', 'activity', result.rows[0].id, { name, type });
        res.status(201).json({ code: 0, message: '活动创建成功', data: { id: result.rows[0].id } });
    } catch (error) {
        console.error('创建活动失败:', error);
        res.status(500).json({ code: 1, message: '创建活动失败', data: null });
    }
});

// ── PUT /api/activities/:id  修改活动 ──
router.put('/:id', authenticate, adminOnly, async (req, res) => {
    try {
        const { id } = req.params;
        const { name, type, description, banner_url, start_time, end_time, sort_order } = req.body;

        const check = await db.query('SELECT id FROM activities WHERE id = $1', [id]);
        if (check.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '活动不存在', data: null });
        }

        if (start_time && end_time && new Date(end_time) <= new Date(start_time)) {
            return res.status(400).json({ code: 1, message: '结束时间必须晚于开始时间', data: null });
        }

        await db.query(
            `UPDATE activities
             SET name = COALESCE($2, name),
                 type = COALESCE($3, type),
                 description = $4,
                 banner_url = $5,
                 start_time = COALESCE($6, start_time),
                 end_time = COALESCE($7, end_time),
                 sort_order = COALESCE($8, sort_order),
                 updated_at = NOW()
             WHERE id = $1`,
            [id, name || null, type || null, description, banner_url, start_time || null, end_time || null, sort_order != null ? sort_order : null]
        );

        await logAdmin(db, req.user.id, 'update_activity', 'activity', parseInt(id), { name, type });
        res.json({ code: 0, message: '活动更新成功', data: null });
    } catch (error) {
        console.error('更新活动失败:', error);
        res.status(500).json({ code: 1, message: '更新活动失败', data: null });
    }
});

// ── PUT /api/activities/:id/toggle  启用/停用活动 ──
router.put('/:id/toggle', authenticate, adminOnly, async (req, res) => {
    try {
        const { id } = req.params;

        const result = await db.query(
            `UPDATE activities
             SET is_enabled = NOT is_enabled,
                 updated_at = NOW()
             WHERE id = $1
             RETURNING id, is_enabled, name`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '活动不存在', data: null });
        }

        const activity = result.rows[0];
        await logAdmin(db, req.user.id, 'toggle_activity', 'activity', parseInt(id), { is_enabled: activity.is_enabled });

        res.json({
            code: 0,
            message: activity.is_enabled ? `活动「${activity.name}」已启用` : `活动「${activity.name}」已停用`,
            data: { is_enabled: activity.is_enabled }
        });
    } catch (error) {
        console.error('切换活动状态失败:', error);
        res.status(500).json({ code: 1, message: '操作失败', data: null });
    }
});

// ── DELETE /api/activities/:id  删除活动 ──
router.delete('/:id', authenticate, adminOnly, async (req, res) => {
    try {
        const { id } = req.params;

        const check = await db.query('SELECT id, name FROM activities WHERE id = $1', [id]);
        if (check.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '活动不存在', data: null });
        }

        await db.query('DELETE FROM activities WHERE id = $1', [id]);
        await logAdmin(db, req.user.id, 'delete_activity', 'activity', parseInt(id), { name: check.rows[0].name });

        res.json({ code: 0, message: '活动已删除', data: null });
    } catch (error) {
        console.error('删除活动失败:', error);
        res.status(500).json({ code: 1, message: '删除活动失败', data: null });
    }
});

module.exports = router;
