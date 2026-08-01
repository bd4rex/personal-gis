const state = {
  view: "versions",
  packs: [],
  inventory: null,
  maintenance: null,
  selected: new Set(),
  menuPackId: null,
  query: "",
  catalogQuery: "",
  catalogScope: "recommended",
  focusPackId: new URLSearchParams(location.search).get("pack"),
  polling: null,
  jobStatesReady: false,
  knownJobStates: new Map(),
  inventoryDirty: false,
  refreshing: false
};

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];
const icons = () => window.lucide?.createIcons({ attrs: { "stroke-width": 1.8 } });

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  })[character]);
}

function formatBytes(value) {
  const bytes = Number(value);
  if (!Number.isFinite(bytes) || bytes < 0) return "--";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let amount = bytes;
  let index = 0;
  while (amount >= 1024 && index < units.length - 1) { amount /= 1024; index += 1; }
  return `${amount.toFixed(index >= 3 ? 2 : index === 0 ? 0 : 1)} ${units[index]}`;
}

function formatDate(value) {
  if (!value) return "--";
  const date = new Date(value);
  if (Number.isNaN(date.valueOf())) return String(value);
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit"
  }).format(date);
}

function packName(pack) {
  if (pack?.kind === "country" && pack.countryId && typeof Intl.DisplayNames === "function") {
    try {
      return new Intl.DisplayNames(["zh-CN"], { type: "region" }).of(pack.countryId) || pack.shortName || pack.name || pack.id;
    } catch {}
  }
  return pack.shortName || pack.name || pack.id;
}

function requestError(error) {
  const message = error?.message || "请求失败";
  showNotice(message, true);
}

function showNotice(message, error = false) {
  const notice = $("#notice");
  notice.textContent = message;
  notice.classList.toggle("error", error);
  notice.hidden = false;
  clearTimeout(showNotice.timer);
  showNotice.timer = setTimeout(() => { notice.hidden = true; }, 6500);
}

function announceResourceChange(job) {
  const revision = JSON.stringify({
    at: new Date().toISOString(),
    resourceId: job.resourceId,
    action: job.action,
    status: job.status
  });
  localStorage.setItem("giss-resource-revision", revision);
}

function detectJobTransitions(jobs) {
  if (state.jobStatesReady) {
    for (const job of jobs) {
      const previous = state.knownJobStates.get(job.id);
      if (previous && ["queued", "running"].includes(previous) && job.status === "succeeded") {
        announceResourceChange(job);
        state.inventoryDirty = true;
      }
    }
  }
  state.knownJobStates = new Map(jobs.map((job) => [job.id, job.status]));
  state.jobStatesReady = true;
}

async function api(path, options = {}) {
  const response = await fetch(`/api${path}`, {
    ...options,
    headers: { "Content-Type": "application/json", ...(options.headers || {}) }
  });
  if (!response.ok) {
    let detail = `${response.status} ${response.statusText}`;
    try { detail = (await response.json()).detail || detail; } catch {}
    throw new Error(detail);
  }
  return response.status === 204 ? null : response.json();
}

async function loadInventory() {
  try {
    return await api("/resources?cached=true");
  } catch {
    return api("/resources");
  }
}

async function watchInventoryRefresh(previousGeneratedAt) {
  for (let attempt = 0; attempt < 150; attempt += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2000));
    try {
      const inventory = await api("/resources?cached=true");
      if (inventory.generatedAt && inventory.generatedAt !== previousGeneratedAt) {
        state.inventory = inventory;
        state.inventoryDirty = false;
        render();
        showNotice("本地资源状态已刷新");
        return;
      }
    } catch {}
  }
}

