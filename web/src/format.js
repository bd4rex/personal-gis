export function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

export function formatBytes(value) {
  if (!Number.isFinite(value)) return "--";
  if (value >= 1024 ** 3) return `${(value / 1024 ** 3).toFixed(2)} GB`;
  return `${(value / 1024 / 1024).toFixed(1)} MB`;
}

export function formatEstimateRange(values, suffix) {
  if (!Array.isArray(values) || values.length < 2) return "待测算";
  const [minimum, maximum] = values.map(Number);
  if (!Number.isFinite(minimum) || !Number.isFinite(maximum)) return "待测算";
  return minimum === maximum ? `${minimum}${suffix}` : `${minimum}–${maximum}${suffix}`;
}

export function formatDate(value) {
  if (!value) return "--";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "--";
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric", month: "2-digit", day: "2-digit"
  }).format(date);
}
