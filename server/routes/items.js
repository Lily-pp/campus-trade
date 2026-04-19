const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticate } = require('../middlewares/auth');
const { logAdmin } = require('../utils/adminLog');
const { verifyToken } = require('../utils/jwt');

const adminOnly = (req, res, next) => {
    if (!['admin', 'operator'].includes(req.user.role)) {
        return res.status(403).json({ code: 1, message: '无权限', data: null });
    }
    next();
};

const parseOptionalUser = (req) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return null;
    }

    return verifyToken(authHeader.split(' ')[1]);
};

// ── GET /api/items  商品列表（支持分页、分类筛选、排序、搜索）──
router.get('/', async (req, res) => {
    try {
        const {
            page = 1,
            pageSize = 12,
            category_id,
            keyword,
            sort = 'newest'   // newest | price_asc | price_desc
        } = req.query;

        const offset = (parseInt(page) - 1) * parseInt(pageSize);
        const params = [];
        const conditions = ["i.status = 'on_sale'"];

        if (category_id) {
            params.push(parseInt(category_id));
            conditions.push(`i.category_id = $${params.length}`);
        }

        if (keyword) {
            params.push(`%${keyword}%`);
            conditions.push(`i.title ILIKE $${params.length}`);
        }

        const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';

        const orderMap = {
            newest: 'i.created_at DESC',
            price_asc: 'i.price ASC',
            price_desc: 'i.price DESC'
        };
        const orderBy = orderMap[sort] || orderMap.newest;

        // 查总数
        const countResult = await db.query(
            `SELECT COUNT(*) FROM items i ${where}`,
            params
        );
        const total = parseInt(countResult.rows[0].count);

        // 查数据
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
             ${where}
             ORDER BY ${orderBy}
             LIMIT $${params.length - 1} OFFSET $${params.length}`,
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
        console.error(error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

// ── GET /api/items/all  后台管理：查全部商品（分页 + 筛选）──
router.get('/all', authenticate, adminOnly, async (req, res) => {
    try {
        const { page = 1, pageSize = 15, status, category_id, keyword } = req.query;
        const offset = (parseInt(page) - 1) * parseInt(pageSize);
        const params = [];
        const conditions = [];

        if (status) {
            params.push(status);
            conditions.push(`i.status = $${params.length}`);
        }
        if (category_id) {
            params.push(parseInt(category_id));
            conditions.push(`i.category_id = $${params.length}`);
        }
        if (keyword) {
            params.push(`%${keyword}%`);
            conditions.push(`i.title ILIKE $${params.length}`);
        }

        const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';

        const countResult = await db.query(
            `SELECT COUNT(*) FROM items i ${where}`, params
        );
        const total = parseInt(countResult.rows[0].count);

        params.push(parseInt(pageSize));
        params.push(offset);
        const listResult = await db.query(
                `SELECT i.id, i.title, i.price, i.status,
                    i.is_approved,
                    CASE WHEN i.status = 'sold' THEN 0 ELSE COALESCE(i.quantity, 1) END AS quantity,
                    i.views_count, i.favorites_count,
                    i.created_at, i.updated_at,
                    c.name AS category_name,
                    u.id AS seller_id, u.username AS seller_name, u.campus AS seller_campus
             FROM items i
             LEFT JOIN categories c ON i.category_id = c.id
             LEFT JOIN users u ON i.user_id = u.id
             ${where}
             ORDER BY i.created_at DESC, i.id ASC
             LIMIT $${params.length - 1} OFFSET $${params.length}`,
            params
        );

        res.json({ code: 0, message: 'success', data: { total, page: parseInt(page), list: listResult.rows } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

// ── GET /api/items/my  我的发布（前台用户）──
router.get('/my', authenticate, async (req, res) => {
    try {
        const result = await db.query(
                `SELECT i.id, i.title, i.price, i.status,
                    i.is_approved,
                    CASE WHEN i.status = 'sold' THEN 0 ELSE COALESCE(i.quantity, 1) END AS quantity,
                    i.views_count, i.favorites_count, i.created_at,
                    c.name AS category_name
             FROM items i
             LEFT JOIN categories c ON i.category_id = c.id
             WHERE i.user_id = $1
             ORDER BY i.created_at DESC`,
            [req.user.id]
        );
        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

// ── GET /api/items/:id  商品详情 ──
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const currentUser = parseOptionalUser(req);

        const result = await db.query(
            `SELECT i.*,
                    c.name AS category_name,
                    u.id AS seller_id, u.username AS seller_name, u.campus AS seller_campus, u.real_name AS seller_real_name
             FROM items i
             LEFT JOIN categories c ON i.category_id = c.id
             LEFT JOIN users u ON i.user_id = u.id
             WHERE i.id = $1`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '商品不存在', data: null });
        }

        const item = result.rows[0];
        const isOwner = currentUser && item.user_id === currentUser.id;
        const isAdmin = currentUser && ['admin', 'operator'].includes(currentUser.role);
        if (item.status !== 'on_sale' && !isOwner && !isAdmin) {
            return res.status(403).json({ code: 1, message: '商品暂不可查看', data: null });
        }

        // 查商品图片
        const imgResult = await db.query(
            'SELECT id, image_url AS url FROM item_images WHERE item_id = $1 ORDER BY sort_order',
            [id]
        );

        if (item.status === 'on_sale') {
            await db.query('UPDATE items SET views_count = views_count + 1 WHERE id = $1', [id]);
            item.views_count = (item.views_count || 0) + 1;
        }

        const data = item;
        if (data.status === 'sold') {
            data.quantity = 0;
        }
        data.images = imgResult.rows;

        res.json({ code: 0, message: 'success', data });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

// ── POST /api/items  发布商品（需登录）──
router.post('/', authenticate, async (req, res) => {
    try {
        const { title, description, price, category_id, campus, images, quantity } = req.body;

        if (!title || price === undefined || !category_id) {
            return res.status(400).json({ code: 1, message: '标题、价格、分类不能为空', data: null });
        }

        const qty = parseInt(quantity) > 0 ? parseInt(quantity) : 1;

        const result = await db.query(
            `INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity)
             VALUES ($1, $2, $3, $4, $5, 'pending', FALSE, $6, $7)
             RETURNING id`,
            [title, description || null, parseFloat(price), parseInt(category_id), req.user.id, campus || null, qty]
        );

        const itemId = result.rows[0].id;

        // 保存商品图片
        if (images && Array.isArray(images) && images.length > 0) {
            for (let i = 0; i < images.length; i++) {
                await db.query(
                    `INSERT INTO item_images (item_id, image_url, sort_order) VALUES ($1, $2, $3)`,
                    [itemId, images[i], i]
                );
            }
        }

        res.status(201).json({ code: 0, message: '发布成功', data: { id: itemId } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '发布失败', data: null });
    }
});

// ── PUT /api/items/:id/status  更新商品状态（本人或管理员）──
router.put('/:id/status', authenticate, async (req, res) => {
    try {
        const { id } = req.params;
        const { status } = req.body;

        const allowed = ['on_sale', 'sold', 'off', 'rejected'];
        if (!allowed.includes(status)) {
            return res.status(400).json({ code: 1, message: '无效的状态值', data: null });
        }

        const itemResult = await db.query(
            'SELECT user_id, status, is_approved, COALESCE(quantity, 1) AS quantity FROM items WHERE id = $1',
            [id]
        );
        if (itemResult.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '商品不存在', data: null });
        }

        const item = itemResult.rows[0];
        const isOwner = item.user_id === req.user.id;
        const isAdmin = ['admin', 'operator'].includes(req.user.role);

        if (!isOwner && !isAdmin) {
            return res.status(403).json({ code: 1, message: '无权限', data: null });
        }

        if (!isAdmin) {
            // pending/on_sale 均可下架；已审核的 off 可重新上架；rejected/pending未审核的 off 不可自行上架
            const ownerAllowedTransitions = {
                pending: ['off'],
                on_sale: ['off'],
                off: item.is_approved ? ['on_sale'] : [],
                rejected: []  // 管理员拒绝的商品，用户不可自行操作（需删除后重新发布）
            };
            const nextAllowed = ownerAllowedTransitions[item.status] || [];
            if (!nextAllowed.includes(status)) {
                return res.status(400).json({ code: 1, message: '当前状态不允许此操作', data: null });
            }
        }

        if (status === 'on_sale' && !isAdmin && !item.is_approved) {
            return res.status(400).json({ code: 1, message: '商品尚未审核通过，不能上架', data: null });
        }

        if (status === 'on_sale' && parseInt(item.quantity) <= 0) {
            return res.status(400).json({ code: 1, message: '库存为0，不能上架', data: null });
        }

        await db.query(
            `UPDATE items
             SET status = $1::varchar,
                 is_approved = CASE WHEN $1::varchar = 'on_sale' THEN TRUE ELSE is_approved END,
                 quantity    = CASE WHEN $1::varchar = 'sold'    THEN 0    ELSE quantity    END,
                 updated_at  = NOW()
             WHERE id = $2`,
            [status, id]
        );
        await logAdmin(db, req.user.id, 'update_item_status', 'item', parseInt(id), { status });
        res.json({ code: 0, message: '状态更新成功', data: null });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '更新失败', data: null });
    }
});

// ── DELETE /api/items/:id  删除商品（本人或管理员）──
router.delete('/:id', authenticate, async (req, res) => {
    try {
        const { id } = req.params;

        const itemResult = await db.query('SELECT id, user_id FROM items WHERE id = $1', [id]);
        if (itemResult.rows.length === 0) {
            return res.status(404).json({ code: 1, message: '商品不存在', data: null });
        }

        const isOwner = itemResult.rows[0].user_id === req.user.id;
        const isAdmin = ['admin', 'operator'].includes(req.user.role);

        if (!isOwner && !isAdmin) {
            return res.status(403).json({ code: 1, message: '无权限删除该商品', data: null });
        }

        await db.query('DELETE FROM items WHERE id = $1', [id]);
        await logAdmin(db, req.user.id, 'delete_item', 'item', parseInt(id), null);
        res.json({ code: 0, message: '删除成功', data: null });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '删除失败', data: null });
    }
});

module.exports = router;