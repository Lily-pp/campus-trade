const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticate } = require('../middlewares/auth');

const adminOnly = (req, res, next) => {
    if (!['admin','operator'].includes(req.user.role)) return res.status(403).json({ code:1,message:'无权限' });
    next();
};

// ══════════════════════════════════════════
//  公益商品列表
// ══════════════════════════════════════════

// ── GET /api/charity/items  免费赠送商品列表 ──
router.get('/items', async (req, res) => {
    try {
        const { page = 1, pageSize = 12, campus } = req.query;
        const offset = (parseInt(page) - 1) * parseInt(pageSize);
        const params = [];
        const conditions = ["i.item_type = 'charity'", "i.status = 'on_sale'", "i.is_approved = TRUE"];
        if (campus) { params.push(campus); conditions.push(`i.campus = $${params.length}`); }
        const where = 'WHERE ' + conditions.join(' AND ');

        const countResult = await db.query(`SELECT COUNT(*) FROM items i ${where}`, params);
        const total = parseInt(countResult.rows[0].count);

        params.push(parseInt(pageSize)); params.push(offset);
        const listResult = await db.query(
            `SELECT i.id, i.title, i.description, i.price, i.campus, i.views_count, i.free_deadline, i.created_at,
                    u.username AS owner_name, u.real_name AS owner_real_name,
                    (SELECT image_url FROM item_images WHERE item_id = i.id ORDER BY sort_order LIMIT 1) AS cover_image,
                    (SELECT COUNT(*) FROM free_apply WHERE item_id = i.id AND status = 'pending') AS apply_count
             FROM items i LEFT JOIN users u ON i.user_id = u.id
             ${where} ORDER BY i.created_at DESC LIMIT $${params.length-1} OFFSET $${params.length}`, params);

        res.json({ code: 0, message: 'success', data: { total, page: parseInt(page), list: listResult.rows } });
    } catch (e) { console.error(e); res.status(500).json({ code:1,message:'获取失败',data:null }); }
});

// ── GET /api/charity/items/:id  公益商品详情 ──
router.get('/items/:id', async (req, res) => {
    try {
        const result = await db.query(
            `SELECT i.*, u.username AS owner_name, u.real_name AS owner_real_name, u.campus AS owner_campus,
                    (SELECT json_agg(image_url) FROM item_images WHERE item_id = i.id) AS images
             FROM items i LEFT JOIN users u ON i.user_id = u.id WHERE i.id = $1`, [req.params.id]);
        if (result.rows.length === 0) return res.status(404).json({ code:1,message:'商品不存在' });
        res.json({ code: 0, message: 'success', data: result.rows[0] });
    } catch (e) { console.error(e); res.status(500).json({ code:1,message:'获取失败',data:null }); }
});

// ══════════════════════════════════════════
//  免费领取申请
// ══════════════════════════════════════════

// ── POST /api/charity/apply  申请领取 ──
router.post('/apply', authenticate, async (req, res) => {
    try {
        const { item_id, message } = req.body;
        if (!item_id) return res.status(400).json({ code:1,message:'缺少商品ID' });

        const item = await db.query("SELECT * FROM items WHERE id = $1 AND item_type = 'charity'", [item_id]);
        if (item.rows.length === 0) return res.status(404).json({ code:1,message:'商品不存在' });
        if (item.rows[0].user_id === req.user.id) return res.status(400).json({ code:1,message:'不能领取自己的商品' });

        // 检查是否已申请
        const exist = await db.query('SELECT id FROM free_apply WHERE item_id=$1 AND applicant_id=$2 AND status != $3',
            [item_id, req.user.id, 'cancelled']);
        if (exist.rows.length > 0) return res.status(400).json({ code:1,message:'你已经申请过了' });

        await db.query(
            `INSERT INTO free_apply (item_id, applicant_id, owner_id, apply_message) VALUES ($1,$2,$3,$4)`,
            [item_id, req.user.id, item.rows[0].user_id, message || null]);
        res.status(201).json({ code: 0, message: '申请已提交，等待发布者确认' });
    } catch (e) { console.error(e); res.status(500).json({ code:1,message:'申请失败',data:null }); }
});

