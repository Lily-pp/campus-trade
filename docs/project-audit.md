# CampusTrade 完整项目分析报告

> 审计日期：2026-07-23  
> 审计范围：当前工作区的 README、双端前端、后端、配置、路由、API、数据库初始化脚本与 V001–V009 迁移文件  
> 审计方式：静态代码审阅；未连接数据库、未启动服务、未执行迁移、未修改业务代码  
> 项目定位：校园二手交易平台，《计算机应用大型作业》课程项目

## 0. 执行摘要

CampusTrade 是一个前后端分离的校园交易与校园生活服务平台。项目已不只是基础二手交易：它还包含活动补贴、代金券抽奖、即时私信、寄存、租赁和毕业公益循环等模块，课程展示素材较丰富。

当前最需要优先处理的不是继续堆功能，而是统一数据库基线、移除敏感/生成文件、修正权限边界，并形成可重复的一键部署流程。

主要结论：

- 用户端、管理端和 Express API 的主链路齐全。
- 数据库设计最终涉及 **23 张业务表**，但基础初始化脚本只覆盖其中 14 张；其余表依赖后续迁移。
- `database/init.sql`、`database/migrations/V001_init.sql`、`server/init.sql` 当前内容完全相同。
- `npm run db:init` **只执行 `server/init.sql`，不会执行 V002–V009**。
- `V002_plus.sql` 是 V003–V009 的合并版，不应再和 V003–V009 拆分文件重复执行；同时目录里还有 `V002_activity.sql`，存在同版本号歧义。
- 当前 Git 索引中追踪了 `.env`、约 1150 个 `node_modules` 文件、Vite 缓存和一个上传文件。报告不展示其中任何秘密值。
- 密码目前是明文存储和比较，种子迁移中也存在固定测试密码。
- 分类写接口没有认证，统计接口只要求登录但不限制管理员；部分校园服务管理接口也缺少严格角色/所有权校验。
- 前端 API、Socket.IO 和图片地址硬编码为 `localhost:3000`，不利于部署和组员 B 功能合并。

## 1. 项目整体结构

### 1.1 技术栈

| 层级 | 技术 |
|---|---|
| 用户端 | Vue 3.5、Vite 6、Vue Router、Pinia、Axios、Element Plus、Socket.IO Client、图片懒加载 |
| 管理端 | Vue 3.5、Vite 7、Vue Router、Pinia、Axios、Element Plus |
| 后端 | Node.js、Express 5、CommonJS、Socket.IO、Multer、JWT、dotenv |
| 数据访问 | `pg`（node-postgres）连接池、参数化 SQL |
| 数据库 | openGauss；代码依赖 PostgreSQL 协议和大量 PostgreSQL 语法 |
| 测试/质量 | 管理端含 Vitest、Playwright、ESLint、Oxlint、Prettier；后端无有效测试 |

管理端 `package.json` 要求 Node.js `^20.19.0 || >=22.12.0`。为避免双端工具链差异，建议全项目统一使用符合该范围的 Node.js 版本。

### 1.2 目录作用

```text
campus-trade/
├─ client/
│  ├─ user-app/                 用户端 Vue 应用，开发端口 5174
│  │  └─ src/
│  │     ├─ api/                Axios 实例与 Token 注入
│  │     ├─ components/         代金券抽奖等复用组件
│  │     ├─ layouts/            用户端主布局
│  │     ├─ router/             用户端路由、鉴权、预加载
│  │     ├─ stores/             用户与商品 Pinia Store
│  │     ├─ utils/              性能辅助方法
│  │     └─ views/              用户端页面
│  └─ vue-project/              管理端 Vue 应用，Vite 默认端口 5173
│     └─ src/
│        ├─ api/                管理端 Axios 实例
│        ├─ layouts/            后台主布局
│        ├─ router/             后台路由与角色守卫
│        └─ views/              后台管理页面
├─ server/
│  ├─ app.js                    HTTP/Socket.IO 入口及路由挂载
│  ├─ config/db.js              openGauss/PostgreSQL 连接池
│  ├─ middlewares/auth.js       JWT 请求认证
│  ├─ routes/                   20 个 REST 路由模块
│  ├─ scripts/                  基础初始化与启动时局部补列
│  ├─ utils/                    JWT、管理员日志
│  ├─ uploads/                  本地上传文件目录
│  └─ init.sql                  基础数据库初始化脚本
├─ database/
│  ├─ init.sql                  与 server/init.sql 相同的基础脚本
│  └─ migrations/              V001–V009 迁移及 V002_plus 合并迁移
├─ README.md                    极简项目说明
└─ *.md                         设计、变更、性能和旧分析文档
```

注意：用户端存在 `StorageServices.vue` 和 `StorageService.vue` 两个相近页面，但路由实际指向 `StorageService.vue`，前者目前更像遗留/未接线路由的实现。

## 2. 启动方式

以下命令以仓库根目录为起点。首次运行前，应先准备 openGauss 数据库和 `server/.env`。建议提供一个不含真实值的 `server/.env.example`，至少列出：

```dotenv
DB_HOST=
DB_PORT=
DB_USER=
DB_PASSWORD=
DB_NAME=
JWT_SECRET=
PORT=3000
```

### 2.1 数据库初始化

当前仓库提供的基础初始化命令：

```powershell
cd server
npm install
npm run db:init
```

该命令只执行 `server/init.sql`，会执行基础 DDL、种子数据及多条 `DELETE`，**不是纯增量、无损迁移**。不要对包含有效业务数据的数据库直接运行。

若要得到支持当前全部功能的全新数据库，推荐在空库中采用以下二选一策略。

策略 A：拆分迁移，最适合课程提交和版本追踪：

```text
V001_init.sql
V002_activity.sql
V003_subsidy.sql
V004_campus_services.sql
V005_cleanup_and_seed.sql
V006_storage_enhance.sql
V007_fixes_and_seed.sql
V008_storage_orders.sql
V009_charity_system.sql
```

