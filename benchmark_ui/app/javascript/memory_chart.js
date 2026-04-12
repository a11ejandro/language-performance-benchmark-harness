import ApexCharts from "apexcharts";

function parseJSONAttribute(el, name) {
  const raw = el.getAttribute(name);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch (_) {
    return null;
  }
}

function toSeries(seriesByHandler) {
  if (!seriesByHandler) return [];
  const preferredOrder = ["ruby", "go", "python", "node"]; // stable colors
  const keys = [
    ...preferredOrder.filter((k) => Object.prototype.hasOwnProperty.call(seriesByHandler, k)),
    ...Object.keys(seriesByHandler).filter((k) => !preferredOrder.includes(k)).sort(),
  ];

  return keys.map((handler) => {
    const points = seriesByHandler[handler] || [];
    const data = points
      .filter((p) => p && Array.isArray(p.y) && p.y.length === 5)
      .map((p) => ({ x: String(p.x), y: p.y.map((v) => Number(v)) }))
      .filter((p) => p.y.every((v) => Number.isFinite(v)));
    return { name: handler, data };
  });
}

function renderMemoryChart(el, seriesByHandler) {
  const series = toSeries(seriesByHandler);
  const chart = new ApexCharts(el, {
    chart: { type: "boxPlot", height: 360, animations: { enabled: false } },
    series,
    title: { text: "Memory by Page Size", align: "left" },
    xaxis: { type: "category", title: { text: "Page Size" } },
    yaxis: { title: { text: "Memory" } },
    tooltip: { shared: false, intersect: true },
    grid: { padding: { right: 16 } },
    theme: { mode: document.documentElement.dataset.theme || "light" },
    legend: { position: "top" },
  });
  chart.render();
}

function initMemory() {
  const container = document.querySelector("div[data-memories]");
  if (!container || container.dataset.chartAttached === "1") return;
  const data = parseJSONAttribute(container, "data-memories");
  container.innerHTML = "";
  renderMemoryChart(container, data || {});
  container.dataset.chartAttached = "1";
}

document.addEventListener("turbo:load", initMemory);
document.addEventListener("DOMContentLoaded", initMemory);
if (document.readyState === "interactive" || document.readyState === "complete") {
  initMemory();
}
