import test from "node:test";
import assert from "node:assert";
import { resetAccounts } from "../src/accounts.js";
import { registerAlias, listAliases, resetAliases } from "../src/alias.js";

test.beforeEach(() => {
  resetAccounts();
  resetAliases();
});

test("accepts a valid CNPJ and rejects a bad check digit and repeated digits", () => {
  const alias = registerAlias("ACC-002", "cnpj", "11222333000181");
  assert.strictEqual(alias.key, "11222333000181");

  assert.throws(() => registerAlias("ACC-002", "cnpj", "11222333000180"),
                { message: /invalid cnpj key/ });
  assert.throws(() => registerAlias("ACC-002", "cnpj", "11111111111111"),
                { message: /invalid cnpj key/ });
});

test("rejects malformed phone, email and EVP keys", () => {
  assert.throws(() => registerAlias("ACC-001", "phone", "5511987654321"),
                { message: /invalid phone key/ });
  assert.throws(() => registerAlias("ACC-001", "phone", "+12"),
                { message: /invalid phone key/ });
  assert.throws(() => registerAlias("ACC-001", "email", "user@example"),
                { message: /invalid email key/ });
  assert.throws(() => registerAlias("ACC-001", "evp", "not-a-uuid"),
                { message: /invalid evp key/ });
});

test("rejects an unsupported key type", () => {
  assert.throws(() => registerAlias("ACC-001", "pix", "anything"),
                { message: "unsupported key type: pix" });
});

test("rejects an unknown account before registering anything", () => {
  assert.throws(() => registerAlias("ACC-999", "email", "a@example.com"),
                { message: "account not found: ACC-999" });
  assert.strictEqual(listAliases("ACC-999").length, 0);
});

test("business accounts allow 20 aliases and reject the 21st", () => {
  for (let i = 1; i <= 20; i++) {
    registerAlias("ACC-002", "email", `biz${i}@example.com`);
  }
  assert.strictEqual(listAliases("ACC-002").length, 20);
  assert.throws(() => registerAlias("ACC-002", "email", "biz21@example.com"),
                { message: /max 20 aliases for business account/ });
});

test("a rejected registration does not consume a quota slot", () => {
  assert.throws(() => registerAlias("ACC-001", "cpf", "52998224724"),
                { message: /invalid cpf key/ });
  assert.strictEqual(listAliases("ACC-001").length, 0);
  registerAlias("ACC-001", "email", "first@example.com");
  assert.strictEqual(listAliases("ACC-001").length, 1);
});
