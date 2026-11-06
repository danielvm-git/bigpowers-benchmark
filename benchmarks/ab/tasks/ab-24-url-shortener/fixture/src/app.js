import http from "node:http";
import { sendError, sendJson } from "./errors.js";
import { createLink, deleteLink, getLink, listLinks, reset } from "./store.js";

async function readJson(req) {
  let body = "";
  for await (const chunk of req) body += chunk;
  if (!body) return {};
  try { return JSON.parse(body); } catch { return null; }
}

function code() {
  return Math.random().toString(36).slice(2, 8);
}

export function createApp() {
  return http.createServer(async (req, res) => {
    const url = new URL(req.url, "http://localhost");
    const parts = url.pathname.split("/").filter(Boolean);

    if (req.method === "POST" && url.pathname === "/links") {
      const body = await readJson(req);
      if (body === null) return sendError(res, 400, "invalid_input", "body must be valid JSON");
      if (typeof body.url !== "string") return sendError(res, 400, "invalid_url", "url is required");
      const link = createLink({ url: body.url, code: body.alias || code() });
      return sendJson(res, 201, link);
    }

    if (req.method === "GET" && url.pathname === "/links") {
      return sendJson(res, 200, { links: listLinks() });
    }

    if (req.method === "GET" && parts.length === 2 && parts[0] === "links") {
      const link = getLink(parts[1]);
      if (!link) return sendError(res, 404, "not_found", `link not found: ${parts[1]}`);
      return sendJson(res, 200, link);
    }

    if (req.method === "DELETE" && parts.length === 2 && parts[0] === "links") {
      if (!deleteLink(parts[1])) return sendError(res, 404, "not_found", `link not found: ${parts[1]}`);
      res.writeHead(204);
      return res.end();
    }

    if (req.method === "GET" && parts.length === 1) {
      const link = getLink(parts[0]);
      if (!link) return sendError(res, 404, "not_found", `link not found: ${parts[0]}`);
      res.writeHead(302, { location: link.url });
      return res.end();
    }

    return sendError(res, 404, "not_found", `route not found: ${req.method} ${url.pathname}`);
  });
}

export { reset };
