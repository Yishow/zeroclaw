const invoke =
  window.__TAURI__?.core?.invoke ||
  window.__TAURI__?.invoke ||
  window.__TAURI_INTERNALS__?.invoke;
const EXTENSIONS_SECTION = "__extensions__";

const state = {
  schema: null,
  defs: {},
  configJson: {},
  docsFieldHelp: {},
  rawToml: "",
  section: "all",
  search: ""
};

const els = {
  configPath: document.getElementById("configPath"),
  warnings: document.getElementById("warnings"),
  status: document.getElementById("status"),
  sectionSelect: document.getElementById("sectionSelect"),
  searchInput: document.getElementById("searchInput"),
  formRoot: document.getElementById("formRoot"),
  rawEditor: document.getElementById("rawEditor"),
  reloadBtn: document.getElementById("reloadBtn"),
  syncBtn: document.getElementById("syncBtn"),
  chmodBtn: document.getElementById("chmodBtn"),
  saveStructuredBtn: document.getElementById("saveStructuredBtn"),
  saveRawBtn: document.getElementById("saveRawBtn")
};

const FIELD_DESCRIPTION_ZH = {
  agent: "代理核心行為設定，控制工具使用、上下文壓縮與推理迭代等策略。",
  agents: "多代理委派設定，定義不同子代理的角色與執行參數。",
  api_key: "預設模型供應商 API 金鑰，建議以環境變數或秘密管理機制注入。",
  api_url: "預設模型供應商 API 端點，通常用於私有網關或自建相容服務。",
  autonomy: "自主決策行為設定，控制代理在無人工介入時的行為邊界。",
  browser: "瀏覽器工具設定，控制網頁互動能力與執行限制。",
  channels_config: "通訊通道設定，管理 Telegram、Discord、Slack 等整合參數。",
  composio: "Composio 整合設定，用於外部應用授權與工具連接。",
  cost: "成本治理設定，定義預算、統計與成本保護策略。",
  cron: "週期任務設定，以排程方式執行指定工作。",
  default_model: "預設模型名稱，未指定模型時將使用此值。",
  default_provider: "預設模型供應商，未指定 provider 時將使用此值。",
  default_temperature: "預設溫度參數，影響回應隨機性與創造性。",
  embedding_routes: "向量嵌入路由設定，定義不同任務使用的 embedding 模型。",
  gateway: "網關服務設定，控制對外入口、綁定位置與存取策略。",
  hardware: "硬體整合設定，管理本地板卡或裝置相關能力。",
  heartbeat: "心跳與健康檢查設定，確保長時間執行可觀測。",
  http_request: "HTTP 請求工具設定，控制外部網路請求行為。",
  identity: "代理身份設定，定義名稱、角色與預設行為語氣。",
  memory: "記憶系統設定，控制儲存後端、檢索策略與容量行為。",
  model_routes: "模型路由策略，為不同任務分派對應模型。",
  multimodal: "多模態能力設定，管理影像/音訊等非文字能力。",
  observability: "可觀測性設定，控制日誌、追蹤與診斷輸出。",
  peripherals: "周邊裝置設定，管理 GPIO、感測器等外接能力。",
  proxy: "代理伺服器設定，用於網路出口與企業環境相容。",
  query_classification: "查詢分類設定，先分類再路由以提升回應品質。",
  reliability: "穩定性設定，控制重試、超時與容錯策略。",
  runtime: "執行時設定，控制流程調度與系統行為邊界。",
  scheduler: "排程器設定，控制任務觸發條件與執行規則。",
  secrets: "密鑰管理設定，集中定義敏感資訊來源與讀取策略。",
  storage: "儲存設定，控制資料落地位置與存取模式。",
  tunnel: "隧道設定，管理內網穿透或遠端回連能力。",
  web_search: "網路搜尋設定，控制搜尋供應商與查詢行為。"
};

