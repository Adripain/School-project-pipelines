const http = require("http");

const port = Number(process.env.PORT || 3000);

function sendJson(res, statusCode, payload) {
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  });
  res.end(JSON.stringify(payload, null, 2));
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);

  if (req.method === "GET" && url.pathname === "/") {
    return sendJson(res, 200, {
      name: "TP DevOps API NodeJS",
      message: "API NodeJS deployee avec Jenkins, DockerHub et Docker Compose.",
      endpoints: ["/", "/health", "/api/status"],
    });
  }

  if (req.method === "GET" && url.pathname === "/health") {
    return sendJson(res, 200, {
      status: "ok",
      service: "tp-devops-api",
      timestamp: new Date().toISOString(),
    });
  }

  if (req.method === "GET" && url.pathname === "/api/status") {
    return sendJson(res, 200, {
      project: "School-project-pipelines",
      stack: ["NodeJS", "Docker", "DockerHub", "Jenkins", "Docker Compose"],
      deployed: true,
    });
  }

  return sendJson(res, 404, {
    error: "Not Found",
    path: url.pathname,
  });
});

server.listen(port, "0.0.0.0", () => {
  console.log(`TP DevOps API NodeJS listening on port ${port}`);
});
