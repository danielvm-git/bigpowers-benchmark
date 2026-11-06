const links = new Map();
let created = 0;

export function reset() {
  links.clear();
  created = 0;
}

export function createLink({ url, code }) {
  const link = { code, url, createdAt: new Date().toISOString(), clicks: 0 };
  links.set(code, link);
  created += 1;
  return { ...link };
}

export function getLink(code) {
  return links.get(code) || null;
}

export function deleteLink(code) {
  return links.delete(code);
}

export function listLinks() {
  return [...links.values()].map((link) => ({ ...link }));
}
