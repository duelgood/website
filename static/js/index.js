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
      }
    } catch (error) {
      console.error("Error fetching total:", error);
      totalElement.textContent = "a lot";
      livesElement.textContent = "a few";
    }
  }

  function renderCausesChart(causes, givewell) {
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
            // Only draw for non-zero bars
            const barX = x.getPixelForValue(index); // X position of bar
            const barTop = y.getPixelForValue(value); // Top of bar
            const img = new Image();
            img.src = logoUrls[index];
            img.onload = () => {
              const imgSize = 40; // Image size (adjust as needed)
              ctx.drawImage(
                img,
                barX - imgSize / 2,
                barTop - imgSize - 5,
                imgSize,
                imgSize
              ); // Center above bar
            };
          }
        });
      },
    };

    new Chart(ctx, {
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
