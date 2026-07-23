const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authenticate } = require('../middlewares/auth');

// GET /api/stats  后台数据统计
router.get('/', authenticate, async (req, res) => {
    try {
        const [
            usersResult,
            itemsResult,
            categoriesResult,
            recentResult,
            hotItemsResult,
            categoryDistResult,
            userTrendResult,
            itemTrendResult,
            ordersResult,
            reportsResult,
            activitiesResult,
            charityResult,
            storageResult,
            rentalResult,
            vouchersResult,
            storageOrdersResult,
            rentalOrdersResult
        ] = await Promise.all([
            db.query("SELECT COUNT(*) AS count FROM users WHERE role = 'user'"),
            db.query("SELECT status, COUNT(*) AS count FROM items GROUP BY status"),
            db.query("SELECT COUNT(*) AS count FROM categories"),
            db.query(`SELECT i.id, i.title, i.price, i.status, i.created_at, u.username AS seller_name FROM items i LEFT JOIN users u ON i.user_id = u.id ORDER BY i.created_at DESC LIMIT 6`),
            db.query(`SELECT i.id, i.title, i.price, i.views_count, i.favorites_count, (i.views_count + i.favorites_count * 3) AS score FROM items i WHERE i.status = 'on_sale' ORDER BY score DESC LIMIT 6`),
            db.query(`SELECT c.name, COUNT(i.id) AS item_count FROM categories c LEFT JOIN items i ON i.category_id = c.id AND i.status != 'off' WHERE c.parent_id = 0 GROUP BY c.id, c.name ORDER BY item_count DESC`),
            db.query(`SELECT TO_CHAR(created_at, 'MM-DD') AS day, COUNT(*) AS count FROM users WHERE role = 'user' AND created_at >= NOW() - INTERVAL '7 days' GROUP BY day ORDER BY day`),
            db.query(`SELECT TO_CHAR(created_at, 'MM-DD') AS day, COUNT(*) AS count FROM items WHERE created_at >= NOW() - INTERVAL '7 days' GROUP BY day ORDER BY day`),
            db.query("SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE status='completed') AS completed FROM orders"),
            db.query("SELECT COUNT(*) AS count FROM reports WHERE status = 'pending'"),
            // 活动统计
            db.query("SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE is_enabled=TRUE AND start_time<=NOW() AND end_time>=NOW()) AS active FROM activities"),
            // 公益商品
            db.query("SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE status='on_sale') AS available FROM items WHERE item_type='charity'"),
            // 寄存服务
            db.query("SELECT COUNT(*) AS total FROM storage_services"),
            // 转租物品
            db.query("SELECT COUNT(*) AS total FROM rental_items"),
            // 未使用代金券
            db.query("SELECT COUNT(*) AS total, COALESCE(SUM(amount),0) AS sum_amount FROM vouchers WHERE status='unused'"),
            // 寄存订单
            db.query("SELECT COUNT(*) AS total FROM storage_orders"),
            // 租赁订单
            db.query("SELECT COUNT(*) AS total FROM rental_orders")
        ]);

        const itemsByStatus = {};
        itemsResult.rows.forEach(row => {
            itemsByStatus[row.status] = parseInt(row.count);
        });
        const totalItems = Object.values(itemsByStatus).reduce((a, b) => a + b, 0);

        res.json({
            code: 0,
            message: 'success',
            data: {
                // 总览卡片
                users:          parseInt(usersResult.rows[0].count),
                total_items:    totalItems,
                on_sale:        itemsByStatus['on_sale'] || 0,
                sold:           itemsByStatus['sold'] || 0,
                pending:        itemsByStatus['pending'] || 0,
                categories:     parseInt(categoriesResult.rows[0].count),
                total_orders:   parseInt(ordersResult.rows[0].total),
                pending_reports: parseInt(reportsResult.rows[0].count),
                // 新增功能统计
                activities_total:   parseInt(activitiesResult.rows[0].total),
                activities_active:  parseInt(activitiesResult.rows[0].active),
                charity_total:      parseInt(charityResult.rows[0].total),
                charity_available:  parseInt(charityResult.rows[0].available),
                storage_services:   parseInt(storageResult.rows[0].total),
                rental_items:       parseInt(rentalResult.rows[0].total),
                vouchers_unused:    parseInt(vouchersResult.rows[0].total),
                vouchers_amount:    parseFloat(vouchersResult.rows[0].sum_amount) || 0,
                storage_orders:     parseInt(storageOrdersResult.rows[0].total),
                rental_orders:      parseInt(rentalOrdersResult.rows[0].total),
                // 列表
                recent_items:   recentResult.rows,
                hot_items:      hotItemsResult.rows,
                // 图表数据
                category_dist:  categoryDistResult.rows,
                user_trend:     userTrendResult.rows,
                item_trend:     itemTrendResult.rows,
            }
        });
    } catch (error) {
        console.error('stats error:', error);
        res.status(500).json({ code: 1, message: '查询失败', data: null });
    }
});

module.exports = router;

