# 本地服务栈说明

> [English](local-stack.md) | 简体中文 · 快照 `2026-08-03T23:12:23+08:00`

| 组件 | 作用 | 宿主机暴露 |
| --- | --- | --- |
| nginx | 唯一入口、静态资源、PMTiles Range 与反向代理 | `127.0.0.1:8080` |
| MapLibre | 浏览器地图组合、矢量渲染与交互 | 通过 nginx |
| OSM Carto | 熟悉的本地 OSM 栅格地图 | 通过 `/carto/` |
| PMTiles | 独立版本的可交互区域矢量地图 | 通过 `/tiles/` |
| FastAPI | 个人 CRUD、GPX、媒体、搜索、路线适配、资源与导出 | 内部 |
| PostGIS | 个人权威数据、空间索引、版本与审计 | 内部 |
| Martin | 批准的个人数据矢量瓦片视图 | 内部 |
| Nominatim | 地址搜索与反向地理编码 | 内部 |
| Valhalla | 驾车、骑行和步行离线路线 | 内部 |
| Kiwix | 本地中文维基百科与维基导游 | 通过 `/wiki/` |
| HGT/Terrarium | 海拔、剖面、阴影与等高线 | 通过 `/api/` |

## 为什么有些地址返回 JSON

应用只访问 `http://localhost:8080/`，资源管理访问 `http://localhost:8080/resources.html`。`/api/health`、`/martin/catalog`、`/healthz` 本来就是机器接口。

## 为什么地图与个人数据分开

OSM 地图、搜索索引、路线和缓存都是可重建参考产品。个人点位、轨迹、照片和备注保存在 PostGIS 与 `data/media`，不可替代。这样可以更换渲染器或区域包而不迁移个人数据。

## 当前限制

- 当前高细节离线地图及共享搜索/路线范围是江苏、安徽、山东；后续范围由已安装且启用的区域清单自动推导。
- 全球目录描述可下载包，不代表全球地图已经安装。
- 中文维基百科采用 all-mini，不包含完整多媒体语料。
- 系统没有账号体系，只适合受信任 localhost 单用户环境。

扩展计划见[路线图](ROADMAP.zh-CN.md)。
