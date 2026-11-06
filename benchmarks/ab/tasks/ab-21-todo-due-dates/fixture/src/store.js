import fs from "node:fs";

export function loadState(file) {
  if (!fs.existsSync(file)) return { nextId: 1, todos: [] };
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

export function saveState(file, state) {
  fs.writeFileSync(file, JSON.stringify(state, null, 2));
}
