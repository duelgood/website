function loadMap(data) {
  // US map with existing Chart.js implementation
  fetch("https://cdn.jsdelivr.net/npm/us-atlas/states-10m.json")
    .then((res) => res.json())
    .then((us) => {
      const canvas = document.getElementById("us-map");
      const states = ChartGeo.topojson.feature(us, us.objects.states).features;

      // TODO: Backend needs to parse mailing addresses and group by state
      const donationsByState = data.donations_by_state || {};

      new Chart(canvas, {
        type: "choropleth",
        data: {
          labels: states.map((d) => d.properties.name),
          datasets: [
            {
              label: "Donations by State",
              data: states.map((d) => ({
                feature: d,
                value: donationsByState[d.properties.name] || 0,
              })),
            },
          ],
        },
        options: {
          showOutline: true,
          showGraticule: false,
          scales: {
            projection: {
              axis: "x",
              projection: "albersUsa",
            },
            color: {
              axis: "x",
              quantize: 5,
              legend: {
                position: "bottom-right",
                align: "right",
              },
            },
          },
          plugins: {
            legend: { display: false },
            tooltip: {
              callbacks: {
                label: (ctx) =>
                  `${ctx.label}: $${ctx.raw.value.toLocaleString()}`,
              },
              callbacks: {
                label: (ctx) => {
                  // feature name (ChartGeo puts the GeoJSON feature on ctx.raw.feature)
                  const name =
                    (ctx &&
                      ctx.raw &&
                      ctx.raw.feature &&
                      ctx.raw.feature.properties &&
                      ctx.raw.feature.properties.name) ||
                    ctx.label ||
                    "Unknown";
                  const value =
                    ctx && ctx.raw && typeof ctx.raw.value !== "undefined"
                      ? ctx.raw.value
                      : 0;
                  // ensure numeric formatting
                  const displayValue =
                    typeof value === "number"
                      ? value.toLocaleString()
                      : String(value);
                  return `${name}: $${displayValue}`;
                },
              },
            },
          },
        },
      });
    })
    .catch((error) => {
      console.error("Error loading map data:", error);
      const canvas = document.getElementById("us-map");
      canvas.style.display = "none";
      canvas.parentElement.innerHTML =
        '<p style="text-align: center; color: #666; padding: 40px;">Map temporarily unavailable</p>';
      const container = document.querySelector(".map-container");
      // keep the canvas (so page layout remains stable) and show a small message
      const msg = document.createElement("div");
      msg.className = "map-error";
      msg.textContent = "Map temporarily unavailable";
      msg.style.cssText =
        "text-align:center;color:#666;padding:20px;font-size:14px;";
      // remove any previous message then append
      const prev = container.querySelector(".map-error");
      if (prev) prev.remove();
      container.appendChild(msg);
    });
}