const TOKEN_ZH = {
  agent: "代理",
  agents: "多代理",
  api: "API",
  key: "金鑰",
  url: "網址",
  autonomy: "自主",
  browser: "瀏覽器",
  channels: "通道",
  channel: "通道",
  config: "設定",
  composio: "Composio",
  cost: "成本",
  cron: "排程",
  default: "預設",
  model: "模型",
  provider: "供應商",
  temperature: "溫度",
  embedding: "嵌入",
  embeddings: "嵌入",
  routes: "路由",
  route: "路由",
  gateway: "網關",
  hardware: "硬體",
  heartbeat: "心跳",
  http: "HTTP",
  request: "請求",
  identity: "身份",
  memory: "記憶",
  multimodal: "多模態",
  observability: "可觀測",
  peripherals: "周邊",
  proxy: "代理伺服器",
  query: "查詢",
  classification: "分類",
  reliability: "穩定性",
  runtime: "執行時",
  scheduler: "排程器",
  secrets: "密鑰",
  storage: "儲存",
  tunnel: "隧道",
  web: "網路",
  search: "搜尋",
  timeout: "逾時",
  retries: "重試",
  retry: "重試",
  max: "最大",
  min: "最小",
  enable: "啟用",
  enabled: "已啟用",
  disable: "停用"
};

const TYPE_LABEL_ZH = {
  object: "物件",
  array: "陣列",
  string: "字串",
  integer: "整數",
  number: "數值",
  boolean: "布林值",
  unknown: "未知"
};

function setStatus(message, kind = "info") {
  const palette = {
    info: ["#eef6ff", "#cde2ff", "#204777"],
    ok: ["#eaf9f0", "#bce8cc", "#106d3f"],
    warn: ["#fff5ee", "#ffd7be", "#a53f00"],
    error: ["#ffeef0", "#ffcdd4", "#9f1239"]
  };
  const [bg, bd, fg] = palette[kind] || palette.info;
  els.status.textContent = message;
  els.status.style.background = bg;
  els.status.style.borderColor = bd;
  els.status.style.color = fg;
}

function deepClone(value) {
  return JSON.parse(JSON.stringify(value));
}

function isObject(value) {
  return value && typeof value === "object" && !Array.isArray(value);
}

function schemaRefName(ref) {
  return ref.split("/").pop();
}

function resolveSchema(node) {
  let current = node;
  const seen = new Set();
  while (current && current.$ref) {
    const refName = schemaRefName(current.$ref);
    if (seen.has(refName)) break;
    seen.add(refName);
    current = state.defs[refName];
  }
  return current || node;
}

function isNullSchema(node) {
  const resolved = resolveSchema(node);
  if (!resolved) return false;
  if (resolved.type === "null") return true;
  if (Array.isArray(resolved.type) && resolved.type.includes("null")) return true;
  return false;
}

function isNullable(node) {
  const resolved = resolveSchema(node);
  if (!resolved) return false;
  if (Array.isArray(resolved.type) && resolved.type.includes("null")) return true;
  if (Array.isArray(resolved.anyOf) && resolved.anyOf.some(isNullSchema)) return true;
  if (Array.isArray(resolved.oneOf) && resolved.oneOf.some(isNullSchema)) return true;
  return false;
}

function nonNullSchema(node) {
  const resolved = resolveSchema(node);
  if (!resolved) return node;

  if (Array.isArray(resolved.anyOf)) {
    const candidate = resolved.anyOf.find((n) => !isNullSchema(n));
    return resolveSchema(candidate || resolved);
  }

  if (Array.isArray(resolved.oneOf)) {
    const constOnly = resolved.oneOf.every((n) => Object.prototype.hasOwnProperty.call(n, "const"));
    if (constOnly) return resolved;
    const candidate = resolved.oneOf.find((n) => !isNullSchema(n));
    return resolveSchema(candidate || resolved);
  }

  if (Array.isArray(resolved.type) && resolved.type.includes("null")) {
    const nextType = resolved.type.find((t) => t !== "null") || "string";
    return { ...resolved, type: nextType };
  }

  return resolved;
}

