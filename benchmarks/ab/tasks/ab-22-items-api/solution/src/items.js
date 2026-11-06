const SEED = [
  { id: 1, name: "Keyboard", priceCents: 4500, quantity: 10 },
  { id: 2, name: "Mouse", priceCents: 2500, quantity: 20 },
];

const EDITABLE = ["name", "priceCents", "quantity"];

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
    update: (id, patch) => {
      const item = rows.find((row) => row.id === Number(id));
      if (!item) return null;
      for (const key of EDITABLE) if (Object.prototype.hasOwnProperty.call(patch, key)) item[key] = patch[key];
      return { ...item };
    },
    reset: () => { rows = items.map((item) => ({ ...item })); nextId = items.reduce((max, item) => Math.max(max, item.id), 0) + 1; },
  };
}
