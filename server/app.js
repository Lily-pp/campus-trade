const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRoutes      = require('./routes/auth');
const itemRoutes      = require('./routes/items');
const categoryRoutes  = require('./routes/categories');
const favoriteRoutes  = require('./routes/favorites');
const viewRoutes      = require('./routes/views');
const statsRoutes     = require('./routes/stats');
const userRoutes      = require('./routes/users');
const orderRoutes     = require('./routes/orders');
const reportRoutes    = require('./routes/reports');
const logRoutes       = require('./routes/logs');
const cartRoutes      = require('./routes/cart');
const uploadRoutes    = require('./routes/upload');
const messageRoutes   = require('./routes/messages');
const { ensureSchema } = require('./scripts/ensure-schema');

const path = require('path');
const app = express();

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.use((req, res, next) => {
  console.log('[req]', req.method, req.originalUrl);
  next();
});

app.use('/api/auth',       authRoutes);
app.use('/api/items',      itemRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/favorites',  favoriteRoutes);
app.use('/api/views',      viewRoutes);
app.use('/api/stats',      statsRoutes);
app.use('/api/users',      userRoutes);
app.use('/api/orders',     orderRoutes);
app.use('/api/reports',    reportRoutes);
app.use('/api/logs',       logRoutes);
app.use('/api/cart',       cartRoutes);
app.use('/api/upload',     uploadRoutes);
app.use('/api/messages',   messageRoutes);

app.get('/', (req, res) => {
    res.json({ message: 'CampusTrade API 运行中' });
});

const PORT = process.env.PORT || 3000;

async function startServer() {
  try {
    await ensureSchema();
    app.listen(PORT, () => {
      console.log(`🚀 服务器运行在 http://localhost:${PORT}`);
    });
  } catch (error) {
    console.error('❌ 启动失败，数据库结构检查未通过:', error.message);
    process.exit(1);
  }
}

startServer();