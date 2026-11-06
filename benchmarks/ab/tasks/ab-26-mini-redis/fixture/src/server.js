import net from "node:net";

export function createStore() {
  return { strings: new Map() };
}

function handle(store, line) {
  const parts = line.trim().split(/\s+/);
  const command = parts[0]?.toUpperCase();
  if (command === "PING") return "PONG";
  if (command === "SET") {
    store.strings.set(parts[1], parts.slice(2).join(" "));
    return "OK";
  }
  if (command === "GET") return store.strings.get(parts[1]) ?? "(nil)";
  if (command === "DEL") return store.strings.delete(parts[1]) ? "1" : "0";
  return `ERR unknown command: ${command}`;
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
        if (line.trim()) socket.write(`${handle(store, line)}\n`);
      }
    });
  });
}