async function refresh({ upstream = false, quiet = false, freshInventory = false } = {}) {
  if (state.refreshing) return;
  state.refreshing = true;
  const refreshButton = $("#refreshButton");
  const upstreamButton = $("#upstreamButton");
  (upstream ? upstreamButton : refreshButton).disabled = true;
  (upstream ? upstreamButton : refreshButton).classList.add("loading");
  try {
    if (upstream) await api("/resources?check_upstream=true");
    const shouldRefreshInventory = freshInventory || state.inventoryDirty;
    const [packs, inventory, maintenance] = await Promise.all([
      api("/map-packs"),
      upstream ? api("/resources?cached=true") : shouldRefreshInventory ? api("/resources") : loadInventory(),
      api("/maintenance")
    ]);
    state.inventoryDirty = false;
    state.packs = packs.packs || [];
    state.inventory = inventory;
    state.maintenance = maintenance;
    detectJobTransitions(maintenance.jobs || []);
    if (state.focusPackId) {
      const focusedPack = state.packs.find((pack) => pack.id === state.focusPackId);
      if (focusedPack && !focusedPack.installed) {
        state.view = "catalog";
        state.catalogScope = "global";
        state.catalogQuery = packName(focusedPack);
        $("#catalogSearch").value = packName(focusedPack);
        $$("[data-catalog-scope]").forEach((button) => button.classList.toggle("active", button.dataset.catalogScope === "global"));
      }
    }
    render();
    if (inventory.cache?.state === "refreshing") {
      watchInventoryRefresh(inventory.generatedAt);
      if (!quiet) showNotice(upstream ? "正在后台检查上游版本" : "正在后台盘点本地资源");
    } else if (!quiet) {
      showNotice(upstream ? "上游版本检查完成" : "本地资源状态已刷新");
    }
  } catch (error) {
    requestError(error);
  } finally {
    refreshButton.disabled = false;
    upstreamButton.disabled = false;
    refreshButton.classList.remove("loading");
    upstreamButton.classList.remove("loading");
    state.refreshing = false;
    icons();
  }
}

function renderStorage() {
  const storage = state.inventory?.storage || {};
  const total = Number(storage.diskTotalBytes) || 0;
  const used = Number(storage.diskUsedBytes) || 0;
  const free = Number(storage.diskFreeBytes) || 0;
  const managed = Number(storage.managedBytes) || 0;
  $("#storageFree").textContent = `${formatBytes(free)} 可用`;
  $("#storageMeta").textContent = `磁盘总计 ${formatBytes(total)} · 资源清单 ${formatDate(state.inventory?.generatedAt)}`;
  $("#storageUsedBar").style.width = `${total ? Math.min(100, used / total * 100) : 0}%`;
  $("#managedSize").textContent = formatBytes(managed);
  $("#diskUsed").textContent = formatBytes(used);
}

function renderNavigation() {
  const installed = state.packs.filter((pack) => pack.installed);
  const active = (state.maintenance?.jobs || []).filter((job) => ["queued", "running"].includes(job.status));
  $("#versionBadge").textContent = installed.length;
  $("#catalogBadge").textContent = state.packs.filter((pack) => !pack.installed).length;
  $("#localBadge").textContent = state.inventory?.localGroups?.reduce((sum, group) => sum + (group.items?.length || 0), 0) || 0;
  $("#taskBadge").textContent = active.length;
  const commonPack = installed.find((pack) => pack.currentSourceSequence);
  $("#sourceSequence").textContent = commonPack?.currentSourceSequence || "--";
  $("#sourceTimestamp").textContent = commonPack?.currentSourceUpdatedAt ? formatDate(commonPack.currentSourceUpdatedAt) : "没有可信状态";
  const worker = state.maintenance?.worker || {};
  $("#workerState").textContent = worker.online ? "维护服务在线" : "维护服务离线";
  $("#workerState").className = `status-pill ${worker.online ? "" : "error"}`;
  $$("[data-view]").forEach((button) => button.classList.toggle("active", button.dataset.view === state.view));
  $$(".view").forEach((view) => view.classList.toggle("active", view.id === `${state.view}View`));
}

function updateState(pack) {
  if (!pack.installed) return { label: "未安装", tone: "disabled" };
  if (pack.updateAvailable) return { label: "有新版本", tone: "update" };
  if (!pack.sourceSequence) return { label: "版本未知", tone: "error" };
  return { label: "已是最新", tone: "" };
}

function taskForPack(packId) {
  return (state.maintenance?.jobs || []).find((job) =>
    job.resourceId === packId && ["queued", "running"].includes(job.status)
  );
}

