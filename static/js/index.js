document.addEventListener("DOMContentLoaded", function () {
  const totalElement = document.getElementById("total-amount");
  const livesElement = document.getElementById("lives-saved");

  async function update() {
    try {
      const response = await fetch("/api/total");
      const data = await response.json();
      if (data.total !== undefined) {
        totalElement.textContent = `${data.total}`;
        // https://www.givewell.org/how-much-does-it-cost-to-save-a-life
        livesElement.textContent = `${Math.round(data.total / 3000)}`;
      }
    } catch (error) {
      console.error("Error fetching total:", error);
      totalElement.textContent = "Error loading";
    }
  }

  // Update on load
  update();

  // Optional: Refresh every 60 seconds
  setInterval(update, 60000);
});