function enumValues(node) {
  const resolved = nonNullSchema(node);
  if (!resolved) return [];
  if (Array.isArray(resolved.enum)) return resolved.enum;
  if (Array.isArray(resolved.oneOf)) {
    const consts = resolved.oneOf
      .filter((n) => Object.prototype.hasOwnProperty.call(n, "const"))
      .map((n) => n.const);
    if (consts.length > 0) return consts;
  }
  return [];
}

function schemaType(node) {
  const resolved = nonNullSchema(node);
  if (!resolved) return "unknown";
  if (resolved.type) return resolved.type;
  if (resolved.properties || resolved.additionalProperties) return "object";
  if (resolved.items) return "array";
  if (enumValues(node).length > 0) return "string";
  return "unknown";
}

function defaultValueForSchema(node) {
  const resolved = nonNullSchema(node);
  if (!resolved) return null;
  if (Object.prototype.hasOwnProperty.call(resolved, "default")) return deepClone(resolved.default);

  const values = enumValues(resolved);
  if (values.length > 0) return values[0];

  const type = schemaType(resolved);
  if (type === "object") return {};
  if (type === "array") return [];
  if (type === "boolean") return false;
  if (type === "integer" || type === "number") return 0;
  if (type === "string") return "";
  return null;
}

function pathMatches(path, query) {
  return !query || path.toLowerCase().includes(query.toLowerCase());
}

function hasMatchingDescendant(schemaNode, path, query) {
  if (!query) return true;
  if (pathMatches(path, query)) return true;

  const resolved = nonNullSchema(schemaNode);
  const type = schemaType(resolved);
  if (type === "object") {
    const props = resolved.properties || {};
    for (const [key, child] of Object.entries(props)) {
      if (hasMatchingDescendant(child, `${path}.${key}`, query)) return true;
    }
    if (resolved.additionalProperties) {
      return hasMatchingDescendant(resolved.additionalProperties, `${path}.*`, query);
    }
  }
  if (type === "array" && resolved.items) {
    return hasMatchingDescendant(resolved.items, `${path}.[]`, query);
  }
  return false;
}

function ensureObject(parent, key, schemaNode) {
  if (!isObject(parent[key])) {
    const fallback = defaultValueForSchema(schemaNode);
    parent[key] = isObject(fallback) ? fallback : {};
  }
  return parent[key];
}

function isSensitivePath(path) {
  return /(api_key|token|secret|password|access_token|auth_token|bot_token|paired_tokens)/i.test(path);
}

function formatPreview(value, maxLen = 180) {
  let raw;
  try {
    raw = JSON.stringify(value);
  } catch {
    raw = String(value);
  }
  if (raw.length <= maxLen) return raw;
  return `${raw.slice(0, maxLen)}...`;
}

function toZhSegment(segment) {
  if (!segment) return "";
  if (TOKEN_ZH[segment]) return TOKEN_ZH[segment];
  const parts = segment.split("_");
  const mapped = parts.map((p) => TOKEN_ZH[p] || p);
  return mapped.join(" ");
}

function pathToZh(path) {
  return path
    .split(".")
    .flatMap((part) => part.split(/[\[\]\*]/g))
    .filter(Boolean)
    .map((part) => toZhSegment(part))
    .join(" / ");
}

function purposeForPathZh(path) {
  const doc = fieldDocForPath(path);
  if (doc?.purpose_zh) return doc.purpose_zh;

  if (FIELD_DESCRIPTION_ZH[path]) return FIELD_DESCRIPTION_ZH[path];

  const [top] = path.split(".");
  if (top && FIELD_DESCRIPTION_ZH[top] && path !== top) {
    const subPath = path.slice(top.length + 1);
    return `${FIELD_DESCRIPTION_ZH[top]} 子項「${subPath}」用於細部控制。`;
  }

  return `此欄位用於設定「${pathToZh(path)}」。`;
}

function fieldDocForPath(path) {
  if (!isObject(state.docsFieldHelp)) return null;
  if (state.docsFieldHelp[path]) return state.docsFieldHelp[path];

  const top = path.split(".")[0];
  if (top && state.docsFieldHelp[top]) return state.docsFieldHelp[top];
  return null;
}

