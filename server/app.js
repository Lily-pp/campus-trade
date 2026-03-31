const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./routes/auth');
const itemRoutes = require('./routes/items');
const categoryRoutes = require('./routes/categories');
const favoriteRoutes = require('./routes/favorites');
const viewRoutes = require('./routes/views');
const statsRoutes = require('./routes/stats');
const userRoutes = require('./routes/users');

const app = express();

app.use(cors());
app.use(express.json());

app.use((req, res, next) => {
  console.log('[req]', req.method, req.originalUrl);
  next();
});

app.use('/api/auth', authRoutes);
app.use('/api/items', itemRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/favorites', favoriteRoutes);
app.use('/api/views', viewRoutes);
app.use('/api/stats', statsRoutes);
app.use('/api/users', userRoutes);

app.get('/', (req, res) => {
    res.json({ message: 'CampusTrade API 运行中' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 服务器运行在 http://localhost:${PORT}`);
});