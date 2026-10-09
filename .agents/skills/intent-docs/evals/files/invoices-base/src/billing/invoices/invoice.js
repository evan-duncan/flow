import { InvalidAmount, AlreadyPaid } from "./errors.js";

let nextId = 1;

export function createInvoice({ customerId, amountCents, dueDate }) {
  if (!Number.isInteger(amountCents) || amountCents <= 0) {
    throw new InvalidAmount(amountCents);
  }
  return {
    id: `inv_${nextId++}`,
    customerId,
    amountCents,
    dueDate: new Date(dueDate),
    paidAt: null,
  };
}

export function markPaid(invoice, paidAt) {
  if (invoice.paidAt) throw new AlreadyPaid(invoice.id);
  return { ...invoice, paidAt: new Date(paidAt) };
}