使用 openGauss 的 `gsql` 时，可按实际连接信息逐个执行，例如：

```powershell
gsql -d <数据库名> -U <用户名> -W -f database/migrations/V001_init.sql
gsql -d <数据库名> -U <用户名> -W -f database/migrations/V002_activity.sql
gsql -d <数据库名> -U <用户名> -W -f database/migrations/V003_subsidy.sql
gsql -d <数据库名> -U <用户名> -W -f database/migrations/V004_campus_services.sql
gsql -d <数据库名> -U <用户名> -W -f database/migrations/V005_cleanup_and_seed.sql
gsql -d <数据库名> -U <用户名> -W -f database/migrations/V006_storage_enhance.sql
gsql -d <数据库名> -U <用户名> -W -f database/migrations/V007_fixes_and_seed.sql
gsql -d <数据库名> -U <用户名> -W -f database/migrations/V008_storage_orders.sql
gsql -d <数据库名> -U <用户名> -W -f database/migrations/V009_charity_system.sql
```

策略 B：合并迁移，适合快速建立演示库：

```text
V001_init.sql
V002_activity.sql
V002_plus.sql
```

`V002_plus.sql` 明确声明其内容合并了 V003–V009。选择它以后，不要再执行 V003–V009；否则虽然不少 DDL/DML 做了幂等处理，仍会发生重复更新、重复清理、约束重建和版本记录歧义。

目前没有 Flyway、Liquibase、Sequelize migration 或自研迁移执行器，也没有迁移历史表。文件名中的版本号只是约定，并不会被程序自动识别。

### 2.2 后端启动

```powershell
cd server
npm install
npm run dev
```

生产式启动：

```powershell
cd server
npm install
npm start
```

默认地址为 `http://localhost:3000`。启动时会调用 `ensureSchema()`，但它仅补充：

- `items.quantity`
- `items.is_approved`
- `items.avg_rating`
- `items.review_count`
- `reviews` 表及索引

它不会创建活动、代金券、寄存、租赁、公益等表。因此必须先正确完成迁移。

### 2.3 用户端启动

```powershell
cd client/user-app
npm install
npm run dev
```

配置端口为 `5174`，即通常访问 `http://localhost:5174`。

### 2.4 管理端启动

```powershell
cd client/vue-project
npm install
npm run dev
```

未显式配置端口，Vite 默认通常为 `5173`。若端口占用，Vite 可能自动切换端口。

### 2.5 推荐启动顺序

```text
openGauss 启动并建空库
  → 执行 V001–V009（或 V001 + V002_activity + V002_plus）
  → 启动 server
  → 启动 user-app
  → 启动 vue-project
```

## 3. 已实现功能分析

### 3.1 用户端

| 功能 | 前端页面/组件 | 主要 API | 主要数据表 |
|---|---|---|---|
| 注册、登录、会话恢复 | `Login.vue`、`Register.vue`、用户 Store | `/api/auth/login`、`register`、`me` | `users` |
| 商品首页、分页、搜索、分类、排序 | `Home.vue`、商品 Store | `GET /api/items`、`categories` | `items`、`categories`、`item_images`、`tags`、`item_tags`、`users` |
| 热门和相似推荐 | `Home.vue`、`ItemDetail.vue` | `/api/recommendations/trending`、`similar/:itemId` | `items`、`views_log`、`favorites`、`categories` |
| 商品详情 | `ItemDetail.vue` | `GET /api/items/:id`、`/:id/tags` | `items`、`item_images`、`users`、`categories`、`tags` |
| 发布、编辑、上下架 | `Publish.vue`、`Profile.vue` | `POST/PUT /api/items`、`PUT /:id/status`、上传接口 | `items`、`item_images`、`item_tags`、`tags` |
| 收藏、浏览历史 | `ItemDetail.vue`、`Profile.vue` | `/api/favorites`、`/api/views` | `favorites`、`views_log`、`items` |
| 购物车和批量结算 | `Cart.vue` | `/api/cart`、`/checkout` | `cart`、`items`、`orders` |
| 直接购买、买入/卖出订单 | `ItemDetail.vue`、`MyOrders.vue` | `/api/orders/buy`、`my`、`sold`、取消/完成 | `orders`、`items`、`users` |
| 评价 | `ItemDetail.vue` | `/api/reviews/item/:id`、`can-review`、新增/删除 | `reviews`、`orders`、`items`、`users` |
| 举报及我的举报 | `ItemDetail.vue`、`MyReports.vue` | `POST /api/reports`、`GET /my` | `reports`、`items`、`users` |
| 私信、未读、实时推送 | `Messages.vue` | `/api/messages/*`、Socket.IO | `messages`、`users`、`items` |
| 活动专区、补贴展示 | `Home.vue`、`ActivityDetail.vue` | `/api/activities`、`/:id`、`/:id/items` | `activities`、`items`、`item_images` |
| 下单后抽代金券 | `LotteryModal.vue`、`Profile.vue` | `/api/vouchers`、`lottery/:orderId`、`/:id/use` | `vouchers`、`orders`、`activities` |
| 发布/浏览寄存服务 | `StorageService.vue`、`PublishStorage.vue` | `/api/storage-services` | `storage_services`、`users` |
| 发布/浏览寄存需求 | `StorageRequest.vue`、`PublishStorage.vue` | `/api/storage-requests` | `storage_requests`、`users` |
| 寄存预约和我的寄存订单 | `StorageService.vue`、`StorageRequest.vue`、`MyOrders.vue` | `/api/storage-orders` | `storage_orders`、`storage_services`、`users` |
| 转租发布、浏览、租赁 | `RentalItems.vue`、`PublishRental.vue`、`MyOrders.vue` | `/api/rental-items`、`/orders` | `rental_items`、`rental_orders`、`users` |
| 毕业公益赠送/申请 | `GraduationCharity.vue` | `/api/charity/items`、`apply`、`applies/my`、`stats` | `items`、`free_apply`、`users` |
| 个人中心汇总 | `Profile.vue` | 我的发布、收藏、浏览、代金券、校园服务 | 上述多表 |