function appendSchemaConstraintHints(lines, resolved) {
  if (!resolved || !isObject(resolved)) return;

  if (typeof resolved.minimum === "number") {
    lines.push(`最小值：${resolved.minimum}。`);
  }
  if (typeof resolved.maximum === "number") {
    lines.push(`最大值：${resolved.maximum}。`);
  }
  if (typeof resolved.minLength === "number") {
    lines.push(`最短長度：${resolved.minLength}。`);
  }
  if (typeof resolved.maxLength === "number") {
    lines.push(`最長長度：${resolved.maxLength}。`);
  }
  if (typeof resolved.minItems === "number") {
    lines.push(`最少項目數：${resolved.minItems}。`);
  }
  if (typeof resolved.maxItems === "number") {
    lines.push(`最多項目數：${resolved.maxItems}。`);
  }
  if (typeof resolved.pattern === "string" && resolved.pattern.trim()) {
    lines.push(`格式限制：需符合正則 ${resolved.pattern}。`);
  }
}

function buildFieldHelpLines(path, schemaNode, type, nullable) {
  const resolved = nonNullSchema(schemaNode);
  const enums = enumValues(schemaNode);
  const doc = fieldDocForPath(path);
  const lines = [];

  lines.push(`用途：${purposeForPathZh(path)}`);

  if (doc?.usage_zh) {
    lines.push(`使用說明：${doc.usage_zh}`);
  }

  const typeLabel = TYPE_LABEL_ZH[type] || TYPE_LABEL_ZH.unknown;
  if (type === "object") {
    lines.push(`資料型別：${typeLabel}。可展開後編輯子欄位。`);
  } else if (type === "array") {
    lines.push(`資料型別：${typeLabel}。請以 JSON 陣列格式編輯。`);
  } else if (type === "boolean") {
    lines.push(`資料型別：${typeLabel}。勾選為啟用，取消為停用。`);
  } else {
    lines.push(`資料型別：${typeLabel}。`);
  }

  if (nullable) {
    lines.push("可為空值：此欄位可設為 null，代表停用或未設定。");
  }

  if (enums.length > 0) {
    lines.push(`可選值：${enums.map((v) => String(v)).join("、")}。`);
  }

  if (resolved && Object.prototype.hasOwnProperty.call(resolved, "default")) {
    lines.push(`預設值：${formatPreview(resolved.default)}。`);
  }

  appendSchemaConstraintHints(lines, resolved);

  if (isSensitivePath(path)) {
    lines.push("安全提醒：此欄位可能含敏感資訊，建議使用秘密管理或環境變數，並確保設定檔權限為 600。");
  }

  if (Array.isArray(doc?.examples) && doc.examples.length > 0) {
    const shown = doc.examples.slice(0, 2);
    shown.forEach((ex, idx) => {
      lines.push(`範例 ${idx + 1}：${ex}`);
    });
  }

  return lines;
}

async function loadFieldHelpDocs() {
  try {
    const resp = await fetch("./field-help.zh.generated.json", { cache: "no-store" });
    if (!resp.ok) {
      state.docsFieldHelp = {};
      return;
    }
    const payload = await resp.json();
    state.docsFieldHelp = isObject(payload?.fields) ? payload.fields : {};
  } catch {
    state.docsFieldHelp = {};
  }
}

function renderFieldHelp(parentEl, path, schemaNode, type, nullable) {
  const lines = buildFieldHelpLines(path, schemaNode, type, nullable);
  if (!lines.length) return;

  const wrap = document.createElement("div");
  wrap.className = "field-help";

  const title = document.createElement("div");
  title.className = "field-help-title";
  title.textContent = "中文說明";
  wrap.appendChild(title);

  const list = document.createElement("ul");
  lines.forEach((line) => {
    const item = document.createElement("li");
    item.textContent = line;
    list.appendChild(item);
  });
  wrap.appendChild(list);
  parentEl.appendChild(wrap);
}

