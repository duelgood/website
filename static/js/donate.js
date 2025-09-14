console.log("donate.js loaded");
const stripe = Stripe(
  "pk_test_51S5FMtPaAbpNU2MW6IFPfy7uuVlvMcfDkJmI6xpUEd8AC8VvkwwO87PGhUlfUkPEmio4i3LnDgygBkpl5X68hCSj00SD13F37u"
);

document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("donation-form");

  const elements = stripe.elements();
  const card = elements.create("card");
  card.mount("#card-element");

  form.addEventListener("submit", async (e) => {
    e.preventDefault();

    // Gather form data
    const formData = new FormData(form);
    const payload = Object.fromEntries(formData.entries());

    // Ask Flask backend to create a PaymentIntent
    const res = await fetch("/api/donations", {
      method: "POST",
      body: new URLSearchParams(payload),
    });

    const data = await res.json();
    if (data.error) {
      alert(data.error);
      return;
    }

    // Confirm card payment
    const result = await stripe.confirmCardPayment(data.clientSecret, {
      payment_method: {
        card: card,
        billing_details: {
          name: payload.legal_name,
          email: payload.email,
          address: {
            line1: payload.street_address,
            city: payload.city,
            state: payload.state,
            postal_code: payload.zip,
          },
        },
      },
    });

    if (result.error) {
      alert(result.error.message);
    } else if (result.paymentIntent.status === "succeeded") {
      window.location = "/thank-you";
    }
  });
});