### 3.2 管理端

| 功能 | 前端页面 | 主要 API | 主要数据表 |
|---|---|---|---|
| 管理员/运营登录 | `Login.vue` | `POST /api/auth/admin/login` | `users` |
| 数据仪表盘 | `Dashboard.vue` | `GET /api/stats` | 几乎所有核心业务表 |
| 商品审核、上下架、删除 | `Items.vue` | `/api/items/all`、状态更新、删除 | `items`、`item_images`、`users`、`categories` |
| 分类维护 | `Categories.vue` | `/api/categories` 增删改查 | `categories` |
| 用户新增、启禁、删除 | `Users.vue` | `/api/users` | `users`、关联业务表 |
| 订单查询和状态更新 | `Orders.vue` | `/api/orders`、`/:id/status` | `orders`、`items`、`users` |
| 举报处理 | `Reports.vue` | `/api/reports`、`/:id/handle` | `reports`、`items`、`users` |
| 管理操作日志 | `Logs.vue` | `GET /api/logs` | `admin_logs`、`users` |
| 活动运营 | `Activities.vue` | `/api/activities/all`、新增、修改、启停、删除 | `activities`、`items`、`users` |
| 校园服务审核/订单 | `CampusServices.vue` | 寄存、需求、租赁列表、审批、订单 | `storage_services`、`storage_requests`、`rental_items`、两类订单 |
| 公益回收和捐赠记录 | `CharityManagement.vue` | `/api/charity/recycle-pool`、`donations` | `items`、`free_apply`、`donation_record` |

### 3.3 后端能力

- JWT HTTP 认证与 Socket.IO 握手认证。
- `admin`、`operator`、`user` 角色模型。
- 参数化 SQL，降低常见 SQL 注入风险。
- Multer 单图/多图上传，格式白名单、5 MB 单文件限制。
- 购物车结算、直接购买时使用数据库事务和库存检查。
- 浏览数、收藏数、评分统计由触发器/汇总字段维护。
- 管理员操作日志。
- 活动时间窗、补贴价和代金券抽奖。
- Socket.IO 按 `user:<id>` 房间推送新消息。

### 3.4 数据库能力

- 主键、唯一约束、外键、部分级联删除。
- 商品、订单、用户角色、评价分数等 CHECK 约束。
- 商品浏览、收藏、评价统计触发器。
- 标签多对多关系。
- 活动、交易、寄存、租赁、公益等多个业务域。
- 大量可重复执行的 `DO $$` 补列逻辑和 `WHERE NOT EXISTS` 种子数据。

## 4. 数据库分析

### 4.1 全部数据表

最终迁移目标共 23 张表：

| 表 | 主键 | 作用与主要关系 |
|---|---|---|
| `users` | `id` | 所有用户；被商品、订单、消息、服务等引用 |
| `categories` | `id` | 商品分类；`parent_id` 是逻辑自关联，但没有外键 |
| `items` | `id` | 商品/公益物品；关联分类、发布者、可选活动 |
| `item_images` | `id` | 商品图片，多对一关联 `items` |
| `tags` | `id` | 标签，名称唯一 |
| `item_tags` | `(item_id, tag_id)` | 商品与标签多对多 |
| `favorites` | `(user_id, item_id)` | 用户收藏商品 |
| `views_log` | `id` | 用户或匿名浏览商品 |
| `cart` | `id`，另有 `(user_id,item_id)` 唯一 | 购物车 |
| `orders` | `id` | 二手商品订单，关联商品、买家、卖家 |
| `reviews` | `id`，另有 `(order_id,reviewer_id)` 唯一 | 订单评价 |
| `reports` | `id` | 举报；`target_id` 为多态逻辑关联，没有外键 |
| `admin_logs` | `id` | 管理操作审计 |
| `messages` | `id` | 用户私信，可关联商品 |
| `activities` | `id` | 活动运营；创建者关联用户 |
| `vouchers` | `id` | 用户代金券，关联活动和订单 |
| `storage_services` | `id` | 寄存供给 |
| `storage_requests` | `id` | 寄存需求 |
| `storage_orders` | `id` | 寄存预约，关联服务、预约者、提供者 |
| `rental_items` | `id` | 转租/租赁物品 |
| `rental_orders` | `id` | 租赁订单，关联物品、租客、所有者 |
| `free_apply` | `id` | 公益物品领取申请 |
| `donation_record` | `id` | 公益捐赠批次/去向记录 |

### 4.2 主要表关系

```text
users
├─< items >─ categories
│   ├─< item_images
│   ├─< item_tags >─ tags
│   ├─< favorites >─ users
│   ├─< views_log >─ users（可空）
│   ├─< cart >─ users
│   ├─< orders >─ users（buyer / seller）
│   │   └─< reviews >─ users
│   ├─< messages（可选 item）
│   ├─< free_apply >─ users（applicant / owner）
│   └─< donation_record
├─< activities ─< items
│   └─< vouchers >─ orders
├─< storage_services ─< storage_orders >─ users
├─< storage_requests
└─< rental_items ─< rental_orders >─ users
```

### 4.3 主键、外键和约束观察