function renderPrimitive(parentEl, parentObj, key, schemaNode, path) {
  const type = schemaType(schemaNode);
  const enums = enumValues(schemaNode);
  const current = parentObj[key];
  const fallback = defaultValueForSchema(schemaNode);

  const row = document.createElement("div");
  row.className = "input-row";

  if (enums.length > 0) {
    const select = document.createElement("select");
    const selected = current === undefined || current === null ? fallback : current;
    enums.forEach((value) => {
      const option = document.createElement("option");
      option.value = String(value);
      option.textContent = String(value);
      if (String(selected) === String(value)) option.selected = true;
      select.appendChild(option);
    });
    select.addEventListener("change", () => {
      parentObj[key] = select.value;
    });
    row.appendChild(select);
    parentEl.appendChild(row);
    return;
  }

  if (type === "boolean") {
    const input = document.createElement("input");
    input.type = "checkbox";
    input.checked = Boolean(current === undefined ? fallback : current);
    input.addEventListener("change", () => {
      parentObj[key] = input.checked;
    });
    row.appendChild(input);
    parentEl.appendChild(row);
    return;
  }

  if (type === "integer" || type === "number") {
    const input = document.createElement("input");
    input.type = "number";
    input.step = type === "integer" ? "1" : "any";
    input.value = current === undefined || current === null ? String(fallback ?? "") : String(current);
    input.addEventListener("change", () => {
      if (!input.value.trim()) {
        delete parentObj[key];
        return;
      }
      const parsed = type === "integer" ? Number.parseInt(input.value, 10) : Number.parseFloat(input.value);
      if (Number.isNaN(parsed)) {
        setStatus(`欄位 ${path} 的數值格式錯誤`, "error");
        return;
      }
      parentObj[key] = parsed;
    });
    row.appendChild(input);
    parentEl.appendChild(row);
    return;
  }

  const input = document.createElement("input");
  input.type = isSensitivePath(path) ? "password" : "text";
  input.value = current === undefined || current === null ? String(fallback ?? "") : String(current);
  input.addEventListener("change", () => {
    parentObj[key] = input.value;
  });
  row.appendChild(input);
  parentEl.appendChild(row);
}

function renderArray(parentEl, parentObj, key, schemaNode, path) {
  const row = document.createElement("div");
  row.className = "input-row";

  const textarea = document.createElement("textarea");
  const current = Array.isArray(parentObj[key]) ? parentObj[key] : defaultValueForSchema(schemaNode) || [];
  textarea.value = JSON.stringify(current, null, 2);
  textarea.addEventListener("blur", () => {
    try {
      const parsed = JSON.parse(textarea.value || "[]");
      if (!Array.isArray(parsed)) throw new Error("應為 JSON 陣列");
      parentObj[key] = parsed;
      setStatus(`已更新 ${path}`, "ok");
    } catch (error) {
      setStatus(`欄位 ${path} 的 JSON 陣列格式錯誤：${error.message}`, "error");
    }
  });
  row.appendChild(textarea);
  parentEl.appendChild(row);
}

function renderMap(parentEl, parentObj, key, schemaNode, path) {
  const row = document.createElement("div");
  row.className = "input-row";

  const textarea = document.createElement("textarea");
  const current = isObject(parentObj[key]) ? parentObj[key] : defaultValueForSchema(schemaNode) || {};
  textarea.value = JSON.stringify(current, null, 2);
  textarea.addEventListener("blur", () => {
    try {
      const parsed = JSON.parse(textarea.value || "{}");
      if (!isObject(parsed)) throw new Error("應為 JSON 物件");
      parentObj[key] = parsed;
      setStatus(`已更新 ${path}`, "ok");
    } catch (error) {
      setStatus(`欄位 ${path} 的 JSON 物件格式錯誤：${error.message}`, "error");
    }
  });
  row.appendChild(textarea);
  parentEl.appendChild(row);
}

