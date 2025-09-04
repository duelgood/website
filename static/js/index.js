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
      console.error("Invalid JSON", text);
      return;
    }

    const num = (v) => (Number.isFinite(v) ? v : 0);
    const fmt = (v) => num(v).toLocaleString();
    const money = (v) => `$${fmt(v)}`;
    const q = (id) => document.getElementById(id);

    if (q("total-amount"))
      q("total-amount").textContent = money(data.total_amount || 0);
    if (q("month-amount"))
      q("month-amount").textContent = money(data.month_amount || 0);
    if (q("lives-saved"))
      q("lives-saved").textContent = fmt(data.lives_saved || 0);
    if (q("lives-saved-month"))
      q("lives-saved-month").textContent = fmt(data.lives_saved_month || 0);
    if (q("a")) q("a").textContent = money((data.cause_a ?? data.a) || 0);
    if (q("b")) q("b").textContent = money((data.cause_b ?? data.b) || 0);

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
        div.innerHTML = `<span class="donor-name">${
          d.donor || "Anonymous"
        }</span><span class="donor-amount">$${fmt(d.amount || 0)}</span>`;
        el.appendChild(div);
      });
    };
    renderList("top-donors-all", data.top_donors || []);
    renderList("top-donors-month", data.top_donors_month || []);

    // call map after stats are ready
    if (typeof window.loadMap === "function") window.loadMap(data);
  } catch (e) {
    console.error("Error loading stats:", e);
  }
}

document.addEventListener("DOMContentLoaded", loadStats);
