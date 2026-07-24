# CampusTrade 项目启动指南

## 1. 文档目的

本文档用于指导新成员从零开始运行 CampusTrade 项目。

适用场景： - 新成员首次加入项目 - 更换电脑重新部署 -
验收前重新搭建环境 - 后续功能开发前了解项目结构

目标：从 GitHub
获取代码开始，完成环境配置、数据库初始化、后端启动和前端启动。

------------------------------------------------------------------------

## 2. 环境要求

需要安装：

  环境         建议版本
  ------------ ----------
  Node.js      18+
  npm          9+
  Git          最新版本
  PostgreSQL   14+

检查：

``` bash
node -v
npm -v
git --version
```

------------------------------------------------------------------------

## 3. 获取项目代码

``` bash
git clone https://github.com/Lily-pp/campus-trade.git
cd campus-trade
git checkout merge-b-version
git pull origin merge-b-version
```

------------------------------------------------------------------------

## 4. 项目结构

    campus-trade
    ├── client
    │   ├── user-app       用户端前端
    │   └── vue-project    管理端前端
    ├── server             后端服务
    ├── database           数据库迁移文件
    └── docs               项目文档

------------------------------------------------------------------------

## 5. 数据库配置

创建数据库：

``` sql
CREATE DATABASE campus_trade;
```

进入 `server` 创建 `.env`：

``` env
PORT=3000

DB_HOST=localhost
DB_PORT=5432
DB_USER=你的数据库用户名
DB_PASSWORD=你的数据库密码
DB_NAME=campus_trade

JWT_SECRET=my-super-secret-key-2024
```

------------------------------------------------------------------------

## 6. 初始化数据库

进入后端：

``` bash
cd server
npm install
```

执行：

``` bash
npm run db:init
```

会按照顺序执行：

    V001_init.sql
    V002_activity.sql
    ...
    V011_expected_address.sql

包含：

-   用户系统
-   商品交易
-   订单系统
-   活动补贴
-   租赁
-   寄存
-   公益
-   失物招领
-   期望交易地点

已有数据库升级：

``` bash
npm run db:migrate
```

不要对已有业务数据执行：

``` bash
npm run db:init
```

------------------------------------------------------------------------

## 7. 启动后端

``` bash
cd server
npm run dev
```

访问：

    http://localhost:3000

------------------------------------------------------------------------

## 8. 启动用户端

``` bash
cd client/user-app
npm install
npm run dev
```

------------------------------------------------------------------------

## 9. 启动管理端

``` bash
cd client/vue-project
npm install
npm run dev
```

------------------------------------------------------------------------

## 10. 功能模块

### 商品交易

支持：

-   商品发布
-   审核
-   浏览
-   下单
-   订单管理
-   收藏评价

### 期望交易地点

支持：

-   手动填写交易地点
-   地图选点
-   保存经纬度
-   编辑回填

字段：

    expected_address
    expected_longitude
    expected_latitude

### 失物招领

支持：

-   发布失物
-   发布招领
-   类型切换
-   搜索
-   状态筛选

采用独立数据模型。

### 租赁与寄存

支持：

-   租赁发布
-   租赁订单
-   寄存服务
-   寄存需求

### 公益循环

支持：

-   免费发布
-   领取申请
-   捐赠记录
-   公益积分

------------------------------------------------------------------------

## 11. 新功能开发流程

推荐流程：

    需求分析
    ↓
    数据库设计
    ↓
    新增 migration
    ↓
    后端 API
    ↓
    前端页面
    ↓
    测试
    ↓
    Pull Request

数据库新增结构：

不要修改历史：

    V001
    V002
    ...

新增：

    V012_xxx.sql

------------------------------------------------------------------------

## 12. Git 协作规范

不要直接修改：

    merge-b-version

推荐：

    feature/功能名称

开发完成后：

    feature
    ↓
    测试
    ↓
    Pull Request
    ↓
    merge-b-version

------------------------------------------------------------------------

## 13. 常见问题

### 页面打开但接口失败

检查：

-   后端是否启动
-   `.env` 是否正确
-   Network 请求状态

### 字段不存在

执行：

``` bash
npm run db:migrate
```

不要重新初始化。

### vite 找不到

进入对应前端目录：

``` bash
npm install
```

------------------------------------------------------------------------

## 14. 完整启动流程

``` bash
git clone 项目地址

CREATE DATABASE campus_trade;

# 后端
cd server
npm install
npm run db:init
npm run dev

# 用户端
cd client/user-app
npm install
npm run dev

# 管理端
cd client/vue-project
npm install
npm run dev
```

完成以上步骤即可运行 CampusTrade。