- 大多数实体使用 `SERIAL` 整数主键，关联表使用联合主键或唯一约束。
- `categories.parent_id` 没有自引用外键，可能出现指向不存在分类的脏数据。
- `reports.target_type + target_id` 和 `admin_logs.target_type + target_id` 是多态关系，数据库无法保证目标存在。
- 订单对用户/商品的外键普遍没有 `ON DELETE` 策略，删除有关用户或商品时可能直接失败；管理端却提供用户/商品删除功能。
- `rental_orders` 和 `storage_orders` 的日期逻辑缺少 `end_date >= start_date` CHECK。
- 多个金额字段缺少非负约束；`items.price` 在 V009 才由 `> 0` 放宽到 `>= 0` 以兼容公益物品。
- `free_apply` 没有 `(item_id, applicant_id)` 唯一约束，理论上可重复申请。
- `donation_record` 的 `batch_id` 没有唯一约束。
- `rental_items.images` 使用 `TEXT` 保存 JSON 字符串，结构有效性由应用层承担。

### 4.4 V001–V009 执行顺序

| 文件 | 作用 | 前置依赖 |
|---|---|---|
| V001 | 14 张基础表、种子数据、触发器、CHECK | 空库 |
| V002_activity | `activities`，`items.activity_id` | V001 |
| V003 | 活动补贴字段、`vouchers`、考研资料字段 | V002_activity |
| V004 | 寄存/需求/租赁及租赁订单 | V001 |
| V005 | 清理活动、补充活动和校园服务种子 | V002–V004 |
| V006 | 寄存字段增强、状态约束、更多种子 | V003–V005 |
| V007 | 管理账号/数据修复、租赁联系方式 | V006 |
| V008 | 审核字段、`storage_orders`、订单种子 | V004–V007 |
| V009 | 公益字段、申请/捐赠表、公益种子 | V002、V001 |

### 4.5 V002–V009 潜在冲突

1. **重复版本号**：同时存在 `V002_activity.sql` 和 `V002_plus.sql`。标准迁移工具通常要求版本唯一，会直接拒绝。
2. **合并版与拆分版重复**：`V002_plus.sql` 内部完整合并 V003–V009，不能再顺序执行 V003–V009。
3. **合并版仍依赖活动表**：`V002_plus.sql` 从 V003 内容开始，假设 `activities` 已由 `V002_activity.sql` 创建；它不能单独接在 V001 后面。
4. **基础脚本具有清数据行为**：V001/init.sql 会按顺序删除多张基础表中的数据并重置序列，不适合升级已有库。
5. **三个基础脚本副本**：三份内容当前相同，但未来非常容易漂移，且 `npm run db:init` 只认 `server/init.sql`。
6. **重复建标签表**：V001 中 `tags`、`item_tags` 的建表片段出现两次，虽有 `IF NOT EXISTS`，但属于维护噪声。
7. **种子数据依赖用户名、标题和活动类型**：大量 DML 通过文本查找外键；组员 B 若改名或先插入同名数据，可能导致关联错误或跳过预期种子。
8. **所谓幂等并不完全等于无副作用**：迁移中含 `DELETE`、状态/密码强制更新、约束删除重建；重复执行仍可能改变当前业务数据。
9. **缺少迁移历史表与事务总控**：不能可靠判断某环境执行到了哪一步；中途失败后恢复困难。
10. **openGauss 兼容性需实机验证**：脚本使用 `SERIAL`、`DO $$`、`FILTER`、`ILIKE`、`ON CONFLICT`、`RETURNING`、`NULLS LAST`、`IS DISTINCT FROM`、`information_schema`、触发器函数等 PostgreSQL 风格能力，不同 openGauss 版本/兼容模式可能有差异。

## 5. 后端接口分析

### 5.1 全局约定

- API 基址：`http://localhost:3000/api`
- Token：`Authorization: Bearer <JWT>`
- 常见响应：`{ code: 0, message, data }`
- 错误时通常为 `{ code: 1, message, data: null }`
- 分页接口常返回 `{ total, page, pageSize?, list }`
- `adminOnly` 通常允许 `admin` 和 `operator`，但并非所有管理型接口都正确使用它。

以下“参数”列中，`Q` 表示 query，`B` 表示 JSON body，`P` 表示 path，`F` 表示 multipart file。

### 5.2 认证与用户

| 方法与路由 | 鉴权 | 参数 | 返回/业务 |
|---|---|---|---|
| POST `/api/auth/admin/login` | 无 | B: `username,password` | Token 和脱敏后的 admin/operator 用户 |
| POST `/api/auth/login` | 无 | B: `username,password` | 普通用户 Token 和用户信息 |
| POST `/api/auth/register` | 无 | B: `username,password,real_name,campus` | 创建普通用户并直接登录 |
| GET `/api/auth/me` | 登录 | 无 | 当前用户资料 |
| GET `/api/users` | 管理角色 | Q: `page,pageSize,keyword,role,status` | 用户分页 |
| POST `/api/users` | 管理角色 | B: 用户名、密码、姓名、角色、校区 | 新增用户 |
| PUT `/api/users/:id/status` | 管理角色 | P: `id`; B: `status` | 启用/禁用 |
| DELETE `/api/users/:id` | 管理角色 | P: `id` | 删除用户 |

### 5.3 商品、分类、收藏、浏览与推荐

