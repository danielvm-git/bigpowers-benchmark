import test from "node:test";
import assert from "node:assert";
import { parse } from "../src/parser.js";
test("parses a nested value", () => {
  assert.deepStrictEqual(parse('{"a":[1,true,null]}'), { a: [1, true, null] });
});
