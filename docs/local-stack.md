# 本地 PostGIS + Martin + MapLibre 栈

> 本页是快速摘要。完整信息见[技术架构与组合逻辑](architecture.md)、[资源与配置清单](resource-configuration.md)和[运行与验证手册](operations.md)。

当前 MVP 范围只做江苏省和安徽省。

## 组件作用

| 组件 | 地址 | 作用 |
|---|---|---|
| PostGIS | `localhost:5432` | 长期保存个人点位、轨迹、照片路径、分类和备注 |
| Martin | `http://localhost:3000` | 从 PostGIS 发布矢量瓦片，供 Web 地图读取 |
| MapLibre 页面 | `http://localhost:8080/web/` | 浏览器地图界面，当前先读取 `data/places.geojson` |

## 当前文件

| 文件 | 作用 |
|---|---|
| `services/docker-compose.yml` | 启动 PostGIS 和 Martin |
| `services/postgis/init.sql` | 初始化 `app.places` 表和苏皖示例点 |
| `services/martin/config.yml` | 只允许 Martin 发布 `app.places_web` |
| `data/places.geojson` | 静态预览用点位数据 |
| `web/index.html` | MapLibre 地图页面 |
| `scripts/start-web.ps1` | 启动本地静态 Web 服务 |
| `scripts/start-services.ps1` | Docker 可用后启动 PostGIS/Martin |

## 启动方式

只启动 Web 静态预览：

```powershell
.\scripts\start-web.ps1
```

打开：

```text
http://localhost:8080/web/
```

如果 `8080` 已被其他本地服务占用，可从项目根目录临时改用：

```powershell
.\scripts\start-web.ps1 -Port 8081
```

并打开 `http://localhost:8081/web/`。

Docker Desktop 可用时，启动数据库和瓦片服务：

```powershell
.\scripts\start-services.ps1
```

当前 Compose 使用本地开发凭据 `gis/gis`，并将 5432、3000 映射到主机；不要直接用于公网或生产环境。

## 数据范围

地图初始视野和最大视野限定在江苏、安徽附近：

```text
经度：约 114.7 - 122.1
纬度：约 29.3 - 35.4
```

后续可以接入 Geofabrik/BBBike 的江苏、安徽 OSM 数据，或者先继续使用在线 OSM 底图，只把个人标记数据放进 PostGIS。
