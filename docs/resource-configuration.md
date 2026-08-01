# 资源与配置清单

本文逐项记录项目已经声明或实际使用的计算、网络、存储、数据库、前端和外部资源。除“本机观测”小节外，配置事实均来自仓库文件。

## 1. 配置事实源

| 优先级 | 文件 | 决定的内容 |
|---:|---|---|
| 1 | `services/docker-compose.yml` | 容器镜像、名称、端口、卷、环境变量、健康检查、依赖和 Martin 参数 |
| 2 | `services/postgis/init.sql` | 扩展、schema、表、约束、索引、种子数据和发布视图 |
| 3 | `services/martin/config.yml` | Martin 监听、CORS、数据库连接引用和唯一发布源白名单 |
| 4 | `web/index.html` | MapLibre 版本、外部资源 URL、地图范围、数据源选择、样式和交互 |
| 5 | `scripts/start-services.ps1` | 服务启动目录、Docker 前置检查和启动命令 |
| 6 | `scripts/start-web.ps1` | 静态服务器实现、默认绑定地址和可覆盖端口 |
| 7 | `data/places.geojson` | 静态回退数据结构和演示点 |

文档不是运行时配置源；若上述文件变化，应同步更新本文。

## 2. 主机资源

### 2.1 必需软件

| 软件 | 用途 | 最低要求/当前约束 |
|---|---|---|
| Windows PowerShell | 执行 `.ps1` 启动脚本 | 脚本使用标准 cmdlet，无模块依赖 |
| Python | 提供静态 HTTP 服务 | 必须能执行 `python -m http.server` |
| Docker Desktop / Engine | 运行 PostGIS 和 Martin | 必须支持 `docker compose` 与 Linux 容器 |
| 浏览器 | 运行 MapLibre/WebGL | 需支持现代 JavaScript、Fetch、WebGL |
| 网络连接 | 加载 MapLibre CDN 与 OSM 瓦片 | 当前在线底图路径需要公网 |

Node.js、npm、QGIS、GDAL、`psql` 和 GitHub CLI 都不是当前运行静态 MVP 的硬依赖；它们分别属于未来前端构建、桌面 GIS、数据导入、数据库运维和 GitHub 发布工具链。

### 2.2 2026-08-01 本机观测快照

这部分只说明检查时的主机状态，不属于可移植配置：

| 项目 | 观测结果 |
|---|---|
| Git | 2.53.0.windows.3，可用 |
| Python | 3.12.1，可用 |
| Docker Desktop | 4.80.0，可用 |
| Docker Engine | 29.6.1，`linux/amd64`，可用 |
| Docker Compose | v5.3.0，可用 |
| PostGIS 镜像 | `postgis/postgis:16-3.5` 已在本地 |
| Martin 镜像 | `ghcr.io/maplibre/martin:1.11.0` 对应镜像已在本地（此前以 `latest` 标签拉取） |
| 本项目容器 | 未运行 |
| 端口 3000 | 未发现监听 |
| 端口 5432 | 未发现监听 |
| 端口 8080 | 已被另一项目的 `giss-web` 容器占用 |
| Node.js / npm | 未发现 |
| QGIS / GDAL / `psql` | 未发现于 PATH |
| GitHub CLI `gh` | 2.97.0，已认证账号 `bd4rex` |
| Git 仓库/remote | 本地 `main`；`origin` 指向公开仓库 `https://github.com/bd4rex/personal-gis.git` |

因此，Compose 与 GitHub 发布工具链都已就绪；默认 Web 启动端口当前仍与另一项目冲突，可使用 `-Port 8081`。

### 2.3 实机验证基线

使用全新的 `personal-gis_postgis_data` 演示卷验证后，结果如下：

