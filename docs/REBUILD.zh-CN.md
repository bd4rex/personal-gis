# 从零重建

> [English](REBUILD.md) | 简体中文 · 快照 `2026-08-03T23:12:23+08:00`

本流程使用仓库文件和开放数据，从零重建当前江苏/安徽系统。

## 前提条件

- Windows 10/11 与 PowerShell 5.1 或更高版本；
- 使用 Linux 容器的 Docker Desktop；
- 构建时至少 8GB 可用内存、主机总内存至少 16GB，推荐 32GB；
- 当前两区域系统至少保留 80GB 空间；如果同一维护窗口还要重建共享索引并创建恢复包，建议保留 150GB；
- 下载阶段可以联网。

镜像、网页资源和数据准备好后，日常运行可以完全离线。

## 1. 恢复仓库

把项目放到 `D:\GISS`。不要从公开仓库恢复 `services/.env`。

本机 Docker Desktop 数据位于 `D:\DockerData\wsl`，通过 `CustomWslDistroDir` 配置。源代码检出不会自动创建或移动 Docker 数据，恢复大型镜像和卷前先确认位置。

应存在：

```text
config/
services/
scripts/
web/
tests/
docs/
```

## 2. 启动数据库与核心服务

```powershell
D:\GISS\start-giss.cmd
```

启动脚本会：

1. 缺失时创建带强随机密码的 `services/.env`；
2. 启动 PostGIS 并等待就绪；
3. 同步数据库角色密码；
4. 应用有序 SQL 迁移；
5. 构建并启动 FastAPI、Martin 和 nginx；
6. 已有高级产品时启动相应服务和维护工作器。

此时个人数据功能可用，但区域底图仍需要构建产品。

## 3. 下载浏览器资源

```powershell
D:\GISS\download-web-assets.cmd
```

该命令安装本地 MapLibre、PMTiles JS、Lucide、字形和 sprites，并生成来源清单。正常运行不依赖 CDN。

## 4. 下载 OSM 数据

```powershell
D:\GISS\download-osm.cmd
```

权威输入是：

```text
D:\GISS\raw\osm\china\china-latest.osm.pbf
```

旧入口只维护共享中国快照和复制状态，不再生成重复省级源树。34 个省级边界位于 `raw/osm/polygons`；大陆区域共用中国快照，台湾使用独立 Geofabrik 来源配置。

## 5. 构建省级地图

```powershell
D:\GISS\region-pack.cmd Plan -PackId jiangsu
D:\GISS\region-pack.cmd Build -PackId jiangsu
D:\GISS\region-pack.cmd Build -PackId anhui
```

每条命令生成一个独立版本的 OpenMapTiles PMTiles 与高细节叠加清单，最大缩放为 z16：

```text
D:\GISS\products\tiles\pmtiles\jiangsu.pmtiles
D:\GISS\products\tiles\pmtiles\anhui.pmtiles
```

在当前硬件上每个省可能需要几十分钟。新产品只有通过大小、首部、元数据和清单校验后才替换当前版本，并保留上一版用于回退。

## 6. 构建轻量离线搜索

```powershell
D:\GISS\build-capability-source.cmd
D:\GISS\import-reference-search.cmd
```

系统从 `giss-core-latest.osm.pbf` 生成命名地点索引，并在 PostGIS 记录源时间和 SHA256。数据库备份会包含该索引，但它仍可从共享源安全重建。

## 7. 构建高级离线能力

```powershell
D:\GISS\prepare-advanced.cmd
```

该命令准备共享能力源、中文维基百科和维基导游、全球概览、天气、航海、Valhalla 路线/海拔和 Nominatim 地址库。

16 GiB Windows 主机必须先完成 Valhalla，再进行 Nominatim 导入，避免两个重型构建共享 Docker 内存。

OSM Carto 作为独立、可续建流程构建：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\GISS\scripts\build-osm-carto.ps1
```

其数据库和瓦片缓存单独验收，并进入完整恢复包。

## 8. 验证

```powershell
D:\GISS\health-check.cmd
D:\GISS\smoke-test.cmd
```

然后打开：

```text
http://localhost:8080/
```

需要视觉回归时，运行 [运维文档](OPERATIONS.zh-CN.md)中的 Playwright 容器命令。

## 9. 建立恢复点

```powershell
D:\GISS\backup-giss.cmd
```

至少把以下内容复制到第二块物理磁盘：

- Git 仓库与 `backups/`；
- 已安装 PMTiles 和对应 manifest；
- 中国 PBF、状态和省级边界；
- 共享能力 PBF、Valhalla、百科、OSM Carto 来源；
- 无法联网拉取镜像时所需的 Docker 镜像归档。

## 完全断网重建准备

只有 Git 和个人数据库备份不足以完成无网重建。创建并演练完整恢复包：

```powershell
D:\GISS\create-offline-kit.cmd
D:\GISS\test-offline-recovery.cmd
```

恢复包包含固定运行镜像、本地构建镜像、Planetiler 与缓存输入、地图/PBF、Nominatim、OSM Carto 和新个人备份。具体校验与替换电脑恢复步骤见[离线恢复指南](OFFLINE_RECOVERY.zh-CN.md)。经过验证的 Docker Desktop 安装包需要单独离线保存。
