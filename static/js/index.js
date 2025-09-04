async function loadStats() {
  try {
    const res = await fetch("/api/stats", { credentials: "same-origin" });
    const text = await res.text();
    if (!res.ok) {
      console.error("/api/stats failed", res.status, text);
      return;
    }
    let data;
    try {
      data = JSON.parse(text);
    } catch (e) {
      console.error("Invalid JSON from /api/stats:", text);
      return;
    }

    // Counters
    const num = (v) => (Number.isFinite(v) ? v : 0);
    const fmt = (v) => num(v).toLocaleString();
    const money = (v) => `$${fmt(v)}`;

    const total = num(data.total_amount);
    const month = num(data.month_amount);
    const lives = num(data.lives_saved);
    const livesM = num(data.lives_saved_month);
    const causeA = num(data.cause_a ?? data.a);
    const causeB = num(data.cause_b ?? data.b);

    const q = (id) => document.getElementById(id);
    if (q("total-amount")) q("total-amount").textContent = money(total);
    if (q("month-amount")) q("month-amount").textContent = money(month);
    if (q("lives-saved")) q("lives-saved").textContent = fmt(lives);
    if (q("lives-saved-month"))
      q("lives-saved-month").textContent = fmt(livesM);
    if (q("a")) q("a").textContent = money(causeA);
    if (q("b")) q("b").textContent = money(causeB);

    // Top donors (all time)
    const renderList = (elId, items) => {
      const el = q(elId);
      if (!el) return;
      el.innerHTML = "";
      if (!Array.isArray(items) || items.length === 0) {
        el.innerHTML =
          '<div class="donor-item placeholder">No donors yet</div>';
        return;
      }
      items.forEach((d) => {
        const div = document.createElement("div");
        div.className = "donor-item";
        const name = d.donor || "Anonymous";
        const amt = money(d.amount || 0);
        div.innerHTML = `<span class="donor-name">${name}</span><span class="donor-amount">${amt}</span>`;
        el.appendChild(div);
      });
    };
    renderList("top-donors-all", data.top_donors || []);
    renderList("top-donors-month", data.top_donors_month || []);

    // Map
    if (typeof loadMap === "function") {
      loadMap(data);
    } else {
      // if map.js loads later, try once on next tick
      setTimeout(() => {
        if (typeof loadMap === "function") loadMap(data);
      }, 0);
    }
  } catch (err) {
    console.error("Error loading stats:", err);
  }
}

document.addEventListener("DOMContentLoaded", loadStats);