function renderAdditionalPropertiesMap(parentEl, targetObj, fixedProps, path) {
  const row = document.createElement("div");
  row.className = "input-row";

  const textarea = document.createElement("textarea");
  const extras = Object.fromEntries(
    Object.entries(targetObj).filter(([k]) => !fixedProps.has(k))
  );
  textarea.value = JSON.stringify(extras, null, 2);
  textarea.addEventListener("blur", () => {
    try {
      const parsed = JSON.parse(textarea.value || "{}");
      if (!isObject(parsed)) throw new Error("應為 JSON 物件");

      Object.keys(targetObj).forEach((k) => {
        if (!fixedProps.has(k)) delete targetObj[k];
      });
      Object.entries(parsed).forEach(([k, v]) => {
        targetObj[k] = v;
      });
      setStatus(`已更新 ${path}`, "ok");
    } catch (error) {
      setStatus(`欄位 ${path} 的 JSON 物件格式錯誤：${error.message}`, "error");
    }
  });
  row.appendChild(textarea);
  parentEl.appendChild(row);
}

function schemaTopLevelKeys() {
  if (!state.schema) return [];
  const root = resolveSchema(state.schema);
  return Object.keys(root.properties || {});
}

function topLevelExtensionsObject() {
  const known = new Set(schemaTopLevelKeys());
  return Object.fromEntries(Object.entries(state.configJson).filter(([k]) => !known.has(k)));
}

function writeTopLevelExtensions(nextExtensions) {
  const known = new Set(schemaTopLevelKeys());
  const rebuilt = {};

  Object.entries(state.configJson).forEach(([k, v]) => {
    if (known.has(k)) rebuilt[k] = v;
  });
  Object.entries(nextExtensions).forEach(([k, v]) => {
    if (!known.has(k)) rebuilt[k] = v;
  });

  state.configJson = rebuilt;
}

function renderExtensionsEditor(container) {
  const path = "extensions.*";
  if (!pathMatches(path, state.search)) return;

  const field = document.createElement("div");
  field.className = "field";

  const head = document.createElement("div");
  head.className = "field-head";

  const pathEl = document.createElement("div");
  pathEl.className = "path";
  pathEl.textContent = path;
  head.appendChild(pathEl);

  const badge = document.createElement("span");
  badge.className = "type-badge";
  badge.textContent = "物件";
  head.appendChild(badge);
  field.appendChild(head);

  renderFieldHelp(field, path, { type: "object" }, "object", false);

  const row = document.createElement("div");
  row.className = "input-row";
  const textarea = document.createElement("textarea");
  textarea.value = JSON.stringify(topLevelExtensionsObject(), null, 2);
  textarea.addEventListener("blur", () => {
    try {
      const parsed = JSON.parse(textarea.value || "{}");
      if (!isObject(parsed)) throw new Error("應為 JSON 物件");
      writeTopLevelExtensions(parsed);
      setStatus("已更新 extensions 擴充鍵。", "ok");
      fillSectionSelector();
      renderForm();
    } catch (error) {
      setStatus(`extensions JSON 格式錯誤：${error.message}`, "error");
    }
  });
  row.appendChild(textarea);
  field.appendChild(row);
  container.appendChild(field);
}

