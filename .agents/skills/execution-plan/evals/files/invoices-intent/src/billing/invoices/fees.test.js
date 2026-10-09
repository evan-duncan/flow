import { test } from "node:test";
import assert from "node:assert/strict";
import { lateFee } from "./fees.js";

const inv = (paidAt = null) => ({ dueDate: new Date("2026-01-01"), paidAt });

test("no fee inside grace period", () => {
  assert.equal(lateFee(inv(), "2026-01-04"), 0);
});

test("flat fee after grace period", () => {
  assert.equal(lateFee(inv(), "2026-01-05"), 2500);
});

test("paid on time stays fee-free later", () => {
  assert.equal(lateFee(inv(new Date("2026-01-02")), "2026-03-01"), 0);
});
