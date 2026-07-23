const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { authenticate } = require('../middlewares/auth');

// ==================== 1. 获取所有失物招领处 ====================
router.get('/points', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM lost_found_points WHERE is_active = TRUE ORDER BY id'
    );
    res.json({ code: 200, message: 'success', data: result.rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ code: 500, message: '获取招领处失败', data: null });
  }
});

// ==================== 2. 发布招领信息 ====================
router.post('/found', authenticate, async (req, res) => {
  try {
    const {
      title,
      description,
      category,
      found_location,
      placed_at_point_id,
      found_time,
      image_url,
      contact_phone,
      longitude,
      latitude
    } = req.body;

    console.log('收到坐标:', { longitude, latitude });

    if (!title || !description || !found_location || !found_time) {
      return res.status(400).json({ code: 400, message: '请填写完整信息', data: null });
    }

    const result = await pool.query(
      `INSERT INTO found_items 
       (finder_user_id, title, description, category, found_location, placed_at_point_id, found_time, image_url, contact_phone, longitude, latitude)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING *`,
      [req.user.id, title, description, category, found_location, placed_at_point_id, found_time, image_url, contact_phone, longitude, latitude]
    );

    res.json({ code: 200, message: '发布成功', data: result.rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ code: 500, message: '发布失败', data: null });
  }
});

// ==================== 3. 获取招领列表 ====================
router.get('/found', async (req, res) => {
  try {
    const { keyword = '', status = 'available', page = 1, pageSize = 10 } = req.query;
    const offset = (page - 1) * pageSize;

    let where = `WHERE f.status = $1`;
    const params = [status];

    if (keyword) {
      where += ` AND (f.title ILIKE $2 OR f.description ILIKE $2 OR f.found_location ILIKE $2)`;
      params.push(`%${keyword}%`);
    }

    const countResult = await pool.query(
      `SELECT COUNT(*) FROM found_items f ${where}`,
      params
    );

    params.push(pageSize, offset);
    const result = await pool.query(
      `SELECT f.*, u.username AS finder_name, p.name AS point_name
       FROM found_items f
       LEFT JOIN users u ON f.finder_user_id = u.id
       LEFT JOIN lost_found_points p ON f.placed_at_point_id = p.id
       ${where}
       ORDER BY f.found_time DESC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params
    );

    res.json({
      code: 200,
      message: 'success',
      data: {
        list: result.rows,
        total: parseInt(countResult.rows[0].count),
        page: parseInt(page),
        pageSize: parseInt(pageSize)
      }
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ code: 500, message: '获取列表失败', data: null });
  }
});

// ==================== 4. 发布丢失信息 ====================
router.post('/lost', authenticate, async (req, res) => {
  try {
    const {
      title,
      description,
      lost_location,
      lost_time,
      image_url,
      reward,
      contact_phone,
      longitude,
      latitude
    } = req.body;

    console.log('收到坐标:', { longitude, latitude });

    if (!title || !description || !lost_location || !lost_time) {
      return res.status(400).json({ code: 400, message: '请填写完整信息', data: null });
    }

    const result = await pool.query(
      `INSERT INTO lost_posts 
       (owner_user_id, title, description, lost_location, lost_time, image_url, reward, contact_phone, longitude, latitude)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
      [req.user.id, title, description, lost_location, lost_time, image_url, reward || 0, contact_phone, longitude, latitude]
    );

    res.json({ code: 200, message: '发布成功', data: result.rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ code: 500, message: '发布失败', data: null });
  }
});

// ==================== 5. 获取丢失列表 ====================
router.get('/lost', async (req, res) => {
  try {
    const { keyword = '', status = 'open', page = 1, pageSize = 10 } = req.query;
    const offset = (page - 1) * pageSize;

    let where = `WHERE l.status = $1`;
    const params = [status];

    if (keyword) {
      where += ` AND (l.title ILIKE $2 OR l.description ILIKE $2 OR l.lost_location ILIKE $2)`;
      params.push(`%${keyword}%`);
    }

    const countResult = await pool.query(
      `SELECT COUNT(*) FROM lost_posts l ${where}`,
      params
    );

    params.push(pageSize, offset);
    const result = await pool.query(
      `SELECT l.*, u.username AS owner_name
       FROM lost_posts l
       LEFT JOIN users u ON l.owner_user_id = u.id
       ${where}
       ORDER BY l.lost_time DESC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params
    );

    res.json({
      code: 200,
      message: 'success',
      data: {
        list: result.rows,
        total: parseInt(countResult.rows[0].count),
        page: parseInt(page),
        pageSize: parseInt(pageSize)
      }
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ code: 500, message: '获取列表失败', data: null });
  }
});

// ==================== 6. 删除自己的招领信息 ====================
router.delete('/found/:id', authenticate, async (req, res) => {
  try {
    const id = parseInt(req.params.id)
    const userId = req.user.id

    const check = await pool.query(
      'SELECT finder_user_id FROM found_items WHERE id = $1',
      [id]
    )

    if (check.rows.length === 0) {
      return res.status(404).json({ code: 404, message: '记录不存在' })
    }

    if (check.rows[0].finder_user_id !== userId) {
      return res.status(403).json({ code: 403, message: '无权删除他人的记录' })
    }

    await pool.query('DELETE FROM found_items WHERE id = $1', [id])

    res.json({ code: 200, message: '删除成功' })
  } catch (err) {
    console.error(err)
    res.status(500).json({ code: 500, message: '删除失败' })
  }
})

// ==================== 7. 删除自己的丢失信息 ====================
router.delete('/lost/:id', authenticate, async (req, res) => {
  try {
    const id = parseInt(req.params.id)
    const userId = req.user.id

    const check = await pool.query(
      'SELECT owner_user_id FROM lost_posts WHERE id = $1',
      [id]
    )

    if (check.rows.length === 0) {
      return res.status(404).json({ code: 404, message: '记录不存在' })
    }

    if (check.rows[0].owner_user_id !== userId) {
      return res.status(403).json({ code: 403, message: '无权删除他人的记录' })
    }

    await pool.query('DELETE FROM lost_posts WHERE id = $1', [id])

    res.json({ code: 200, message: '删除成功' })
  } catch (err) {
    console.error(err)
    res.status(500).json({ code: 500, message: '删除失败' })
  }
})

module.exports = router;