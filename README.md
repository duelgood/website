# DuelGood

A website for canceling opposing political donations and directing the difference to charity.

## Getting an Instance

This website is hosted with Oracle Cloud's always-free tier. Here's a
script to aid in getting an always-free instance:

Here is the shape to select:

- Oracle Linux 9
- ARM ec2.x.x.x.micro

```js
function keepSessionAlive() {
  // Click the "Create" button
  const buttons = Array.from(document.querySelectorAll("button"));
  const createBtn = buttons.find((btn) => btn.textContent.trim() === "Create");

  if (createBtn) {
    createBtn.click();
    console.log('Clicked "Create" at', new Date().toLocaleTimeString());
  } else {
    console.warn('"Create" button not found!');
  }

  // Simulate mouse movement
  document.dispatchEvent(
    new MouseEvent("mousemove", {
      bubbles: true,
      cancelable: true,
      clientX: Math.random() * window.innerWidth,
      clientY: Math.random() * window.innerHeight,
    })
  );

  // Simulate key press
  document.dispatchEvent(
    new KeyboardEvent("keydown", { key: "Shift", bubbles: true })
  );
  document.dispatchEvent(
    new KeyboardEvent("keyup", { key: "Shift", bubbles: true })
  );

  // Occasionally switch focus to mimic tab switching
  if (Math.random() > 0.8) {
    // ~20% of the time
    window.blur();
    setTimeout(() => window.focus(), 500);
  }
}

// Run immediately, then every 30 seconds
keepSessionAlive();
setInterval(keepSessionAlive, 30000);
```

## Setting up

Copy Cloudflare origin key into `/etc/ssl/cloudflare/key.pem`.
Copy Cloudflare origin cert into `/etc/ssl/cloudflare/cert.pem`

```sh
sudo chmod 644 "/etc/ssl/cloudflare/cert.pem"
sudo chmod 600 "/etc/ssl/cloudflare/key.pem"
```

Then, run

```sh
sudo mkdir -p /opt/duelgood && sudo curl -H "Authorization: token ${GITHUB_PAT:?Set GITHUB_PAT environment variable}" -sSL "https://raw.githubusercontent.com/duelgood/duelgood/main/docker-compose.yml?$(date +%s)" -o /opt/duelgood/docker-compose.yml && sudo curl -H "Authorization: token $GITHUB_PAT" -sSL "https://raw.githubusercontent.com/duelgood/duelgood/main/startup.sh?$(date +%s)" -o startup.sh && sh startup.sh
```
