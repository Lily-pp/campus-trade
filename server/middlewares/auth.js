const { verifyToken } = require('../utils/jwt');

const authenticate = (req, res, next) => {
    const authHeader = req.headers.authorization;
    console.log('Auth middleware triggered for:', req.method, req.originalUrl);
    console.log('Auth header:', authHeader);
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        console.log('No auth header or not Bearer');
        return res.status(401).json({ error: '未登录' });
    }

    const token = authHeader.split(' ')[1];
    console.log('Token:', token);
    const decoded = verifyToken(token);

    if (!decoded) {
        console.log('Token verification failed');
        return res.status(401).json({ error: '登录已过期' });
    }

    console.log('Token valid, user:', decoded);
    req.user = decoded;
    next();
};

module.exports = { authenticate };