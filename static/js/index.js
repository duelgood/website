document.addEventListener("DOMContentLoaded", function () {
  const totalElement = document.getElementById("total-diverted");
  const livesElement = document.getElementById("lives-saved");

  async function update() {
    try {
      const response = await fetch("/api/stats");
      const data = await response.json();
      if (data.givewell !== undefined) {
        totalElement.textContent = `${data.givewell.toLocaleString()}`;
        // https://www.givewell.org/how-much-does-it-cost-to-save-a-life
        livesElement.textContent = `${Math.round(
          data.givewell / 3000
        ).toLocaleString()}`;
        renderCausesChart(data.causes, data.givewell);
        renderStatesMap(data.states);
      }
    } catch (error) {
      console.error("Error fetching total:", error);
      totalElement.textContent = "loading...";
      livesElement.textContent = "loading...";
    }
  }

  async function renderStatesMap(states) {
    const ctx = document.getElementById("us-map").getContext("2d");

    // Fetch US states topojson
    const response = await fetch("/static/js/us-states.json");
    const us = await response.json();

    // State code mapping (abbrev to FIPS)
    const stateCodeMap = {
      AL: "01",
      AK: "02",
      AZ: "04",
      AR: "05",
      CA: "06",
      CO: "08",
      CT: "09",
      DE: "10",
      DC: "11",
      FL: "12",
      GA: "13",
      HI: "15",
      ID: "16",
      IL: "17",
      IN: "18",
      IA: "19",
      KS: "20",
      KY: "21",
      LA: "22",
      ME: "23",
      MD: "24",
      MA: "25",
      MI: "26",
      MN: "27",
      MS: "28",
      MO: "29",
      MT: "30",
      NE: "31",
      NV: "32",
      NH: "33",
      NJ: "34",
      NM: "35",
      NY: "36",
      NC: "37",
      ND: "38",
      OH: "39",
      OK: "40",
      OR: "41",
      PA: "42",
      RI: "44",
      SC: "45",
      SD: "46",
      TN: "47",
      TX: "48",
      UT: "49",
      VT: "50",
      VA: "51",
      WA: "53",
      WV: "54",
      WI: "55",
      WY: "56",
    };

    const data = us.objects.states.geometries.map((feature) => {
      const stateAbbrev = Object.keys(stateCodeMap).find(
        (key) => stateCodeMap[key] === feature.properties.STATE
      );
      const amount = states[stateAbbrev] || 0;
      return {
        feature: feature,
        value: amount,
      };
    });

    new Chart(ctx, {
      type: "choropleth",
      data: {
        labels: us.objects.states.geometries.map((d) => d.properties.NAME),
        datasets: [
          {
            label: "Donations ($)",
            data: data,
            borderWidth: 1,
            borderColor: "#fff",
            backgroundColor: (context) => {
              const value = context.raw.value;
              return value > 0 ? "#0A3161" : "#f0f0f0";
            },
          },
        ],
      },
      options: {
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (context) => {
                const state = context.label;
                const amount = context.raw.value;
                return `${state}: $${amount.toFixed(2)}`;
              },
            },
          },
        },
        scales: {
          projection: {
            axis: "x",
            projection: "albersUsa",
          },
        },
      },
    });
  }

  let chartInstance = null;

  function renderCausesChart(causes, givewell) {
    if (chartInstance) {
      chartInstance.destroy();
    }

    const ctx = document.getElementById("causes-chart").getContext("2d");
    const labels = [
      "PP",
      "FotF",
      "Everytown",
      "NRA Foundation",
      "Trevor Project",
      "FRC",
      "DuelGood",
      "GiveWell",
    ];
    const values = [
      causes.planned_parenthood_amount,
      causes.focus_on_the_family_amount,
      causes.everytown_for_gun_safety_amount,
      causes.nra_foundation_amount,
      causes.trevor_project_amount,
      causes.family_research_council_amount,
      causes.duelgood_amount,
      givewell,
    ];
    const colors = [
      "#0A3161",
      "#B31942",
      "#0A3161",
      "#B31942",
      "#0A3161",
      "#B31942",
      "#f88920",
      "#f88920",
    ];

    const logoUrls = [
      "/static/logos/planned_parenthood.png",
      "/static/logos/focus_on_the_family.png",
      "/static/logos/everytown_for_gun_safety.png",
      "/static/logos/nra_foundation.png",
      "/static/logos/trevor_project.png",
      "/static/logos/family_research_council.png",
      "/static/logo.png",
      "/static/logos/givewell.png",
    ];

    const images = logoUrls.map((url) => {
      const img = new Image();
      img.src = url;
      return img;
    });

    const imagePlugin = {
      id: "imagePlugin",
      afterDraw: (chart) => {
        const {
          ctx,
          chartArea: { left, right, top, bottom },
          scales: { x, y },
        } = chart;
        chart.data.datasets[0].data.forEach((value, index) => {
          if (value > 0) {
            const barX = x.getPixelForValue(index);
            let barTop = y.getPixelForValue(value);
            // Clamp barTop to ensure it's within chart area
            barTop = Math.max(barTop, top + 10); // At least 10px below top
            const img = images[index];
            if (img.complete && img.naturalHeight > 0) {
              const imgSize = 40;
              const imgY = barTop - imgSize - 10;
              if (imgY > top) {
                // Ensure image is visible
                ctx.drawImage(img, barX - imgSize / 2, imgY, imgSize, imgSize);
                console.log(
                  `Drew image for index ${index} at x:${barX}, y:${imgY}`
                ); // Debug
              }
            } else {
              console.warn(`Image not ready: ${logoUrls[index]}`);
            }
          }
        });
      },
    };

    chartInstance = new Chart(ctx, {
      type: "bar",
      data: {
        labels: labels, // Keep labels for tooltips/legend, but hide x-axis if needed
        datasets: [
          {
            label: "Donations ($)",
            data: values,
            backgroundColor: colors,
            borderColor: colors,
            borderWidth: 1,
          },
        ],
      },
      options: {
        scales: {
          y: { beginAtZero: true },
          x: {
            display: false, // Hide x-axis text labels since we're using images
          },
        },
        plugins: [imagePlugin], // Register the plugin
      },
    });
  }

  // Update on load
  update();

  // Optional: Refresh every 60 seconds
  setInterval(update, 60000);
});
