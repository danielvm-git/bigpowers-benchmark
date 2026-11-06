import http from "node:http";
import { matchRoute } from "./router.js";
import { createRepository } from "./items.js";
import { hasUpdateFields, validateItem } from "./validation.js";
import { sendError, sendJson } from "./errors.js";

async function readJson(req) {
  let body = "";
  for await (const chunk of req) body += chunk;
  if (!body) return {};
  try { return JSON.parse(body); } catch { return null; }
}

export function createApp(repo = createRepository()) {
  const routes = [
    { method: "GET", path: "/items", handler: (req, res) => sendJson(res, 200, { items: repo.list() }) },
    { method: "GET", path: "/items/:id", handler: (req, res, params) => {
      const item = repo.get(params.id);
      if (!item) return sendError(res, 404, "not_found", `item not found: ${params.id}`);
      return sendJson(res, 200, item);
    } },
    { method: "POST", path: "/items", handler: async (req, res) => {
      const body = await readJson(req);
      if (body === null) return sendError(res, 400, "invalid_input", "body must be valid JSON");
      const problem = validateItem(body);
      if (problem) return sendError(res, 400, "invalid_input", problem);
      return sendJson(res, 201, repo.create(body));
    } },
    { method: "PATCH", path: "/items/:id", handler: async (req, res, params) => {
      const body = await readJson(req);
      if (body === null) return sendError(res, 400, "invalid_input", "body must be valid JSON");
      if (!hasUpdateFields(body)) return sendError(res, 400, "invalid_input", "no fields to update");
      const problem = validateItem(body, { partial: true });
      if (problem) return sendError(res, 400, "invalid_input", problem);
      const item = repo.update(params.id, body);
      if (!item) return sendError(res, 404, "not_found", `item not found: ${params.id}`);
      return sendJson(res, 200, item);
    } },
  ];

  return http.createServer(async (req, res) => {
    const url = new URL(req.url, "http://localhost");
    const match = matchRoute(routes, req.method, url.pathname);
    if (!match) return sendError(res, 404, "not_found", `route not found: ${req.method} ${url.pathname}`);
    try {
      await match.route.handler(req, res, match.params, repo);
    } catch (error) {
      return sendError(res, 500, "internal_error", "internal server error");
    }
  });
}
