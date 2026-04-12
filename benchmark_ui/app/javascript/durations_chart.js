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
  const preferredOrder = ["ruby", "go", "python", "node"]; // keep colors stable
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

function renderDurationsChart(el, seriesByHandler) {
  const series = toSeries(seriesByHandler);
  const chart = new ApexCharts(el, {
    chart: { type: "boxPlot", height: 360, animations: { enabled: false } },
    series,
    title: { text: "Duration by Page Size", align: "left" },
    xaxis: { type: "category", title: { text: "Page Size" } },
    yaxis: { title: { text: "Duration" } },
    tooltip: { shared: false, intersect: true },
    grid: { padding: { right: 16 } },
    theme: { mode: document.documentElement.dataset.theme || "light" },
    legend: { position: "top" },
  });
  chart.render();
}

function initDurations() {
  const container = document.querySelector("div[data-durations]");
  if (!container || container.dataset.chartAttached === "1") return;
  const data = parseJSONAttribute(container, "data-durations");
  container.innerHTML = "";
  renderDurationsChart(container, data || {});
  container.dataset.chartAttached = "1";
}

document.addEventListener("turbo:load", initDurations);
document.addEventListener("DOMContentLoaded", initDurations);
if (document.readyState === "interactive" || document.readyState === "complete") {
  initDurations();
}