function renderVersions() {
  const normalized = state.query.trim().toLocaleLowerCase("zh-CN");
  const installed = state.packs.filter((pack) => pack.installed && (
    !normalized || `${packName(pack)} ${pack.name} ${pack.id} ${pack.groupName || ""}`.toLocaleLowerCase("zh-CN").includes(normalized)
  ));
  const advancedActionsReady = Number(state.maintenance?.worker?.schemaVersion || 0) >= 2;
  $("#versionRows").innerHTML = installed.length ? installed.map((pack) => {
    const status = updateState(pack);
    const job = taskForPack(pack.id);
    const focused = state.focusPackId === pack.id;
    const menuOpen = state.menuPackId === pack.id;
    return `<tr data-pack-row="${escapeHtml(pack.id)}" class="${focused ? "focused" : ""}">
      <td><input type="checkbox" data-select-pack="${escapeHtml(pack.id)}" ${state.selected.has(pack.id) ? "checked" : ""} /></td>
      <td><div class="pack-cell">
        <span class="pack-name"><i data-lucide="map"></i><strong>${escapeHtml(packName(pack))}</strong></span>
        <small>${pack.enabled === false ? "已停用，文件保留" : "已启用，参与渲染与索引"}</small>
      </div></td>
      <td><div class="version-cell">
        <span class="mono">序列 ${escapeHtml(pack.sourceSequence || "--")}</span>
        <small>源 ${escapeHtml(formatDate(pack.sourceUpdatedAt))}</small>
        <small>构建 ${escapeHtml(formatDate(pack.generatedAt))}</small>
      </div></td>
      <td><div class="version-cell">
        <span class="state-label ${status.tone}">${escapeHtml(job ? (job.status === "running" ? "执行中" : "等待中") : status.label)}</span>
        <small class="mono">${escapeHtml(pack.upstreamSourceSequence || pack.currentSourceSequence || "--")}</small>
        <small>${escapeHtml(formatDate(pack.upstreamSourceUpdatedAt || pack.currentSourceUpdatedAt))}</small>
      </div></td>
      <td><div class="rollback-cell">
        ${pack.rollbackReady
          ? `<span class="mono">序列 ${escapeHtml(pack.rollbackSourceSequence || "--")}</span><small>${escapeHtml(formatDate(pack.rollbackGeneratedAt))}</small><small>${escapeHtml(formatBytes(pack.rollbackBytes))}</small>`
          : "<span>没有回退副本</span><small>生成新版本后按需保留</small>"}
      </div></td>
      <td><strong>${escapeHtml(formatBytes(pack.bytes))}</strong></td>
      <td><div class="row-actions">
        ${pack.updateAvailable && !job ? `<button class="primary" type="button" data-pack-action="update" data-pack-id="${escapeHtml(pack.id)}"><i data-lucide="refresh-cw"></i><span>更新</span></button>` : ""}
        <button type="button" data-pack-menu="${escapeHtml(pack.id)}" title="更多操作" aria-label="${escapeHtml(packName(pack))}更多操作"><i data-lucide="more-vertical"></i></button>
        ${menuOpen ? `<div class="menu">
          <button type="button" data-pack-action="info" data-pack-id="${escapeHtml(pack.id)}"><i data-lucide="history"></i><span>版本详情</span></button>
          <button type="button" data-pack-action="verify" data-pack-id="${escapeHtml(pack.id)}" ${advancedActionsReady ? "" : "disabled"}><i data-lucide="shield-check"></i><span>校验完整性</span></button>
          <button type="button" data-pack-action="toggle" data-pack-id="${escapeHtml(pack.id)}"><i data-lucide="power"></i><span>${pack.enabled === false ? "启用地图包" : "停用地图包"}</span></button>
          <button type="button" data-pack-action="rebuild" data-pack-id="${escapeHtml(pack.id)}"><i data-lucide="hammer"></i><span>重新生成</span></button>
          <button type="button" data-pack-action="rollback" data-pack-id="${escapeHtml(pack.id)}" ${pack.rollbackReady && advancedActionsReady ? "" : "disabled"}><i data-lucide="rotate-ccw"></i><span>回退并保留当前版</span></button>
          <button type="button" data-pack-action="manifest" data-pack-id="${escapeHtml(pack.id)}"><i data-lucide="file-down"></i><span>导出清单</span></button>
          <button type="button" data-pack-action="browse" data-pack-id="${escapeHtml(pack.id)}" ${pack.enabled === false ? "disabled" : ""}><i data-lucide="map-pinned"></i><span>在地图中浏览</span></button>
          <button class="danger" type="button" data-pack-action="remove" data-pack-id="${escapeHtml(pack.id)}"><i data-lucide="trash-2"></i><span>受保护删除</span></button>
        </div>` : ""}
      </div></td>
    </tr>`;
  }).join("") : '<tr><td colspan="7"><div class="empty">没有匹配的已安装地图包</div></td></tr>';
  const selectedCount = state.selected.size;
  $("#selectedLabel").textContent = selectedCount ? `已选 ${selectedCount} 项` : "选择地图包";
  $("#selectAllPacks").checked = installed.length > 0 && installed.every((pack) => state.selected.has(pack.id));
  $$("[data-bulk-action]").forEach((button) => {
    button.disabled = selectedCount === 0 || (button.dataset.bulkAction === "verify" && !advancedActionsReady);
  });
}

