export function settle(entries, config) {
  const { base, rates } = config;
  const byAccount = new Map();
  let totalBaseCents = 0;
  for (const entry of entries) {
    const converted = Math.round((entry.amountCents * rates[entry.currency]) / 10000);
    totalBaseCents += converted;
    byAccount.set(entry.account, (byAccount.get(entry.account) ?? 0) + converted);
  }
  return {
    totalBaseCents,
    byAccount: [...byAccount].map(([account, baseCents]) => ({ account, baseCents }))
      .sort((a, b) => a.account.localeCompare(b.account)),
  };
}
