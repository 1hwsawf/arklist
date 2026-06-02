const PAGE_SIZE = 20;
const JSON_FILE = "servers.json";

const MAP_NAMES = {
  TheIsland_WP: "孤岛",
  Ragnarok_WP: "仙境",
  LostColony_WP: "失落殖民地",
  TheCenter_WP: "中心岛",
  ScorchedEarth_WP: "焦土",
  Aberration_WP: "畸变",
  Extinction_WP: "灭绝",
  Genesis_WP: "创世",
  Genesis2_WP: "创世第二季",
  Fjordur_WP: "峡湾",
  Valguero_WP: "瓦尔盖罗",
  CrystalIsles_WP: "水晶岛",
  LostIsland_WP: "失落岛",
  Aquatica_WP: "水世界",
};

const FIELD_LABELS = {
  SessionName: "会话名称",
  SessionNameUpper: "会话名称（大写）",
  Name: "名称",
  MapName: "地图",
  SessionIsPve: "游戏模式",
  NumPlayers: "在线人数",
  MaxPlayers: "最大人数",
  ServerPing: "延迟 (ms)",
  IP: "IP 地址",
  Port: "端口",
  HasPassword: "需要密码",
  BuildId: "主版本号",
  MinorBuildId: "次版本号",
  ClusterId: "集群 ID",
  PlatformType: "支持平台",
  IsOfficial: "官方服务器",
  AllowDownloadItems: "允许下载物品",
  AllowDownloadChars: "允许下载角色",
  AllowDownloadDinos: "允许下载恐龙",
  SessionID: "会话 ID",
  Steelshield: "Steelshield",
  Sandbox: "沙盒",
  DayTime: "游戏内时间",
  SOTFMatchStarted: "SOTF 比赛已开始",
  Service: "服务",
  Battleye: "Battleye",
  LatencyPort: "延迟检测端口",
  LastUpdated: "最后更新",
  SearchHandle: "搜索句柄",
  GameMode: "游戏规则",
};

const PLATFORM_NAMES = {
  "PC+PS5+XSX": "PC / PS5 / Xbox Series X",
  PC: "PC",
  PS5: "PlayStation 5",
  XSX: "Xbox Series X",
};

let allServers = [];
let filtered = [];
let sortCol = "NumPlayers";
let sortDir = -1;
let currentPage = 1;

const $ = (id) => document.getElementById(id);

function getJsonUrl() {
  return new URL(JSON_FILE, window.location.href).href;
}