function resourceStatus(item) {
  if (item.status === "ready") return ["就绪", ""];
  if (item.status === "warning") return ["需检查", "update"];
  if (item.status === "archive") return ["归档", "disabled"];
  if (item.status === "cache") return ["可再生", "disabled"];
  if (item.status === "external") return [item.storageClass === "external-runtime" ? "系统能力" : "外部卷", "disabled"];
  return ["未安装", "disabled"];
}

function renderLocal() {
  const summary = state.inventory?.summary || {};
  const hasActiveJobs = (state.maintenance?.jobs || []).some((job) => ["queued", "running"].includes(job.status));
  $("#resourceSummary").innerHTML = [
    ["当前地图", summary.currentMapBytes],
    ["地图回退", summary.rollbackMapBytes],
    ["源快照回退", summary.rollbackSourceBytes],
    ["可再生缓存", summary.regenerableCacheBytes]
  ].map(([label, bytes]) => `<div class="metric"><span>${label}</span><strong>${formatBytes(bytes || 0)}</strong></div>`).join("");
  $("#localGroups").innerHTML = (state.inventory?.localGroups || []).map((group) => `
    <section class="resource-group">
      <div class="section-title"><h3>${escapeHtml(group.name)}</h3><span>${group.items?.length || 0} 项</span></div>
      ${(group.items || []).map((item) => {
        const [label, tone] = resourceStatus(item);
        return `<div class="resource-row">
          <span class="resource-icon"><i data-lucide="${escapeHtml(item.icon || "database")}"></i></span>
          <span class="resource-copy"><strong>${escapeHtml(item.name)}</strong><span>${escapeHtml(item.subtitle || "")}</span></span>
          <span class="resource-size">${item.bytes == null ? "Docker 卷" : formatBytes(item.bytes)}</span>
          <span class="state-label ${tone}">${label}</span>
        </div>`;
      }).join("")}
    </section>`).join("") + (state.inventory?.legacyPackages || []).map((legacy) => `<section class="resource-group">
      <div class="section-title"><h3>旧区域包替代建议</h3><span>${escapeHtml(legacy.name)}</span></div>
      <div class="resource-row">
        <span class="resource-icon"><i data-lucide="split"></i></span>
        <span class="resource-copy"><strong>${escapeHtml(legacy.name)}</strong><span>${escapeHtml(legacy.reason)} · 建议改用 ${(legacy.replacementPacks || []).map((item) => item.name).join("、")}</span></span>
        <span class="resource-size">${formatBytes(legacy.bytes || 0)}</span>
        <span class="state-label ${legacy.readyToRemove ? "update" : "disabled"}">${legacy.readyToRemove ? "可替代" : "先安装替代包"}</span>
      </div>
    </section>`).join("") + `<section class="resource-group">
      <div class="section-title"><h3>可再生缓存</h3><span>${(state.inventory?.caches || []).length} 项</span></div>
      ${(state.inventory?.caches || []).map((cache) => `<div class="resource-row">
        <span class="resource-icon"><i data-lucide="database-zap"></i></span>
        <span class="resource-copy"><strong>${escapeHtml(cache.name)}</strong><span>${escapeHtml(cache.description || cache.pathLabel)}</span></span>
        <span class="resource-size">${formatBytes(cache.bytes || 0)}</span>
        <button class="command-button" type="button" data-clear-cache="${escapeHtml(cache.id)}" ${cache.bytes && !(cache.id === "build-temp" && hasActiveJobs) ? "" : "disabled"}><i data-lucide="trash-2"></i><span>${cache.id === "build-temp" && hasActiveJobs ? "使用中" : "清理"}</span></button>
      </div>`).join("")}
    </section>`;
}

