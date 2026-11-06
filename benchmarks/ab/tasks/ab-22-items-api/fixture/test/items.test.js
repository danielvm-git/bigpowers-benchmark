import test from "node:test";
import assert from "node:assert";
import { createApp } from "../src/app.js";
import { createRepository } from "../src/items.js";

async function withServer(run) {
  const repo = createRepository();
  const server = createApp(repo);
  await new Promise((resolve) => server.listen(0, resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try { await run(base, repo); } finally { await new Promise((resolve) => server.close(resolve)); }
}

test("lists items", async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/items`);
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.items.length, 2);
  });
});

test("gets one item and returns the shared not-found shape", async () => {
  await withServer(async (base) => {
    const found = await fetch(`${base}/items/1`);
    assert.strictEqual(found.status, 200);
    assert.strictEqual((await found.json()).name, "Keyboard");

    const missing = await fetch(`${base}/items/99`);
    assert.strictEqual(missing.status, 404);
    assert.deepStrictEqual(await missing.json(), { error: { code: "not_found", message: "item not found: 99" } });
  });
});

test("creates an item", async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/items`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ name: "Cable", priceCents: 500, quantity: 5 }),
    });
    assert.strictEqual(res.status, 201);
    assert.strictEqual((await res.json()).name, "Cable");
  });
});

test("rejects invalid input with the shared error shape", async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/items`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ name: "", priceCents: -1, quantity: 1 }),
    });
    assert.strictEqual(res.status, 400);
    const body = await res.json();
    assert.strictEqual(body.error.code, "invalid_input");
    assert.match(body.error.message, /name/);
  });
});