// ── GET /api/charity/applies/my  我的申请记录 ──
router.get('/applies/my', authenticate, async (req, res) => {
    try {
        const { type = 'all' } = req.query; // applied:我申请的, received:别人申请我的
        let where = '';
        if (type === 'applied') where = `WHERE fa.applicant_id = ${req.user.id}`;
        else if (type === 'received') where = `WHERE fa.owner_id = ${req.user.id}`;
        else where = `WHERE (fa.applicant_id = ${req.user.id} OR fa.owner_id = ${req.user.id})`;

        const result = await db.query(
            `SELECT fa.*, i.title AS item_title,
                    ap.username AS applicant_name, ow.username AS owner_name
             FROM free_apply fa
             JOIN items i ON fa.item_id = i.id
             LEFT JOIN users ap ON fa.applicant_id = ap.id
             LEFT JOIN users ow ON fa.owner_id = ow.id
             ${where} ORDER BY fa.created_at DESC`);
        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (e) { console.error(e); res.status(500).json({ code:1,message:'获取失败',data:null }); }
});

// ── PUT /api/charity/apply/:id  处理申请（接受/拒绝/完成）──
router.put('/apply/:id', authenticate, async (req, res) => {
    try {
        const { status } = req.body;
        const apply = await db.query('SELECT * FROM free_apply WHERE id = $1', [req.params.id]);
        if (apply.rows.length === 0) return res.status(404).json({ code:1,message:'申请不存在' });
        if (apply.rows[0].owner_id !== req.user.id && !['admin','operator'].includes(req.user.role))
            return res.status(403).json({ code:1,message:'无权操作' });

        await db.query('UPDATE free_apply SET status=$1, updated_at=NOW() WHERE id=$2', [status, req.params.id]);

        // 完成领取：增加双方公益积分
        if (status === 'completed') {
            await db.query('UPDATE users SET charity_points = charity_points + 10 WHERE id = $1', [apply.rows[0].owner_id]);
            await db.query('UPDATE users SET charity_points = charity_points + 5 WHERE id = $1', [apply.rows[0].applicant_id]);
            await db.query("UPDATE items SET status = 'sold', updated_at = NOW() WHERE id = $1", [apply.rows[0].item_id]);
        }

        res.json({ code:0, message: status==='accepted'?'已接受':status==='completed'?'已完成':status==='cancelled'?'已取消':'已更新' });
    } catch (e) { console.error(e); res.status(500).json({ code:1,message:'操作失败',data:null }); }
});

// ══════════════════════════════════════════
//  公益回收池 + 捐赠管理（管理员）
// ══════════════════════════════════════════

// ── GET /api/charity/recycle-pool  回收池（未领取的公益商品）──
router.get('/recycle-pool', authenticate, adminOnly, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT i.*, u.username AS owner_name,
                    (SELECT image_url FROM item_images WHERE item_id = i.id ORDER BY sort_order LIMIT 1) AS cover_image
             FROM items i LEFT JOIN users u ON i.user_id = u.id
             WHERE i.item_type = 'charity'
               AND i.id NOT IN (SELECT item_id FROM free_apply WHERE status = 'completed')
             ORDER BY i.created_at DESC`);
        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (e) { console.error(e); res.status(500).json({ code:1,message:'获取失败',data:null }); }
});

// ── GET /api/charity/donations  捐赠记录列表 ──
router.get('/donations', authenticate, adminOnly, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT dr.*, i.title AS item_title, u.username AS creator_name
             FROM donation_record dr
             LEFT JOIN items i ON dr.item_id = i.id
             LEFT JOIN users u ON dr.created_by = u.id
             ORDER BY dr.donation_time DESC NULLS LAST, dr.created_at DESC`);
        res.json({ code: 0, message: 'success', data: result.rows });
    } catch (e) { console.error(e); res.status(500).json({ code:1,message:'获取失败',data:null }); }
});

// ── POST /api/charity/donations  创建捐赠记录 ──
router.post('/donations', authenticate, adminOnly, async (req, res) => {
    try {
        const { item_ids, batch_id, organization, description, proof_image, donation_time } = req.body;
        if (!item_ids || !item_ids.length) return res.status(400).json({ code:1,message:'请选择商品' });

        for (const itemId of item_ids) {
            await db.query(
                `INSERT INTO donation_record (item_id, batch_id, donation_time, organization, description, proof_image, created_by)
                 VALUES ($1,$2,$3,$4,$5,$6,$7)`,
                [itemId, batch_id || null, donation_time || new Date(), organization || null, description || null, proof_image || null, req.user.id]);
            await db.query("UPDATE items SET status='sold', updated_at=NOW() WHERE id=$1", [itemId]);
            // 发布者获得公益积分
            const item = await db.query('SELECT user_id FROM items WHERE id=$1', [itemId]);
            if (item.rows.length > 0) {
                await db.query('UPDATE users SET charity_points = charity_points + 20 WHERE id = $1', [item.rows[0].user_id]);
            }
        }
        res.status(201).json({ code: 0, message: `已记录 ${item_ids.length} 件捐赠` });
    } catch (e) { console.error(e); res.status(500).json({ code:1,message:'操作失败',data:null }); }
});

// ── GET /api/charity/stats  公益统计 ──
router.get('/stats', async (req, res) => {
    try {
        const total = await db.query("SELECT COUNT(*)::int AS cnt FROM items WHERE item_type='charity' AND is_approved=TRUE");
        const completed = await db.query("SELECT COUNT(*)::int AS cnt FROM free_apply WHERE status='completed'");
        const donations = await db.query("SELECT COUNT(*)::int AS cnt FROM donation_record");
        res.json({ code:0, data: { total_items: total.rows[0].cnt, completed_gives: completed.rows[0].cnt, total_donations: donations.rows[0].cnt } });
    } catch (e) { console.error(e); res.status(500).json({ code:1,message:'获取失败' }); }
});

module.exports = router;