| 方法与路由 | 鉴权 | 参数 | 返回/业务 |
|---|---|---|---|
| GET `/api/items` | 公开 | Q: 分页、分类、关键词、校区、标签、排序、活动等 | 在售普通商品分页 |
| GET `/api/items/all` | 管理角色 | Q: 分页、关键词、状态、分类 | 后台全部商品 |
| GET `/api/items/my` | 登录 | 无 | 当前用户发布 |
| GET `/api/items/:id` | 公开 | P: `id` | 商品、卖家、分类、图片 |
| POST `/api/items` | 登录 | B: 标题、描述、价格、分类、校区、联系方式、图片、标签、活动等 | 发布待审核商品 |
| PUT `/api/items/:id` | 登录/本人 | P: `id`; B: 商品字段 | 编辑并重新进入审核 |
| PUT `/api/items/:id/status` | 登录 | P: `id`; B: `status` | 本人上下架或管理审核；代码内按角色分支 |
| DELETE `/api/items/:id` | 登录 | P: `id` | 本人或管理角色删除 |
| GET `/api/items/:id/tags` | 公开 | P: `id` | 标签列表 |
| GET `/api/categories` | 公开 | 无 | 分类列表 |
| GET `/api/categories/:id` | 公开 | P: `id` | 分类详情 |
| POST `/api/categories` | **无** | B: `name,parent_id,sort_order` | 新建分类 |
| PUT `/api/categories/:id` | **无** | P: `id`; B: 分类字段 | 修改分类 |
| DELETE `/api/categories/:id` | **无** | P: `id` | 删除无子分类的分类 |
| POST `/api/favorites` | 登录 | B: `item_id` | 收藏 |
| DELETE `/api/favorites/:item_id` | 登录 | P: `item_id` | 取消收藏 |
| GET `/api/favorites/check/:item_id` | 登录 | P: `item_id` | 是否已收藏 |
| GET `/api/favorites` | 登录 | 无 | 收藏列表 |
| POST `/api/views` | 可匿名 | B: `item_id` | 写浏览记录 |
| GET `/api/views` | 登录 | 无 | 当前用户浏览历史 |
| GET `/api/recommendations/trending` | 公开 | 无 | 近 30 天热门商品 |
| GET `/api/recommendations/similar/:itemId` | 公开 | P: `itemId` | 同分类、相近价格商品 |

### 5.4 购物车、订单、评价、代金券

| 方法与路由 | 鉴权 | 参数 | 返回/业务 |
|---|---|---|---|
| GET `/api/cart` | 登录 | 无 | 当前购物车 |
| POST `/api/cart` | 登录 | B: `item_id` | 加购，检查自买/重复/库存 |
| DELETE `/api/cart/:item_id` | 登录 | P: `item_id` | 移除 |
| POST `/api/cart/checkout` | 登录 | B: `item_ids` 等 | 事务内批量建单、扣库存、清购物车 |
| GET `/api/orders/my` | 登录 | 无 | 买到的订单 |
| GET `/api/orders/sold` | 登录 | 无 | 卖出的订单 |
| POST `/api/orders/buy` | 登录 | B: `item_id` | 直接购买并扣库存 |
| GET `/api/orders` | 管理角色 | Q: `page,pageSize,status,keyword` | 全部订单 |
| PUT `/api/orders/:id/status` | 管理角色 | B: `status` | 后台改状态 |
| PUT `/api/orders/:id/confirm` | 登录/买家 | P: `id` | 确认收货 |
| PUT `/api/orders/:id/cancel` | 登录/相关方 | P: `id` | 取消并恢复库存 |
| PUT `/api/orders/:id/complete` | 登录/卖家 | P: `id` | 卖家完成 |
| GET `/api/orders/:id` | 管理角色 | P: `id` | 订单详情 |
| GET `/api/reviews/item/:itemId` | 公开 | P: `itemId` | 商品评价 |
| GET `/api/reviews/can-review/:itemId` | 登录 | P: `itemId` | 是否有资格评价 |
| POST `/api/reviews` | 登录 | B: `item_id,order_id,rating,content` | 创建评价 |
| DELETE `/api/reviews/:id` | 登录/本人 | P: `id` | 删除评价 |
| GET `/api/vouchers` | 登录 | 无 | 我的代金券 |
| GET `/api/vouchers/usable` | 登录 | 无 | 可用代金券 |
| POST `/api/vouchers/lottery/:orderId` | 登录 | P: `orderId` | 对符合活动的订单抽一次券 |
| PUT `/api/vouchers/:id/use` | 登录/本人 | B: `order_id` | 标记券已使用 |

### 5.5 消息、举报、日志、统计、上传

| 方法与路由 | 鉴权 | 参数 | 返回/业务 |
|---|---|---|---|
| GET `/api/messages/conversations` | 登录 | 无 | 会话及最后消息、未读数 |
| GET `/api/messages/unread-count` | 登录 | 无 | 未读总数 |
| GET `/api/messages/:userId` | 登录 | P: 对方用户 ID | 两人聊天记录 |
| POST `/api/messages` | 登录 | B: `receiver_id,item_id,content` | 落库并 Socket.IO 推送 |
| PUT `/api/messages/read/:userId` | 登录 | P: 对方用户 ID | 标记该会话已读 |
| POST `/api/reports` | 登录 | B: `target_type,target_id,reason` | 创建举报 |
| GET `/api/reports` | 管理角色 | Q: 分页、状态 | 后台举报列表 |
| GET `/api/reports/my` | 登录 | Q: 分页 | 我的举报 |
| PUT `/api/reports/:id/handle` | 管理角色 | B: `action` | 忽略、下架商品或冻结用户等 |
| GET `/api/logs` | 管理角色 | Q: 分页、动作等 | 操作日志 |
| GET `/api/stats` | **仅登录** | 无 | 仪表盘汇总、趋势和各模块统计 |
| POST `/api/upload` | 登录 | F: `file` | 单图 URL |
| POST `/api/upload/multiple` | 登录 | F: `files`，最多 6 张 | URL 数组 |

### 5.6 活动

| 方法与路由 | 鉴权 | 参数 | 返回/业务 |
|---|---|---|---|
| GET `/api/activities` | 公开 | 无 | 当前有效、已启用活动 |
| GET `/api/activities/all` | 管理角色 | Q: `page,pageSize` | 全部活动和时间状态 |
| POST `/api/activities` | 管理角色 | B: 名称、类型、时间、Banner、补贴/券配置 | 新建 |
| PUT `/api/activities/:id` | 管理角色 | P: `id`; B: 活动字段 | 更新 |
| PUT `/api/activities/:id/toggle` | 管理角色 | P: `id` | 启停 |
| DELETE `/api/activities/:id` | 管理角色 | P: `id` | 删除 |
| GET `/api/activities/:id` | 公开 | P: `id` | 活动详情 |
| GET `/api/activities/:id/items` | 公开 | Q: `page,pageSize,sort` | 活动商品及补贴展示价 |

