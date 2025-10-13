document.addEventListener("DOMContentLoaded", function () {
  const totalElement = document.getElementById("total-diverted");
  const livesElement = document.getElementById("lives-saved");

  async function update() {
    try {
      const response = await fetch("/api/stats");
      const data = await response.json();
      if (data.givewell !== undefined) {
        totalElement.textContent = `${data.givewell}`;
        // https://www.givewell.org/how-much-does-it-cost-to-save-a-life
        livesElement.textContent = `${Math.round(data.givewell / 3000)}`;
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

    new Chart(ctx, {
      type: "bar",
      data: {
        labels: labels,
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
        },
      },
    });
  }

  // Update on load
  update();

  // Optional: Refresh every 60 seconds
  setInterval(update, 60000);
});