| 检查项 | 结果 |
|---|---|
| PostgreSQL | 16.9 |
| PostGIS | 3.5.2 |
| Martin | 1.11.0 |
| PostGIS health | healthy |
| Martin health | healthy |
| 数据库对象 | `app.places` 基表、`app.places_web` 视图 |
| 种子数据 | 2 条，全部为 SRID 4326 |
| Martin catalog | 只有 `places_web`，未发布底层表或 `tiger.*` |
| TileJSON | `places_web` / TileJSON 3.0.0，字段与边界正确 |
| MVT | `z=7/x=106/y=51` 返回 HTTP 200、`application/x-protobuf`、348 字节 |
| 静态页面 | `/web/` 返回 HTTP 200，UTF-8 标题正确 |
| 静态 GeoJSON | `/data/places.geojson` 返回 HTTP 200、2 个 Feature |
| CORS | 从 `http://127.0.0.1:8081` 请求 Martin 成功，响应允许该 Origin |

干净卷首次启动时 Martin 重启计数为 5：PostGIS 初始化过程中临时数据库会切换为正式数据库，`pg_isready` 可能在切换前短暂成功；`restart: unless-stopped` 让 Martin 在正式数据库就绪后自动恢复。验证完成后容器已停止，演示数据卷保留。

## 3. Docker Compose 资源

### 3.1 资源拓扑

```mermaid
flowchart TB
    subgraph HOST["Windows 主机"]
        H5432["0.0.0.0:5432"]
        H3000["0.0.0.0:3000"]
        INIT["services/postgis/init.sql\n只读 bind mount"]
        MCFG["services/martin/config.yml\n只读 bind mount"]
        VOL["personal-gis_postgis_data\n命名卷"]
    end

    subgraph NET["Compose 独立网络 personal-gis_default"]
        PG["personal-gis-postgis\npostgis/postgis:16-3.5\nTCP 5432"]
        MARTIN["personal-gis-martin\nghcr.io/maplibre/martin:1.11.0\nHTTP 3000"]
        MARTIN -->|"postgres://gis:gis@postgis:5432/personal_gis"| PG
    end

    H5432 --> PG
    H3000 --> MARTIN
    INIT -->|"/docker-entrypoint-initdb.d/01-init.sql:ro"| PG
    MCFG -->|"/config.yml:ro"| MARTIN
    VOL -->|"/var/lib/postgresql/data"| PG
```

Compose 顶层显式声明 `name: personal-gis`，所以网络和命名卷的实际名称分别是 `personal-gis_default` 与 `personal-gis_postgis_data`。固定项目名可避免多个仓库都把编排文件放在通用的 `services/` 目录时被 Compose 错误归入同一项目。

### 3.2 PostGIS 服务

| 配置项 | 值 | 含义 |
|---|---|---|
| Compose service | `postgis` | Docker 内部 DNS 名也是 `postgis` |
| image | `postgis/postgis:16-3.5` | PostgreSQL 16 + PostGIS 3.5 镜像系列；满足 Martin 1.11 的建议最低版本 |
| container_name | `personal-gis-postgis` | 固定容器名，不能按同名配置横向扩展 |
| restart | `unless-stopped` | 异常退出或 Docker 重启后自动恢复，显式停止后不自动启动 |
| database | `personal_gis` | 首次初始化创建的数据库 |
| user | `gis` | 数据库用户 |
| password | `gis` | 本地开发明文默认密码 |
| host port | `5432` | 主机访问端口 |
| container port | `5432` | PostgreSQL 服务端口 |
| Compose project | `personal-gis` | 隔离容器、网络和卷的项目命名空间 |
| persistent volume | `personal-gis_postgis_data` | 保存数据库集群文件 |
| volume target | `/var/lib/postgresql/data` | 容器内 PostgreSQL 数据目录 |
| init bind source | `services/postgis/init.sql` | 主机上的初始化 SQL |
| init bind target | `/docker-entrypoint-initdb.d/01-init.sql` | 镜像首次初始化入口 |
| init mount mode | read-only | 容器不可修改主机 SQL |
| network | `personal-gis_default` | Compose 自动创建的桥接网络 |

