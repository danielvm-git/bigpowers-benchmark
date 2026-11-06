import test from "node:test";
import assert from "node:assert";
import net from "node:net";
import { createServer } from "../src/server.js";

function readLine(socket) {
  return new Promise((resolve) => {
    let buffer = "";
    const onData = (chunk) => {
      buffer += chunk;
      const index = buffer.indexOf("\n");
      if (index !== -1) {
        socket.off("data", onData);
        resolve(buffer.slice(0, index).replace(/\r$/, ""));
      }
    };
    socket.on("data", onData);
  });
}

async function withClient(run) {
  const server = createServer();
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const socket = net.createConnection({ port: server.address().port, host: "127.0.0.1" });
  await new Promise((resolve) => socket.once("connect", resolve));
  socket.setEncoding("utf8");
  try { await run(socket); } finally {
    socket.destroy();
    await new Promise((resolve) => server.close(resolve));
  }
}

test("PING, SET, GET and DEL", async () => {
  await withClient(async (socket) => {
    socket.write("PING\n");
    assert.strictEqual(await readLine(socket), "PONG");

    socket.write("SET name Ada\n");
    assert.strictEqual(await readLine(socket), "OK");
    socket.write("GET name\n");
    assert.strictEqual(await readLine(socket), "Ada");
    socket.write("DEL name\n");
    assert.strictEqual(await readLine(socket), "1");
  });
});
