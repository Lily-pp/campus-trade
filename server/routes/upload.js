const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const db = require('../config/db');
const { authenticate } = require('../middlewares/auth');

// 确保上传目录存在
const uploadDir = path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

// 配置 multer
const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, uploadDir),
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = path.extname(file.originalname);
        cb(null, uniqueSuffix + ext);
    }
});

const fileFilter = (req, file, cb) => {
    const allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    if (allowedTypes.includes(file.mimetype)) {
        cb(null, true);
    } else {
        cb(new Error('仅支持 jpg/png/gif/webp 格式'), false);
    }
};

const upload = multer({
    storage,
    fileFilter,
    limits: { fileSize: 5 * 1024 * 1024 } // 5MB
});

// ── POST /api/upload  上传图片（单张）──
router.post('/', authenticate, upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ code: 1, message: '请选择图片文件', data: null });
        }

        const url = `/uploads/${req.file.filename}`;
        res.json({ code: 0, message: '上传成功', data: { url } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '上传失败', data: null });
    }
});

// ── POST /api/upload/multiple  上传图片（多张，最多6张）──
router.post('/multiple', authenticate, upload.array('files', 6), async (req, res) => {
    try {
        if (!req.files || req.files.length === 0) {
            return res.status(400).json({ code: 1, message: '请选择图片文件', data: null });
        }

        const urls = req.files.map(f => `/uploads/${f.filename}`);
        res.json({ code: 0, message: '上传成功', data: { urls } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ code: 1, message: '上传失败', data: null });
    }
});

// multer 错误处理
router.use((err, req, res, next) => {
    if (err instanceof multer.MulterError) {
        if (err.code === 'LIMIT_FILE_SIZE') {
            return res.status(400).json({ code: 1, message: '文件不能超过 5MB', data: null });
        }
        return res.status(400).json({ code: 1, message: err.message, data: null });
    }
    if (err) {
        return res.status(400).json({ code: 1, message: err.message, data: null });
    }
    next();
});

module.exports = router;
