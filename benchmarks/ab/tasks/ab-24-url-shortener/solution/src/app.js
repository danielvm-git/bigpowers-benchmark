import http from "node:http";
import { sendError, sendJson } from "./errors.js";
import {
  createLink, deleteLink, generateCode, getLink, hasAlias, incrementClicks, listLinks, reset,
} from "./store.js";
import { isValidAlias, isValidExpiry, isValidUrl } from "./validate.js";

async function readJson(req) {
  let body = "";
  for await (const chunk of req) body += chunk;
  if (!body) return {};
  try { return JSON.parse(body); } catch { return null; }
}

function meta(link) {
  return {
    ...link,
    expired: Boolean(link.expiresAt && Date.parse(link.expiresAt) <= Date.now()),
  };
}

export function createApp() {
  return http.createServer(async (req, res) => {
    const url = new URL(req.url, "http://localhost");
    const parts = url.pathname.split("/").filter(Boolean);

    if (req.method === "POST" && url.pathname === "/links") {
      const body = await readJson(req);
      if (body === null) return sendError(res, 400, "invalid_input", "body must be valid JSON");
      if (!isValidUrl(body.url)) return sendError(res, 400, "invalid_url", "url must be an absolute http or https URL");
      if (body.alias !== undefined && !isValidAlias(body.alias)) {
        return sendError(res, 400, "invalid_alias", "alias must match [A-Za-z0-9_-]{3,32}");
      }
      if (body.alias && hasAlias(body.alias)) {
        return sendError(res, 409, "alias_taken", `alias already in use: ${body.alias}`);
      }
      if (body.expiresAt !== undefined && !isValidExpiry(body.expiresAt)) {
        return sendError(res, 400, "invalid_expiry", "expiresAt must be a future ISO-8601 date");
      }
      const code = body.alias || generateCode();
      const link = createLink({ url: body.url, code, alias: body.alias ?? null, expiresAt: body.expiresAt ?? null });
      return sendJson(res, 201, meta(link));
    }

    if (req.method === "GET" && url.pathname === "/links") {
      return sendJson(res, 200, { links: listLinks().map(meta) });
    }

    if (req.method === "GET" && parts.length === 2 && parts[0] === "links") {
      const link = getLink(parts[1]);
      if (!link) return sendError(res, 404, "not_found", `link not found: ${parts[1]}`);
      return sendJson(res, 200, meta(link));
    }

    if (req.method === "DELETE" && parts.length === 2 && parts[0] === "links") {
      if (!deleteLink(parts[1])) return sendError(res, 404, "not_found", `link not found: ${parts[1]}`);
      res.writeHead(204);
      return res.end();
    }

    if (req.method === "GET" && parts.length === 1) {
      const link = getLink(parts[0]);
      if (!link) return sendError(res, 404, "not_found", `link not found: ${parts[0]}`);
      if (link.expiresAt && Date.parse(link.expiresAt) <= Date.now()) {
        return sendError(res, 410, "expired", `link expired: ${parts[0]}`);
      }
      incrementClicks(link.code);
      res.writeHead(302, { location: link.url });
      return res.end();
    }

    return sendError(res, 404, "not_found", `route not found: ${req.method} ${url.pathname}`);
  });
}

export { reset };
