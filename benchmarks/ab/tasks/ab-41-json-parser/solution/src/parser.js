export class ParseError extends Error {
  constructor(message, position) {
    super(message);
    this.name = "ParseError";
    this.position = position;
  }
}

const ESCAPES = { '"': '"', "\\": "\\", "/": "/", b: "\b", f: "\f", n: "\n", r: "\r", t: "\t" };
const NUMBER = /^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/;

export function parse(text) {
  if (typeof text !== "string") throw new ParseError("Input must be a string", 0);
  let i = 0;
  const length = text.length;
  const fail = (message, position = i) => { throw new ParseError(message, position); };
  const skip = () => { while (i < length && /[ \t\n\r]/.test(text[i])) i += 1; };

  function string() {
    i += 1;
    let out = "";
    while (i < length) {
      const char = text[i];
      if (char === '"') { i += 1; return out; }
      if (char === "\\") {
        i += 1;
        const escape = text[i];
        if (escape === "u") {
          const hex = text.slice(i + 1, i + 5);
          if (!/^[0-9a-fA-F]{4}$/.test(hex)) fail("Invalid unicode escape", i);
          let code = parseInt(hex, 16);
          i += 5;
          if (code >= 0xd800 && code <= 0xdbff) {
            if (text[i] !== "\\" || text[i + 1] !== "u") fail("Unpaired surrogate", i);
            const lowHex = text.slice(i + 2, i + 6);
            if (!/^[0-9a-fA-F]{4}$/.test(lowHex)) fail("Invalid unicode escape", i + 2);
            const low = parseInt(lowHex, 16);
            if (low < 0xdc00 || low > 0xdfff) fail("Unpaired surrogate", i);
            code = 0x10000 + ((code - 0xd800) << 10) + (low - 0xdc00);
            i += 6;
          } else if (code >= 0xdc00 && code <= 0xdfff) {
            fail("Unpaired surrogate", i - 6);
          }
          out += String.fromCodePoint(code);
        } else if (escape in ESCAPES) {
          out += ESCAPES[escape]; i += 1;
        } else {
          fail(`Invalid escape '\\${escape}'`, i);
        }
      } else {
        if (char.charCodeAt(0) < 0x20) fail("Unescaped control character", i);
        out += char; i += 1;
      }
    }
    fail("Unterminated string", length);
  }

  function number() {
    const match = NUMBER.exec(text.slice(i));
    if (!match) fail("Invalid number", i);
    i += match[0].length;
    return Number(match[0]);
  }

  function literal(word, value) {
    if (text.slice(i, i + word.length) !== word) fail(`Unexpected token '${text[i]}'`, i);
    i += word.length;
    return value;
  }

  function array() {
    i += 1; skip();
    const out = [];
    if (text[i] === "]") { i += 1; return out; }
    while (true) {
      out.push(value()); skip();
      if (text[i] === "]") { i += 1; return out; }
      if (text[i] !== ",") fail(`Expected ',' or ']'`, i);
      i += 1; skip();
    }
  }

  function object() {
    i += 1; skip();
    const out = {};
    if (text[i] === "}") { i += 1; return out; }
    while (true) {
      if (text[i] !== '"') fail("Expected a string key", i);
      const key = string(); skip();
      if (text[i] !== ":") fail("Expected ':'", i);
      i += 1; skip();
      out[key] = value(); skip();
      if (text[i] === "}") { i += 1; return out; }
      if (text[i] !== ",") fail(`Expected ',' or '}'`, i);
      i += 1; skip();
    }
  }

  function value() {
    skip();
    if (i >= length) fail("Unexpected end of input", length);
    const char = text[i];
    if (char === '"') return string();
    if (char === "{") return object();
    if (char === "[") return array();
    if (char === "t") return literal("true", true);
    if (char === "f") return literal("false", false);
    if (char === "n") return literal("null", null);
    if (char === "-" || (char >= "0" && char <= "9")) return number();
    fail(`Unexpected character '${char}'`, i);
  }

  const result = value();
  skip();
  if (i !== length) fail(`Unexpected trailing content '${text[i]}'`, i);
  return result;
}
