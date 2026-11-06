import test from "node:test";
import assert from "node:assert";
import net from "node:net";
import { createServer } from "../src/server.js";

function frame(value) {
  const body = Buffer.from(JSON.stringify(value));
  const header = Buffer.alloc(4);
  header.writeUInt32BE(body.length, 0);
  return Buffer.concat([header, body]);
}
const sockets = new Set();
function connect(port) {
  const socket = net.createConnection({ port, host: "127.0.0.1" });
  sockets.add(socket);
  socket.once("close", () => sockets.delete(socket));
  const frames = [];
  const waiters = [];
  let buffer = Buffer.alloc(0);
  socket.on("data", (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);
    while (buffer.length >= 4) {
      const length = buffer.readUInt32BE(0);
      if (buffer.length < 4 + length) return;
      const value = JSON.parse(buffer.subarray(4, 4 + length).toString("utf8"));
      buffer = buffer.subarray(4 + length);
      const waiter = waiters.shift();
      if (waiter) waiter(value); else frames.push(value);
    }
  });
  return {
    socket,
    ready: new Promise((resolve) => socket.once("connect", resolve)),
    send: (buffer) => socket.write(buffer),
    read: () => frames.length ? Promise.resolve(frames.shift())
      : new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error("read timeout")), 1000);
        waiters.push((value) => { clearTimeout(timer); resolve(value); });
      }),
    close: () => socket.destroy(),
  };
}
async function withServer(run) {
  const server = createServer();
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const port = server.address().port;
  try { await run(port); } finally {
    for (const socket of sockets) socket.destroy();
    sockets.clear();
    await new Promise((resolve) => server.close(resolve));
  }
}

test("set, get and delete over frames", { timeout: 3000 }, async () => {
  await withServer(async (port) => {
    const c = connect(port); await c.ready;
    c.send(frame({ cmd: "set", key: "a", value: 1 })); assert.deepStrictEqual(await c.read(), { ok: true });
    c.send(frame({ cmd: "get", key: "a" })); assert.deepStrictEqual(await c.read(), { ok: true, value: 1 });
    c.send(frame({ cmd: "del", key: "a" })); assert.deepStrictEqual(await c.read(), { ok: true, removed: true });
    c.send(frame({ cmd: "get", key: "a" })); assert.deepStrictEqual(await c.read(), { ok: true, value: null });
    c.close();
  });
});

test("partial frames are buffered", { timeout: 3000 }, async () => {
  await withServer(async (port) => {
    const c = connect(port); await c.ready;
    const bytes = frame({ cmd: "set", key: "a", value: 1 });
    c.send(bytes.subarray(0, 2));
    await new Promise((resolve) => setTimeout(resolve, 20));
    c.send(bytes.subarray(2, 7));
    await new Promise((resolve) => setTimeout(resolve, 20));
    c.send(bytes.subarray(7));
    assert.deepStrictEqual(await c.read(), { ok: true });
    c.close();
  });
});

test("pipelined frames answer in order", { timeout: 3000 }, async () => {
  await withServer(async (port) => {
    const c = connect(port); await c.ready;
    c.send(Buffer.concat([
      frame({ cmd: "set", key: "a", value: 1 }),
      frame({ cmd: "get", key: "a" }),
      frame({ cmd: "del", key: "a" }),
    ]));
    assert.deepStrictEqual(await c.read(), { ok: true });
    assert.deepStrictEqual(await c.read(), { ok: true, value: 1 });
    assert.deepStrictEqual(await c.read(), { ok: true, removed: true });
    c.close();
  });
});

test("clients share the store", { timeout: 3000 }, async () => {
  await withServer(async (port) => {
    const a = connect(port); const b = connect(port); await Promise.all([a.ready, b.ready]);
    a.send(frame({ cmd: "set", key: "shared", value: "yes" })); await a.read();
    b.send(frame({ cmd: "get", key: "shared" })); assert.deepStrictEqual(await b.read(), { ok: true, value: "yes" });
    a.close(); b.close();
  });
});

test("malformed JSON, unknown commands and invalid requests are explicit", { timeout: 3000 }, async () => {
  await withServer(async (port) => {
    const c = connect(port); await c.ready;
    c.send(frame({ cmd: "nope" })); assert.deepStrictEqual(await c.read(), { ok: false, error: "unknown_command" });
    c.send(frame({ cmd: "get" })); assert.deepStrictEqual(await c.read(), { ok: false, error: "invalid_request" });
    const bad = Buffer.from("{not json");
    const header = Buffer.alloc(4); header.writeUInt32BE(bad.length, 0);
    c.send(Buffer.concat([header, bad]));
    assert.deepStrictEqual(await c.read(), { ok: false, error: "invalid_json" });
    c.close();
  });
});

test("oversized frames are rejected and the connection closes", { timeout: 3000 }, async () => {
  await withServer(async (port) => {
    const c = connect(port); await c.ready;
    const header = Buffer.alloc(4);
    header.writeUInt32BE(1024 * 1024 + 1, 0);
    const closed = new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error("close timeout")), 1000);
      c.socket.once("close", () => { clearTimeout(timer); resolve(); });
    });
    c.send(header);
    assert.deepStrictEqual(await c.read(), { ok: false, error: "frame_too_large" });
    await closed;
  });
});

test("quit closes without a response", { timeout: 3000 }, async () => {
  await withServer(async (port) => {
    const c = connect(port); await c.ready;
    const closed = new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error("close timeout")), 1000);
      c.socket.once("close", () => { clearTimeout(timer); resolve(); });
    });
    c.send(frame({ cmd: "quit" }));
    await closed;
  });
});
