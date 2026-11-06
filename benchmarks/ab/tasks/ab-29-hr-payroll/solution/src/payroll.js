const employees = new Map();
const payrolls = new Map();

export function reset() {
  employees.clear();
  payrolls.clear();
}

function fail(code) {
  throw new Error(code);
}

function taxFor(grossCents) {
  const middle = Math.min(Math.max(grossCents - 200000, 0), 200000) * 0.10;
  const top = Math.max(grossCents - 400000, 0) * 0.20;
  return Math.round(middle + top);
}

export function createEmployee({ id, name, salaryCents, active = true }) {
  if (typeof id !== "string" || !id) fail("invalid_employee_id");
  if (employees.has(id)) fail(`duplicate_employee: ${id}`);
  if (!Number.isInteger(salaryCents) || salaryCents < 0) fail("invalid_salary");
  const employee = { id, name, salaryCents, active: Boolean(active) };
  employees.set(id, employee);
  return { ...employee };
}

export function runPayroll({ period, leaveDays = {} }) {
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(period || "")) fail("invalid_period");
  if (payrolls.has(period)) fail(`payroll_already_run: ${period}`);

  const lines = [];
  for (const employee of employees.values()) {
    if (!employee.active) continue;
    const days = leaveDays[employee.id] ?? 0;
    if (!Number.isInteger(days) || days < 0 || days > 30) fail(`invalid_leave: ${employee.id}`);
    const grossCents = Math.round((employee.salaryCents * (30 - days)) / 30);
    const taxCents = taxFor(grossCents);
    const pensionCents = Math.round(grossCents * 0.05);
    lines.push({
      employeeId: employee.id,
      grossCents,
      taxCents,
      pensionCents,
      netCents: grossCents - taxCents - pensionCents,
    });
  }

  const totals = lines.reduce((sum, line) => ({
    grossCents: sum.grossCents + line.grossCents,
    taxCents: sum.taxCents + line.taxCents,
    pensionCents: sum.pensionCents + line.pensionCents,
    netCents: sum.netCents + line.netCents,
  }), { grossCents: 0, taxCents: 0, pensionCents: 0, netCents: 0 });

  const report = { period, lines, totals };
  payrolls.set(period, report);
  return { period, lines: lines.map((line) => ({ ...line })), totals: { ...totals } };
}

export function payrollReport(period) {
  const report = payrolls.get(period);
  if (!report) fail(`payroll_not_found: ${period}`);
  return { period: report.period, lines: report.lines.map((line) => ({ ...line })), totals: { ...report.totals } };
}