function installEstimate(pack) {
  const estimate = Array.isArray(pack.estimatedInstallGiB) ? pack.estimatedInstallGiB : [];
  if (!estimate.length) return pack.sourceSizeMiB ? `源约 ${pack.sourceSizeMiB} MB` : "构建后计量";
  return estimate.length > 1 ? `${estimate[0]}-${estimate.at(-1)} GB` : `${estimate[0]} GB`;
}

function renderCatalog() {
  const query = state.catalogQuery.trim().toLocaleLowerCase("zh-CN");
  let packs = state.packs.filter((pack) => !pack.installed);
  if (state.catalogScope === "recommended" && !query) packs = packs.filter((pack) => pack.kind === "province");
  if (query) {
    packs = packs.filter((pack) =>
      `${packName(pack)} ${pack.name} ${pack.id} ${pack.groupName || ""} ${pack.countryId || ""}`
        .toLocaleLowerCase("zh-CN").includes(query)
    );
  }
  const groups = new Map();
  for (const pack of packs) {
    const group = pack.kind === "province" ? "中国省级行政区" : (pack.groupName || pack.countryId || "其他区域");
    if (!groups.has(group)) groups.set(group, []);
    groups.get(group).push(pack);
  }
  $("#catalogResults").innerHTML = groups.size ? [...groups].map(([group, items]) => `
    <section class="catalog-group">
      <div class="section-title"><h3>${escapeHtml(group)}</h3><span>${items.length} 项</span></div>
      ${items.map((pack) => {
        const job = taskForPack(pack.id);
        return `<div class="catalog-row" data-catalog-pack="${escapeHtml(pack.id)}">
          <span class="pack-cell"><span class="pack-name"><i data-lucide="map"></i><strong>${escapeHtml(packName(pack))}</strong></span><small>${escapeHtml(pack.description || pack.administrativeType || "独立离线地图包")}</small></span>
          <span class="catalog-source"><strong>${escapeHtml(pack.sourceProvider || "开放地图来源")}</strong><span>${escapeHtml(pack.sourceMode === "direct" ? "区域快照" : "从共享快照提取")}</span></span>
          <span class="catalog-estimate"><strong>${escapeHtml(installEstimate(pack))}</strong><span>预计安装</span></span>
          <span class="catalog-actions">
            <button class="icon-button" type="button" data-locate-pack="${escapeHtml(pack.id)}" title="在地图中定位" aria-label="在地图中定位 ${escapeHtml(packName(pack))}"><i data-lucide="scan-search"></i></button>
            <button class="command-button" type="button" data-catalog-build="${escapeHtml(pack.id)}" ${job || !pack.buildReady ? "disabled" : ""}><i data-lucide="${job ? "loader-circle" : "download"}"></i><span>${job ? "处理中" : pack.buildReady ? "构建" : "源未就绪"}</span></button>
          </span>
        </div>`;
      }).join("")}
    </section>`).join("") : '<div class="empty">没有匹配的可获取区域</div>';
}

function activityText(job) {
  const activity = job.progress?.activity;
  if (job.progress?.serviceContinuity) return "当前地图继续可用";
  if (activity && Number.isFinite(Number(activity.processed)) && Number.isFinite(Number(activity.total))) {
    const unit = activity.processedUnit === "tiles" ? "瓦片" : activity.processedUnit || "项";
    return `${Number(activity.processed).toLocaleString("zh-CN")} / ${Number(activity.total).toLocaleString("zh-CN")} ${unit}`;
  }
  if (!activity || !Number.isFinite(Number(activity.rate))) return job.status === "queued" ? `队列第 ${job.progress?.queuePosition || "--"} 位` : "正在计算速率";
  const rate = Number(activity.rate);
  if (rate <= 0) return "正在准备地图要素";
  if (activity.unit === "bytes/s") return `${formatBytes(rate)}/s`;
  const unit = activity.unit === "tiles/s" ? "瓦片/秒" : activity.unit === "features/s" ? "要素/秒" : activity.unit;
  return `${rate.toLocaleString("zh-CN", { maximumFractionDigits: 1 })} ${unit}`;
}