环境变量原值：

```text
POSTGRES_DB=personal_gis
POSTGRES_USER=gis
POSTGRES_PASSWORD=gis
```

健康检查：

| 项目 | 值 |
|---|---|
| command | `pg_isready -U gis -d personal_gis` |
| interval | 5 秒 |
| timeout | 5 秒 |
| retries | 20 次 |
| start_period | 未配置 |
| 判定用途 | Martin 的 `depends_on.condition=service_healthy` |

理论上检查最多可经历约 100 秒的重试间隔；实际失败时间还受单次超时和 Docker 调度影响，不能把 100 秒当成严格上限。

### 3.3 Martin 服务

| 配置项 | 值 | 含义 |
|---|---|---|
| Compose service | `martin` | 服务标识 |
| image | `ghcr.io/maplibre/martin:1.11.0` | 锁定 Martin 语义版本 |
| container_name | `personal-gis-martin` | 固定容器名 |
| restart | `unless-stopped` | 首次数据库初始化瞬时断连或服务异常退出后自动重试 |
| host port | `3000` | 浏览器访问的 HTTP 端口 |
| container port | `3000` | Martin 监听端口 |
| command | `--config /config.yml` | 使用显式配置文件，不走全库自动发现 |
| config bind source | `services/martin/config.yml` | 主机上的版本化 Martin 配置 |
| config bind target | `/config.yml:ro` | 容器内只读配置路径 |
| listen_addresses | `0.0.0.0:3000` | 容器内监听全部接口 |
| cors | `true` | 允许不同端口的本地 Web 页面跨源读取 TileJSON/MVT |
| default_srid | `4326` | SRID 缺失时使用的默认值；当前 geometry 已显式为 4326 |
| database URL | `postgres://gis:gis@postgis:5432/personal_gis` | 通过 Docker DNS 访问 PostGIS |
| depends_on | `postgis: service_healthy` | PostGIS 健康后才启动 Martin |
| persistent volume | 无 | Martin 为无状态发布服务 |
| auto_publish | `false` | 禁止发布未列入白名单的空间表、视图和函数 |
| table source | `places_web` → `app.places_web.geom` | 唯一对 Web 发布的数据库源 |
| properties | 除 `geom` 外的 12 个业务字段 | 明确允许写入瓦片属性的字段 |
| image healthcheck | `wget --spider http://127.0.0.1:3000/health` | 镜像内置；Compose 状态显示 Martin 健康度 |

当前已配置源白名单，且前端发布源 ID 固定为 `places_web`。文本型 `id` 作为普通瓦片属性发布，没有配置 MVT feature ID；Martin/PostGIS 的 MVT 聚合只接受整数型 feature ID。未显式配置 cache、route prefix、base path、TLS 或认证；Martin 1.11.0 会使用自身默认缓存配置（全局默认 512 MB，包含瓦片及其他内部缓存分配），但容器仍没有硬性内存上限。

### 3.4 未配置的容器资源

以下项目在 Compose 中均未声明，运行时使用 Docker 默认行为：

| 项目 | 当前状态 | 影响 |
|---|---|---|
| CPU 限额/预留 | 未配置 | 容器可在 Docker Desktop 总配额内竞争 CPU |
| 内存限额/预留 | 未配置 | 容器可在 Docker Desktop 总配额内增长 |
| 日志驱动/轮转 | 未配置 | 使用 Docker 默认日志配置，可能持续增长 |
| read-only root filesystem | 未配置 | 容器根文件系统可写 |
| user | 未配置 | 使用镜像默认用户 |
| secrets | 未配置 | 密码直接位于 Compose 环境变量和连接 URL 中 |
| TLS | 未配置 | 数据库与 HTTP 均为本地明文连接 |
| healthcheck: Martin | Compose 未覆盖 | 使用 Martin 1.11.0 镜像内置 `/health` 检查；间隔/超时采用镜像或 Docker 默认值 |
| 备份/监控 | 未配置 | 需要运维命令或后续服务补充 |
| 镜像摘要 | 未配置 | Martin 与 PostGIS 都锁定标签但未锁 digest，上游重推时仍可能漂移 |

