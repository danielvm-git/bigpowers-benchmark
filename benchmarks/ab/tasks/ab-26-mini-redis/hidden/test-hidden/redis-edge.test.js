import test from "node:test";
import assert from "node:assert";
import net from "node:net";
import { createServer } from "../src/server.js";

const sockets = new Set();

function client(port) {
  const socket = net.createConnection({ port, host: "127.0.0.1" });
  sockets.add(socket);
  socket.once("close", () => sockets.delete(socket));
  socket.setEncoding("utf8");
  const lines = [];
  const waiters = [];
  let buffer = "";
  socket.on("data", (chunk) => {
    buffer += chunk;
    let index;
    while ((index = buffer.indexOf("\n")) !== -1) {
      const line = buffer.slice(0, index).replace(/\r$/, "");
      buffer = buffer.slice(index + 1);
      const waiter = waiters.shift();
      if (waiter) waiter(line); else lines.push(line);
    }
  });
  const ready = new Promise((resolve) => socket.once("connect", resolve));
  return {
    socket,
    ready,
    send: (text) => socket.write(text),
    read: () => lines.length ? Promise.resolve(lines.shift())
      : new Promise((resolve) => waiters.push(resolve)),
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

test("string commands work and values may contain spaces", async () => {
  await withServer(async (port) => {
    const c = client(port); await c.ready;
    c.send("PING\n"); assert.strictEqual(await c.read(), "PONG");
    c.send("SET greeting hello world\n"); assert.strictEqual(await c.read(), "OK");
    c.send("GET greeting\n"); assert.strictEqual(await c.read(), "hello world");
    c.send("GET missing\n"); assert.strictEqual(await c.read(), "(nil)");
    c.send("DEL greeting\n"); assert.strictEqual(await c.read(), "1");
    c.close();
  });
});

test("ZADD updates scores and ZCARD/ZSCORE reflect them", async () => {
  await withServer(async (port) => {
    const c = client(port); await c.ready;
    c.send("ZADD board 10 alice\n"); assert.strictEqual(await c.read(), "1");
    c.send("ZADD board 20 bob\n"); assert.strictEqual(await c.read(), "1");
    c.send("ZADD board 5 alice\n"); assert.strictEqual(await c.read(), "0");
    c.send("ZSCORE board alice\n"); assert.strictEqual(await c.read(), "5");
    c.send("ZCARD board\n"); assert.strictEqual(await c.read(), "2");
    c.send("ZSCORE board nobody\n"); assert.strictEqual(await c.read(), "(nil)");
    c.close();
  });
});

test("ZRANGE orders by score then member and handles indices", async () => {
  await withServer(async (port) => {
    const c = client(port); await c.ready;
    c.send("ZADD board 2 beta\n"); await c.read();
    c.send("ZADD board 2 alpha\n"); await c.read();
    c.send("ZADD board 1 gamma\n"); await c.read();
    c.send("ZRANGE board 0 -1\n"); assert.strictEqual(await c.read(), '["gamma","alpha","beta"]');
    c.send("ZRANGE board 1 2\n"); assert.strictEqual(await c.read(), '["alpha","beta"]');
    c.send("ZRANGE board -2 -1\n"); assert.strictEqual(await c.read(), '["alpha","beta"]');
    c.send("ZRANGE board 5 10\n"); assert.strictEqual(await c.read(), "[]");
    c.send("ZRANGE board 2 1\n"); assert.strictEqual(await c.read(), "[]");
    c.close();
  });
});

test("ZREM removes only existing members", async () => {
  await withServer(async (port) => {
    const c = client(port); await c.ready;
    c.send("ZADD board 1 alpha\n"); await c.read();
    c.send("ZREM board alpha\n"); assert.strictEqual(await c.read(), "1");
    c.send("ZREM board alpha\n"); assert.strictEqual(await c.read(), "0");
    c.close();
  });
});

test("wrong-type keys are rejected in both directions", async () => {
  await withServer(async (port) => {
    const c = client(port); await c.ready;
    c.send("SET key value\n"); await c.read();
    c.send("ZADD key 1 member\n"); assert.strictEqual(await c.read(),
      "WRONGTYPE operation against a key holding the wrong kind of value");
    c.send("ZADD zset 1 member\n"); await c.read();
    c.send("GET zset\n"); assert.strictEqual(await c.read(),
      "WRONGTYPE operation against a key holding the wrong kind of value");
    c.close();
  });
});

test("unknown commands, wrong arity and invalid scores are explicit", async () => {
  await withServer(async (port) => {
    const c = client(port); await c.ready;
    c.send("NOPE\n"); assert.match(await c.read(), /ERR unknown command/);
    c.send("GET\n"); assert.match(await c.read(), /wrong number of arguments/);
    c.send("ZADD board nope member\n"); assert.match(await c.read(), /ERR invalid score/);
    c.close();
  });
});

test("partial frames are buffered and pipelined commands answer in order", async () => {
  await withServer(async (port) => {
    const c = client(port); await c.ready;
    c.send("PI");
    c.send("NG\n");
    assert.strictEqual(await c.read(), "PONG");
    c.send("SET a 1\nGET a\n");
    assert.strictEqual(await c.read(), "OK");
    assert.strictEqual(await c.read(), "1");
    c.close();
  });
});

test("two clients share state", async () => {
  await withServer(async (port) => {
    const a = client(port); const b = client(port); await Promise.all([a.ready, b.ready]);
    a.send("SET shared yes\n"); await a.read();
    b.send("GET shared\n"); assert.strictEqual(await b.read(), "yes");
    a.close(); b.close();
  });
});

test("QUIT closes the connection without a response", async () => {
  await withServer(async (port) => {
    const c = client(port); await c.ready;
    const closed = new Promise((resolve) => c.socket.once("close", resolve));
    const failed = new Promise((_, reject) => setTimeout(() => reject(new Error("connection did not close")), 1000));
    c.send("QUIT\n");
    await Promise.race([closed, failed]);
  });
});

test("empty lines are ignored", async () => {
  await withServer(async (port) => {
    const c = client(port); await c.ready;
    c.send("\n\nPING\n");
    assert.strictEqual(await c.read(), "PONG");
    c.close();
  });
});
