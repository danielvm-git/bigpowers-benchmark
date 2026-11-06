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

function patch(base, id, body) {
  return fetch(`${base}/items/${id}`, {
    method: "PATCH",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

test("patches one field and leaves the others unchanged", async () => {
  await withServer(async (base) => {
    const res = await patch(base, 1, { name: "Mechanical Keyboard" });
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.name, "Mechanical Keyboard");
    assert.strictEqual(body.priceCents, 4500);
    assert.strictEqual(body.quantity, 10);
  });
});

test("patches price and quantity together", async () => {
  await withServer(async (base) => {
    const res = await patch(base, 2, { priceCents: 3000, quantity: 0 });
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.priceCents, 3000);
    assert.strictEqual(body.quantity, 0);
  });
});

test("unknown id returns not_found", async () => {
  await withServer(async (base) => {
    const res = await patch(base, 99, { name: "Ghost" });
    assert.strictEqual(res.status, 404);
    assert.deepStrictEqual(await res.json(), {
      error: { code: "not_found", message: "item not found: 99" },
    });
  });
});

test("invalid patch values return invalid_input", async () => {
  await withServer(async (base) => {
    for (const body of [{ priceCents: -1 }, { quantity: 1.5 }, { name: "" }]) {
      const res = await patch(base, 1, body);
      assert.strictEqual(res.status, 400, JSON.stringify(body));
      assert.strictEqual((await res.json()).error.code, "invalid_input");
    }
  });
});

test("an empty body and an unknown-only body are rejected", async () => {
  await withServer(async (base) => {
    for (const body of [{}, { sku: "ignored" }]) {
      const res = await patch(base, 1, body);
      assert.strictEqual(res.status, 400);
      assert.deepStrictEqual(await res.json(), {
        error: { code: "invalid_input", message: "no fields to update" },
      });
    }
  });
});

test("unknown fields alongside a valid field are ignored", async () => {
  await withServer(async (base) => {
    const res = await patch(base, 1, { name: "Quiet Keyboard", sku: "ignored" });
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.name, "Quiet Keyboard");
    assert.strictEqual(body.sku, undefined);
  });
});

test("invalid JSON returns the shared error shape", async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/items/1`, {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: "{not json",
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual((await res.json()).error.code, "invalid_input");
  });
});

test("regression: list, get, create and unknown routes", async () => {
  await withServer(async (base) => {
    assert.strictEqual((await (await fetch(`${base}/items`)).json()).items.length, 2);
    assert.strictEqual((await fetch(`${base}/items/1`)).status, 200);
    const created = await fetch(`${base}/items`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ name: "Cable", priceCents: 500, quantity: 5 }),
    });
    assert.strictEqual(created.status, 201);
    const missing = await fetch(`${base}/nope`);
    assert.strictEqual(missing.status, 404);
    assert.strictEqual((await missing.json()).error.code, "not_found");
  });
});