function renderProperty(container, key, propertySchema, parentObj, path) {
  if (!hasMatchingDescendant(propertySchema, path, state.search)) return;

  const nullable = isNullable(propertySchema);
  const resolved = nonNullSchema(propertySchema);
  const type = schemaType(resolved);

  const field = document.createElement("div");
  field.className = type === "object" ? "section" : "field";

  const head = document.createElement("div");
  head.className = type === "object" ? "path" : "field-head";

  const pathEl = document.createElement("div");
  pathEl.className = "path";
  pathEl.textContent = path;
  head.appendChild(pathEl);

  if (type !== "object") {
    const badge = document.createElement("span");
    badge.className = "type-badge";
    badge.textContent = TYPE_LABEL_ZH[type] || type;
    head.appendChild(badge);
  }

  field.appendChild(head);
  renderFieldHelp(field, path, propertySchema, type, nullable);

  const current = parentObj[key];
  const enabled = current !== null && current !== undefined;

  if (nullable) {
    const toggleWrap = document.createElement("label");
    toggleWrap.className = "toggle-null";
    const toggle = document.createElement("input");
    toggle.type = "checkbox";
    toggle.checked = enabled;
    const txt = document.createElement("span");
    txt.textContent = "啟用";
    toggleWrap.appendChild(toggle);
    toggleWrap.appendChild(txt);
    field.appendChild(toggleWrap);

    toggle.addEventListener("change", () => {
      if (!toggle.checked) {
        parentObj[key] = null;
      } else {
        parentObj[key] = defaultValueForSchema(resolved);
      }
      renderForm();
    });

    if (!enabled) {
      container.appendChild(field);
      return;
    }
  }

  if (type === "object") {
    const props = resolved.properties || {};
    const hasProps = Object.keys(props).length > 0;
    const hasMap = Boolean(resolved.additionalProperties);

    if (hasMap && !hasProps) {
      renderMap(field, parentObj, key, resolved, path);
      container.appendChild(field);
      return;
    }

    const target = ensureObject(parentObj, key, resolved);
    const nested = document.createElement("div");
    nested.className = "nested";

    Object.entries(props).forEach(([childKey, childSchema]) => {
      renderProperty(nested, childKey, childSchema, target, `${path}.${childKey}`);
    });

    if (hasMap) {
      renderAdditionalPropertiesMap(nested, target, new Set(Object.keys(props)), `${path}.*`);
    }

    field.appendChild(nested);
    container.appendChild(field);
    return;
  }

  if (type === "array") {
    renderArray(field, parentObj, key, resolved, path);
    container.appendChild(field);
    return;
  }

  renderPrimitive(field, parentObj, key, resolved, path);
  container.appendChild(field);
}

function fillSectionSelector() {
  const root = resolveSchema(state.schema);
  const props = root.properties || {};

  els.sectionSelect.innerHTML = "";

  const allOption = document.createElement("option");
  allOption.value = "all";
  allOption.textContent = "全部";
  els.sectionSelect.appendChild(allOption);

  Object.keys(props)
    .sort((a, b) => a.localeCompare(b))
    .forEach((key) => {
      const option = document.createElement("option");
      option.value = key;
      option.textContent = key;
      els.sectionSelect.appendChild(option);
    });

  const extOption = document.createElement("option");
  extOption.value = EXTENSIONS_SECTION;
  extOption.textContent = "擴充設定";
  els.sectionSelect.appendChild(extOption);

  if (state.section !== "all" && !props[state.section] && state.section !== EXTENSIONS_SECTION) {
    state.section = "all";
  }
  els.sectionSelect.value = state.section;
}

function renderForm() {
  if (!state.schema) return;

  const root = resolveSchema(state.schema);
  const props = root.properties || {};
  const targetKeys = state.section === "all" ? Object.keys(props) : [state.section];

  els.formRoot.innerHTML = "";

  targetKeys
    .filter((k) => props[k])
    .forEach((key) => {
      renderProperty(els.formRoot, key, props[key], state.configJson, key);
    });

  if (state.section === "all" || state.section === EXTENSIONS_SECTION) {
    renderExtensionsEditor(els.formRoot);
  }

  if (!els.formRoot.children.length) {
    const empty = document.createElement("div");
    empty.className = "muted";
    empty.textContent = "目前區段或搜尋條件沒有符合欄位。";
    els.formRoot.appendChild(empty);
  }
}

function translateWarningToZh(message) {
  if (typeof message !== "string") return String(message ?? "");

  const permissionMatch = message.match(/^Config file permissions are (.+) \(recommended: 600\)\.$/);
  if (permissionMatch) {
    return `設定檔權限目前為 ${permissionMatch[1]}（建議：600）。`;
  }

  if (message.startsWith("Config file does not exist yet: ")) {
    const path = message.slice("Config file does not exist yet: ".length);
    return `設定檔尚未建立：${path}`;
  }

  if (message === "Config file is empty; editing starts from an empty object.") {
    return "設定檔目前為空，將以空物件開始編輯。";
  }

  return message;
}

function showWarnings(warnings) {
  if (!warnings || warnings.length === 0) {
    els.warnings.classList.add("hidden");
    els.warnings.innerHTML = "";
    return;
  }
  const list = warnings.map((w) => `<li>${translateWarningToZh(w)}</li>`).join("");
  els.warnings.innerHTML = `<ul>${list}</ul>`;
  els.warnings.classList.remove("hidden");
}

