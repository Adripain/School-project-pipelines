const serverSource = require("fs").readFileSync("server.js", "utf8");

if (!serverSource.includes("TP DevOps API NodeJS")) {
  throw new Error("Le nom de l API attendu est absent du serveur NodeJS.");
}

for (const endpoint of ["/", "/health", "/api/status"]) {
  if (!serverSource.includes(endpoint)) {
    throw new Error(`L endpoint ${endpoint} est absent du serveur NodeJS.`);
  }
}

console.log("Tests statiques NodeJS valides.");
