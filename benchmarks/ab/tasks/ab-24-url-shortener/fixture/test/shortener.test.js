import test from "node:test";
import assert from "node:assert";
import { createApp, reset } from "../src/app.js";

async function withServer(run) {
  reset();
  const server = createApp();
  await new Promise((resolve) => server.listen(0, resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try { await run(base); } finally { await new Promise((resolve) => server.close(resolve)); }
}

test("creates a short link and redirects", async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/links`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ url: "https://example.com/a?b=1#c" }),
    });
    assert.strictEqual(res.status, 201);
    const link = await res.json();
    assert.match(link.code, /^[A-Za-z0-9]{6}$/);

    const redirect = await fetch(`${base}/${link.code}`, { redirect: "manual" });
    assert.strictEqual(redirect.status, 302);
    assert.strictEqual(redirect.headers.get("location"), "https://example.com/a?b=1#c");
  });
});

test("returns metadata and deletes a link", async () => {
  await withServer(async (base) => {
    const created = await fetch(`${base}/links`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ url: "https://example.com", alias: "docs" }),
    });
    assert.strictEqual(created.status, 201);

    const meta = await fetch(`${base}/links/docs`);
    assert.strictEqual(meta.status, 200);
    assert.strictEqual((await meta.json()).url, "https://example.com");

    const deleted = await fetch(`${base}/links/docs`, { method: "DELETE" });
    assert.strictEqual(deleted.status, 204);
    assert.strictEqual((await fetch(`${base}/links/docs`)).status, 404);
  });
});
