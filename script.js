const yearElement = document.querySelector("#current-year");
const themeToggle = document.querySelector(".theme-toggle");

if (yearElement) {
  yearElement.textContent = new Date().getFullYear();
}

const savedTheme = localStorage.getItem("theme");
const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;

if (savedTheme === "dark" || (!savedTheme && prefersDark)) {
  document.body.classList.add("dark");
}

function updateThemeButton() {
  const isDark = document.body.classList.contains("dark");
  themeToggle.textContent = isDark ? "Mode clair" : "Mode sombre";
}

if (themeToggle) {
  updateThemeButton();

  themeToggle.addEventListener("click", () => {
    document.body.classList.toggle("dark");
    const isDark = document.body.classList.contains("dark");
    localStorage.setItem("theme", isDark ? "dark" : "light");
    updateThemeButton();
  });
}
