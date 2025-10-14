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

        const stateData = data.states;
        const numericStates = {};
        for (const [key, value] of Object.entries(stateData)) {
          numericStates[key] =
            typeof value === "object" ? value.parsedValue : value;
        }

        renderStatesMap(numericStates);
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

    const features = window.topojson.feature(us, us.objects.states).features;

    // Combine each feature with its donation value
    const dataPoints = features.map((feature) => {
      const stateAbbrev = Object.keys(stateCodeMap).find(
        (key) => stateCodeMap[key] === feature.properties.STATE
      );
      return {
        feature: feature, // GeoJSON geometry
        value: states[stateAbbrev] || 0, // Donation value
      };
    });

    // Destroy any previous chart instance if necessary
    if (window.usMapChart) window.usMapChart.destroy();

    window.usMapChart = new Chart(ctx, {
      type: "choropleth",
      data: {
        labels: features.map((f) => f.properties.NAME),
        datasets: [
          {
            label: "Donations ($)",
            data: dataPoints, // ✅ must contain {feature, value}
            borderColor: "#fff",
            borderWidth: 1,
            backgroundColor: (ctx) => {
              // ✅ use ctx.raw.value safely
              const value = ctx.raw?.value ?? 0;
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
                const amount = context.raw?.value ?? 0;
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

  function loadImages(urls) {
    return Promise.all(
      urls.map(
        (url) =>
          new Promise((resolve) => {
            const img = new Image();
            img.onload = () => resolve(img);
            img.onerror = () => resolve(null);
            img.src = url;
          })
      )
    );
  }

  async function renderCausesChart(causes, givewell) {
    if (chartInstance) chartInstance.destroy();

    const ctx = document.getElementById("causes-chart").getContext("2d");

    const labels = [
      "Planned Parenthood",
      "Focus on the Family",
      "Everytown for Gun Safety",
      "NRA Foundation",
      "Trevor Project",
      "Family Research Council",
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
      "/static/logos/nra.png",
      "/static/logos/trevor_project.png",
      "/static/logos/family_research_council.png",
      "/static/logos/favicon.png",
      "/static/logos/givewell.png",
    ];

    // --- Helper: preload all images ---
    async function loadImages(urls) {
      return Promise.all(
        urls.map(
          (url) =>
            new Promise((resolve) => {
              const img = new Image();
              img.onload = () => resolve(img);
              img.onerror = () => {
                console.warn("Logo failed to load:", url);
                resolve(null);
              };
              img.src = url;
            })
        )
      );
    }

    const images = await loadImages(logoUrls);

    // --- Custom plugin to draw images under bars ---
    const imagePlugin = {
      id: "imagePlugin",
      afterDraw: (chart) => {
        const {
          ctx,
          chartArea: { bottom },
          scales: { x },
        } = chart;

        const imgSize = Math.min(50, chart.width / (images.length * 2)); // auto-scale
        const gap = 10; // space between chart and images

        chart.data.datasets[0].data.forEach((value, index) => {
          const img = images[index];
          if (!img) return;

          const barX = x.getPixelForValue(index);
          const imgX = barX - imgSize / 2;
          const imgY = bottom + gap;

          ctx.save();
          ctx.drawImage(img, imgX, imgY, imgSize, imgSize);
          ctx.restore();
        });
      },
    };

    chartInstance = new Chart(ctx, {
      type: "bar",
      data: {
        labels,
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
        layout: {
          padding: { bottom: 70 }, // give room for logos
        },
        scales: {
          y: { beginAtZero: true },
          x: {
            display: false, // hide text labels since logos replace them
          },
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              title: (context) => labels[context[0].dataIndex],
              label: (context) =>
                `$${context.parsed.y.toLocaleString()} donated`,
            },
          },
        },
      },
      plugins: [imagePlugin],
    });
  }
  // Update on load
  update();

  // Optional: Refresh every 60 seconds
  // setInterval(update, 60000);
});
