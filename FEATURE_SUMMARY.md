# 校园二手交易平台 — 第一阶段节点化运营 功能总览

> 分支：feature/activity-module | 日期：2026-07-20
> 迁移文件：V002_plus.sql（合并 V003~V009）

---

## 一、功能模块总览

```
CampusTrade 节点化运营
│
├── 🎓 校园活动运营
│   ├── 毕业甩卖专场
│   ├── 新生淘货专区
│   ├── 考研资料专区
│   ├── 官方补贴系统（降价+代金券+抽奖）
│   └── 毕业季公益循环计划
│
├── 🏠 校园生活服务
│   ├── 寒暑假闲置寄存（服务+需求+预约）
│   └── 校园转租服务（物品租赁）
│
├── 👤 用户端
│   ├── 首页：活动专区 + 生活服务入口 + 公益入口
│   ├── 我的：商品/寄存/转租/代金券/公益积分
│   ├── 订单：买到/卖出/预约寄存/接单寄存/租赁
│   └── 私信：商品/寄存/转租 联系
│
└── 🔧 管理后台
    ├── operator：商品审核 + 活动管理 + 校园服务管理 + 公益管理
    └── admin：operator全部权限 + 用户/订单/举报/日志管理
```

---

## 二、数据库变更

| 迁移文件 | 内容 |
|------|------|
| V001_init.sql | 初始库结构（13张表 + 种子数据） |
| V002_activity.sql | activities 表 + items.activity_id |
| **V002_plus.sql** | 以下所有合并： |
| _V003_ | activities 补贴字段 + vouchers 表 + items 考研字段 |
| _V004_ | storage_services/requests + rental_items/orders |
| _V005_ | 种子数据 + holiday_storage 清理 |
| _V006_ | storage 扩展字段 + 转租种子数据 + 购物车 + 代金券 + admin fix |
| _V007_ | admin/operator 登录修复 + rental_items.contact_info + 冲突数据清理 |
| _V008_ | storage_orders 表 + is_approved 审核字段 + 订单测试数据 |
| _V009_ | items.item_type/free_deadline + free_apply + donation_record + users.charity_points + price>=0 约束 |

**现有全部表（21张）**：

users, categories, items, item_images, tags, item_tags, favorites, views_log, cart, orders, reviews, reports, messages, admin_logs, activities, vouchers, storage_services, storage_requests, storage_orders, rental_items, rental_orders, free_apply, donation_record

---

## 三、后端路由与 API 总览

### 3.1 用户认证 `server/routes/auth.js`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/auth/login` | 用户登录 |
| POST | `/api/auth/register` | 用户注册 |
| POST | `/api/auth/admin/login` | 管理员登录 |
| GET | `/api/auth/me` | 当前用户信息（含 charity_points） |

### 3.2 商品 `server/routes/items.js`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/items` | 商品列表（排除公益商品），支持 display_price |
| GET | `/api/items/all` | 后台全部商品（含 activity_name） |
| GET | `/api/items/my` | 我的发布 |
| GET | `/api/items/:id` | 商品详情（含补贴价） |
| POST | `/api/items` | 发布商品（支持 activity_id, item_type, 考研字段） |
| PUT | `/api/items/:id` | 修改商品 |
| PUT | `/api/items/:id/status` | 状态变更 |
| DELETE | `/api/items/:id` | 删除 |

### 3.3 活动 `server/routes/activities.js`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/activities` | 当前有效活动（首页） |
| GET | `/api/activities/all` | 全部活动（admin/operator） |
| GET | `/api/activities/:id` | 活动详情 |
| GET | `/api/activities/:id/items` | 活动商品列表 |
| POST | `/api/activities` | 新增活动 |
| PUT | `/api/activities/:id` | 修改活动 |
| PUT | `/api/activities/:id/toggle` | 启用/停用 |
| DELETE | `/api/activities/:id` | 删除 |

### 3.4 代金券 `server/routes/vouchers.js`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/vouchers` | 我的代金券 |
| GET | `/api/vouchers/usable` | 可用代金券 |
| POST | `/api/vouchers/lottery/:orderId` | 抽奖 |
| PUT | `/api/vouchers/:id/use` | 使用代金券 |

