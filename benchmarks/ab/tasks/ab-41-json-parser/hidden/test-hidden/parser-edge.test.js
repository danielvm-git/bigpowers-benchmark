import test from "node:test";
import assert from "node:assert";
import { parse, ParseError } from "../src/parser.js";

test("parses valid JSON values", () => {
  const cases = [
    ["null", null], ["true", true], ["false", false],
    ["0", 0], ["-0", -0], ["1.5", 1.5], ["1e3", 1000], ["-2.5e-2", -0.025],
    ['"a\\"b\\\\c\\/d\\b\\f\\n\\r\\t"', 'a"b\\c/d\b\f\n\r\t'],
    ['"\\u00e9"', "é"],
    ['"\\ud83d\\ude00"', "😀"],
    ["[]", []], ["{}", {}],
    ['{"a":1,"a":2}', { a: 2 }],
    [' { "a" : [ 1 , true , null ] } ', { a: [1, true, null] }],
  ];
  for (const [text, expected] of cases) assert.deepStrictEqual(parse(text), expected, text);
});

test("rejects invalid syntax with a position", () => {
  const cases = [
    ['{"a":1,}', 7],
    ["[1 2]", 3],
    ['{"a":1} x', 8],
    ['{"a": }', 6],
    ['{a:1}', 1],
    ['"\\x"', 2],
    ['"\\ud800"', 7],
    ['"a\nb"', 2],
    ["01", 1],
    ["+1", 0],
    ["NaN", 0],
    ["[1,]", 3],
    ["", 0],
  ];
  for (const [text, position] of cases) {
    assert.throws(() => parse(text), (error) => {
      assert.ok(error instanceof ParseError, text);
      assert.strictEqual(error.name, "ParseError", text);
      assert.strictEqual(error.position, position, `${text} position`);
      return true;
    }, text);
  }
});

test("valid JSON agrees with JSON.parse", () => {
  const samples = ['{"a":[1,2,{"b":"c"}]}', "[null,true,false,1.5e2]", '"text"'];
  for (const sample of samples) assert.deepStrictEqual(parse(sample), JSON.parse(sample));
});
