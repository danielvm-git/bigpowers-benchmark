import net from "node:net";
const MAX_FRAME = 1024 * 1024;
export function createStore() { return new Map(); }
function send(socket, value) {
  const body = Buffer.from(JSON.stringify(value));
  const header = Buffer.alloc(4);
  header.writeUInt32BE(body.length, 0);
  socket.write(Buffer.concat([header, body]));
}
function handle(store, message) {
  if (!message || typeof message !== "object") return { ok: false, error: "invalid_request" };
  if (message.cmd === "set") {
    if (typeof message.key !== "string") return { ok: false, error: "invalid_request" };
    store.set(message.key, message.value);
    return { ok: true };
  }
  if (message.cmd === "get") {
    if (typeof message.key !== "string") return { ok: false, error: "invalid_request" };
    return { ok: true, value: store.has(message.key) ? store.get(message.key) : null };
  }
  if (message.cmd === "del") {
    if (typeof message.key !== "string") return { ok: false, error: "invalid_request" };
    return { ok: true, removed: store.delete(message.key) };
  }
  if (message.cmd === "quit") return { close: true };
  return { ok: false, error: "unknown_command" };
}
export function createServer(store = createStore()) {
  return net.createServer((socket) => {
    let buffer = Buffer.alloc(0);
    socket.on("data", (chunk) => {
      buffer = Buffer.concat([buffer, chunk]);
      while (buffer.length >= 4) {
        const length = buffer.readUInt32BE(0);
        if (length > MAX_FRAME) {
          send(socket, { ok: false, error: "frame_too_large" });
          socket.end();
          buffer = Buffer.alloc(0);
          return;
        }
        if (buffer.length < 4 + length) return;
        const body = buffer.subarray(4, 4 + length).toString("utf8");
        buffer = buffer.subarray(4 + length);
        let message;
        try { message = JSON.parse(body); } catch {
          send(socket, { ok: false, error: "invalid_json" });
          continue;
        }
        const response = handle(store, message);
        if (response.close) { socket.end(); return; }
        send(socket, response);
      }
    });
  });
}
