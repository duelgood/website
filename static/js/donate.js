document.addEventListener("DOMContentLoaded", function () {
  const form = document.getElementById("donation-form");
  const cardErrors = document.getElementById("card-errors");

  // Initialize Stripe.js with your publishable key
  const stripe = Stripe(
    "pk_test_51S5FMtPaAbpNU2MW6IFPfy7uuVlvMcfDkJmI6xpUEd8AC8VvkwwO87PGhUlfUkPEmio4i3LnDgygBkpl5X68hCSj00SD13F37u"
  );
  const elements = stripe.elements();
  const cardElement = elements.create("card");
  cardElement.mount("#card-element");

  const amountIds = [
    "planned_parenthood_amount",
    "national_right_to_life_committee_amount",
    "everytown_for_gun_safety_amount",
    "nra_foundation_amount",
    "trevor_project_amount",
    "alliance_defending_freedom_amount",
    "duelgood_amount",
  ];

  // Helpers: enforce min=0 and reset empty -> 0
  amountIds.forEach((id) => {
    const input = document.getElementById(id);

    input.addEventListener("input", () => {
      if (parseFloat(input.value) < 0) input.value = "0";
    });

    input.addEventListener("blur", () => {
      if (input.value === "") input.value = "0";
    });
  });

  form.addEventListener("submit", function (e) {
    e.preventDefault();

    // Wait a tick so Enter key values finalize
    setTimeout(async () => {
      // ---- 1. Validate donation amounts ----
      const hasOneAboveOne = amountIds.some(
        (id) => parseFloat(document.getElementById(id).value) >= 1
      );

      if (!hasOneAboveOne) {
        alert("Please enter at least one donation amount of $1 or more.");
        return;
      }

      // ---- 2. Collect form data ----
      const formData = new FormData(form);
      const data = Object.fromEntries(formData.entries());

      try {
        // ---- 3. Send donation data to backend ----
        const response = await fetch("/api/donations", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(data),
        });

        const { clientSecret, error } = await response.json();
        if (error) {
          cardErrors.textContent = error;
          return;
        }

        // ---- 4. Confirm payment with Stripe ----
        const { paymentIntent, error: stripeError } =
          await stripe.confirmCardPayment(clientSecret, {
            payment_method: {
              card: cardElement,
              billing_details: {
                name: data.legal_name,
                email: data.email,
                address: {
                  line1: data.street_address,
                  city: data.city,
                  state: data.state,
                  postal_code: data.zip,
                },
              },
            },
          });

        if (stripeError) {
          cardErrors.textContent = stripeError.message;
        } else if (paymentIntent && paymentIntent.status === "succeeded") {
          alert("Donation successful! Thank you for your support.");
          form.reset();
          cardElement.clear();
          // reset donation inputs to "0"
          amountIds.forEach((id) => (document.getElementById(id).value = "0"));
        }
      } catch (err) {
        console.error("Donation error:", err);
        cardErrors.textContent =
          "An unexpected error occurred. Please try again.";
      }
    }, 0);
  });
});
