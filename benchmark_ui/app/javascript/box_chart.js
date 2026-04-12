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

function toBoxPlotData(statsByHandler) {
  // statsByHandler: { "Go": {min,q1,median,q3,max,...}, "Ruby": {...} }
  const data = [];
  Object.entries(statsByHandler || {}).forEach(([handler, s]) => {
    if (!s) return;
    const { min, q1, median, q3, max } = s;
    const values = [min, q1, median, q3, max].map((v) =>
      typeof v === "string" ? Number(v) : v
    );
    if (values.every((v) => Number.isFinite(v))) {
      data.push({ x: handler, y: values });
    }
  });
  return data;
}

function renderBoxChart(el, statsByHandler, title) {
  const series = [
    {
      name: title,
      data: toBoxPlotData(statsByHandler),
    },
  ];

  const chart = new ApexCharts(el, {
    chart: { type: "boxPlot", height: 320, animations: { enabled: false } },
    series,
    title: { text: title, align: "left" },
    xaxis: { type: "category" },
    tooltip: { shared: false, intersect: true },
    grid: { padding: { right: 16 } },
    theme: { mode: document.documentElement.dataset.theme || "light" },
  });
  chart.render();
}

function initBoxCharts() {
  document.querySelectorAll(".box-chart .box").forEach((box) => {
    const container = box.querySelector(
      "div[data-duration], div[data-memory], div[data-memory_usage]"
    );
    if (!container || container.dataset.chartAttached === "1") return;

    const duration = parseJSONAttribute(container, "data-duration");
    const memory =
      parseJSONAttribute(container, "data-memory") ||
      parseJSONAttribute(container, "data-memory_usage");

    container.innerHTML = "";

    if (duration && Object.keys(duration).length) {
      renderBoxChart(container, duration, "Duration");
      container.dataset.chartAttached = "1";
    } else if (memory && Object.keys(memory).length) {
      renderBoxChart(container, memory, "Memory");
      container.dataset.chartAttached = "1";
    }
  });
}

// Run on Turbo navigation, DOM load, and immediately if already loaded
document.addEventListener("turbo:load", initBoxCharts);
document.addEventListener("DOMContentLoaded", initBoxCharts);
if (document.readyState === "interactive" || document.readyState === "complete") {
  initBoxCharts();
}
