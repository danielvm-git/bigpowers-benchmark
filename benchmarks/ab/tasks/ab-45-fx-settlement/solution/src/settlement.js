function fail(code) { throw new Error(code); }
function convert(amountCents, rate) {
  const scaled = amountCents * rate;
  const rounded = Math.floor(Math.abs(scaled) / 10000 + 0.5);
  return scaled < 0 ? -rounded : rounded;
}
export function settle(entries, config) {
  const { base, rates } = config;
  if (rates[base] !== 10000) fail("invalid_base_rate");
  for (const [currency, rate] of Object.entries(rates)) {
    if (!Number.isInteger(rate) || rate <= 0) fail(`invalid_rate: ${currency}`);
  }
  const byAccount = new Map(); let totalBaseCents = 0;
  for (const entry of entries) {
    if (!Number.isInteger(entry.amountCents)) fail("invalid_amount");
    const rate = rates[entry.currency];
    if (rate === undefined) fail(`unknown_rate: ${entry.currency}`);
    const converted = convert(entry.amountCents, rate);
    totalBaseCents += converted;
    byAccount.set(entry.account, (byAccount.get(entry.account) ?? 0) + converted);
  }
  return {
    totalBaseCents,
    byAccount: [...byAccount].map(([account, baseCents]) => ({ account, baseCents }))
      .sort((a, b) => a.account.localeCompare(b.account)),
  };
}
