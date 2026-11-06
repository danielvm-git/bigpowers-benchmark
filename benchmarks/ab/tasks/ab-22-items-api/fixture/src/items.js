const SEED = [
  { id: 1, name: "Keyboard", priceCents: 4500, quantity: 10 },
  { id: 2, name: "Mouse", priceCents: 2500, quantity: 20 },
];

export function createRepository(items = SEED) {
  let nextId = items.reduce((max, item) => Math.max(max, item.id), 0) + 1;
  let rows = items.map((item) => ({ ...item }));

  return {
    list: () => rows.map((item) => ({ ...item })),
    get: (id) => {
      const item = rows.find((row) => row.id === Number(id));
      return item ? { ...item } : null;
    },
    create: (input) => {
      const item = { id: nextId++, name: input.name, priceCents: input.priceCents, quantity: input.quantity };
      rows.push(item);
      return { ...item };
    },
    reset: () => { rows = items.map((item) => ({ ...item })); nextId = items.reduce((max, item) => Math.max(max, item.id), 0) + 1; },
  };
}
