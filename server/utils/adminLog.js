/**
 * 记录管理员操作日志
 * @param {object} db  - pg pool
 * @param {number} adminId
 * @param {string} action      - 操作标识，如 'delete_item' / 'freeze_user'
 * @param {string} targetType  - 'item' | 'user' | 'category' | 'order' | 'report'
 * @param {number} targetId
 * @param {object} detail      - 任意附加信息（会被 JSON.stringify）
 */
const logAdmin = async (db, adminId, action, targetType, targetId, detail = null) => {
    try {
        await db.query(
            'INSERT INTO admin_logs (admin_id, action, target_type, target_id, detail) VALUES ($1, $2, $3, $4, $5)',
            [adminId, action, targetType, targetId, detail ? JSON.stringify(detail) : null]
        );
    } catch (err) {
        // 日志失败不影响主流程
        console.error('[admin_log error]', err.message);
    }
};

module.exports = { logAdmin };
