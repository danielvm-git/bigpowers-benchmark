import test from "node:test";
import assert from "node:assert";
import { createEmployee, payrollReport, reset, runPayroll } from "../src/payroll.js";

function employee(id, salaryCents, active = true) {
  createEmployee({ id, name: id, salaryCents, active });
}

function lineFor(report, id) {
  return report.lines.find((line) => line.employeeId === id);
}

test("progressive tax at the bracket boundaries", () => {
  reset();
  for (const [id, salary] of [["A", 200000], ["B", 210000], ["C", 400000], ["D", 500000]]) {
    employee(id, salary);
  }
  const report = runPayroll({ period: "2026-01" });
  assert.deepStrictEqual(
    [lineFor(report, "A"), lineFor(report, "B"), lineFor(report, "C"), lineFor(report, "D")]
      .map((line) => [line.taxCents, line.pensionCents, line.netCents]),
    [[0, 10000, 190000], [1000, 10500, 198500], [20000, 20000, 360000], [40000, 25000, 435000]],
  );
});

test("unpaid leave prorates gross before tax and pension", () => {
  reset();
  employee("A", 300000);
  const report = runPayroll({ period: "2026-02", leaveDays: { A: 10 } });
  const line = lineFor(report, "A");
  assert.strictEqual(line.grossCents, 200000);
  assert.strictEqual(line.taxCents, 0);
  assert.strictEqual(line.pensionCents, 10000);
  assert.strictEqual(line.netCents, 190000);
});

test("rounding is applied to pension and prorated gross", () => {
  reset();
  employee("A", 33333);
  const report = runPayroll({ period: "2026-03" });
  assert.strictEqual(lineFor(report, "A").pensionCents, 1667);
  assert.strictEqual(lineFor(report, "A").netCents, 31666);

  const prorated = runPayroll({ period: "2026-04", leaveDays: { A: 1 } });
  assert.strictEqual(lineFor(prorated, "A").grossCents, Math.round((33333 * 29) / 30));
});

test("inactive employees are excluded", () => {
  reset();
  employee("A", 100000);
  employee("B", 100000, false);
  const report = runPayroll({ period: "2026-05" });
  assert.deepStrictEqual(report.lines.map((line) => line.employeeId), ["A"]);
});

test("a period can be run only once", () => {
  reset();
  employee("A", 100000);
  const first = runPayroll({ period: "2026-06" });
  assert.throws(() => runPayroll({ period: "2026-06" }),
    { message: "payroll_already_run: 2026-06" });
  assert.deepStrictEqual(payrollReport("2026-06"), first);
});

test("invalid periods, leave and unknown reports fail", () => {
  reset();
  employee("A", 100000);
  for (const period of ["2026-13", "2026-00", "26-01", "2026-1", ""]) {
    assert.throws(() => runPayroll({ period }), { message: "invalid_period" });
  }
  for (const days of [-1, 31, 1.5, "2"]) {
    assert.throws(() => runPayroll({ period: "2026-07", leaveDays: { A: days } }),
      { message: "invalid_leave: A" });
  }
  assert.throws(() => payrollReport("2026-07"), { message: "payroll_not_found: 2026-07" });
});

test("totals equal the sum of the lines", () => {
  reset();
  employee("A", 250000);
  employee("B", 450000);
  const report = runPayroll({ period: "2026-08" });
  const sum = report.lines.reduce((total, line) => ({
    grossCents: total.grossCents + line.grossCents,
    taxCents: total.taxCents + line.taxCents,
    pensionCents: total.pensionCents + line.pensionCents,
    netCents: total.netCents + line.netCents,
  }), { grossCents: 0, taxCents: 0, pensionCents: 0, netCents: 0 });
  assert.deepStrictEqual(report.totals, sum);
});

test("an empty active roster produces a zero report", () => {
  reset();
  employee("A", 100000, false);
  const report = runPayroll({ period: "2026-09" });
  assert.deepStrictEqual(report.lines, []);
  assert.deepStrictEqual(report.totals,
    { grossCents: 0, taxCents: 0, pensionCents: 0, netCents: 0 });
});

test("employee validation", () => {
  reset();
  assert.throws(() => createEmployee({ id: "A", name: "A", salaryCents: -1 }),
    { message: "invalid_salary" });
  employee("A", 100000);
  assert.throws(() => createEmployee({ id: "A", name: "Again", salaryCents: 1 }),
    { message: "duplicate_employee: A" });
});
