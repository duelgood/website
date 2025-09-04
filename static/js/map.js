// register chart-geo pieces (must run after ChartGeo script tag)
if (window.Chart && window.ChartGeo) {
  Chart.register(
    ChartGeo.ChoroplethController,
    ChartGeo.GeoFeature,
    ChartGeo.ProjectionScale,
    ChartGeo.ColorScale,
    ChartGeo.SizeScale
  );
}

let _usTopo = null;
let _usChart = null;

function loadMap(data) {
  // libs/canvas present?
  if (!window.Chart || !window.ChartGeo) return;
  const canvas = document.getElementById("us-map");
  if (!canvas) return;

  const topoPromise = _usTopo
    ? Promise.resolve(_usTopo)
    : fetch("https://cdn.jsdelivr.net/npm/us-atlas/states-10m.json")
        .then((r) => r.json())
        .then((us) => (_usTopo = us));

  topoPromise
    .then((us) => {
      const states = ChartGeo.topojson.feature(us, us.objects.states).features;
      const byState = (data && data.donations_by_state) || {};

      if (_usChart) {
        try {
          _usChart.destroy();
        } catch (_) {}
        _usChart = null;
      }

      _usChart = new Chart(canvas, {
        type: "choropleth",
        data: {
          labels: states.map((d) => d.properties.name),
          datasets: [
            {
              label: "Donations by State",
              data: states.map((d) => ({
                feature: d,
                value: byState[d.properties.name] || 0,
              })),
            },
          ],
        },
        options: {
          showOutline: true,
          showGraticule: false,
          scales: {
            projection: { axis: "x", projection: "albersUsa" },
            color: {
              axis: "x",
              quantize: 5,
              legend: { position: "bottom-right", align: "right" },
            },
          },
          plugins: {
            legend: { display: false },
            tooltip: {
              callbacks: {
                label: (ctx) => {
                  const name =
                    ctx?.raw?.feature?.properties?.name ||
                    ctx.label ||
                    "Unknown";
                  const val =
                    typeof ctx?.raw?.value === "number" ? ctx.raw.value : 0;
                  return `${name}: $${val.toLocaleString()}`;
                },
              },
            },
          },
        },
      });
    })
    .catch((err) => {
      console.error("Map load failed:", err);
      const container = document.querySelector(".map-container");
      if (container && !container.querySelector(".map-error")) {
        const msg = document.createElement("div");
        msg.className = "map-error";
        msg.textContent = "Map temporarily unavailable";
        msg.style.cssText =
          "text-align:center;color:#666;padding:20px;font-size:14px;";
        container.appendChild(msg);
      }
    });
}

window.loadMap = loadMap; // make available to index.js
