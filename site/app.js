document.querySelectorAll("[data-copy]").forEach((button) => {
  button.addEventListener("click", async () => {
    const text = button.getAttribute("data-copy");
    const original = button.textContent;

    if (!text) {
      return;
    }

    try {
      await navigator.clipboard.writeText(text);
      button.textContent = "Copied";
    } catch {
      button.textContent = "Copy failed";
    }

    window.setTimeout(() => {
      button.textContent = original;
    }, 1400);
  });
});