## 4. 网络资源与端点

| 方向 | 协议/端口 | 地址 | 生产者 | 消费者 | 状态 |
|---|---|---|---|---|---|
| 主机 → 静态 Web | HTTP/8080（默认） | `http://127.0.0.1:8080/` | Python `http.server` | 浏览器 | 仅绑定 loopback；可用 `-Port` 覆盖；本机默认端口冲突 |
| 浏览器 → 页面 | HTTP/8080 | `/web/` | 静态 Web | 浏览器 | 已实现 |
| 浏览器 → GeoJSON | HTTP/8080 | `/data/places.geojson` | 静态 Web | MapLibre | 已实现 |
| 浏览器 → Martin | HTTP/3000 | `http://localhost:3000/places_web` | Martin | MapLibre | 已配置；当前未运行 |
| 浏览器 → MVT | HTTP/3000 | `/places_web/{z}/{x}/{y}` | Martin | MapLibre | 由 TileJSON 间接提供 |
| Martin → PostGIS | PostgreSQL/5432 | `postgis:5432/personal_gis` | PostGIS | Martin | Docker 内网 |
| 主机 → PostGIS | PostgreSQL/5432 | `localhost:5432/personal_gis` | PostGIS | QGIS/psql/工具 | 已映射；当前未运行 |
| 浏览器 → MapLibre CDN | HTTPS/443 | `unpkg.com/maplibre-gl@5.6.0/...` | unpkg | 浏览器 | 外部依赖 |
| 浏览器 → OSM | HTTPS/443 | `tile.openstreetmap.org/{z}/{x}/{y}.png` | OSM | MapLibre | 外部依赖 |

端口映射写成 `"5432:5432"` 和 `"3000:3000"`，未限定 `127.0.0.1`。在 Docker Desktop 的实际网络策略允许时，它们可能从主机其他接口可达；不要把默认密码配置暴露到不受信任网络。

## 5. 持久化与文件资源

### 5.1 数据分类

| 资源 | 位置 | 生命周期 | 是否应提交 Git | 备份优先级 |
|---|---|---|---|---|
| 数据库 | Docker 卷 `personal-gis_postgis_data` | 跨容器重建保留 | 否 | 高 |
| 初始化 DDL/种子 | `services/postgis/init.sql` | 版本化配置 | 是 | 高 |
| 演示 GeoJSON | `data/places.geojson` | 版本化脱敏样例 | 是 | 中 |
| 个人导入文件 | `data/imports/` | 本地原始输入 | 否 | 视来源而定 |
| 个人照片 | `data/photos/` | 本地附件 | 否 | 高 |
| 离线底图 | `data/basemaps/` | 可重新下载/生成的大文件 | 否 | 低或中 |
| QGIS 项目定义 | 未来 `qgis/*.qgz` | 项目配置 | 可提交，但先检查数据源路径和凭据 | 高 |
| GeoPackage | 未来 `*.gpkg` | 文件型主数据/缓存 | 默认不提交 | 高 |
| 会话工作记录 | `gao/` | 工具会话与中间记录 | 否 | 低 |
| 文档与脚本 | `docs/`、`scripts/` | 版本化资产 | 是 | 高 |

### 5.2 文档整理前的初始文件量

以下是开始整理前的盘点基线，用于说明原项目规模；不含本轮新增文档和配置：