### 5.7 寄存与租赁

| 方法与路由 | 鉴权 | 参数 | 返回/业务 |
|---|---|---|---|
| GET `/api/storage-services` | 公开 | Q: 分页、类型、校区、状态、关键词、排序 | 已审核服务 |
| GET `/api/storage-services/:id` | 公开 | P: `id` | 服务详情 |
| POST `/api/storage-services` | 登录 | B: 服务、地点、时间、价格、容量、联系信息 | 发布待审核服务 |
| PUT `/api/storage-services/:id` | 登录/发布者 | B: `status,remain_capacity` | 更新 |
| DELETE `/api/storage-services/:id` | 登录 | P: `id` | 删除；需重点复核所有权/角色 |
| PUT `/api/storage-services/:id/approve` | 登录 | B: `approved` | 审批；后端需补管理角色限制 |
| GET `/api/storage-requests` | 公开 | Q: 分页和筛选 | 已审核需求 |
| GET `/api/storage-requests/:id` | 公开 | P: `id` | 需求详情 |
| POST `/api/storage-requests` | 登录 | B: 需求字段 | 发布待审核需求 |
| PUT `/api/storage-requests/:id` | 登录 | B: 状态等 | 更新；需重点复核所有权 |
| DELETE `/api/storage-requests/:id` | 登录 | P: `id` | 删除；需重点复核所有权/角色 |
| PUT `/api/storage-requests/:id/approve` | 登录 | B: `approved` | 审批；后端需补管理角色限制 |
| POST `/api/storage-orders` | 登录 | B: 服务、日期、物品描述 | 创建寄存预约 |
| GET `/api/storage-orders/my` | 登录 | 无 | 我的预约/供给订单 |
| GET `/api/storage-orders` | 登录 | 无 | 全部寄存订单；应限制管理角色 |
| GET `/api/rental-items` | 公开 | Q: 分页、分类、校区、状态、关键词 | 已审核租赁物品 |
| POST `/api/rental-items` | 登录 | B: 租赁物品字段 | 发布待审核 |
| GET `/api/rental-items/:id` | 公开 | P: `id` | 详情 |
| PUT `/api/rental-items/:id` | 登录/发布者 | B: 可修改字段 | 更新 |
| DELETE `/api/rental-items/:id` | 登录/发布者或管理 | P: `id` | 删除 |
| PUT `/api/rental-items/:id/approve` | 管理角色 | B: `approved` | 审核 |
| POST `/api/rental-items/orders` | 登录 | B: `rental_item_id,start_date,end_date` | 创建租赁订单 |
| GET `/api/rental-items/orders/my` | 登录 | 无 | 我的租赁订单 |
| GET `/api/rental-items/orders` | 管理角色 | 无 | 全部租赁订单 |

### 5.8 公益

| 方法与路由 | 鉴权 | 参数 | 返回/业务 |
|---|---|---|---|
| GET `/api/charity/items` | 公开 | Q: `page,pageSize` | 可领取公益商品 |
| GET `/api/charity/items/:id` | 公开 | P: `id` | 公益商品详情 |
| POST `/api/charity/apply` | 登录 | B: `item_id,message` | 申请领取 |
| GET `/api/charity/applies/my` | 登录 | Q: `type` | 我发起/我收到的申请 |
| PUT `/api/charity/apply/:id` | 登录/相关方 | B: `status` | 接受、完成或取消 |
| GET `/api/charity/recycle-pool` | 管理角色 | 无 | 到期回收池 |
| GET `/api/charity/donations` | 管理角色 | 无 | 捐赠记录 |
| POST `/api/charity/donations` | 管理角色 | B: `item_ids` 及批次/机构/证明信息 | 创建捐赠记录 |
| GET `/api/charity/stats` | 公开 | 无 | 公益统计 |

## 6. 前后端对应关系

```text
首页 Home.vue
  ├─ GET /api/items ─────────────── items + item_images + categories + users
  ├─ GET /api/recommendations/* ─── items + views_log + favorites
  └─ GET /api/activities ────────── activities + items

商品发布 Publish.vue
  ├─ POST /api/upload ───────────── server/uploads
  └─ POST /api/items ────────────── items + item_images + tags + item_tags

商品详情 ItemDetail.vue
  ├─ GET /api/items/:id ─────────── items + item_images + users + categories
  ├─ POST /api/views ─────────────── views_log → 触发更新 items.views_count
  ├─ POST/DELETE /api/favorites ─── favorites → 触发更新 favorites_count
  ├─ POST /api/orders/buy ───────── orders + items.quantity/status
  ├─ GET/POST /api/reviews ──────── reviews → 触发更新评分汇总
  └─ POST /api/reports ──────────── reports

购物车 Cart.vue
  ├─ GET/POST/DELETE /api/cart ──── cart + items
  └─ POST /api/cart/checkout ────── orders + items + cart

私信 Messages.vue
  ├─ REST /api/messages ─────────── messages + users + items
  └─ Socket.IO ──────────────────── user:<id> 实时房间

活动详情 ActivityDetail.vue
  ├─ GET /api/activities/:id ────── activities
  └─ GET /api/activities/:id/items  activities + items + item_images

寄存页面
  ├─ /api/storage-services ──────── storage_services + users
  ├─ /api/storage-requests ──────── storage_requests + users
  └─ /api/storage-orders ────────── storage_orders + storage_services + users

租赁页面
  ├─ /api/rental-items ──────────── rental_items + users
  └─ /api/rental-items/orders ───── rental_orders + rental_items + users

毕业公益 GraduationCharity.vue
  ├─ /api/charity/items ─────────── items(item_type='charity') + users
  ├─ /api/charity/apply ─────────── free_apply
  └─ /api/charity/stats ─────────── items + free_apply + donation_record

管理端 Dashboard.vue
  └─ GET /api/stats ─────────────── 核心业务表汇总

管理端各维护页面
  ├─ Items.vue ──────────────────── items
  ├─ Categories.vue ─────────────── categories
  ├─ Users.vue ──────────────────── users
  ├─ Orders.vue ─────────────────── orders
  ├─ Reports.vue ────────────────── reports
  ├─ Logs.vue ───────────────────── admin_logs
  ├─ Activities.vue ─────────────── activities
  ├─ CampusServices.vue ─────────── storage_* + rental_*
  └─ CharityManagement.vue ──────── items + free_apply + donation_record
```

