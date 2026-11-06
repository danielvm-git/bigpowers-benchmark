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

function create(base, body) {
  return fetch(`${base}/links`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

test("generates unique six-character codes", async () => {
  await withServer(async (base) => {
    const codes = [];
    for (let i = 0; i < 5; i += 1) {
      const res = await create(base, { url: `https://example.com/${i}` });
      assert.strictEqual(res.status, 201);
      codes.push((await res.json()).code);
    }
    for (const code of codes) assert.match(code, /^[A-Za-z0-9]{6}$/);
    assert.strictEqual(new Set(codes).size, codes.length);
  });
});

test("rejects non-http URLs and overlong URLs", async () => {
  await withServer(async (base) => {
    for (const url of ["ftp://example.com", "javascript:alert(1)", "/relative", "not a url"]) {
      const res = await create(base, { url });
      assert.strictEqual(res.status, 400, url);
      assert.strictEqual((await res.json()).error.code, "invalid_url");
    }
    const tooLong = `https://example.com/${"a".repeat(2049)}`;
    const res = await create(base, { url: tooLong });
    assert.strictEqual(res.status, 400);
    assert.strictEqual((await res.json()).error.code, "invalid_url");
  });
});

test("alias length boundaries and collision", async () => {
  await withServer(async (base) => {
    assert.strictEqual((await create(base, { url: "https://example.com", alias: "ab" })).status, 400);
    assert.strictEqual((await create(base, { url: "https://example.com", alias: "abc" })).status, 201);
    assert.strictEqual((await create(base, { url: "https://example.com", alias: "a".repeat(32) })).status, 201);
    assert.strictEqual((await create(base, { url: "https://example.com", alias: "a".repeat(33) })).status, 400);

    const first = await create(base, { url: "https://example.com/one", alias: "docs" });
    assert.strictEqual(first.status, 201);
    const second = await create(base, { url: "https://example.com/two", alias: "docs" });
    assert.strictEqual(second.status, 409);
    assert.strictEqual((await second.json()).error.code, "alias_taken");
    assert.strictEqual((await (await fetch(`${base}/links`)).json()).links.length, 3);
  });
});

test("clicks increment only on redirect", async () => {
  await withServer(async (base) => {
    const created = await (await create(base, { url: "https://example.com/x?y=1#z" })).json();
    await fetch(`${base}/${created.code}`, { redirect: "manual" });
    await fetch(`${base}/${created.code}`, { redirect: "manual" });

    const meta = await (await fetch(`${base}/links/${created.code}`)).json();
    assert.strictEqual(meta.clicks, 2);
    assert.strictEqual(meta.expired, false);

    const redirect = await fetch(`${base}/${created.code}`, { redirect: "manual" });
    assert.strictEqual(redirect.status, 302);
    assert.strictEqual(redirect.headers.get("location"), "https://example.com/x?y=1#z");

    const after = await (await fetch(`${base}/links/${created.code}`)).json();
    assert.strictEqual(after.clicks, 3);
  });
});

test("unknown codes fail consistently", async () => {
  await withServer(async (base) => {
    for (const path of ["/nope", "/links/nope"]) {
      const res = await fetch(`${base}${path}`, { redirect: "manual" });
      assert.strictEqual(res.status, 404, path);
      assert.strictEqual((await res.json()).error.code, "not_found");
    }
    const deleted = await fetch(`${base}/links/nope`, { method: "DELETE" });
    assert.strictEqual(deleted.status, 404);
  });
});

test("expiry is future-only and expired links are 410 on redirect but readable", async () => {
  await withServer(async (base) => {
    const past = await create(base, { url: "https://example.com", expiresAt: "2020-01-01T00:00:00Z" });
    assert.strictEqual(past.status, 400);
    assert.strictEqual((await past.json()).error.code, "invalid_expiry");

    const soon = new Date(Date.now() + 120).toISOString();
    const created = await (await create(base, { url: "https://example.com", alias: "soon", expiresAt: soon })).json();
    assert.strictEqual(created.expired, false);

    await new Promise((resolve) => setTimeout(resolve, 200));
    const redirect = await fetch(`${base}/soon`, { redirect: "manual" });
    assert.strictEqual(redirect.status, 410);
    assert.strictEqual((await redirect.json()).error.code, "expired");

    const meta = await (await fetch(`${base}/links/soon`)).json();
    assert.strictEqual(meta.expired, true);
    assert.strictEqual((await (await fetch(`${base}/links`)).json()).links[0].expired, true);
  });
});

test("delete removes both redirect and metadata", async () => {
  await withServer(async (base) => {
    await create(base, { url: "https://example.com", alias: "gone" });
    assert.strictEqual((await fetch(`${base}/links/gone`, { method: "DELETE" })).status, 204);
    assert.strictEqual((await fetch(`${base}/gone`, { redirect: "manual" })).status, 404);
    assert.strictEqual((await fetch(`${base}/links/gone`)).status, 404);
    assert.strictEqual((await fetch(`${base}/links/gone`, { method: "DELETE" })).status, 404);
  });
});

test("list is ordered and carries the same metadata shape", async () => {
  await withServer(async (base) => {
    await create(base, { url: "https://example.com/1", alias: "one" });
    await create(base, { url: "https://example.com/2", alias: "two" });
    const { links } = await (await fetch(`${base}/links`)).json();
    assert.deepStrictEqual(links.map((link) => link.code), ["one", "two"]);
    for (const key of ["code", "url", "alias", "createdAt", "expiresAt", "clicks", "expired"]) {
      assert.ok(key in links[0], key);
    }
  });
});

test("malformed JSON and unknown routes use the shared error shape", async () => {
  await withServer(async (base) => {
    const bad = await fetch(`${base}/links`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{not json",
    });
    assert.strictEqual(bad.status, 400);
    assert.strictEqual((await bad.json()).error.code, "invalid_input");

    const route = await fetch(`${base}/not/a/route`);
    assert.strictEqual(route.status, 404);
    assert.strictEqual((await route.json()).error.code, "not_found");
  });
});
