import net from "node:net";

export function createStore() {
  return { strings: new Map(), zsets: new Map() };
}

function wrongType() {
  return "WRONGTYPE operation against a key holding the wrong kind of value";
}

function arity(command) {
  return `ERR wrong number of arguments for '${command}'`;
}

function parseScore(value) {
  if (!/^\d+$/.test(value)) return null;
  const score = Number(value);
  return Number.isSafeInteger(score) ? score : null;
}

function parseIndex(value) {
  if (!/^-?\d+$/.test(value)) return null;
  return Number(value);
}

function handle(store, line) {
  const parts = line.trim().split(/\s+/);
  const command = parts[0]?.toUpperCase();

  if (command === "PING") {
    return { response: parts.length === 1 ? "PONG" : arity("PING") };
  }
  if (command === "SET") {
    if (parts.length < 3) return { response: arity("SET") };
    if (store.zsets.has(parts[1])) return { response: wrongType() };
    store.strings.set(parts[1], parts.slice(2).join(" "));
    return { response: "OK" };
  }
  if (command === "GET") {
    if (parts.length !== 2) return { response: arity("GET") };
    if (store.zsets.has(parts[1])) return { response: wrongType() };
    return { response: store.strings.get(parts[1]) ?? "(nil)" };
  }
  if (command === "DEL") {
    if (parts.length !== 2) return { response: arity("DEL") };
    const removed = store.strings.delete(parts[1]) || store.zsets.delete(parts[1]);
    return { response: removed ? "1" : "0" };
  }
  if (command === "ZADD") {
    if (parts.length !== 4) return { response: arity("ZADD") };
    if (store.strings.has(parts[1])) return { response: wrongType() };
    const score = parseScore(parts[2]);
    if (score === null) return { response: `ERR invalid score: ${parts[2]}` };
    const set = store.zsets.get(parts[1]) ?? new Map();
    const exists = set.has(parts[3]);
    set.set(parts[3], score);
    store.zsets.set(parts[1], set);
    return { response: exists ? "0" : "1" };
  }
  if (command === "ZSCORE") {
    if (parts.length !== 3) return { response: arity("ZSCORE") };
    if (store.strings.has(parts[1])) return { response: wrongType() };
    const score = store.zsets.get(parts[1])?.get(parts[2]);
    return { response: score === undefined ? "(nil)" : String(score) };
  }
  if (command === "ZRANGE") {
    if (parts.length !== 4) return { response: arity("ZRANGE") };
    if (store.strings.has(parts[1])) return { response: wrongType() };
    const start = parseIndex(parts[2]);
    const stop = parseIndex(parts[3]);
    if (start === null || stop === null) return { response: `ERR invalid range: ${parts[2]} ${parts[3]}` };
    const members = [...(store.zsets.get(parts[1]) ?? new Map()).entries()]
      .sort(([memberA, scoreA], [memberB, scoreB]) => scoreA - scoreB || memberA.localeCompare(memberB))
      .map(([member]) => member);
    const length = members.length;
    const from = start < 0 ? Math.max(length + start, 0) : Math.min(start, length);
    const to = stop < 0 ? length + stop : Math.min(stop, length - 1);
    return { response: JSON.stringify(from > to ? [] : members.slice(from, to + 1)) };
  }
  if (command === "ZREM") {
    if (parts.length !== 3) return { response: arity("ZREM") };
    if (store.strings.has(parts[1])) return { response: wrongType() };
    const removed = store.zsets.get(parts[1])?.delete(parts[2]) ?? false;
    return { response: removed ? "1" : "0" };
  }
  if (command === "ZCARD") {
    if (parts.length !== 2) return { response: arity("ZCARD") };
    if (store.strings.has(parts[1])) return { response: wrongType() };
    return { response: String(store.zsets.get(parts[1])?.size ?? 0) };
  }
  if (command === "QUIT") {
    if (parts.length !== 1) return { response: arity("QUIT") };
    return { close: true };
  }
  return { response: `ERR unknown command: ${parts[0]}` };
}

export function createServer(store = createStore()) {
  return net.createServer((socket) => {
    let buffer = "";
    socket.setEncoding("utf8");
    socket.on("data", (chunk) => {
      buffer += chunk;
      let newline;
      while ((newline = buffer.indexOf("\n")) !== -1) {
        const line = buffer.slice(0, newline).replace(/\r$/, "");
        buffer = buffer.slice(newline + 1);
        if (!line.trim()) continue;
        const result = handle(store, line);
        if (result.close) {
          socket.end();
          return;
        }
        socket.write(`${result.response}\n`);
      }
    });
  });
}
