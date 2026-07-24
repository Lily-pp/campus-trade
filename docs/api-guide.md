# CampusTrade API 接口说明

## 1. API 概述

CampusTrade 后端基于 Node.js + Express + PostgreSQL 构建。

接口统一由后端服务提供：

    http://localhost:3000/api

主要业务模块：

-   用户认证
-   商品交易
-   订单管理
-   活动管理
-   推荐系统
-   失物招领
-   租赁服务
-   寄存服务
-   公益模块
-   管理后台

------------------------------------------------------------------------

# 2. 通用接口规范

## 请求格式

主要使用：

-   GET 查询数据
-   POST 创建数据
-   PUT 修改数据
-   DELETE 删除数据

## 返回格式

成功：

``` json
{
  "code":0,
  "message":"success",
  "data":{}
}
```

失败：

``` json
{
  "code":1,
  "message":"错误信息"
}
```

------------------------------------------------------------------------

# 3. 用户认证模块

路径：

    server/routes/auth.js

## 登录

    POST /api/auth/login

请求：

``` json
{
 "username":"username",
 "password":"password"
}
```

返回：

-   token
-   用户信息
-   用户角色

## 注册

    POST /api/auth/register

------------------------------------------------------------------------

# 4. 商品模块

路径：

    server/routes/items.js

基础地址：

    /api/items

## 商品列表

    GET /api/items

支持：

-   分页
-   分类筛选
-   关键词搜索
-   排序

参数：

  参数          说明
  ------------- --------
  page          页码
  pageSize      数量
  keyword       关键词
  category_id   分类

------------------------------------------------------------------------

## 商品详情

    GET /api/items/:id

返回：

-   商品信息
-   发布用户
-   图片
-   标签
-   地址信息

------------------------------------------------------------------------

## 发布商品

    POST /api/items

主要字段：

``` json
{
"title":"",
"description":"",
"price":0,
"category_id":1
}
```

------------------------------------------------------------------------

## 商品修改

    PUT /api/items/:id

## 商品删除

    DELETE /api/items/:id

------------------------------------------------------------------------

# 5. 期望交易地点模块

商品表新增：

    expected_address
    expected_longitude
    expected_latitude

用于：

-   校园线下面交地点记录；
-   地图选点；
-   后续距离计算。

示例：

``` json
{
"expected_address":"图书馆",
"expected_longitude":121.4,
"expected_latitude":31.2
}
```

------------------------------------------------------------------------

# 6. 订单模块

路径：

    server/routes/orders.js

功能：

-   创建订单
-   查询订单
-   更新订单状态

主要接口：

    POST /api/orders

创建订单。

    GET /api/orders/my

查询当前用户订单。

------------------------------------------------------------------------

# 7. 活动模块

路径：

    server/routes/activities.js

接口：

    GET /api/activities

获取活动列表。

支持：

-   活动展示
-   商品关联
-   活动补贴

------------------------------------------------------------------------

# 8. 推荐模块

路径：

    server/routes/recommendations.js

## 热门推荐

    GET /api/recommendations/trending

## 相似推荐

    GET /api/recommendations/similar/:id

当前采用规则推荐：

-   商品分类
-   价格范围
-   热度信息

------------------------------------------------------------------------

# 9. 失物招领模块

路径：

    server/routes/lostFound.js

数据模型：

    lost_posts
    found_items
    lost_found_points

独立于商品模块。

## 发布失物

    POST /api/lost-found/lost

## 发布招领

    POST /api/lost-found/found

## 搜索

    GET /api/lost-found/search

支持：

-   关键词
-   类型
-   状态
-   分页

------------------------------------------------------------------------

# 10. 租赁模块

路径：

    server/routes/rental.js

核心数据：

    rental_items
    rental_orders

功能：

-   租赁商品发布
-   租赁审核
-   租赁订单

------------------------------------------------------------------------

# 11. 寄存模块

路径：

    server/routes/storage.js

核心数据：

    storage_services
    storage_requests
    storage_orders

功能：

-   发布寄存服务
-   发布寄存需求
-   预约
-   订单管理

------------------------------------------------------------------------

# 12. 公益模块

路径：

    server/routes/charity.js

核心数据：

    free_apply
    donation_record

功能：

-   公益商品
-   领取申请
-   捐赠记录
-   公益积分

------------------------------------------------------------------------

# 13. 收藏与评价

收藏：

    POST /api/favorites

评价：

    POST /api/reviews

查询评价：

    GET /api/reviews/item/:id

------------------------------------------------------------------------

# 14. 文件上传

用于：

-   商品图片
-   服务图片

接口：

    POST /api/upload

------------------------------------------------------------------------

# 15. 管理端接口

管理端主要功能：

## 用户管理

    /api/users

## 商品审核

    /api/items/all

## 数据统计

    /api/stats

## 管理日志

    /api/admin-logs

------------------------------------------------------------------------

# 16. 新接口开发规范

新增业务模块：

例如：

    forum

步骤：

## 1. 创建路由

    server/routes/forum.js

## 2. 注册接口

修改：

    server/app.js

添加：

``` javascript
app.use(
 '/api/forum',
 forumRouter
)
```

## 3. 创建数据库迁移

新增：

    database/migrations/V012_forum.sql

## 4. 添加前端页面

用户端：

    client/user-app/src/views

管理端：

    client/vue-project/src/views

------------------------------------------------------------------------

# 17. 联调检查

新增接口后检查：

后端：

-   参数校验
-   权限验证
-   数据库操作

前端：

-   请求地址
-   参数格式
-   返回字段

数据库：

-   migration 是否执行
-   外键是否正确

------------------------------------------------------------------------

# 18. API 开发原则

1.  一个业务对应一个 route 文件；
2.  数据库变化必须新增 migration；
3.  不修改历史 migration；
4.  返回格式保持统一；
5.  涉及用户数据必须检查权限；
6.  复杂操作使用事务保证一致性。
