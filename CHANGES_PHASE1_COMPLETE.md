# 第一阶段"节点化运营"完整开发变更说明

> **分支**: feature/activity-module  
> **日期**: 2026-07-17  
> **基于**: Activity Module V002

---

## 变更概览

本次开发完成了第一阶段"节点化运营"的全部功能：

### A 部分：官方补贴活动系统（V003）
- 官方补贴定价（自动降价10%）
- 校园代金券系统（抽奖 + 管理 + 使用）
- 考研资料专区扩展字段
- 活动详情增强（倒计时、补贴标签）

### B 部分：校园生活服务系统（V004）
- 寒暑假闲置寄存（服务 + 需求）
- 校园转租服务（物品租赁）

---

## 新建文件（12个）

| 文件 | 说明 |
|------|------|
| `database/migrations/V003_subsidy.sql` | 补贴系统迁移：activities扩展 + vouchers表 + items考研字段 |
| `database/migrations/V004_campus_services.sql` | 生活服务迁移：4张新表（寄存+转租） |
| `server/routes/vouchers.js` | 代金券API：列表、可用券、抽奖、使用 |
| `server/routes/storage.js` | 寄存API：服务+需求 CRUD |
| `server/routes/rental.js` | 转租API：物品列表+租赁订单 |
| `client/user-app/src/components/LotteryModal.vue` | 幸运转盘抽奖动画组件 |
| `client/user-app/src/views/StorageServices.vue` | 寄存服务浏览页 |
| `client/user-app/src/views/PublishStorage.vue` | 发布寄存服务/需求 |
| `client/user-app/src/views/RentalItems.vue` | 转租物品浏览页 |
| `client/user-app/src/views/PublishRental.vue` | 发布转租物品 |

## 修改文件（8个）

| 文件 | 改动内容 |
|------|----------|
| `server/app.js` | +6行：注册 vouchers/storage/rental 路由 |
| `server/routes/activities.js` | +20行：POST/PUT 支持补贴字段 |
| `server/routes/items.js` | +30行：display_price计算 + 考研字段 + 补贴活动校验 |
| `server/routes/orders.js` | +1行：返回 activity_id |
| `client/user-app/src/router/index.js` | +20行：新增5个路由 |
| `client/user-app/src/views/Home.vue` | +35行：补贴标签 + 校园生活服务入口 |
| `client/user-app/src/views/ActivityDetail.vue` | +30行：补贴横幅 + 毕业倒计时 |
| `client/user-app/src/views/Publish.vue` | +50行：补贴确认弹窗 + 考研字段 |
| `client/user-app/src/views/Profile.vue` | +40行：我的代金券Tab |
| `client/user-app/src/views/MyOrders.vue` | +15行：抽奖按钮 + LotteryModal |

---

## 数据库新增

### V003
- activities 新增5个字段：subsidy_enabled, subsidy_discount_rate, voucher_min_rate, voucher_max_rate, tagline
- 新增 vouchers 表
- items 新增4个字段：school, major, exam_year, is_landed

### V004
- 新增 storage_services 表
- 新增 storage_requests 表
- 新增 rental_items 表
- 新增 rental_orders 表

---

## API 新增

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/vouchers` | 我的代金券 |
| GET | `/api/vouchers/usable` | 可用代金券 |
| POST | `/api/vouchers/lottery/:orderId` | 抽奖 |
| PUT | `/api/vouchers/:id/use` | 使用代金券 |
| GET | `/api/storage-services` | 寄存服务列表 |
| GET | `/api/storage-services/:id` | 寄存服务详情 |
| POST | `/api/storage-services` | 发布寄存服务 |
| GET | `/api/storage-services/requests` | 寄存需求列表 |
| POST | `/api/storage-services/requests` | 发布寄存需求 |
| GET | `/api/rental-items` | 转租物品列表 |
| GET | `/api/rental-items/:id` | 转租物品详情 |
| POST | `/api/rental-items` | 发布转租 |
| POST | `/api/rental-items/orders` | 创建租赁订单 |

---

## 部署步骤

```bash
# 1. 执行数据库迁移
psql -h <host> -U campus_dev -d campus_trade_dev \
  -f database/migrations/V003_subsidy.sql \
  -f database/migrations/V004_campus_services.sql

# 2. 重启后端
cd server && npm run dev

# 3. 前端自动热更新（Vite HMR）
```
