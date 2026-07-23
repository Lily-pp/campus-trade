# 数据库迁移说明

CampusTrade 使用 `database/migrations` 中的版本化 SQL 管理 PostgreSQL 数据库结构。迁移状态记录在数据库的 `schema_migrations` 表中，该表是判断迁移是否执行的唯一依据。

## 正式迁移链

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
V010_lost_found.sql
V011_expected_address.sql
```

迁移文件必须使用 `V数字_名称.sql` 格式，版本号从 V001 开始连续且不能重复。新数据库变更必须创建下一个版本的 SQL 文件，禁止修改已经执行过的历史迁移。

## 全新数据库

仅对新建的空数据库使用：

```powershell
cd server
npm run db:init
```

`db:init` 会从 V001 开始执行完整迁移链。部分早期迁移包含测试数据清理、序列重置和种子数据，因此绝对不能在已有业务数据的数据库上重新运行。

初始化脚本会在每个迁移成功后同步写入 `schema_migrations`。初始化完成后，可以直接使用 `db:migrate` 执行未来增量迁移，不需要再运行 baseline。

## 已有数据库首次接入迁移记录

已有数据库禁止执行 `db:init`。

先进行只读计划检查：

```powershell
cd server
npm run db:baseline:dry
```

确认 V001–当前版本需要的表和字段全部存在后，再写入基线：

```powershell
npm run db:baseline
```

Baseline 脚本不会执行迁移 SQL。它会逐版本检查必要结构，只有所有版本检查通过后，才在一个事务中将尚未登记的版本写入 `schema_migrations`。如果中间版本缺少必要结构，脚本会停止，且不会跨过缺失版本登记后续迁移。

`--dry-run` 不创建或写入 `schema_migrations`，只读取数据库结构和已有迁移记录并输出计划。

## 后续升级

数据库完成 baseline 后，所有后续升级使用：

```powershell
cd server
npm run db:migrate
```

迁移器会：

1. 校验迁移文件名、版本连续性和版本唯一性；
2. 计算每个 SQL 文件的 SHA-256 checksum；
3. 读取 `schema_migrations`；
4. 跳过 checksum 一致的已执行迁移；
5. 对每个待执行迁移使用独立事务；
6. 在同一事务中执行 SQL 并写入迁移记录；
7. 失败时回滚当前迁移并停止后续执行。

部分历史 SQL 文件自身带有独立成行的 `BEGIN/COMMIT`。执行时脚本会从执行副本中移除这些事务控制行，由迁移器统一管理外层事务；原 SQL 文件和用于校验的 checksum 不会因此改变。

如果数据库中已经存在业务表但 `schema_migrations` 没有记录，`db:migrate` 会拒绝从 V001 开始执行，并提示先完成 baseline。

如果已执行版本的文件名或 checksum 发生变化，迁移器会拒绝继续。不要通过手工修改 `schema_migrations` 绕过校验，应恢复原始历史文件并通过新版本迁移完成修正。

## schema_migrations

```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
  version VARCHAR(20) PRIMARY KEY,
  filename VARCHAR(255) NOT NULL,
  checksum VARCHAR(64),
  executed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

`schema_migrations` 是迁移状态的唯一依据。不要根据“某张表看起来存在”推断迁移已执行；结构检查只用于已有数据库首次 baseline。

## 操作规则

- 已有数据库禁止重新执行 `db:init`。
- 已执行的历史迁移禁止修改、重命名或删除。
- 新变更必须创建新的、更高版本 SQL。
- 禁止同时运行两个迁移进程；脚本也会使用 PostgreSQL advisory lock 防止并发。
- 正式升级前应备份数据库，并先在数据库副本验证。
- 不要把历史合并脚本放回 `database/migrations`。

历史合并脚本 `database/archive/V003-V009_merged_legacy.sql` 仅用于追溯，不属于正式迁移链，也不会被迁移器扫描。