| 区域 | 文件数 | 字节数 | 说明 |
|---|---:|---:|---|
| `data/` | 1 | 1,301 | 仅演示 GeoJSON |
| `docs/`（整理前） | 2 | 8,699 | 原有规划与栈摘要 |
| `scripts/` | 2 | 633 | 两个 PowerShell 启动脚本 |
| `services/` | 2 | 2,888 | 原始 Compose 与初始化 SQL |
| `web/` | 1 | 6,889 | 单文件 Web 页面 |
| `gao/` | 2 | 205,476 | 会话记录，已排除发布 |

数据库卷、镜像和未来底图不计入代码目录文件量。检查时本地 PostGIS 16-3.5 镜像约 883 MB、Martin 1.11.0 镜像约 747 MB；这些大小依本地镜像版本和 Docker 显示口径变化，不是容量承诺。

## 6. 数据库资源

### 6.1 数据库对象层级

```mermaid
flowchart TB
    DB["database: personal_gis"] --> EXT["extension: postgis"]
    DB --> SCHEMA["schema: app"]
    SCHEMA --> TABLE["table: app.places"]
    SCHEMA --> VIEW["view: app.places_web"]
    TABLE --> PK["PRIMARY KEY id"]
    TABLE --> CHECK["CHECK rating 0..5"]
    TABLE --> I1["GiST geom"]
    TABLE --> I2["B-tree province"]
    TABLE --> I3["B-tree category"]
    TABLE --> I4["B-tree updated_at"]
    VIEW -->|"SELECT 全部当前字段"| TABLE
```

### 6.2 `app.places` 字段

| 字段 | PostgreSQL 类型 | Null | 默认值 | 约束/语义 | Web 是否发布 |
|---|---|---:|---|---|---:|
| `id` | `text` | 否 | 无 | 主键、稳定 ID | 是 |
| `name` | `text` | 否 | 无 | 名称 | 是 |
| `province` | `text` | 否 | `''` | 省份 | 是 |
| `category` | `text` | 否 | `'todo'` | 分类 | 是 |
| `note` | `text` | 否 | `''` | 备注 | 是 |
| `tags` | `text` | 否 | `''` | 当前是逗号分隔文本 | 是 |
| `rating` | `integer` | 否 | `0` | `0..5` 检查约束 | 是 |
| `source` | `text` | 否 | `'manual'` | 数据来源 | 是 |
| `photo_path` | `text` | 否 | `''` | 本地相对路径约定，数据库不验证 | 是 |
| `created_at` | `timestamptz` | 否 | `now()` | 创建时间 | 是 |
| `updated_at` | `timestamptz` | 否 | `now()` | 更新时间，调用方负责维护 | 是 |
| `sync_state` | `text` | 否 | `'local'` | 同步状态 | 是 |
| `geom` | `geometry(Point,4326)` | 否 | 无 | WGS84 点 | 是，作为几何列 |

### 6.3 索引

| 索引 | 方法 | 列 | 用途 |
|---|---|---|---|
| `app.places_pkey` | B-tree（主键隐式创建） | `id` | 唯一性、按 ID 查找、冲突判断 |
| `places_geom_idx` | GiST | `geom` | 视窗/相交/邻近等空间查询 |
| `places_province_idx` | B-tree | `province` | 省份筛选 |
| `places_category_idx` | B-tree | `category` | 分类筛选 |
| `places_updated_at_idx` | B-tree | `updated_at` | 按更新时间排序或增量读取 |

### 6.4 视图

`app.places_web` 原样选择 `app.places` 的 13 个字段。Martin 只允许发布该视图，不发布底层表和 `tiger.*` 等 PostGIS 附带对象。它的主要作用是给发布层提供稳定名称和未来的字段裁剪边界。目前它没有：

- 行级过滤；
- 字段脱敏；
- 空间范围过滤；
- 权限隔离；
- 物化缓存；
- 自定义 TileJSON 元数据。

### 6.5 种子数据