function parseServers(raw) {
  const data = JSON.parse(raw);
  if (Array.isArray(data)) return data;
  if (data && typeof data === "object") return [data];
  throw new Error("JSON 格式无效，需要服务器对象数组");
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function mapLabel(code) {
  if (!code) return "未知地图";
  return MAP_NAMES[code] || code.replace(/_WP$/, "").replace(/([A-Z])/g, " $1").trim();
}

function platformLabel(code) {
  if (!code) return "—";
  return PLATFORM_NAMES[code] || code;
}

function formatFieldValue(key, value) {
  if (value == null || value === "") return "—";

  switch (key) {
    case "MapName":
      return `${mapLabel(value)} (${value})`;
    case "SessionIsPve":
      return Number(value) === 1 ? "PVE（PvE）" : "PVP（PvP）";
    case "HasPassword":
    case "SOTFMatchStarted":
      return value === true || value === "true" || value === 1 || value === "1" ? "是" : "否";
    case "IsOfficial":
    case "AllowDownloadItems":
    case "AllowDownloadChars":
    case "AllowDownloadDinos":
    case "Steelshield":
    case "Battleye":
      return value === 1 || value === "1" || value === true ? "是" : "否";
    case "PlatformType":
      return platformLabel(value);
    case "LastUpdated":
      return new Date(Number(value)).toLocaleString("zh-CN");
    default:
      return String(value);
  }
}

function fieldLabel(key) {
  return FIELD_LABELS[key] || key;
}

function uniqueSorted(arr, key) {
  return [...new Set(arr.map((s) => s[key]).filter((v) => v != null && v !== ""))].sort((a, b) =>
    String(a).localeCompare(String(b), "zh-CN")
  );
}

function fillSelect(select, values, allLabel, labelFn = (v) => v) {
  select.innerHTML = `<option value="">${allLabel}</option>`;
  values.forEach((v) => {
    const opt = document.createElement("option");
    opt.value = v;
    opt.textContent = labelFn(v);
    select.appendChild(opt);
  });
}

function populateFilters(servers) {
  fillSelect($("filterMap"), uniqueSorted(servers, "MapName"), "全部地图", mapLabel);
  fillSelect($("filterCluster"), uniqueSorted(servers, "ClusterId"), "全部集群");
  fillSelect($("filterPlatform"), uniqueSorted(servers, "PlatformType"), "全部平台", platformLabel);
  fillSelect($("filterBuild"), uniqueSorted(servers, "BuildId"), "全部版本", (v) => `v${v}`);
}

function serverMatchesSearch(server, q) {
  if (!q) return true;
  const lower = q.toLowerCase();
  const mapCn = mapLabel(server.MapName).toLowerCase();
  return (
    mapCn.includes(lower) ||
    Object.values(server).some((v) => String(v).toLowerCase().includes(lower))
  );
}

function applyFilters() {
  const q = $("searchText").value.trim();
  const map = $("filterMap").value;
  const mode = $("filterMode").value;
  const password = $("filterPassword").value;
  const cluster = $("filterCluster").value;
  const platform = $("filterPlatform").value;
  const build = $("filterBuild").value;
  const minPlayers = $("minPlayers").value === "" ? null : Number($("minPlayers").value);
  const maxPing = $("maxPing").value === "" ? null : Number($("maxPing").value);
  const minSlots = $("minSlots").value === "" ? null : Number($("minSlots").value);

  filtered = allServers.filter((s) => {
    if (!serverMatchesSearch(s, q)) return false;
    if (map && s.MapName !== map) return false;
    if (mode === "pve" && Number(s.SessionIsPve) !== 1) return false;
    if (mode === "pvp" && Number(s.SessionIsPve) !== 0) return false;
    if (password === "yes" && !s.HasPassword) return false;
    if (password === "no" && s.HasPassword) return false;
    if (cluster && s.ClusterId !== cluster) return false;
    if (platform && s.PlatformType !== platform) return false;
    if (build && String(s.BuildId) !== build) return false;
    if (minPlayers != null && Number(s.NumPlayers) < minPlayers) return false;
    if (maxPing != null && Number(s.ServerPing) > maxPing) return false;
    if (minSlots != null) {
      const slots = Number(s.MaxPlayers) - Number(s.NumPlayers);
      if (slots < minSlots) return false;
    }
    return true;
  });

  currentPage = 1;
  sortData();
  updateStats();
  renderList();
}

function sortData() {
  filtered.sort((a, b) => {
    let va = a[sortCol];
    let vb = b[sortCol];
    if (sortCol === "SessionIsPve") {
      va = Number(va);
      vb = Number(vb);
    } else if (["NumPlayers", "MaxPlayers", "ServerPing", "Port", "BuildId"].includes(sortCol)) {
      va = Number(va) || 0;
      vb = Number(vb) || 0;
    } else {
      va = String(va ?? "").toLowerCase();
      vb = String(vb ?? "").toLowerCase();
    }
    if (va < vb) return -1 * sortDir;
    if (va > vb) return 1 * sortDir;
    return 0;
  });
}

function pingClass(ping) {
  if (ping <= 100) return "ping-good";
  if (ping <= 200) return "ping-mid";
  return "ping-bad";
}

function getTotalPages() {
  return Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
}

function getPageSlice() {
  const start = (currentPage - 1) * PAGE_SIZE;
  return filtered.slice(start, start + PAGE_SIZE);
}

function updateStats() {
  const pve = allServers.filter((s) => Number(s.SessionIsPve) === 1).length;
  const pvp = allServers.length - pve;
  $("statTotal").textContent = allServers.length.toLocaleString("zh-CN");
  $("statPve").textContent = pve.toLocaleString("zh-CN");
  $("statPvp").textContent = pvp.toLocaleString("zh-CN");
  $("statMatch").textContent = filtered.length.toLocaleString("zh-CN");
  $("resultText").textContent = `当前匹配 ${filtered.length.toLocaleString("zh-CN")} 台 · 每页 ${PAGE_SIZE} 条 · 共 ${allServers.length.toLocaleString("zh-CN")} 台`;
}

function renderList() {
  const list = $("serverList");
  const pageItems = getPageSlice();
  const globalStart = (currentPage - 1) * PAGE_SIZE;

  if (filtered.length === 0) {
    list.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">🔍</div>
        <p>没有找到匹配的服务器</p>
        <p style="margin-top:0.5rem;font-size:0.875rem;">试试调整搜索关键词或筛选条件</p>
      </div>`;
  } else {
    list.innerHTML = pageItems
      .map((s, i) => {
        const globalIdx = globalStart + i;
        const isPve = Number(s.SessionIsPve) === 1;
        const pct = s.MaxPlayers ? (Number(s.NumPlayers) / Number(s.MaxPlayers)) * 100 : 0;
        const name = s.SessionName || s.Name || "未命名服务器";
        const address = `${s.IP || "—"}:${s.Port ?? "—"}`;
        const version = s.BuildId != null ? `v${s.BuildId}.${s.MinorBuildId ?? 0}` : "";
        return `
          <article class="server-card" style="animation-delay:${i * 0.03}s">
            <div class="server-main">
              <div class="server-name" title="${escapeHtml(name)}">${escapeHtml(name)}</div>
              <div class="server-meta">
                <span class="tag ${isPve ? "tag-pve" : "tag-pvp"}">${isPve ? "PVE" : "PVP"}</span>
                <span class="tag tag-map">${escapeHtml(mapLabel(s.MapName))}</span>
                ${s.HasPassword ? '<span class="tag tag-lock">🔒 有密码</span>' : '<span class="tag tag-muted">无密码</span>'}
                ${version ? `<span class="tag tag-muted">${version}</span>` : ""}
                ${s.ClusterId ? `<span class="tag tag-muted">${escapeHtml(s.ClusterId)}</span>` : ""}
              </div>
              <div class="address-line">${escapeHtml(address)}</div>
            </div>
            <div class="server-side">
              <div class="players-wrap">
                <div class="players-num">${s.NumPlayers}/${s.MaxPlayers} 人在线</div>
                <div class="players-bar"><div class="players-fill" style="width:${Math.min(pct, 100)}%"></div></div>
              </div>
              <div class="ping ${pingClass(Number(s.ServerPing))}">${s.ServerPing ?? "—"} ms</div>
              <div class="server-actions">
                <button class="btn btn-ghost btn-icon" data-copy="${escapeHtml(address)}" title="复制地址">📋</button>
                <button class="btn btn-ghost btn-icon" data-detail="${globalIdx}" title="查看详情">ℹ️</button>
              </div>
            </div>
          </article>`;
      })
      .join("");
  }

  renderPagination();
}

function renderPagination() {
  const totalPages = getTotalPages();
  if (currentPage > totalPages) currentPage = totalPages;

  const start = filtered.length === 0 ? 0 : (currentPage - 1) * PAGE_SIZE + 1;
  const end = Math.min(currentPage * PAGE_SIZE, filtered.length);
  const pag = $("pagination");

  if (filtered.length === 0) {
    pag.classList.add("hidden");
    return;
  }

  pag.classList.remove("hidden");

  const pages = [];
  const windowSize = 5;
  let startPage = Math.max(1, currentPage - Math.floor(windowSize / 2));
  let endPage = Math.min(totalPages, startPage + windowSize - 1);
  startPage = Math.max(1, endPage - windowSize + 1);
  for (let p = startPage; p <= endPage; p++) pages.push(p);

  pag.innerHTML = `
    <button class="page-btn" data-action="first" ${currentPage === 1 ? "disabled" : ""} aria-label="首页">«</button>
    <button class="page-btn" data-action="prev" ${currentPage === 1 ? "disabled" : ""} aria-label="上一页">‹</button>
    ${pages.map((p) => `<button class="page-btn${p === currentPage ? " active" : ""}" data-page="${p}">${p}</button>`).join("")}
    <button class="page-btn" data-action="next" ${currentPage === totalPages ? "disabled" : ""} aria-label="下一页">›</button>
    <button class="page-btn" data-action="last" ${currentPage === totalPages ? "disabled" : ""} aria-label="末页">»</button>
    <span class="page-info">第 ${start}–${end} 条 / 共 ${filtered.length.toLocaleString("zh-CN")} 条 · 第 ${currentPage}/${totalPages} 页</span>
  `;
}

function goToPage(page) {
  currentPage = Math.min(Math.max(1, page), getTotalPages());
  renderList();
  $("serverList").scrollIntoView({ behavior: "smooth", block: "start" });
}

function showToast(msg) {
  const toast = $("toast");
  toast.textContent = msg;
  toast.classList.add("show");
  clearTimeout(showToast._timer);
  showToast._timer = setTimeout(() => toast.classList.remove("show"), 2200);
}

function showDetail(index) {
  const s = filtered[index];
  $("modalTitle").textContent = s.SessionName || s.Name || "服务器详情";
  const keys = Object.keys(s).sort((a, b) => {
    const order = Object.keys(FIELD_LABELS);
    return (order.indexOf(a) === -1 ? 999 : order.indexOf(a)) - (order.indexOf(b) === -1 ? 999 : order.indexOf(b));
  });
  $("detailGrid").innerHTML = keys
    .map((k) => `<dt>${escapeHtml(fieldLabel(k))}</dt><dd>${escapeHtml(formatFieldValue(k, s[k]))}</dd>`)
    .join("");
  $("modal").classList.add("open");
  document.body.style.overflow = "hidden";
}

function closeModal() {
  $("modal").classList.remove("open");
  document.body.style.overflow = "";
}

function exportCsv() {
  if (filtered.length === 0) return;
  const keys = [...new Set(filtered.flatMap((s) => Object.keys(s)))];
  const header = keys.map(fieldLabel);
  const rows = [header.join(",")];
  filtered.forEach((s) => {
    rows.push(
      keys
        .map((k) => {
          const v = formatFieldValue(k, s[k]);
          const str = String(v).replace(/"/g, '""');
          return /[",\n]/.test(str) ? `"${str}"` : str;
        })
        .join(",")
    );
  });
  const blob = new Blob(["\ufeff" + rows.join("\n")], { type: "text/csv;charset=utf-8" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `ark-servers-${Date.now()}.csv`;
  a.click();
  URL.revokeObjectURL(a.href);
  showToast("已导出 CSV 文件");
}

function setStatus(state, text) {
  const dot = $("statusDot");
  const label = $("statusText");
  dot.className = "status-dot " + state;
  label.textContent = text;
}

function showSkeleton() {
  $("serverList").innerHTML = Array.from({ length: 5 }, () => '<div class="skeleton"></div>').join("");
}

function onDataLoaded(raw) {
  allServers = parseServers(raw);
  currentPage = 1;
  populateFilters(allServers);
  setStatus("ready", `已加载 ${allServers.length.toLocaleString("zh-CN")} 台服务器`);
  $("mainPanel").classList.remove("hidden");
  applyFilters();
}

async function autoLoadServers() {
  setStatus("", "正在加载数据…");
  $("mainPanel").classList.add("hidden");
  showSkeleton();

  try {
    const res = await fetch(getJsonUrl(), { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    onDataLoaded(await res.text());
  } catch (err) {
    setStatus("error", "加载失败");
    $("serverList").innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">⚠️</div>
        <p style="color:var(--pvp)">无法加载 servers.json</p>
        <p style="margin-top:0.5rem;font-size:0.875rem;">${escapeHtml(err.message)} · 请确认仓库根目录包含该文件</p>
      </div>`;
  }
}

function resetFilters() {
  $("searchText").value = "";
  $("filterMap").value = "";
  $("filterMode").value = "";
  $("filterPassword").value = "";
  $("filterCluster").value = "";
  $("filterPlatform").value = "";
  $("filterBuild").value = "";
  $("minPlayers").value = "";
  $("maxPing").value = "";
  $("minSlots").value = "";
  applyFilters();
  showToast("已重置筛选条件");
}

function initEvents() {
  $("filterToggle").addEventListener("click", () => {
    const body = $("filtersBody");
    const btn = $("filterToggle");
    body.classList.toggle("open");
    btn.classList.toggle("open");
  });

  $("reloadBtn").addEventListener("click", autoLoadServers);
  $("resetBtn").addEventListener("click", resetFilters);
  $("exportBtn").addEventListener("click", exportCsv);
  $("closeModal").addEventListener("click", closeModal);
  $("modal").addEventListener("click", (e) => {
    if (e.target === $("modal")) closeModal();
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") closeModal();
  });

  const filterIds = [
    "searchText", "filterMap", "filterMode", "filterPassword",
    "filterCluster", "filterPlatform", "filterBuild",
    "minPlayers", "maxPing", "minSlots",
  ];
  filterIds.forEach((id) => {
    const el = $(id);
    el.addEventListener("input", applyFilters);
    el.addEventListener("change", applyFilters);
  });

  $("sortSelect").addEventListener("change", (e) => {
    const [col, dir] = e.target.value.split(":");
    sortCol = col;
    sortDir = Number(dir);
    currentPage = 1;
    sortData();
    renderList();
  });

  $("pagination").addEventListener("click", (e) => {
    const btn = e.target.closest(".page-btn");
    if (!btn || btn.disabled) return;
    if (btn.dataset.page) return goToPage(Number(btn.dataset.page));
    const totalPages = getTotalPages();
    if (btn.dataset.action === "first") goToPage(1);
    else if (btn.dataset.action === "prev") goToPage(currentPage - 1);
    else if (btn.dataset.action === "next") goToPage(currentPage + 1);
    else if (btn.dataset.action === "last") goToPage(totalPages);
  });

  $("serverList").addEventListener("click", (e) => {
    const copyBtn = e.target.closest("[data-copy]");
    if (copyBtn) {
      navigator.clipboard.writeText(copyBtn.dataset.copy).then(
        () => showToast("已复制：" + copyBtn.dataset.copy),
        () => showToast("复制失败，请手动复制")
      );
      return;
    }
    const detailBtn = e.target.closest("[data-detail]");
    if (detailBtn) showDetail(Number(detailBtn.dataset.detail));
  });
}

initEvents();
autoLoadServers();