function taskRow(job, active = true) {
  const progress = job.progress || {};
  const percent = Math.max(0, Math.min(100, Number(progress.percent) || 0));
  return `<div class="task-row">
    <span class="task-copy"><strong>${escapeHtml(job.label || job.resourceId)}</strong><span>${escapeHtml(progress.stage || job.message || job.action)}</span></span>
    ${active ? `<span class="progress-cell">
      <span class="progress-track"><span style="width:${percent}%"></span></span>
      <span class="progress-meta"><span>${percent}% · ${escapeHtml(activityText(job))}</span><span>${escapeHtml(formatDate(job.startedAt || job.requestedAt))}</span></span>
    </span>` : `<span class="version-cell"><span>${escapeHtml(job.message || job.progress?.stage || "")}</span><small>开始 ${escapeHtml(formatDate(job.startedAt || job.requestedAt))}</small><small>结束 ${escapeHtml(formatDate(job.finishedAt))}</small></span>`}
    ${active
      ? `<button class="command-button cancel" type="button" data-cancel-job="${escapeHtml(job.id)}" ${job.cancelRequested ? "disabled" : ""}><i data-lucide="circle-x"></i><span>${job.cancelRequested ? "停止中" : "取消"}</span></button>`
      : `<span class="state-label ${job.status === "failed" ? "error" : job.status === "cancelled" ? "disabled" : ""}">${job.status === "succeeded" ? "完成" : job.status === "failed" ? "失败" : "已取消"}</span>`}
  </div>`;
}

function renderTasks() {
  const jobs = state.maintenance?.jobs || [];
  const active = jobs.filter((job) => ["queued", "running"].includes(job.status));
  const history = jobs.filter((job) => !["queued", "running"].includes(job.status)).slice(0, 20);
  const checks = state.inventory?.updateChecks || [];
  $("#activeTaskCount").textContent = `${active.length} 项`;
  $("#activeTasks").innerHTML = active.length ? active.map((job) => taskRow(job)).join("") : '<div class="empty">当前没有运行或排队的任务</div>';
  $("#updateCount").textContent = `${checks.filter((item) => item.updateAvailable).length} 项可处理`;
  $("#updateRows").innerHTML = checks.length ? checks.map((item) => {
    const running = active.find((job) => job.resourceId === item.id);
    return `<div class="task-row">
      <span class="task-copy"><strong>${escapeHtml(item.name)}</strong><span>${escapeHtml(item.reason || "")}</span></span>
      <span class="version-cell">
        <span>源数据 ${escapeHtml(formatDate(item.sourceUpdatedAt || item.installedVersion))}</span>
        <small>本地构建 ${escapeHtml(formatDate(item.builtAt))}</small>
        <small>上游版本 ${escapeHtml(formatDate(item.availableVersion))}</small>
        <small>上次检查 ${escapeHtml(formatDate(item.lastCheckedAt))} · 下次 ${escapeHtml(formatDate(item.nextCheckAt))}</small>
      </span>
      ${running ? '<span class="state-label update">处理中</span>' : item.updateAvailable
        ? `<button class="command-button" type="button" data-resource-update="${escapeHtml(item.id)}"><i data-lucide="refresh-cw"></i><span>处理</span></button>`
        : '<span class="state-label">最新</span>'}
    </div>`;
  }).join("") : '<div class="empty">没有版本检查记录</div>';
  $("#historyTasks").innerHTML = history.length ? history.map((job) => taskRow(job, false)).join("") : '<div class="empty">尚无任务历史</div>';
}

function render() {
  renderStorage();
  renderNavigation();
  renderVersions();
  renderCatalog();
  renderLocal();
  renderTasks();
  icons();
  if (state.focusPackId) {
    requestAnimationFrame(() => {
      const selector = state.view === "catalog" ? `[data-catalog-pack="${CSS.escape(state.focusPackId)}"]` : `[data-pack-row="${CSS.escape(state.focusPackId)}"]`;
      document.querySelector(selector)?.scrollIntoView({ block: "center" });
    });
    state.focusPackId = null;
  }
}

async function createJob(packId, action) {
  try {
    const confirmToken = action === "remove" ? packId : undefined;
    await api("/maintenance/jobs", {
      method: "POST",
      body: JSON.stringify({ resourceId: packId, action, confirmToken })
    });
    state.menuPackId = null;
    await refresh({ quiet: true });
    state.view = "tasks";
    render();
    showNotice(`${packName(state.packs.find((pack) => pack.id === packId) || { id: packId })}已加入任务队列`);
  } catch (error) {
    requestError(error);
  }
}

