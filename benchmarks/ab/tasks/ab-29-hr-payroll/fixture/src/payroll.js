const employees = new Map();
const payrolls = new Map();

export function reset() {
  employees.clear();
  payrolls.clear();
}

export function createEmployee({ id, name, salaryCents, active = true }) {
  const employee = { id, name, salaryCents, active };
  employees.set(id, employee);
  return { ...employee };
}

export function runPayroll({ period }) {
  const lines = [...employees.values()]
    .filter((employee) => employee.active)
    .map((employee) => {
      const grossCents = employee.salaryCents;
      const taxCents = Math.round(grossCents * 0.1);
      return {
        employeeId: employee.id,
        grossCents,
        taxCents,
        netCents: grossCents - taxCents,
      };
    });
  const totals = lines.reduce((sum, line) => ({
    grossCents: sum.grossCents + line.grossCents,
    taxCents: sum.taxCents + line.taxCents,
    netCents: sum.netCents + line.netCents,
  }), { grossCents: 0, taxCents: 0, netCents: 0 });
  const report = { period, lines, totals };
  payrolls.set(period, report);
  return report;
}

export function payrollReport(period) {
  return payrolls.get(period);
}
