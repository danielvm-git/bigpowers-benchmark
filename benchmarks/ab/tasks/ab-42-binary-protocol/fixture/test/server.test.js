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
function readFrame(socket) {
  return new Promise((resolve) => {
    let buffer = Buffer.alloc(0);
    const onData = (chunk) => {
      buffer = Buffer.concat([buffer, chunk]);
      if (buffer.length < 4) return;
      const length = buffer.readUInt32BE(0);
      if (buffer.length < 4 + length) return;
      socket.off("data", onData);
      resolve(JSON.parse(buffer.subarray(4, 4 + length).toString("utf8")));
    };
    socket.on("data", onData);
  });
}
test("set and get over length-prefixed frames", async () => {
  const server = createServer();
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const socket = net.createConnection({ port: server.address().port, host: "127.0.0.1" });
  await new Promise((resolve) => socket.once("connect", resolve));
  try {
    socket.write(frame({ cmd: "set", key: "a", value: 1 }));
    assert.deepStrictEqual(await readFrame(socket), { ok: true });
    socket.write(frame({ cmd: "get", key: "a" }));
    assert.deepStrictEqual(await readFrame(socket), { ok: true, value: 1 });
  } finally {
    socket.destroy();
    await new Promise((resolve) => server.close(resolve));
  }
});
