export function sendJson(res, status, body) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

export function sendError(res, status, code, message) {
  sendJson(res, status, { error: { code, message } });
}
