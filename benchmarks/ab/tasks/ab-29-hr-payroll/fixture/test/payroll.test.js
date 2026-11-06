import test from "node:test";
import assert from "node:assert";
import { createEmployee, payrollReport, reset, runPayroll } from "../src/payroll.js";

test("runs payroll for active employees and stores the report", () => {
  reset();
  createEmployee({ id: "E1", name: "Ana", salaryCents: 100000 });
  const report = runPayroll({ period: "2026-01" });
  assert.strictEqual(report.lines.length, 1);
  assert.strictEqual(report.lines[0].employeeId, "E1");
  assert.strictEqual(report.lines[0].grossCents, 100000);
  assert.strictEqual(report.totals.grossCents, 100000);
  assert.deepStrictEqual(payrollReport("2026-01"), report);
});