### 3.5 寄存服务 `server/routes/storage.js`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/storage-services` | 服务列表（审核通过的） |
| GET | `/api/storage-services/:id` | 服务详情 |
| POST | `/api/storage-services` | 发布（待审核） |
| PUT | `/api/storage-services/:id` | 修改 |
| PUT | `/api/storage-services/:id/approve` | 审核 |
| DELETE | `/api/storage-services/:id` | 删除 |
| GET | `/api/storage-requests` | 需求列表 |
| GET | `/api/storage-requests/:id` | 需求详情 |
| POST | `/api/storage-requests` | 发布需求 |
| PUT | `/api/storage-requests/:id` | 修改 |
| PUT | `/api/storage-requests/:id/approve` | 审核 |
| DELETE | `/api/storage-requests/:id` | 删除 |
| POST | `/api/storage-orders` | 创建寄存预约 |
| GET | `/api/storage-orders/my` | 我的寄存订单 |
| GET | `/api/storage-orders` | 全部寄存订单（admin） |

### 3.6 转租 `server/routes/rental.js`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/rental-items` | 物品列表 |
| GET | `/api/rental-items/:id` | 物品详情 |
| POST | `/api/rental-items` | 发布 |
| PUT | `/api/rental-items/:id/approve` | 审核 |
| PUT | `/api/rental-items/:id` | 修改 |
| DELETE | `/api/rental-items/:id` | 删除 |
| POST | `/api/rental-items/orders` | 创建租赁订单 |
| GET | `/api/rental-items/orders/my` | 我的租赁 |
| GET | `/api/rental-items/orders` | 全部租赁（admin） |

### 3.7 公益 `server/routes/charity.js`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/charity/items` | 公益商品列表 |
| GET | `/api/charity/items/:id` | 商品详情 |
| POST | `/api/charity/apply` | 申请领取 |
| GET | `/api/charity/applies/my` | 我的申请 |
| PUT | `/api/charity/apply/:id` | 处理申请 |
| GET | `/api/charity/recycle-pool` | 回收池（admin） |
| GET | `/api/charity/donations` | 捐赠记录（admin） |
| POST | `/api/charity/donations` | 批量捐赠（admin） |
| GET | `/api/charity/stats` | 公益统计 |

### 3.8 推荐 + 统计

| 文件 | 方法 | 路径 | 说明 |
|------|------|------|------|
| `recommendations.js` | GET | `/api/recommendations/trending` | 热门商品 |
| `recommendations.js` | GET | `/api/recommendations/similar/:id` | 相关推荐 |
| `stats.js` | GET | `/api/stats` | Dashboard 统计 |

---

## 四、前端文件对照

### 4.1 用户端 `client/user-app/src/`

| 文件 | 功能模块 | 说明 |
|------|----------|------|
| **views/Home.vue** | 首页 | 商品列表 + 活动专区 + 生活服务入口 + 公益入口 |
| **views/ActivityDetail.vue** | 活动详情 | Banner + 补贴横幅 + 倒计时 + 商品网格 |
| **views/Publish.vue** | 发布 | 商品类型切换 + 补贴确认 + 考研字段 + 活动选择 |
| **views/Profile.vue** | 个人中心 | 发布/收藏/浏览/代金券/寄存/转租/公益积分 |
| **views/MyOrders.vue** | 我的订单 | 买到/卖出/预约寄存/接单寄存/租赁 + 抽奖 |
| **views/Messages.vue** | 私信 | 已有 |
| **views/Login.vue** | 登录 | 已有 |
| **views/Register.vue** | 注册 | 已有 |
| **views/Cart.vue** | 购物车 | 已有 |
| **views/ItemDetail.vue** | 商品详情 | 已有 |
| **views/StorageService.vue** | 寄存服务 | 浏览 + 联系 + 预约 |
| **views/StorageRequest.vue** | 寄存需求 | 浏览 + 联系 + 接单 |
| **views/PublishStorage.vue** | 发布寄存 | 服务/需求切换 |
| **views/RentalItems.vue** | 转租浏览 | 卡片 + 联系 + 下单租赁 |
| **views/PublishRental.vue** | 发布转租 | 表单 |
| **views/GraduationCharity.vue** | 公益计划 | 免费商品 + 申请 + 领取管理 |
| **components/LotteryModal.vue** | 抽奖 | 幸运转盘动画 |
| **stores/user.js** | 用户状态 | Pinia |
| **stores/item.js** | 商品缓存 | Pinia 5min TTL |
| **utils/performance.js** | 性能 | 防抖/节流 |
| **router/index.js** | 路由 | 所有路由配置 |
| **api/index.js** | API | axios 实例 |

