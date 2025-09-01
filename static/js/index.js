async function loadStats() {
  try {
    const res = await fetch("/api/stats");
    const data = await res.json();

    console.log("Stats data:", data); // Debug log

    // Update counters
    document.getElementById("total-amount").textContent =
      "$" + (data.total_amount || 0).toLocaleString();
    document.getElementById("month-amount").textContent =
      "$" + (data.month_amount || 0).toLocaleString();
    document.getElementById("lives-saved").textContent = (
      data.lives_saved || 0
    ).toLocaleString();
    document.getElementById("lives-saved-month").textContent = (
      data.lives_saved_month || 0
    ).toLocaleString();
    document.getElementById("a").textContent =
      "$" + (data.a || 0).toLocaleString();
    document.getElementById("b").textContent =
      "$" + (data.b || 0).toLocaleString();

    // Top donors (all time)
    const topAllList = document.getElementById("top-donors-all");
    topAllList.innerHTML = "";

    if (data.top_donors && data.top_donors.length > 0) {
      data.top_donors.forEach((d) => {
        const div = document.createElement("div");
        div.className = "donor-item";
        div.innerHTML = `<span class="donor-name">${
          d.donor
        }</span><span class="donor-amount">$${d.amount.toLocaleString()}</span>`;
        topAllList.appendChild(div);
      });
    } else {
      topAllList.innerHTML =
        '<div class="donor-item placeholder">No donors yet</div>';
    }

    // Top donors this month
    const topMonthList = document.getElementById("top-donors-month");
    topMonthList.innerHTML = "";

    if (data.top_donors_month && data.top_donors_month.length > 0) {
      data.top_donors_month.forEach((d) => {
        const div = document.createElement("div");
        div.className = "donor-item";
        div.innerHTML = `<span class="donor-name">${
          d.donor
        }</span><span class="donor-amount">$${d.amount.toLocaleString()}</span>`;
        topMonthList.appendChild(div);
      });
    } else {
      topMonthList.innerHTML =
        '<div class="donor-item placeholder">No donations this month</div>';
    }
  } catch (error) {
    console.error("Error loading stats:", error);
    // Show error state
    document.getElementById("top-donors-all").innerHTML =
      '<div class="donor-item placeholder">Error loading data</div>';
    document.getElementById("top-donors-month").innerHTML =
      '<div class="donor-item placeholder">Error loading data</div>';
  }
}

loadStats();
