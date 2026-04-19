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
    console.log('正在启动服务器...');
    console.log('正在检查数据库结构...');
    await ensureSchema();
    console.log('数据库结构检查完成');
    
    const server = app.listen(PORT, () => {
      console.log(`🚀 服务器运行在 http://localhost:${PORT}`);
      console.log('服务器启动成功，正在监听请求...');
    });
    
    server.on('error', (error) => {
      console.error('❌ 服务器运行错误:', error.message);
    });
    
    process.on('SIGINT', () => {
      console.log('正在关闭服务器...');
      server.close(() => {
        console.log('服务器已关闭');
        process.exit(0);
      });
    });
    
  } catch (error) {
    console.error('❌ 启动失败:', error.message);
    console.error('错误堆栈:', error.stack);
    process.exit(1);
  }
}

console.log('开始启动服务器...');
startServer();