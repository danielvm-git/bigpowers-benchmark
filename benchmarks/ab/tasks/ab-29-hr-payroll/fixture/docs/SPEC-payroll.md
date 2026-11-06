# Specification: payroll run

## Overview

An in-memory monthly payroll for active employees, with progressive tax, pension, unpaid leave,
duplicate-run protection and a stored report.

## API

- `createEmployee({ id, name, salaryCents, active = true })`
- `runPayroll({ period, leaveDays = {} })`
- `payrollReport(period)`
- `reset()`

## Rules

1. **Period.** `YYYY-MM`, month 01–12. Anything else fails with `invalid_period`.
   A period can be run once; a second run fails with `payroll_already_run: <period>`.
2. **Employees.** `salaryCents` is a non-negative integer; otherwise `invalid_salary`.
   A duplicate id fails with `duplicate_employee: <id>`. Only `active` employees are paid.
3. **Gross.** Start from `salaryCents`. Unpaid leave reduces it proportionally:
   `grossCents = round(salaryCents * (30 - leaveDays) / 30)`.
   Leave must be an integer 0–30; otherwise `invalid_leave: <employeeId>`.
4. **Tax (monthly, progressive).**
   - first 200000 cents: 0%
   - next 200000 cents: 10%
   - above 400000 cents: 20%
   Tax is rounded to the nearest cent.
5. **Pension.** 5% of gross, rounded to the nearest cent.
6. **Net.** `gross - tax - pension`.
7. **Report.** `{ period, lines: [{ employeeId, grossCents, taxCents, pensionCents, netCents }],
   totals: { grossCents, taxCents, pensionCents, netCents } }`.
   Totals equal the sum of the lines.
8. **Lookup.** `payrollReport(period)` returns the stored report; unknown period fails with
   `payroll_not_found: <period>`.

## Invariants

- Existing tests in `test/payroll.test.js` keep passing.
- A failed run stores nothing.
