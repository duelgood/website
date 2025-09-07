document
  .getElementById("donation-form")
  .addEventListener("submit", function (e) {
    const amounts = [
      "planned_parenthood_amount",
      "national_right_to_life_committee_amount",
      "everytown_for_gun_safety_amount",
      "nra_foundation_amount",
      "trevor_project_amount",
      "alliance_defending_freedom_amount",
      "duelgood_amount",
    ];

    const total = amounts.reduce(
      (sum, id) => sum + (parseFloat(document.getElementById(id).value) || 0),
      0
    );

    if (total < 1) {
      e.preventDefault();
      alert("Please enter at least one donation amount of $1 or more.");
    }
  });