| ID | 名称 | 省份 | 分类 | 评分 | 坐标 `[经度, 纬度]` | 来源 |
|---|---|---|---|---:|---|---|
| `demo-001` | 南京示例点 | 江苏省 | `todo` | 3 | `[118.7969, 32.0603]` | `manual` |
| `demo-002` | 合肥示例点 | 安徽省 | `field` | 4 | `[117.2272, 31.8206]` | `manual` |

GeoJSON 和初始化 SQL 都包含这两个逻辑演示点，但备注文字略有差异。SQL 使用 `ON CONFLICT (id) DO NOTHING`，不会覆盖已有同 ID 记录。

### 6.6 初始化生命周期

```mermaid
stateDiagram-v2
    [*] --> EmptyVolume: 首次创建 personal-gis_postgis_data
    EmptyVolume --> InitScripts: PostGIS 镜像初始化数据库
    InitScripts --> Ready: 执行 01-init.sql 成功
    Ready --> Reused: 容器停止后再次启动
    Reused --> Reused: 复用同一命名卷
    note right of Reused
      init.sql 不会再次自动执行；
      文件更新不等于数据库迁移。
    end note
```

## 7. Web 前端配置

### 7.1 运行库和页面

| 项目 | 值 |
|---|---|
| HTML 语言 | `zh-CN` |
| 页面标题 | `个人 GIS MVP - 江苏 / 安徽` |
| 字体 | `Microsoft YaHei`, Arial, sans-serif |
| MapLibre CSS | `https://unpkg.com/maplibre-gl@5.6.0/dist/maplibre-gl.css` |
| MapLibre JS | `https://unpkg.com/maplibre-gl@5.6.0/dist/maplibre-gl.js` |
| 构建步骤 | 无；浏览器直接执行单文件脚本 |
| Web 根目录 | 项目根目录，由 `python -m http.server` 暴露 |
| 页面路径 | `/web/` |
| GeoJSON 相对路径 | `../data/places.geojson` |
| 默认绑定地址 | `127.0.0.1`，可用 `-BindAddress` 覆盖 |
| 默认端口 | `8080`，可用 `-Port` 覆盖，范围 `1..65535` |

### 7.2 地图范围

| 参数 | 西南角 | 东北角 | 用途 |
|---|---|---|---|
| 初始 `bounds` | `[114.7, 29.3]` | `[122.1, 35.4]` | 首次加载自动适配江苏、安徽 |
| `maxBounds` | `[113.8, 28.5]` | `[123.0, 36.2]` | 限制用户可平移范围 |
| `fitBoundsOptions.padding` | - | `60 px` | 初始视图留白 |
| CRS 语义 | 经度/纬度 | EPSG:4326 | 与 GeoJSON/PostGIS 坐标一致 |

### 7.3 底图源

| 项目 | 值 |
|---|---|
| source id | `osm` |
| type | `raster` |
| tile URL | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` |
| tile size | 256 px |
| attribution | `© OpenStreetMap contributors` |
| layer id/type | `osm` / `raster` |

### 7.4 点位源选择

| 优先级 | source id | type | URL/data | source-layer |
|---:|---|---|---|---|
| 1 | `places` | `vector` | `http://localhost:3000/places_web` | `places_web` |
| 2 | `places` | `geojson` | 解析后的 `../data/places.geojson` 对象 | 不适用 |

Martin 探测以 HTTP `ok` 为成功标准。没有超时控制、重试或可配置后端 URL。

### 7.5 图层样式与交互

| 项目 | 值 |
|---|---|
| 点图层 ID | `places-circle` |
| 点半径 | 8 px |
| `field` 颜色 | `#1f7a53` |
| `todo` 颜色 | `#d84b2a` |
| 其他分类颜色 | `#3569a8` |
| 描边 | 2 px、白色 `#ffffff` |
| 标签图层 ID | `places-label` |
| 标签字段 | `name` |
| 标签字号 | 13 px |
| 标签偏移/锚点 | `[0, 1.25]` / `top` |
| 标签颜色 | `#1c2c22` |
| 光晕 | 白色、1.5 px |
| 导航控件 | 右下角，启用 pitch 可视化 |
| 点击弹窗 | 名称；省份、分类、来源；备注 |
| hover | 点图层上使用 pointer 光标 |

