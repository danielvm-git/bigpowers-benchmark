import { randomBytes } from "node:crypto";

const links = new Map();
const aliases = new Map();

export function reset() {
  links.clear();
  aliases.clear();
}

export function hasCode(code) {
  return links.has(code);
}

export function hasAlias(alias) {
  return aliases.has(alias);
}

export function createLink({ url, code, alias = null, expiresAt = null }) {
  const link = {
    code,
    url,
    alias,
    createdAt: new Date().toISOString(),
    expiresAt,
    clicks: 0,
  };
  links.set(code, link);
  if (alias) aliases.set(alias, code);
  return { ...link };
}

export function getLink(code) {
  const link = links.get(code);
  return link ? { ...link } : null;
}

export function deleteLink(code) {
  const link = links.get(code);
  if (!link) return false;
  links.delete(code);
  if (link.alias) aliases.delete(link.alias);
  return true;
}

export function listLinks() {
  return [...links.values()].map((link) => ({ ...link }));
}

export function incrementClicks(code) {
  const link = links.get(code);
  if (link) link.clicks += 1;
}

export function generateCode() {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const candidate = randomBytes(5).toString("base64url").replace(/[^A-Za-z0-9]/g, "").slice(0, 6);
    if (candidate.length === 6 && !links.has(candidate)) return candidate;
  }
  throw new Error("could not generate a unique code");
}
