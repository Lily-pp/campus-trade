# 校园二手交易平台 (CampusTrade) 项目分析报告

> **生成时间**：2026-07-16  
> **项目类型**：数据库原理课程设计  
> **Git 分支**：develop（主分支：main）

---

## 目录

1. [项目概览](#1-项目概览)
2. [前端技术栈](#2-前端技术栈)
3. [后端技术栈](#3-后端技术栈)
4. [数据库结构](#4-数据库结构)
5. [API 接口清单](#5-api-接口清单)
6. [当前已有功能](#6-当前已有功能)
7. [项目架构](#7-项目架构)
8. [性能优化](#8-性能优化)
9. [安全性分析](#9-安全性分析)
10. [存在的问题](#10-存在的问题)
11. [下一步开发建议](#11-下一步开发建议)

---

## 1. 项目概览

| 属性 | 说明 |
|------|------|
| **项目名称** | CampusTrade（校园二手交易平台） |
| **数据库** | OpenGauss（华为开源数据库，兼容 PostgreSQL 协议） |
| **运行端口** | 后端 `3000`，前端 Vite 默认端口 |
| **开发方式** | 前后端分离 |

### 项目目录结构

```
campus-trade/
├── client/
│   ├── vue-project/          # 管理后台
│   │   └── src/
│   │       ├── api/          # API 封装
│   │       ├── layouts/      # 布局组件
│   │       ├── router/       # 路由配置
│   │       ├── stores/       # Pinia 状态管理
│   │       └── views/        # 8个页面
│   └── user-app/             # 用户端
│       └── src/
│           ├── api/          # API 封装
│           ├── layouts/      # 布局组件
│           ├── router/       # 路由（含预加载逻辑）
│           ├── stores/       # Pinia（item + user）
│           ├── utils/        # 性能工具（防抖/节流）
│           └── views/        # 11个页面
├── server/                   # 后端
│   ├── config/               # 数据库连接
│   ├── middlewares/          # 认证中间件
│   ├── routes/               # 15个路由模块
│   ├── scripts/              # 数据库初始化脚本
│   ├── utils/                # JWT + 管理员日志
│   └── app.js                # 入口
└── database/
    ├── init.sql              # 初始化脚本（含测试数据）
    ├── migrations/           # 迁移文件
    └── README.md             # 版本管理规范
```

---

## 2. 前端技术栈

### 2.1 管理后台 (`client/vue-project`)

| 类别 | 技术 | 版本 |
|------|------|------|
| 框架 | **Vue 3** (Composition API) | 3.5.30 |
| 构建工具 | **Vite** | 7.3.1 |
| UI 组件库 | **Element Plus**（按需引入） | 2.13.6 |
| 状态管理 | **Pinia** | 3.0.4 |
| 路由 | **Vue Router** | 5.0.3 |
| HTTP | **Axios** | 1.13.6 |
| 测试（单元） | **Vitest** + @vue/test-utils | 4.0.18 |
| 测试（E2E） | **Playwright** | 1.58.2 |
| 代码检查 | **ESLint** + **Oxlint** + **Prettier** | - |

**管理后台页面（8个）**：

| 路由 | 页面 | 说明 |
|------|------|------|
| `/login` | Login.vue | 管理员登录 |
| `/dashboard` | Dashboard.vue | 数据仪表盘 |
| `/items` | Items.vue | 商品管理（审核、上下架） |
| `/categories` | Categories.vue | 分类管理 |
| `/users` | Users.vue | 用户管理 |
| `/orders` | Orders.vue | 订单管理 |
| `/reports` | Reports.vue | 举报处理 |
| `/logs` | Logs.vue | 操作日志 |

### 2.2 用户端 (`client/user-app`)

| 类别 | 技术 | 版本 |
|------|------|------|
| 框架 | **Vue 3** (Composition API) | 3.5.30 |
| 构建工具 | **Vite** | 6.3.5 |
| UI 组件库 | **Element Plus**（按需引入） | 2.13.6 |
| 状态管理 | **Pinia** | 3.0.4 |
| 路由 | **Vue Router** | 5.0.3 |
| HTTP | **Axios** | 1.13.6 |
| 实时通信 | **Socket.IO Client** | 4.8.3 |
| 图片 | **vue-lazyload** | 3.0.0 |

**用户端页面（11个）**：

| 路由 | 页面 | 权限 | 说明 |
|------|------|------|------|
| `/login` | Login.vue | 公开 | 登录 |
| `/register` | Register.vue | 公开 | 注册 |
| `/` | Home.vue | 公开 | 首页商品列表 |
| `/item/:id` | ItemDetail.vue | 公开 | 商品详情+评价 |
| `/publish` | Publish.vue | 需登录 | 发布商品 |
| `/cart` | Cart.vue | 需登录 | 购物车 |
| `/orders` | MyOrders.vue | 需登录 | 我的订单 |
| `/messages` | Messages.vue | 需登录 | 私信 |
| `/profile` | Profile.vue | 需登录 | 个人信息 |
| `/reports` | MyReports.vue | 需登录 | 我的举报 |

---

## 3. 后端技术栈

| 类别 | 技术 | 版本 |
|------|------|------|
| 运行时 | **Node.js** (CommonJS) | - |
| Web 框架 | **Express** | 5.2.1 |
| 数据库驱动 | **pg** (node-postgres) | 8.20.0 |
| 数据库 | **OpenGauss**（兼容 PostgreSQL） | - |
| 认证 | **JWT** (jsonwebtoken) | 9.0.3 |
| 密码加密 | **bcryptjs** | 3.0.3（⚠️ 已安装但未使用） |
| 实时通信 | **Socket.IO** | 4.8.3 |
| 文件上传 | **Multer** | 2.1.1 |
| 跨域 | **cors** | 2.8.6 |
| 环境变量 | **dotenv** | 17.3.1 |
| 开发工具 | **nodemon** | 3.1.14 |

### 启动流程

```
1. 加载 .env 环境变量
2. 连接 OpenGauss 数据库
3. ensureSchema() 自动检查/创建表结构
4. 启动 HTTP 服务器 (端口 3000)
5. Socket.IO 挂载到 HTTP 服务器
```

### JWT 认证流程

```
登录 → 验证用户名密码 → 签发 JWT (7天有效期)
请求 → Authorization: Bearer <token> → authenticate 中间件 → req.user
WebSocket → socket.handshake.auth.token → verifyToken → socket.userId
```

---

## 4. 数据库结构

### 4.1 数据库环境

| 配置项 | 值 |
|--------|-----|
| 类型 | OpenGauss（兼容 PostgreSQL） |
| 主机 | 111.229.206.203 |
| 端口 | 5432 |
| 数据库名 | campus_trade_dev |

### 4.2 数据表总览（13 张表）

| 表名 | 说明 | 核心字段 |
|------|------|----------|
| **users** | 用户表 | id, username, password, role(admin/operator/user), campus, status |
| **categories** | 分类表 | id, name, parent_id, sort_order |
| **items** | 商品表 | id, title, price, status(pending/on_sale/sold/off/rejected), is_approved, quantity, views_count, favorites_count, avg_rating, review_count |
| **item_images** | 商品图片 | id, item_id, image_url, sort_order |
| **tags** | 标签表 | id, name |
| **item_tags** | 商品标签关联 | item_id, tag_id (联合主键) |
| **favorites** | 收藏表 | user_id, item_id (联合主键) |
| **views_log** | 浏览记录 | id, user_id, item_id, viewed_at |
| **cart** | 购物车 | id, user_id, item_id (UNIQUE) |
| **orders** | 订单表 | id, item_id, buyer_id, seller_id, price, status(pending/paid/completed/cancelled/refunded) |
| **reviews** | 评价表 | id, item_id, order_id, rating(1-5), content |
| **reports** | 举报表 | id, reporter_id, target_type(item/user), reason, status |
| **messages** | 私信表 | id, sender_id, receiver_id, item_id, content, is_read |
| **admin_logs** | 操作日志 | id, admin_id, action, target_type, target_id, detail |

### 4.3 E-R 关系

```
users ──< items >── categories
  │        │
  │        ├──< item_images
  │        ├──< item_tags >── tags
  │        └──< reviews
  │
  ├──< favorites
  ├──< views_log
  ├──< cart
  ├──< orders (买家 + 卖家)
  ├──< reports (举报人 + 处理人)
  ├──< admin_logs
  └──< messages (发送 + 接收)

orders ──< reviews (每订单限评一次)
```

### 4.4 商品状态流转

```
pending(待审核) ──审核通过──→ on_sale(在售) ──售出──→ sold(已售)
     │                           │
     └──审核拒绝──→ rejected      └──下架──→ off ──重新上架──→ on_sale
```

### 4.5 数据库触发器（6个）

| 触发器 | 触发时机 | 功能 |
|--------|----------|------|
| `trg_favorites_after_insert` | 收藏后 | favorites_count +1 |
| `trg_favorites_after_delete` | 取消收藏 | favorites_count -1 |
| `trg_views_log_after_insert` | 浏览后 | views_count +1 |
| `trg_reviews_after_insert` | 评价后 | 重算 review_count, avg_rating |
| `trg_reviews_after_update` | 修改评分 | 重算 review_count, avg_rating |
| `trg_reviews_after_delete` | 删除评价 | 重算 review_count, avg_rating |

### 4.6 CHECK 约束（8个）

| 表 | 约束名 | 规则 |
|----|--------|------|
| items | chk_items_price_positive | price > 0 |
| items | chk_items_quantity_non_negative | quantity >= 0 |
| items | chk_items_favorites_count_non_negative | favorites_count >= 0 |
| items | chk_items_views_count_non_negative | views_count >= 0 |
| items | chk_items_status_valid | status IN ('pending','on_sale','sold','off','rejected') |
| reviews | chk_reviews_rating_range | rating BETWEEN 1 AND 5 |
| users | chk_users_role_valid | role IN ('user','admin','operator') |
| orders | chk_orders_status_valid | status IN ('pending','paid','completed','cancelled','refunded') |

---

## 5. API 接口清单

> 统一响应格式：`{ code: 0|1, message: string, data: any }`

### 5.1 认证 `/api/auth`

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| POST | `/api/auth/admin/login` | 无 | 管理员登录 |
| POST | `/api/auth/login` | 无 | 用户登录 |
| POST | `/api/auth/register` | 无 | 用户注册 |
| GET | `/api/auth/me` | Token | 当前用户信息 |

### 5.2 商品 `/api/items`

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| GET | `/api/items` | 无 | 商品列表（分页/分类/搜索/排序/标签） |
| GET | `/api/items/all` | 管理员 | 后台全部商品 |
| GET | `/api/items/my` | Token | 我的发布 |
| GET | `/api/items/:id` | 可选 | 商品详情 |
| GET | `/api/items/:id/tags` | 无 | 商品标签 |
| POST | `/api/items` | Token | 发布商品 |
| PUT | `/api/items/:id` | Token | 修改商品（仅本人） |
| PUT | `/api/items/:id/status` | Token | 更新状态 |
| DELETE | `/api/items/:id` | Token | 删除商品 |

### 5.3 订单 `/api/orders`

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| GET | `/api/orders/my` | Token | 我的订单（买家） |
| GET | `/api/orders/sold` | Token | 我卖出的（卖家） |
| POST | `/api/orders/buy` | Token | 直接购买（扣库存） |
| GET | `/api/orders` | 管理员 | 全部订单 |
| PUT | `/api/orders/:id/status` | 管理员 | 修改订单状态 |
| PUT | `/api/orders/:id/confirm` | Token | 确认收货 |
| PUT | `/api/orders/:id/cancel` | Token | 取消订单（恢复库存） |
| PUT | `/api/orders/:id/complete` | Token | 卖家确认完成 |

### 5.4 购物车 `/api/cart`

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| GET | `/api/cart` | Token | 我的购物车 |
| POST | `/api/cart` | Token | 加入购物车 |
| POST | `/api/cart/checkout` | Token | 批量下单 |
| DELETE | `/api/cart/:item_id` | Token | 移除商品 |

### 5.5 消息 `/api/messages`

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| GET | `/api/messages/conversations` | Token | 会话列表 |
| GET | `/api/messages/unread-count` | Token | 未读消息数 |
| GET | `/api/messages/:userId` | Token | 聊天记录 |
| POST | `/api/messages` | Token | 发送消息（WebSocket推送） |
| PUT | `/api/messages/read/:userId` | Token | 标记已读 |

### 5.6 评价 `/api/reviews`

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| GET | `/api/reviews/item/:itemId` | 无 | 商品评价列表 |
| GET | `/api/reviews/can-review/:itemId` | Token | 检查是否可评价 |
| POST | `/api/reviews` | Token | 提交评价 |
| DELETE | `/api/reviews/:id` | Token | 删除自己的评价 |

### 5.7 举报 `/api/reports`

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| POST | `/api/reports` | Token | 创建举报 |
| GET | `/api/reports` | 管理员 | 举报列表 |
| GET | `/api/reports/my` | Token | 我的举报历史 |
| PUT | `/api/reports/:id/handle` | 管理员 | 处理举报 |

### 5.8 推荐 `/api/recommendations`

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| GET | `/api/recommendations/trending` | 无 | 热门商品（近30天 Top4） |
| GET | `/api/recommendations/similar/:itemId` | 无 | 相关推荐（同分类±50%价格） |

### 5.9 其他

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| GET | `/api/categories` | 无 | 分类列表 |
| POST/ PUT/ DELETE | `/api/categories[/:id]` | 管理员 | 分类管理 |
| POST | `/api/upload` | Token | 图片上传 |
| GET | `/api/users` | 管理员 | 用户列表 |
| POST/ PUT/ DELETE | `/api/users[/:id/status]` | 管理员 | 用户管理 |
| GET | `/api/logs` | 管理员 | 操作日志 |
| GET | `/api/stats/dashboard` | 管理员 | Dashboard数据 |
| GET/ POST/ DELETE | `/api/favorites[/:item_id]` | Token | 收藏管理 |
| GET | `/api/views/:itemId` | 可选 | 记录浏览 |

---

## 6. 当前已有功能

### 6.1 用户端

| 模块 | 功能点 | 状态 |
|------|--------|:----:|
| **用户系统** | 注册、登录、JWT认证、角色区分 | ✅ |
| **商品浏览** | 分页列表、分类筛选、关键词搜索（标题+标签）、排序（最新/价格/最热）、标签过滤 | ✅ |
| **商品详情** | 图片展示、卖家信息、浏览量统计、评价列表、相关推荐 | ✅ |
| **商品发布** | 基本信息、多图片上传、自由标签、发布后待审核 | ✅ |
| **商品编辑** | 修改本人商品、修改后重置审核状态 | ✅ |
| **购物车** | 加入/移除、防重复、防自买、批量下单 | ✅ |
| **订单系统** | 直接购买、库存自动扣减、确认收货、取消订单（恢复库存）、卖家确认 | ✅ |
| **收藏** | 收藏/取消、触发器自动统计 | ✅ |
| **私信** | 会话列表（含未读数）、一对一聊天、关联商品、WebSocket实时推送 | ✅ |
| **评价** | 1-5星评分+文字、每订单限评一次、触发器自动统计 | ✅ |
| **举报** | 举报商品/用户、查看举报历史 | ✅ |

### 6.2 管理后台

| 模块 | 功能点 | 状态 |
|------|--------|:----:|
| **Dashboard** | 数据概览 | ✅ |
| **商品管理** | 全部商品列表、状态管理（审核/上下架/拒绝）、删除 | ✅ |
| **分类管理** | 增删改查 | ✅ |
| **用户管理** | 列表、新增、启用/禁用、删除 | ✅ |
| **订单管理** | 全部订单、状态修改 | ✅ |
| **举报处理** | 举报列表、处理操作（忽略/下架商品/冻结用户） | ✅ |
| **操作日志** | 管理员操作日志自动记录+查看 | ✅ |

---

## 7. 项目架构

```
┌─────────────────────────────────────────────┐
│                  客户端层                    │
│  ┌──────────────┐  ┌──────────────┐         │
│  │  vue-project  │  │   user-app    │         │
│  │  (管理后台)    │  │   (用户端)    │         │
│  └──────┬───────┘  └──────┬───────┘         │
│         │ Axios           │ Axios+Socket.IO │
└─────────┼─────────────────┼─────────────────┘
          │                 │
          ▼                 ▼
┌─────────────────────────────────────────────┐
│              API 层 (Express)                │
│  15个路由模块 | JWT认证 | Socket.IO实时推送   │
│              port: 3000                      │
└──────────────────┬──────────────────────────┘
                   │ pg
                   ▼
┌─────────────────────────────────────────────┐
│           数据层 (OpenGauss)                  │
│  13张表 | 6个触发器 | 8个CHECK约束 | 外键级联  │
└─────────────────────────────────────────────┘
```

---

## 8. 性能优化

| 优化项 | 方法 | 预期效果 |
|--------|------|----------|
| Element Plus 按需引入 | unplugin-vue-components | 包体积 -500KB+ |
| 图片懒加载 | vue-lazyload | 首屏 -30% |
| Gzip/Brotli 压缩 | vite-plugin-compression | 传输体积 -40% |
| 代码分割 | Vite manualChunks | 改进缓存效率 |
| 路由懒加载 | `() => import()` | 按需加载 |
| 路由预加载 | requestIdleCallback | 页面切换更快 |
| keep-alive | 高频页面缓存 | 避免重复渲染 |
| Pinia 数据缓存 | 5分钟 TTL | 重复访问秒开 |
| 防抖/节流 | 搜索500ms/筛选300ms | 减少API请求 |
| Terser 压缩 | 移除console/debugger | 生产代码更干净 |

---

## 9. 安全性分析

### 已实现的安全措施

- JWT 认证（7天有效期）
- 角色权限控制（admin/operator/user 三级）
- WebSocket 认证（连接时验证 JWT）
- 自买防护（不能购买/加入自己的商品）
- 操作归属校验（修改/删除时验证身份）
- 商品/订单状态机保护
- 管理员操作全量日志
- 库存校验
- 唯一约束（购物车防重复、评价防重复、用户名唯一）

### 存在的安全风险

| 风险 | 严重程度 | 说明 |
|------|:--------:|------|
| **密码明文存储** | 🔴 严重 | bcryptjs 已安装但未使用，密码直接明文比对 |
| CORS 全开 | 🟡 中等 | `origin: '*'` 允许任意来源 |
| 无请求频率限制 | 🟡 中等 | 登录/注册/发布等接口无 rate-limit |
| JWT Secret 硬编码 | 🟡 中等 | `.env` 中使用弱密钥 |

---

## 10. 存在的问题

| 问题 | 位置 | 严重程度 |
|------|------|:--------:|
| **密码明文比对** | `server/routes/auth.js:34,69` — `password !== user.password` | 🔴 严重 |
| **bcryptjs 未使用** | 依赖已安装但无任何调用 | 🔴 严重 |
| **init.sql 重复代码** | `database/init.sql:350-368` — 标签建表语句重复 | 🟡 中等 |
| **docker 文件为空** | `server/docker` | 🟢 低 |
| **缺少后端测试** | `server/` 无任何测试 | 🟡 中等 |
| **前端测试不足** | `vue-project` 仅有 1 个测试文件 | 🟢 低 |
| **无支付流程** | 订单缺 `paid` 状态的实际支付环节 | 🟡 中等 |
| **无审核通知** | 新商品发布后管理员无实时通知 | 🟢 低 |
| **无 API 文档** | 缺少 Swagger/OpenAPI | 🟢 低 |

---

## 11. 下一步开发建议

### 🔴 高优先级

| 序号 | 建议 | 说明 |
|:----:|------|------|
| 1 | **密码加密** | 使用 bcryptjs：注册时 `hashSync(password, 10)`，登录时 `compareSync(password, hash)` |
| 2 | **JWT Secret 强化** | 使用强随机密钥，`.env` 不提交到仓库 |
| 3 | **请求频率限制** | 引入 `express-rate-limit` 保护敏感接口 |
| 4 | **CORS 白名单** | 生产环境限制允许的前端域名 |
| 5 | **输入消毒** | 用户输入做 XSS 过滤 |

### 🟡 中优先级

| 序号 | 建议 | 说明 |
|:----:|------|------|
| 6 | **商品审核通知** | WebSocket 推送新商品通知给管理员 |
| 7 | **订单状态通知** | 订单变更时通知买卖双方 |
| 8 | **卖家信誉体系** | 基于 avg_rating + review_count 展示信用等级 |
| 9 | **首页优化** | Banner、最新发布、校区筛选 |
| 10 | **API 文档** | 引入 Swagger/OpenAPI |
| 11 | **TypeScript 迁移** | 从前端 jsconfig 逐步迁移到 tsconfig |

### 🟢 低优先级

| 序号 | 建议 | 说明 |
|:----:|------|------|
| 12 | **清理重复SQL** | 删除 `init.sql` 第 350-368 行重复代码 |
| 13 | **补充测试** | 后端 API 测试 + 前端组件测试 |
| 14 | **Docker 部署** | 编写 Dockerfile + docker-compose.yml |
| 15 | **数据库连接池调优** | 调整 pg.Pool 参数 |
| 16 | **WebP/AVIF 图片** | 上传时自动转码 |
| 17 | **性能监控** | 集成 Web Vitals |
| 18 | **支付集成** | 模拟支付或微信/支付宝 |

---

## 附录

### A. 测试账号

| 角色 | 用户名 | 密码 | 校区 |
|------|--------|------|------|
| 超级管理员 | admin | 123456 | - |
| 运营人员 | operator | 123456 | - |
| 普通用户 | zhangsan | 123456 | 沪东校区 |
| 普通用户 | lisi | 123456 | 延长校区 |
| 普通用户 | wangwu | 123456 | 宝山校区 |

### B. 启动命令

```bash
# 后端
cd server && npm install && npm run dev    # 端口 3000

# 管理后台
cd client/vue-project && npm install && npm run dev

# 用户端
cd client/user-app && npm install && npm run dev

# 数据库初始化
cd server && npm run db:init
```

---

> 📄 报告生成时间：2026-07-16 | 分析工具：Claude Code
