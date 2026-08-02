# GIS_P 江苏 / 安徽本地地图 MVP

## 当前目标

这套 MVP 不是单纯的地图演示，而是一套个人可控、断网后仍可使用的地理信息系统：

- 本地 OSM 参考底图，可独立更新和回滚；
- 自己的点位、轨迹、照片、分类、标签和备注；
- GPX 导入、GeoJSON 导出；
- PostGIS 空间索引、版本号和变更记录；
- 数据库与照片备份、校验和恢复；
- 完整离线地址、反向查询、路线、高程、地形、应急参考和中文百科。

## 使用入口

浏览器只需要访问：

```text
http://localhost:8080/
```

`/api/health`、`/martin/catalog` 等地址返回 JSON 是正常现象，它们是机器接口，不是地图页面。

## 三层数据

| 层 | 当前实现 | 是否可替换 |
| --- | --- | --- |
| 参考底图 | OSM -> Osmium -> Planetiler -> `suwan.pmtiles` | 可重建，不影响个人数据 |
| 个人数据 | FastAPI -> PostGIS，照片按 SHA256 存储 | 长期保留，是系统核心资产 |
| 浏览界面 | MapLibre + 本地样式、字体、图标 | 可持续改进或更换客户端 |
| 高级参考 | Nominatim + Valhalla + HGT + Kiwix | 均位于稳定本地接口之后 |

## 当前能力

- 苏皖、沪浙两个可校验矢量区域包，实际生成到 `z16`，MapLibre 可继续放大到 `z18`；
- 标准/探索两套 OSM-like 配色；
- 地形、水系、用地、道路、铁路、建筑、行政边界、地名、道路名、POI 与图例；
- 添加、编辑、删除个人点位；
- 导入 GPX、查看和删除轨迹；
- 上传并关联照片；
- 个人数据搜索、统计、导出；
- 健康检查、API 冒烟测试和真实浏览器截图测试。
- 完整地址搜索、地图点反查地址、驾车/骑行/步行路线和轨迹保存；
- 路线高程剖面、地形阴影、应急设施分类和本地中文百科。

## 运行与维护

```powershell
D:\GISS\start-giss.cmd
D:\GISS\health-check.cmd
D:\GISS\smoke-test.cmd
D:\GISS\backup-giss.cmd
```

当前只有 `127.0.0.1:8080` 对宿主机开放，数据库、API 和 Martin 不单独暴露端口。

详细说明以根目录 `README.md` 和 `docs/ARCHITECTURE.md`、`docs/OPERATIONS.md`、`docs/REBUILD.md` 为准。
