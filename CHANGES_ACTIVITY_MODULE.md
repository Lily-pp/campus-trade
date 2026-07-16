# Activity Module 开发变更说明

> **分支**：feature/activity-module  
> **日期**：2026-07-16  
> **功能**：校园活动运营系统（节点化运营）第一阶段

---

## 变更概览

本次开发实现了完整的校园活动运营系统，所有活动由数据库驱动，新增活动无需修改代码。

---

## 新建文件（4个）

| 文件 | 说明 |
|------|------|
| `database/migrations/V002_activity.sql` | 数据库迁移：activities 表 + items.activity_id + 初始数据 |
| `server/routes/activities.js` | 9 个活动 API 接口（6个公开 + 3个管理员） |
| `client/user-app/src/views/ActivityDetail.vue` | 用户端活动详情页（Banner + 商品列表 + 排序） |
| `client/vue-project/src/views/Activities.vue` | 管理后台活动管理页（CRUD + 启用/停用 + 表格） |

## 修改文件（7个）

| 文件 | 改动内容 |
|------|----------|
| `server/app.js` | +2 行：注册 `/api/activities` 路由 |
| `server/routes/items.js` | +16 行：POST/PUT 支持 `activity_id`，含活动有效性校验 |
| `client/user-app/src/router/index.js` | +6 行：新增 `/activity/:id` 路由 + 预加载 |
| `client/user-app/src/views/Home.vue` | +40 行：新增「校园活动专区」区域（数据驱动，自动展示有效活动） |
| `client/user-app/src/views/Publish.vue` | +15 行：新增「参加活动」下拉选择框 |
| `client/vue-project/src/router/index.js` | +5 行：新增 `/activities` 路由 |
| `client/vue-project/src/layouts/MainLayout.vue` | +6 行：侧边栏新增「活动管理」菜单项 |

---

## 数据库变更

### 新增表：activities

- 11 个字段，含 CHECK 约束（end_time > start_time）
- 索引：`idx_activities_enabled_time`（加速首页有效活动查询）

### 修改表：items

- 新增 `activity_id` 字段（可空外键，ON DELETE SET NULL）
- 索引：`idx_items_activity`

### 初始数据

插入 4 个第一阶段活动：毕业甩卖专场、新生淘货专区、考研资料专区、寒暑假闲置寄存

---

## API 接口

| 方法 | 路径 | 认证 | 说明 |
|------|------|:----:|------|
| GET | `/api/activities` | 无 | 获取当前有效活动（首页） |
| GET | `/api/activities/all` | 管理员 | 全部活动（后台） |
| GET | `/api/activities/:id` | 无 | 活动详情 |
| GET | `/api/activities/:id/items` | 无 | 活动商品列表（分页+排序） |
| POST | `/api/activities` | 管理员 | 新增活动 |
| PUT | `/api/activities/:id` | 管理员 | 修改活动 |
| PUT | `/api/activities/:id/toggle` | 管理员 | 启用/停用 |
| DELETE | `/api/activities/:id` | 管理员 | 删除活动 |

---

## 核心设计决策

- **数据关联**：items 表增加 `activity_id`（方案A），一个商品属于一个活动
- **时间逻辑**：`WHERE is_enabled=TRUE AND start_time<=NOW() AND end_time>=NOW()` 完全数据库驱动
- **扩展方式**：管理员在后台新增活动即可，零代码修改
- **商品发布**：activity_id 为可选项，验证活动存在且启用才接受

## 部署步骤

1. 执行数据库迁移：`psql -h <host> -U campus_dev -d campus_trade_dev -f database/migrations/V002_activity.sql`
2. 重启后端：`cd server && npm run dev`
3. 前端无需额外操作（Vite HMR 自动更新）

## 测试验证

- [ ] 首页展示有效活动（当前7月应展示：毕业甩卖、寒暑假闲置寄存）
- [ ] 首页不展示已过期活动（考研资料 3-5月不应展示）
- [ ] 首页不展示未开始活动（新生专区 8-10月不应展示）
- [ ] 点击活动卡片进入活动详情页
- [ ] 活动详情页展示 Banner、简介、商品列表
- [ ] 活动商品列表支持分页和排序
- [ ] 发布商品时可选择参加活动
- [ ] 编辑商品时可更换活动
- [ ] 管理后台：新增/编辑/删除活动
- [ ] 管理后台：启用/停用活动
- [ ] 停用活动后首页不再展示