## 8. 外部资源与许可/服务边界

| 资源 | 当前用途 | 运行时失败结果 | 管理建议 |
|---|---|---|---|
| unpkg | 下载固定版本 MapLibre JS/CSS | 地图脚本或样式无法加载 | 长期离线部署改为本地托管并保留许可证 |
| OpenStreetMap tile server | 在线栅格底图 | 底图空白，个人点层也可能因 MapLibre 未加载而不可见 | 遵守 OSM tile usage policy；不要用于高流量批量离线抓取 |
| Docker Hub | 获取 PostGIS 镜像 | 首次部署无法拉取镜像 | 锁定版本并记录镜像摘要 |
| GitHub Container Registry | 获取 Martin 1.11.0 镜像 | 首次部署无法拉取镜像 | 已锁版本；稳定基线再记录镜像摘要 |

项目没有把这些第三方资源打包进仓库。

## 9. 容量与性能边界

当前没有显式容量配额。容量增长主要发生在：

1. `personal-gis_postgis_data` 数据库卷；
2. Docker 镜像与容器日志；
3. 未来的照片、GeoPackage、导入包和离线底图；
4. 浏览器加载整个 GeoJSON 时的内存使用。

当前 2 个点的 GeoJSON 不构成性能问题。点位显著增长后，应以 PostGIS + Martin 矢量瓦片为主路径，避免浏览器每次读取完整 GeoJSON。任何磁盘、内存或点数上限都尚未在项目中定义，不能从当前配置推导出保证值。

## 10. 配置缺口清单

| 类别 | 缺口 | 建议落点 |
|---|---|---|
| 凭据 | 明文弱密码 | `.env` + 不提交的本地值，或 Docker secret |
| 端口 | 固定且未限制绑定地址 | Compose 环境变量；默认绑定 `127.0.0.1` |
| 版本 | 已锁定语义版本，未锁镜像 digest | 稳定部署再固定镜像 digest |
| 数据迁移 | 只有首次初始化 SQL | `services/postgis/migrations/` + 迁移工具 |
| 备份 | 无自动任务 | 运维脚本、备份目录和保留策略 |
| 可观测性 | Martin 只有镜像内置健康检查，无项目级指标/告警 | 显式 healthcheck + 日志/指标采集 |
| 资源治理 | 无 CPU/内存/日志限制 | Compose 资源与 logging 配置 |
| Web 配置 | 后端 URL、端口和范围硬编码 | 独立配置文件或环境注入 |
| 离线能力 | JS/CSS 和底图均远程 | 本地静态依赖 + MBTiles/PMTiles 服务 |
| 数据一致性 | GeoJSON 与 PostGIS 双写 | 单一事实源 + 自动导出流程 |
| 写入能力 | 无 Web API | 后续独立 API，并加入验证、权限、审计 |
| 隐私 | 个人位置/照片属于敏感数据，当前仓库公开 | 只发布脱敏演示点；真实数据留在忽略目录并加密备份 |

## 11. GitHub 发布资源边界

应发布：

- `.gitignore`、`README.md`；
- `docs/`；
- `scripts/`；
- `services/docker-compose.yml`、`services/postgis/init.sql`；
- `services/martin/config.yml`；
- `web/index.html`；
- 脱敏的 `data/places.geojson`。

不应发布：

- `gao/` 会话记录；
- `data/photos/` 个人照片；
- `data/imports/` 原始导入文件；
- `data/basemaps/` 大体积或受许可限制的瓦片；
- `.env`、真实密码、令牌和数据库转储；
- 含真实位置的 GeoPackage、GPX 或 OsmAnd 数据。