### 4.2 管理后台 `client/vue-project/src/`

| 文件 | 功能模块 | 说明 |
|------|----------|------|
| **views/Dashboard.vue** | 数据统计 | 基础+运营双行统计卡片 |
| **views/Items.vue** | 商品管理 | 筛选+审核+活动列 |
| **views/Categories.vue** | 分类管理 | 树形表格 |
| **views/Activities.vue** | 活动管理 | 展开商品+补贴配置+CRUD |
| **views/Users.vue** | 用户管理 | admin only |
| **views/Orders.vue** | 订单管理 | admin only |
| **views/Reports.vue** | 举报管理 | admin only |
| **views/Logs.vue** | 操作日志 | admin only |
| **views/CampusServices.vue** | 校园服务管理 | 寄存/需求/转租/订单 四Tab |
| **views/CharityManagement.vue** | 公益管理 | 商品/回收池/捐赠三Tab |
| **layouts/MainLayout.vue** | 侧边栏 | 角色菜单区分 |
| **router/index.js** | 路由 | 角色守卫 |
| **api/index.js** | API | axios 实例 |

---

## 五、用户端路由一览

| 路径 | 页面 | 权限 |
|------|------|:--:|
| `/` | 首页 | 公开 |
| `/login` | 登录 | 公开 |
| `/register` | 注册 | 公开 |
| `/item/:id` | 商品详情 | 公开 |
| `/activity/:id` | 活动详情 | 公开 |
| `/charity` | 毕业公益循环计划 | 公开 |
| `/storage-services` | 寄存服务 | 公开 |
| `/storage-requests` | 寄存需求 | 公开 |
| `/rental-items` | 校园转租 | 公开 |
| `/publish` | 发布商品 | 需登录 |
| `/publish-storage` | 发布寄存 | 需登录 |
| `/publish-rental` | 发布转租 | 需登录 |
| `/cart` | 购物车 | 需登录 |
| `/orders` | 我的订单 | 需登录 |
| `/messages` | 私信 | 需登录 |
| `/profile` | 个人中心 | 需登录 |
| `/reports` | 我的举报 | 需登录 |

## 六、管理后台路由一览

| 路径 | 页面 | operator | admin |
|------|------|:--:|:--:|
| `/login` | 登录 | ✅ | ✅ |
| `/dashboard` | 数据统计 | ✅ | ✅ |
| `/items` | 商品管理 | ✅ | ✅ |
| `/categories` | 分类管理 | ✅ | ✅ |
| `/activities` | 活动管理 | ✅ | ✅ |
| `/campus-services` | 校园服务管理 | ✅ | ✅ |
| `/charity` | 公益管理 | ✅ | ✅ |
| `/users` | 用户管理 | ❌ | ✅ |
| `/orders` | 订单管理 | ❌ | ✅ |
| `/reports` | 举报管理 | ❌ | ✅ |
| `/logs` | 操作日志 | ❌ | ✅ |

---

## 七、部署

```bash
# 数据库（本地新库一次性执行）
psql -h localhost -p 5433 -U gaussdb -d campus_trade_local \
  -f database/init.sql \
  -f database/migrations/V001_init.sql \
  -f database/migrations/V002_activity.sql \
  -f database/migrations/V002_plus.sql

# 或已有数据库只执行增量
psql -h localhost -p 5433 -U gaussdb -d campus_trade_local \
  -f database/migrations/V002_plus.sql

# 后端
cd server && npm run dev

# 用户端
cd client/user-app && npm run dev

# 管理后台
cd client/vue-project && npm run dev
```
