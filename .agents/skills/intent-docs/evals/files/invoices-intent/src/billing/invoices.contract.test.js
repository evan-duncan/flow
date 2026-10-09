import { test } from "node:test";
import assert from "node:assert/strict";
import { createInvoice, markPaid, lateFee, InvalidAmount, AlreadyPaid } from "./invoices.js";

const invoice = (amountCents = 10000) =>
  createInvoice({ customerId: "cus_1", amountCents, dueDate: "2026-01-01" });

for (const amount of [0, -100, 10.5]) {
  test(`Invalid amounts are refused (<amount>) [amount=${amount}]`, () => {
    assert.throws(() => invoice(amount), InvalidAmount);
  });
}

test("A valid invoice starts unpaid", () => {
  assert.equal(invoice().paidAt, null);
});

test("No fee within the grace period", () => {
  assert.equal(lateFee(invoice(), "2026-01-04"), 0);
});

test("Flat fee once the grace period has passed", () => {
  assert.equal(lateFee(invoice(), "2026-01-05"), 2500);
});

test("Paying on time never produces a fee later", () => {
  const paid = markPaid(invoice(), "2026-01-02");
  assert.equal(lateFee(paid, "2026-03-01"), 0);
});

test("Paying twice is refused", () => {
  const paid = markPaid(invoice(), "2026-01-02");
  assert.throws(() => markPaid(paid, "2026-01-03"), AlreadyPaid);
});