## 7. 项目风险检查

### 7.1 高风险

| 风险 | 证据与影响 | 建议 |
|---|---|---|
| 明文密码 | 登录使用字符串直接比较；注册直接入库；迁移含固定测试密码 | 合并组员 B 前统一 bcrypt/argon2；迁移测试账号仅用于本地，首次登录强制改密 |
| `.env` 已被 Git 追踪 | `.gitignore` 虽忽略 `.env`，但索引中仍有 `server/.env` | 轮换所有可能暴露的数据库/JWT凭据；从版本控制移除；只保留 `.env.example` |
| 独立脚本硬编码数据库凭据 | `server/check_item.js` 含直接连接信息 | 删除或改为环境变量；相关凭据立即轮换；不要在报告/答辩材料展示 |
| 数据库初始化不完整 | `db:init` 只到 V001，代码却直接查询后续表 | 建立唯一、自动化、可验证的迁移入口 |
| 数据初始化会删数据 | V001/init.sql 含多表 `DELETE` 和序列重置 | 拆分 schema migration 与 demo seed；默认命令不得清库 |
| 分类写接口公开 | 未使用 `authenticate/adminOnly` | 所有人可增删改分类；必须限制为管理角色 |

### 7.2 中风险

| 风险 | 影响 | 建议 |
|---|---|---|
| 迁移版本冲突 | V002 重名，合并版重复 V003–V009 | 只保留一条正式迁移链；旧合并文件移至归档说明 |
| 管理权限不一致 | `/api/stats`、部分寄存审批/全量订单只要求登录 | 后端统一 RBAC 中间件，不能只依赖前端路由守卫 |
| `node_modules` 已提交 | 当前追踪约 1150 个依赖文件，仓库膨胀且易冲突 | 从索引移除，依赖只由 lockfile 复现 |
| 缓存/上传文件已提交 | `.vite` 与实际上传图片被追踪 | 清理索引；演示图片放专用 seed/static 目录 |
| 全开放 CORS | HTTP 与 Socket.IO 均允许任意来源 | 用环境变量配置开发/生产白名单 |
| API 地址硬编码 | 双端、图片和 Socket 地址绑定 localhost | 使用 `VITE_API_BASE_URL`/统一 URL helper |
| JWT 配置健壮性不足 | 未见启动时强制校验 Secret；Token 存 localStorage | 启动时校验必填环境变量；补 XSS 防护和更短有效期/刷新机制 |
| 上传文件校验有限 | 主要依赖 MIME 和扩展名，本地永久落盘 | 校验真实文件签名、随机安全文件名、定期清理孤儿文件 |
| 删除与外键冲突 | 用户/商品删除接口遇到订单等 RESTRICT 外键可能 500 | 采用软删除，或明确各关系删除策略 |
| 缺少统一输入验证 | 多数路由手工检查少量必填字段 | 使用 schema validator，限制分页上限、枚举、长度、金额、日期 |
| 错误/日志不统一 | 控制台记录每个请求，错误格式靠各路由维护 | 统一错误中间件和结构化日志，生产环境避免泄露内部错误 |

### 7.3 明显 Bug 或一致性风险

- `database/README.md` 仍声称当前只有 V001，与实际 V009 不一致。
- 根 `README.md` 只有三行，无法指导组员 B 或验收老师启动完整系统。
- 管理端路由守卫只保护部分页面；真正安全边界必须在后端。
- `stats` 会无条件查询活动、公益、寄存、租赁、代金券表；只初始化 V001 时后端虽然能监听，仪表盘接口必然报错。
- `ensureSchema()` 在每次启动时更新商品历史数据，启动过程包含写数据库副作用。
- 用户端 `StorageServices.vue` 未被路由引用，容易与 `StorageService.vue` 在合并时产生功能重复。
- 管理端和用户端使用不同 Vite 大版本，后续升级/锁文件合并可能出现构建差异。
- 用户端声明 Vue Router 5，而生态常见成熟版本线仍需结合当前实际 lockfile 和浏览器验证；课程提交前应锁定可复现版本，不要临时升级。
- API 返回虽大体统一，但状态码、分页字段和鉴权约定并没有集中定义。
- `server/docker` 不是有效的容器化配置，不能作为部署方案。
- 没有后端自动化测试；管理端只有模板级测试，用户端无测试脚本。
- 没有 404 和全局错误处理中间件，也没有 API 文档。
- 金额由 JavaScript `parseFloat` 与数据库 decimal 共同处理，抽奖/优惠计算应定义统一舍入规则。
- 代金券“使用”接口只是标记状态，需确认是否真正参与订单金额计算，避免展示功能与结算功能脱节。

### 7.4 未发现或相对较好的方面

- `.gitignore` 已包含 `.env`、`node_modules`、构建产物和 Vite 缓存规则；问题主要是文件早于规则被追踪。
- 常规 SQL 值大多使用 `$1...$n` 参数化。
- 上传目录由 `path.join(__dirname, ...)` 构造，没有发现业务运行依赖固定 Windows 绝对路径。
- 数据库连接主流程使用环境变量，而不是将秘密写在 `db.js`。
- 返回用户信息时登录接口会剔除密码字段。

## 8. 组员 B 功能合并建议