async function loadBundle() {
  if (!invoke) {
    setStatus("找不到 Tauri invoke API。請在 Tauri 應用程式內執行此頁面。", "error");
    return;
  }

  setStatus("正在載入設定與 Schema...", "info");
  try {
    await loadFieldHelpDocs();
    const bundle = await invoke("load_bundle");
    state.schema = bundle.schemaJson;
    state.defs = bundle.schemaJson.$defs || {};
    state.configJson = isObject(bundle.configJson) ? bundle.configJson : {};
    state.rawToml = bundle.rawToml || "";
    state.section = "all";
    state.search = "";

    els.searchInput.value = "";
    els.rawEditor.value = state.rawToml;
    els.configPath.textContent = `${bundle.configPath}${bundle.fileMode ? `（權限 ${bundle.fileMode}）` : ""}`;

    fillSectionSelector();
    renderForm();
    showWarnings(bundle.warnings || []);

    setStatus("設定與 Schema 載入完成。", "ok");
  } catch (error) {
    setStatus(`載入失敗：${error}`, "error");
  }
}

async function syncStructuredToRaw() {
  if (!invoke) return;
  setStatus("正在從結構化模型產生 TOML...", "info");
  try {
    const tomlText = await invoke("render_toml_from_json", {
      payloadJson: JSON.stringify(state.configJson)
    });
    els.rawEditor.value = tomlText;
    setStatus("已由結構化模型同步到原始 TOML。", "ok");
  } catch (error) {
    setStatus(`同步失敗：${error}`, "error");
  }
}

async function saveStructured() {
  if (!invoke) return;
  setStatus("正在儲存結構化設定...", "info");
  try {
    const result = await invoke("save_config_json", {
      payloadJson: JSON.stringify(state.configJson)
    });
    await syncStructuredToRaw();
    setStatus(`已儲存至 ${result.configPath}`, "ok");
  } catch (error) {
    setStatus(`儲存結構化設定失敗：${error}`, "error");
  }
}

async function saveRaw() {
  if (!invoke) return;
  setStatus("正在儲存原始 TOML...", "info");
  try {
    const result = await invoke("save_config_toml", {
      rawToml: els.rawEditor.value
    });
    setStatus(`已儲存原始 TOML 至 ${result.configPath}`, "ok");
    await loadBundle();
  } catch (error) {
    setStatus(`儲存原始 TOML 失敗：${error}`, "error");
  }
}

async function setConfigMode600() {
  if (!invoke) return;
  setStatus("正在將設定檔權限調整為 600...", "info");
  try {
    const result = await invoke("set_config_mode_600");
    await loadBundle();
    const mode = result?.fileMode || "600";
    setStatus(`已將 ${result.configPath} 權限設為 ${mode}。`, "ok");
  } catch (error) {
    setStatus(`設定檔權限調整失敗：${error}`, "error");
  }
}

function setupEvents() {
  els.reloadBtn.addEventListener("click", loadBundle);
  els.syncBtn.addEventListener("click", syncStructuredToRaw);
  els.chmodBtn.addEventListener("click", setConfigMode600);
  els.saveStructuredBtn.addEventListener("click", saveStructured);
  els.saveRawBtn.addEventListener("click", saveRaw);

  els.sectionSelect.addEventListener("change", () => {
    state.section = els.sectionSelect.value;
    renderForm();
  });

  els.searchInput.addEventListener("input", () => {
    state.search = els.searchInput.value.trim();
    renderForm();
  });

  document.querySelectorAll(".tab").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".tab").forEach((x) => x.classList.remove("active"));
      document.querySelectorAll(".tab-panel").forEach((x) => x.classList.remove("active"));
      btn.classList.add("active");
      const panelId = btn.dataset.tab === "structured" ? "structuredTab" : "rawTab";
      document.getElementById(panelId).classList.add("active");
    });
  });
}

setupEvents();
loadBundle();