async function createBulkJobs(packIds, action) {
  try {
    for (const packId of packIds) {
      await api("/maintenance/jobs", {
        method: "POST",
        body: JSON.stringify({
          resourceId: packId,
          action,
          confirmToken: action === "remove" ? packId : undefined
        })
      });
    }
    state.selected.clear();
    await refresh({ quiet: true });
    state.view = "tasks";
    render();
    showNotice(`${packIds.length} 项任务已加入队列`);
  } catch (error) {
    requestError(error);
  }
}

async function showVersions(pack) {
  try {
    const versions = await api(`/map-packs/${encodeURIComponent(pack.id)}/versions`);
    $("#detailTitle").textContent = `${packName(pack)}版本`;
    $("#detailSubtitle").textContent = "当前、回退与历史清单";
    $("#detailBody").innerHTML = `
      <dl class="version-detail">
        <dt>当前源序列</dt><dd class="mono">${escapeHtml(versions.current.sourceSequence || "--")}</dd>
        <dt>当前构建时间</dt><dd>${escapeHtml(formatDate(versions.current.generatedAt))}</dd>
        <dt>当前文件</dt><dd>${escapeHtml(formatBytes(versions.current.bytes))} · ${versions.current.sizeMatches ? "大小校验通过" : "需要校验"}</dd>
        <dt>回退源序列</dt><dd class="mono">${escapeHtml(versions.rollback.sourceSequence || "--")}</dd>
        <dt>回退构建时间</dt><dd>${escapeHtml(formatDate(versions.rollback.generatedAt))}</dd>
        <dt>回退文件</dt><dd>${versions.rollback.ready ? `${escapeHtml(formatBytes(versions.rollback.bytes))} · ${versions.rollback.sizeMatches ? "大小校验通过" : "需要校验"}` : "没有完整回退版本"}</dd>
      </dl>
      <h3 class="history-heading">历史清单</h3>
      ${(versions.history || []).length ? versions.history.map((item) => `<div class="history-entry">
        <span class="mono">${escapeHtml(item.sourceSequence || "--")}</span>
        <span>${escapeHtml(formatDate(item.generatedAt))}</span>
        <span>${escapeHtml(formatBytes(item.bytes))}</span>
      </div>`).join("") : '<div class="empty">历史清单会在下一次版本替换时开始保留</div>'}`;
    $("#detailDialog").showModal();
    icons();
  } catch (error) {
    requestError(error);
  }
}