合并前先冻结并记录以下“契约”，能显著减少冲突：

1. 以一套数据库迁移链为唯一真源，确定 B 的新表/列从哪个版本继续编号。
2. 导出当前 API 清单和响应结构，B 的接口避免同路径不同语义。
3. 明确用户端和管理端各自的路由命名、Token key（当前分别为 `client_token` 与 `token`）。
4. 将 API 基址、上传资源基址、Socket.IO 基址集中到环境配置。
5. 对 `items`、`users`、`orders` 这三个高冲突核心表，先评审字段并画最终 ER 图，再合 SQL。
6. B 的迁移禁止修改既有 V001–V009；应新增更高版本，保证已执行环境可升级。
7. 区分 schema、修复脚本、demo seed；不要把测试数据继续混在结构迁移里。
8. 合并后至少做三套验证：全新空库、从 A 当前库升级、关键业务回归。

推荐关键回归清单：

- 用户注册/登录、管理员登录和角色隔离。
- 发布商品 → 管理审核 → 首页展示 → 购买 → 双方完成 → 评价。
- 收藏/浏览计数是否正确且不为负。
- 活动补贴商品 → 下单 → 代金券抽取/使用。
- 寄存服务/需求发布 → 审核 → 预约 → 我的订单。
- 租赁发布 → 审核 → 下单。
- 公益发布/展示 → 申请 → 接受/完成 → 捐赠记录。
- 管理端普通 `operator` 与 `admin` 的权限差异。

## 9. 为课程验收提出建议

### 9.1 当前亮点

- 不是简单商品 CRUD，而是覆盖发布、审核、交易、评价、举报和运营的完整闭环。
- openGauss 数据库中有外键、唯一约束、CHECK、索引和触发器，可体现数据库课程能力。
- 活动时间窗、补贴价和代金券把“运营”与交易数据连接起来。
- Socket.IO 私信提供实时交互点。
- 寄存、租赁贴合校园生活，场景辨识度高。
- 公益循环把零元物品、领取申请、回收池、捐赠记录和公益积分串成独立创新模块。
- 双端架构和角色管理适合展示工程分层。

### 9.2 最适合展示的创新功能

1. **校园节点化运营**：毕业季、新生季、考研季活动配置，活动自动生效/过期。
2. **官方补贴 + 抽券**：展示数据库如何关联活动、商品、订单和代金券。
3. **毕业公益循环**：普通交易商品与公益商品共用核心模型，又通过申请/捐赠表扩展业务。
4. **校园寄存与租赁**：从交易平台延伸至校园闲置资源共享。
5. **数据自动维护**：现场展示收藏、浏览、评价触发器对汇总字段的更新。
6. **实时消息**：两浏览器账号之间即时收到私信。

### 9.3 验收前必须补强

优先级 P0：

- 轮换已进入版本历史的秘密，停止追踪 `.env`、硬编码凭据和依赖目录。
- 密码改为安全哈希，迁移现有演示账号。
- 统一并自动执行数据库迁移，确保老师机器能从空库复现。
- 修复分类、统计、校园服务后台接口的权限。
- 完成“一份 README + 一份 `.env.example` + 一条初始化命令”。

优先级 P1：

- 增加后端冒烟测试和三条核心 E2E。
- 统一 API/图片/Socket 基址配置。
- 为核心接口加入输入校验、统一错误处理和分页上限。
- 补 ER 图、系统架构图、用例图、关键时序图和数据字典。
- 准备无网络环境下可用的演示数据和截图/录屏备份。

优先级 P2：

- Swagger/OpenAPI 文档。
- 软删除、审计日志完善、限流和 CORS 白名单。
- 统一前端工具链版本并清理未使用页面。

### 9.4 建议演示流程（约 10–12 分钟）

1. **30 秒架构概览**：Vue 用户端 + Vue 管理端 + Express + openGauss；展示 ER 图。
2. **用户发布商品**：登录、上传图片、标签、选择活动、提交待审核。
3. **后台审核**：切到管理员，查看仪表盘并通过商品；展示操作日志。
4. **交易闭环**：另一个用户在首页筛选活动商品，查看补贴价，加购/购买。
5. **订单与评价**：双方推进订单，买家评价；回商品页观察评分更新。
6. **活动代金券**：对符合条件订单抽券，展示活动—订单—券的关联。
7. **实时消息**：两个窗口快速发送一条私信。
8. **创新模块二选一重点演示**：
   - 公益：申请免费物品 → 物主接受 → 后台进入回收/捐赠；
   - 校园服务：寄存发布 → 审核 → 预约订单。
9. **数据库能力收尾**：展示外键、CHECK、触发器和一条统计 SQL 的结果。
10. **总结分工与扩展**：说明 A 版基线、B 功能合并方式、测试和版本管理。

演示时不要现场展示 `.env`、数据库连接密码、JWT、固定测试密码或服务器敏感日志。

## 10. 建议的交付物清单

- 根 README：环境要求、三端启动、数据库初始化、测试账号获取方式（不写密码）。
- `.env.example`。
- 唯一数据库迁移目录和迁移历史机制。
- ER 图和数据字典。
- API 文档。
- 课程报告：需求分析、总体设计、数据库设计、关键实现、测试、分工和总结。
- 演示脚本、演示数据初始化脚本、备用录屏。
- 安全自查表和测试报告。

## 11. 审计边界

本报告基于静态代码和仓库索引分析，没有：

- 连接或读取实际数据库；
- 输出任何 `.env` 内容、密码、Token 或其他秘密；
- 执行 SQL 迁移；
- 启动前后端；
- 执行会生成构建产物的构建/测试命令；
- 修改任何业务代码或 Git 状态。

因此，“已实现”表示代码中存在对应页面、路由、SQL 和业务逻辑，不等于已在当前数据库环境完成端到端运行验证。课程提交前必须按本报告的回归清单实机验证。
