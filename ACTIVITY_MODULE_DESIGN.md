# 校园活动运营系统（Activity Module）技术设计方案

> **版本**：V1.0  
> **日期**：2026-07-16  
> **分支**：feature/activity-module  
> **状态**：待确认

---

## 目录

1. [需求概述](#1-需求概述)
2. [数据库设计](#2-数据库设计)
3. [数据关联方案分析](#3-数据关联方案分析)
4. [数据库迁移方案](#4-数据库迁移方案)
5. [后端接口设计](#5-后端接口设计)
6. [前端页面设计](#6-前端页面设计)
7. [核心业务逻辑](#7-核心业务逻辑)
8. [权限控制设计](#8-权限控制设计)
9. [业务流程图](#9-业务流程图)
10. [开发计划](#10-开发计划)
11. [涉及文件清单](#11-涉及文件清单)

---

## 1. 需求概述

### 1.1 功能目标

构建一个**数据库驱动的可扩展活动运营系统**，使平台能够根据校园时间节点灵活开展主题运营活动。所有活动由数据库管理，前端和后端动态读取，新增活动无需修改代码。

### 1.2 第一阶段支持的活动

| 活动名称 | 活动类型 | 典型时间 |
|----------|----------|----------|
| 毕业甩卖专场 | graduation_sale | 每年 5-7 月 |
| 新生淘货专区 | freshman_market | 每年 8-10 月 |
| 寒暑假闲置寄存/短期转租 | holiday_storage | 每年 1-2 月、7-8 月 |
| 考研资料专区 | exam_materials | 每年 3-5 月、9-12 月 |

### 1.3 扩展性要求

未来可增加：社团换届专区、双十一校园闲置节、教材回收专区等，**新增活动只需在后台配置，不修改任何代码**。

---

## 2. 数据库设计

### 2.1 新增表：activities（活动表）

```sql
CREATE TABLE IF NOT EXISTS activities (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,                          -- 活动名称
    type            VARCHAR(50)     NOT NULL,                          -- 活动类型标识
    description     TEXT,                                               -- 活动简介
    banner_url      VARCHAR(500),                                      -- Banner 图片 URL
    start_time      TIMESTAMP       NOT NULL,                          -- 活动开始时间
    end_time        TIMESTAMP       NOT NULL,                          -- 活动结束时间
    is_enabled      BOOLEAN         DEFAULT TRUE,                      -- 是否启用
    sort_order      INTEGER         DEFAULT 0,                         -- 排序权重（越大越靠前）
    created_by      INTEGER         REFERENCES users(id),              -- 创建人（管理员）
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_activities_time CHECK (end_time > start_time)       -- 结束时间必须晚于开始时间
);

-- 索引：加速按时间和启用状态查询（首页获取有效活动）
CREATE INDEX IF NOT EXISTS idx_activities_enabled_time
    ON activities(is_enabled, start_time, end_time);
```

### 2.2 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|:----:|------|
| `id` | SERIAL | - | 自增主键 |
| `name` | VARCHAR(100) | ✅ | 活动展示名称，如"毕业甩卖专场" |
| `type` | VARCHAR(50) | ✅ | 活动类型标识，用于前端样式区分，如 `graduation_sale` |
| `description` | TEXT | - | 活动简介，展示在活动详情页顶部 |
| `banner_url` | VARCHAR(500) | - | Banner 图片，建议尺寸 1200×300 |
| `start_time` | TIMESTAMP | ✅ | 活动开始时间，未到不展示 |
| `end_time` | TIMESTAMP | ✅ | 活动结束时间，过期自动下线 |
| `is_enabled` | BOOLEAN | - | 管理员手动控制启用/停用，默认启用 |
| `sort_order` | INTEGER | - | 排序权重，数值越大越靠前，用于首页多个活动同时有效时的排列 |
| `created_by` | INTEGER | - | 创建人ID，关联 users 表 |
| `created_at` | TIMESTAMP | - | 创建时间 |
| `updated_at` | TIMESTAMP | - | 更新时间 |

### 2.3 修改表：items 增加 activity_id

```sql
-- 在 items 表新增 activity_id 字段
ALTER TABLE items
    ADD COLUMN activity_id INTEGER REFERENCES activities(id) ON DELETE SET NULL;

-- 索引：加速按活动查询商品
CREATE INDEX IF NOT EXISTS idx_items_activity ON items(activity_id);
```

### 2.4 初始活动数据

```sql
INSERT INTO activities (name, type, description, start_time, end_time, is_enabled, sort_order, created_by)
VALUES
('毕业甩卖专场', 'graduation_sale',
 '毕业季大甩卖！书籍、电子产品、生活用品低价转让，助力学弟学妹轻松入学',
 '2026-05-01 00:00:00', '2026-07-31 23:59:59', TRUE, 1,
 (SELECT id FROM users WHERE username = 'admin' LIMIT 1)),

('新生淘货专区', 'freshman_market',
 '新生专属福利！学长学姐精选好物，教科书、宿舍用品一站购齐',
 '2026-08-01 00:00:00', '2026-10-31 23:59:59', TRUE, 2,
 (SELECT id FROM users WHERE username = 'admin' LIMIT 1)),

('考研资料专区', 'exam_materials',
 '考研路上不孤单！历年真题、复习笔记、参考教材，助你一战成硕',
 '2026-03-01 00:00:00', '2026-05-31 23:59:59', TRUE, 3,
 (SELECT id FROM users WHERE username = 'admin' LIMIT 1)),

('寒暑假闲置寄存', 'holiday_storage',
 '假期离校不用愁！闲置物品短期寄存/转租，省心又省钱',
 '2026-07-01 00:00:00', '2026-08-31 23:59:59', TRUE, 4,
 (SELECT id FROM users WHERE username = 'admin' LIMIT 1));
```

---

## 3. 数据关联方案分析

### 3.1 方案对比

| 对比维度 | 方案A：items 增加 activity_id | 方案B：activity_items 关联表 |
|----------|------------------------------|------------------------------|
| **实现复杂度** | 简单，一个字段 + 一个索引 | 较复杂，额外建表 + 联合主键 + 索引 |
| **查询性能** | 直接 JOIN，无中间表 | 多一层 JOIN，略慢 |
| **多活动支持** | 一个商品只能属于一个活动 | 一个商品可属于多个活动 |
| **数据一致性** | 直接外键约束 | 需额外处理重复关联 |
| **代码改动量** | 小 | 较大 |
| **与现有模式一致性** | 匹配（items 已有 category_id FK） | 类似 tags ↔ item_tags 模式 |
| **适用场景** | 商品按活动主题归类，互斥 | 同一商品同时出现在多个活动中 |

### 3.2 推荐方案：方案A（items 增加 activity_id）

**选择理由：**

1. **业务语义清晰**：一个商品在某个时间点只能属于一个运营活动。卖家发布商品时选择"参加哪个活动"，逻辑上就是互斥的（如同一个商品不可能同时是"毕业甩卖"又是"新生专区"）。
2. **与现有模式一致**：items 表已通过 `category_id` 外键关联分类，`activity_id` 遵循同样模式，团队理解和维护成本低。
3. **性能更优**：查询"某活动下的商品"只需一次 JOIN，无需穿越中间表。
4. **代码复用度高**：后端已有的商品查询逻辑（分页、筛选、排序）只需增加 `activity_id` 过滤条件即可复用。
5. **扩展性不降低**：如果未来确实需要"一个商品参与多个活动"，可以平滑升级为方案B（activity_id 改为关联表即可），因为前端接口参数和返回格式无需变化。

### 3.3 活动与商品的关系

```
activities (1) ──────< items (N)
     │
     │ 一个活动包含多个商品
     │ 一个商品最多属于一个活动（可为 NULL）
     │ 活动过期/停用 → 商品仍在平台，activity_id 保留但不展示活动标签
     │ 活动删除 → 商品 activity_id 自动置 NULL（ON DELETE SET NULL）
```

---

## 4. 数据库迁移方案

### 4.1 迁移文件

**文件路径**：`database/migrations/V002_activity.sql`

**内容概要**：

```sql
-- V002: 校园活动运营系统
-- 1. 创建 activities 表
-- 2. items 增加 activity_id 字段
-- 3. 插入初始活动数据
-- 4. 所有操作使用 IF NOT EXISTS / DO $$ 保证幂等性
```

### 4.2 迁移原则

- **不修改** `database/init.sql`（保持已有初始化脚本不变）
- **新增** `database/migrations/V002_activity.sql`
- **幂等性**：所有 DDL 使用 `IF NOT EXISTS` / `DO $$` 检查后执行
- **向后兼容**：`activity_id` 为可空字段，不影响现有商品数据
- **初始数据**：使用 `WHERE NOT EXISTS` 防止重复插入

---

## 5. 后端接口设计

### 5.1 接口总览

| 方法 | 路径 | 认证 | 说明 |
|------|------|:----:|------|
| GET | `/api/activities` | 无 | 获取当前有效活动列表（首页展示） |
| GET | `/api/activities/all` | 管理员 | 获取全部活动（后台管理） |
| GET | `/api/activities/:id` | 无 | 获取活动详情 |
| GET | `/api/activities/:id/items` | 无 | 获取活动下的商品列表 |
| POST | `/api/activities` | 管理员 | 新增活动 |
| PUT | `/api/activities/:id` | 管理员 | 修改活动 |
| PUT | `/api/activities/:id/toggle` | 管理员 | 启用/停用活动 |
| DELETE | `/api/activities/:id` | 管理员 | 删除活动 |
| POST | `/api/activities/upload-banner` | 管理员 | 上传活动 Banner |

### 5.2 接口详细说明

#### GET /api/activities — 获取当前有效活动

**说明**：首页调用，返回当前时间处于 `[start_time, end_time]` 区间且 `is_enabled = TRUE` 的活动，按 `sort_order DESC` 排序。

**请求参数**：无

**响应示例**：
```json
{
  "code": 0,
  "message": "success",
  "data": [
    {
      "id": 1,
      "name": "毕业甩卖专场",
      "type": "graduation_sale",
      "description": "毕业季大甩卖！...",
      "banner_url": "/uploads/activities/banner_1.jpg",
      "start_time": "2026-05-01T00:00:00.000Z",
      "end_time": "2026-07-31T23:59:59.000Z",
      "sort_order": 1,
      "item_count": 15
    }
  ]
}
```

**核心 SQL**：
```sql
SELECT a.*,
       (SELECT COUNT(*) FROM items WHERE activity_id = a.id AND status = 'on_sale') AS item_count
FROM activities a
WHERE a.is_enabled = TRUE
  AND a.start_time <= NOW()
  AND a.end_time >= NOW()
ORDER BY a.sort_order DESC;
```

#### GET /api/activities/all — 获取全部活动（管理员）

**请求参数**：`?page=1&pageSize=15`

**权限**：管理员/运营人员

#### GET /api/activities/:id — 活动详情

**说明**：返回活动基本信息 + 商品数量统计。

#### GET /api/activities/:id/items — 活动商品列表

**说明**：复用 items 表已有查询逻辑，增加 `activity_id` 过滤条件。支持分页、排序。

**请求参数**：`?page=1&pageSize=12&sort=newest`

**响应**：与 `GET /api/items` 格式完全一致（复用现有数据结构）

**核心 SQL**：
```sql
-- 完全复用现有 items 查询，仅增加 WHERE i.activity_id = $X
SELECT i.id, i.title, i.price, i.status, i.created_at, i.views_count, i.favorites_count,
       c.name AS category_name,
       u.username AS seller_name, u.campus AS seller_campus,
       (SELECT image_url FROM item_images WHERE item_id = i.id ORDER BY sort_order LIMIT 1) AS cover_image
FROM items i
LEFT JOIN categories c ON i.category_id = c.id
LEFT JOIN users u ON i.user_id = u.id
WHERE i.status = 'on_sale'
  AND i.activity_id = $1          -- ← 仅此行为新增过滤条件
ORDER BY i.created_at DESC
LIMIT $2 OFFSET $3;
```

#### POST /api/activities — 新增活动

**权限**：管理员/运营人员

**请求体**：
```json
{
  "name": "社团换届专区",
  "type": "club_transition",
  "description": "社团换届，闲置物资大转让",
  "banner_url": "/uploads/activities/banner_5.jpg",
  "start_time": "2026-09-01T00:00:00",
  "end_time": "2026-10-31T23:59:59",
  "sort_order": 5
}
```

#### PUT /api/activities/:id — 修改活动

**权限**：管理员/运营人员

#### PUT /api/activities/:id/toggle — 启用/停用

**权限**：管理员/运营人员  
**说明**：切换 `is_enabled` 状态，用于手动提前下线活动或重新上线。

#### DELETE /api/activities/:id — 删除活动

**权限**：管理员/运营人员  
**说明**：删除活动，关联商品的 `activity_id` 自动置 NULL（ON DELETE SET NULL）。

#### POST /api/activities/upload-banner — 上传 Banner

**权限**：管理员/运营人员  
**说明**：复用现有 `/api/upload` 的上传逻辑。

### 5.3 商品发布接口适配

修改 `POST /api/items` 和 `PUT /api/items/:id`：

- 接收可选字段 `activity_id`
- 仅当传入的 `activity_id` 对应的活动存在且有效（is_enabled=TRUE 且未过期）时才接受
- activity_id 可以为 null（不参加任何活动）

**注册到 app.js**：
```js
const activityRoutes = require('./routes/activities');
app.use('/api/activities', activityRoutes);
```

### 5.4 接口风格说明

所有接口严格遵循项目现有规范：
- 响应格式：`{ code: 0|1, message: string, data: any }`
- 认证中间件：`authenticate`（需登录）+ `adminOnly`（管理员）
- 分页参数：`page`, `pageSize`
- 错误处理：try-catch + console.error + 500 响应

---

## 6. 前端页面设计

### 6.1 用户端改动

#### 6.1.1 首页（`Home.vue`）— 增加活动专区

**位置**：在"近期热门"区域和"商品网格"之间插入"校园活动专区"

**UI 设计**：
```
┌──────────────────────────────────────────────────┐
│  校园活动专区                                      │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐  │
│  │  [Banner]   │ │  [Banner]   │ │  [Banner]   │  │
│  │  毕业甩卖专场 │ │  考研资料专区 │ │ 寒暑假闲置寄存│  │
│  │  15件商品    │ │  8件商品     │ │  5件商品     │  │
│  └─────────────┘ └─────────────┘ └─────────────┘  │
└──────────────────────────────────────────────────┘
```

**布局**：3 列网格布局（与 trending-grid 类似），每个活动卡片显示 Banner 图片、活动名称、商品数量。点击跳转至活动详情页。

**逻辑**：
- `onMounted` 时调用 `GET /api/activities` 获取当前有效活动
- 仅当 `activities.length > 0` 时渲染该区域
- 无需任何硬编码的活动判断（完全数据驱动）

#### 6.1.2 活动详情页（新增 `views/ActivityDetail.vue`）

**路由**：`/activity/:id`（name: `activityDetail`）

**页面结构**：
```
┌──────────────────────────────────────────────┐
│  活动 Banner（大图 1200×300）                   │
│  活动名称                                      │
│  活动简介 + 活动时间范围                         │
├──────────────────────────────────────────────┤
│  活动商品列表（复用 Home.vue 的商品网格 + 分页）   │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐        │
│  │ 商品1 │ │ 商品2 │ │ 商品3 │ │ 商品4 │        │
│  └──────┘ └──────┘ └──────┘ └──────┘        │
│  ...                                         │
│  [分页器]                                     │
└──────────────────────────────────────────────┘
```

**数据获取**：
- 活动信息：`GET /api/activities/:id`
- 商品列表：`GET /api/activities/:id/items?page=1&pageSize=12&sort=newest`

#### 6.1.3 发布/编辑商品页（`Publish.vue`）— 增加活动选择

**改动**：在表单中增加一个可选的"参加活动"下拉框：

- 调用 `GET /api/activities` 获取当前有效活动列表
- 下拉框 label："参加校园活动（可选）"
- 选项：第一项为"不参加活动"（值为空），后续为各有效活动名称

#### 6.1.4 路由配置修改（`router/index.js`）

新增路由：
```js
{
  path: 'activity/:id',
  name: 'activityDetail',
  component: () => import('@/views/ActivityDetail.vue'),
  meta: { keepAlive: true }
}
```

### 6.2 管理后台改动

#### 6.2.1 活动管理页（新增 `views/Activities.vue`）

**路由**：`/activities`（name: `activities`）

**页面结构**（参考 `Categories.vue` 风格）：

```
┌──────────────────────────────────────────────┐
│  活动管理                        [+ 新增活动]   │
├──────────────────────────────────────────────┤
│  el-table:                                   │
│  ┌─────────┬──────┬──────┬──────┬──────┬────┐│
│  │ 活动名称 │ 类型  │ 时间  │ 状态 │ 排序 │操作││
│  ├─────────┼──────┼──────┼──────┼──────┼────┤│
│  │毕业甩卖  │grad..│5/1-7/│ 启用 │  1   │...││
│  │新生专区  │fresh.│8/1-10│ 启用 │  2   │...││
│  └─────────┴──────┴──────┴──────┴──────┴────┘│
└──────────────────────────────────────────────┘
```

**表格列**：
- 活动名称（Banner 缩略图 + 名称）
- 活动类型标识
- 活动时间（start_time ~ end_time）
- 状态（启用/停用标签，自动根据时间显示"进行中"/"未开始"/"已结束"）
- 排序值
- 商品数量
- 操作（编辑、启用/停用、删除）

**新增/编辑弹窗**（el-dialog）：
- 活动名称（el-input）
- 活动类型标识（el-input，带提示）
- 活动简介（el-input type=textarea）
- Banner 上传（el-upload，复用现有上传逻辑）
- 开始时间（el-date-picker datetime）
- 结束时间（el-date-picker datetime）
- 排序值（el-input-number）

#### 6.2.2 侧边栏菜单修改（`MainLayout.vue`）

在"分类管理"后增加：
```html
<el-menu-item index="/activities">
  <el-icon><Calendar /></el-icon>
  <span>活动管理</span>
</el-menu-item>
```

#### 6.2.3 路由配置修改（`router/index.js`）

新增路由：
```js
{
  path: 'activities',
  name: 'activities',
  component: () => import('@/views/Activities.vue')
}
```

---

## 7. 核心业务逻辑

### 7.1 活动自动展示/隐藏机制

```
┌──────────────────────────────────────────────┐
│          数据库驱动的时间判断逻辑               │
│                                              │
│  GET /api/activities 查询条件：                │
│                                              │
│  WHERE is_enabled = TRUE                     │
│    AND start_time <= NOW()   ← 已开始         │
│    AND end_time >= NOW()     ← 未结束          │
│                                              │
│  结果：                                       │
│  ✅ 毕业甩卖 (5/1-7/31) → 当前7月 → 展示       │
│  ✅ 考研资料 (3/1-5/31) → 当前7月 → 不展示     │
│  ✅ 新生专区 (8/1-10/31) → 当前7月 → 不展示    │
│  ✅ 寒暑假   (7/1-8/31) → 当前7月 → 展示       │
└──────────────────────────────────────────────┘
```

**关键设计**：
- **无需代码判断**：不写任何 `if (now >= graduationDate)` 之类的硬编码
- **完全数据库驱动**：活动是否展示仅由 `is_enabled` + `start_time` + `end_time` 三个字段决定
- **提前创建**：管理员可提前创建未来活动（如 7 月就创建 9 月的活动），到 `start_time` 自动生效
- **自动下线**：超过 `end_time` 自动不展示，无需手动操作
- **手动干预**：管理员可通过 `is_enabled` 随时手动提前下线或重新上线

### 7.2 活动类型（type）字段的定位

`type` 字段**不是**用来做 `if-else` 判断的，而是用于：

1. **前端 UI 差异化**：不同活动类型可显示不同主题色/图标（纯 CSS 层面，不涉及逻辑分支）
2. **数据统计**：后台可以按活动类型统计商品数量、交易额等
3. **未来扩展**：如果后续某类活动需要特殊功能（如"短期转租"需要关联时间），可基于 type 做扩展

### 7.3 商品与活动的关系维护

- **发布时**：卖家可选择参加一个活动（可选）
- **编辑时**：可更换或取消活动参与
- **活动过期后**：商品的 `activity_id` 不自动清除（保留历史记录，但活动详情页不展示过期活动）
- **活动删除时**：`ON DELETE SET NULL`，商品保留但不属于任何活动

---

## 8. 权限控制设计

| 操作 | 用户 | 运营人员(operator) | 管理员(admin) |
|------|:----:|:----:|:----:|
| 查看有效活动列表 | ✅ | ✅ | ✅ |
| 查看活动详情 | ✅ | ✅ | ✅ |
| 查看活动下商品 | ✅ | ✅ | ✅ |
| 发布商品时选择活动 | ✅ | ✅ | ✅ |
| 管理后台查看全部活动 | ❌ | ✅ | ✅ |
| 新增活动 | ❌ | ✅ | ✅ |
| 修改活动 | ❌ | ✅ | ✅ |
| 启用/停用活动 | ❌ | ✅ | ✅ |
| 删除活动 | ❌ | ✅ | ✅ |
| 上传活动 Banner | ❌ | ✅ | ✅ |

**说明**：权限判断复用现有 `authenticate` + `adminOnly` 中间件模式。

---

## 9. 业务流程图

### 9.1 活动生命周期

```
管理员创建活动（设置 start_time, end_time）
              │
              ▼
    ┌─────────────────────┐
    │   未开始（待生效）     │ ← now < start_time
    │   前端不展示          │
    └─────────┬───────────┘
              │ 到达 start_time（自动）
              ▼
    ┌─────────────────────┐
    │   进行中（展示中）     │ ← start_time ≤ now ≤ end_time
    │   首页动态展示         │   且 is_enabled = TRUE
    │   商品可关联活动       │
    └─────────┬───────────┘
              │ 到达 end_time（自动）或管理员手动停用
              ▼
    ┌─────────────────────┐
    │   已结束（已下线）     │ ← now > end_time 或 is_enabled = FALSE
    │   首页不再展示         │
    │   已关联商品保留       │
    └─────────────────────┘
```

### 9.2 用户参与活动流程

```
用户进入首页
    │
    ▼
调用 GET /api/activities（自动筛选有效活动）
    │
    ▼
首页"校园活动专区"展示有效活动卡片
    │
    ▼
用户点击某个活动
    │
    ▼
进入活动详情页 /activity/:id
    │
    ├── 查看活动 Banner + 简介
    ├── 浏览活动商品列表（分页+排序）
    └── 点击商品进入商品详情 /item/:id → 购买流程
```

### 9.3 管理员配置流程

```
管理员登录后台
    │
    ▼
进入"活动管理"页面
    │
    ├── 新增活动
    │   ├── 填写名称、类型、简介
    │   ├── 上传 Banner
    │   ├── 设置开始/结束时间
    │   ├── 设置排序
    │   └── 保存 → 活动进入"待生效"状态
    │
    ├── 编辑活动（修改信息、时间、Banner）
    │
    ├── 启用/停用（手动控制）
    │
    └── 删除活动（关联商品自动解除）
```

---

## 10. 开发计划

### 阶段一：数据库层

| 步骤 | 内容 | 预计涉及 |
|------|------|----------|
| 1.1 | 编写 `database/migrations/V002_activity.sql` | 新文件 |
| 1.2 | 本地执行迁移，验证表结构和初始数据 | `npm run db:init` 或手动执行 |

### 阶段二：后端接口层

| 步骤 | 内容 | 涉及文件 |
|------|------|----------|
| 2.1 | 新建 `server/routes/activities.js` | 新文件 |
| 2.2 | 在 `server/app.js` 注册路由 | 修改 |
| 2.3 | 修改 `server/routes/items.js`（发布/编辑商品支持 activity_id） | 修改 |
| 2.4 | 本地测试所有接口（使用 curl 或 Postman） | - |

### 阶段三：用户端前端

| 步骤 | 内容 | 涉及文件 |
|------|------|----------|
| 3.1 | 新建 `client/user-app/src/views/ActivityDetail.vue` | 新文件 |
| 3.2 | 在 `router/index.js` 新增活动详情路由 | 修改 |
| 3.3 | 修改 `Home.vue`（增加活动专区区域） | 修改 |
| 3.4 | 修改 `Publish.vue`（增加活动选择下拉框） | 修改 |

### 阶段四：管理后台前端

| 步骤 | 内容 | 涉及文件 |
|------|------|----------|
| 4.1 | 新建 `client/vue-project/src/views/Activities.vue` | 新文件 |
| 4.2 | 在 `router/index.js` 新增活动管理路由 | 修改 |
| 4.3 | 在 `MainLayout.vue` 侧边栏增加菜单项 | 修改 |

### 阶段五：联调测试

| 步骤 | 内容 |
|------|------|
| 5.1 | 用户端首页活动展示验证 |
| 5.2 | 活动详情页商品列表验证 |
| 5.3 | 商品发布/编辑选择活动验证 |
| 5.4 | 后台活动管理 CRUD 验证 |
| 5.5 | 时间自动上/下线验证（修改数据库时间模拟） |

---

## 11. 涉及文件清单

### 新建文件（4个）

| 文件 | 说明 |
|------|------|
| `database/migrations/V002_activity.sql` | 活动系统数据库迁移 |
| `server/routes/activities.js` | 活动相关 API 路由 |
| `client/user-app/src/views/ActivityDetail.vue` | 用户端活动详情页 |
| `client/vue-project/src/views/Activities.vue` | 管理后台活动管理页 |

### 修改文件（7个）

| 文件 | 改动内容 |
|------|----------|
| `server/app.js` | 注册 `/api/activities` 路由 |
| `server/routes/items.js` | 发布/编辑接口支持 `activity_id` |
| `client/user-app/src/router/index.js` | 新增 `/activity/:id` 路由 |
| `client/user-app/src/views/Home.vue` | 增加活动专区区域 |
| `client/user-app/src/views/Publish.vue` | 增加活动选择下拉框 |
| `client/vue-project/src/router/index.js` | 新增 `/activities` 路由 |
| `client/vue-project/src/layouts/MainLayout.vue` | 侧边栏增加活动管理菜单项 |

### 受影响的已有文件（3个：需注意但可能无需大改）

| 文件 | 影响说明 |
|------|----------|
| `client/user-app/src/api/index.js` | 无需改动，活动接口复用同一 axios 实例 |
| `client/vue-project/src/api/index.js` | 无需改动 |
| `server/middlewares/auth.js` | 无需改动，复用 `authenticate` + `adminOnly` |

---

> 📄 设计文档完毕，待确认后开始逐步实现代码。  
> 🔍 开发将基于 `develop` 分支，创建 `feature/activity-module` 分支进行。