async function showManifest(pack) {
  try {
    const manifest = await api(`/map-packs/${encodeURIComponent(pack.id)}/manifest`);
    const blob = new Blob([JSON.stringify(manifest, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `${pack.id}.manifest.json`;
    link.click();
    URL.revokeObjectURL(url);
    showNotice(`${packName(pack)}清单已导出`);
  } catch (error) {
    requestError(error);
  }
}

async function runPackAction(packId, action) {
  const pack = state.packs.find((item) => item.id === packId);
  if (!pack) return;
  if (action === "info") return showVersions(pack);
  if (action === "manifest") return showManifest(pack);
  if (action === "browse") { location.href = `/?pack=${encodeURIComponent(pack.id)}`; return; }
  if (action === "toggle") {
    try {
      await api(`/map-packs/${encodeURIComponent(pack.id)}/activation`, {
        method: "PUT", body: JSON.stringify({ enabled: pack.enabled === false })
      });
      announceResourceChange({ resourceId: pack.id, action: "activation", status: "succeeded" });
      await refresh({ quiet: true });
      showNotice(`${packName(pack)}已${pack.enabled === false ? "启用" : "停用"}`);
    } catch (error) { requestError(error); }
    return;
  }
  if (action === "verify") {
    return createJob(pack.id, "verify");
  }
  if (action === "remove" && !confirm(`移除 ${packName(pack)} 的当前和回退地图文件？源数据会保留，可重新构建。`)) return;
  if (action === "rollback" && !confirm(`将 ${packName(pack)} 切换到回退版本？当前版本会保留为新的回退副本。`)) return;
  if (action === "rebuild" && !confirm(`使用现有源重新生成 ${packName(pack)}？这不会重新下载源数据。`)) return;
  return createJob(pack.id, action);
}

function wireEvents() {
  $$("[data-view]").forEach((button) => button.addEventListener("click", () => {
    state.view = button.dataset.view;
    renderNavigation();
    icons();
  }));
  $("#refreshButton").addEventListener("click", () => refresh({ freshInventory: true }));
  $("#upstreamButton").addEventListener("click", () => refresh({ upstream: true }));
  $("#packSearch").addEventListener("input", (event) => { state.query = event.target.value; renderVersions(); icons(); });
  $("#catalogSearch").addEventListener("input", (event) => {
    state.catalogQuery = event.target.value;
    renderCatalog();
    icons();
  });
  $$("[data-catalog-scope]").forEach((button) => button.addEventListener("click", () => {
    state.catalogScope = button.dataset.catalogScope;
    $$("[data-catalog-scope]").forEach((item) => item.classList.toggle("active", item === button));
    renderCatalog();
    icons();
  }));
  $("#selectAllPacks").addEventListener("change", (event) => {
    const visible = state.packs.filter((pack) => pack.installed);
    visible.forEach((pack) => event.target.checked ? state.selected.add(pack.id) : state.selected.delete(pack.id));
    renderVersions(); icons();
  });
  document.addEventListener("click", async (event) => {
    const select = event.target.closest("[data-select-pack]");
    if (select) {
      select.checked ? state.selected.add(select.dataset.selectPack) : state.selected.delete(select.dataset.selectPack);
      renderVersions(); icons(); return;
    }
    const menu = event.target.closest("[data-pack-menu]");
    if (menu) {
      state.menuPackId = state.menuPackId === menu.dataset.packMenu ? null : menu.dataset.packMenu;
      renderVersions(); icons(); return;
    }
    const action = event.target.closest("[data-pack-action]");
    if (action) { state.menuPackId = null; await runPackAction(action.dataset.packId, action.dataset.packAction); return; }
    const cancel = event.target.closest("[data-cancel-job]");
    if (cancel) {
      try { await api(`/maintenance/jobs/${encodeURIComponent(cancel.dataset.cancelJob)}`, { method: "DELETE" }); await refresh({ quiet: true }); }
      catch (error) { requestError(error); }
      return;
    }
    const resourceUpdate = event.target.closest("[data-resource-update]");
    if (resourceUpdate) { await createJob(resourceUpdate.dataset.resourceUpdate, "update"); return; }
    const clearCache = event.target.closest("[data-clear-cache]");
    if (clearCache) {
      const cacheId = clearCache.dataset.clearCache;
      if (!confirm("清理该可再生缓存？需要时系统会重新生成。")) return;
      try {
        await api(`/caches/${encodeURIComponent(cacheId)}?confirm=${encodeURIComponent(cacheId)}`, { method: "DELETE" });
        await refresh({ quiet: true, freshInventory: true });
        showNotice("缓存已清理");
      } catch (error) { requestError(error); }
      return;
    }
    const catalogBuild = event.target.closest("[data-catalog-build]");
    if (catalogBuild) { await createJob(catalogBuild.dataset.catalogBuild, "build"); return; }
    const locatePack = event.target.closest("[data-locate-pack]");
    if (locatePack) { location.href = `/?coverage=${encodeURIComponent(locatePack.dataset.locatePack)}`; return; }
    const bulk = event.target.closest("[data-bulk-action]");
    if (bulk) {
      const packIds = [...state.selected].filter((packId) => {
        const pack = state.packs.find((item) => item.id === packId);
        return pack && (bulk.dataset.bulkAction !== "update" || pack.updateAvailable);
      });
      if (!packIds.length) {
        showNotice("所选地图包均已是最新版本");
        return;
      }
      if (bulk.dataset.bulkAction === "remove" && !confirm(`移除所选 ${packIds.length} 个地图包的当前与回退文件？源数据会保留。`)) return;
      await createBulkJobs(packIds, bulk.dataset.bulkAction);
      return;
    }
    if (!event.target.closest(".menu")) {
      if (state.menuPackId) { state.menuPackId = null; renderVersions(); icons(); }
    }
  });
  $$("[data-close-dialog]").forEach((button) => button.addEventListener("click", () => $("#detailDialog").close()));
}

wireEvents();
icons();
await refresh({ quiet: true });
state.polling = setInterval(() => refresh({ quiet: true }), 4000);
window.addEventListener("beforeunload", () => clearInterval(state.polling));
