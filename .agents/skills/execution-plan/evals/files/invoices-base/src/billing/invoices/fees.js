const DAY_MS = 24 * 60 * 60 * 1000;
const GRACE_DAYS = 3;
const FLAT_FEE_CENTS = 2500;

// Whole days past the due date, as of `asOf`.
function daysLate(invoice, asOf) {
  return Math.floor((new Date(asOf) - invoice.dueDate) / DAY_MS);
}

export function lateFee(invoice, asOf) {
  // A paid invoice is judged as of the day it was paid.
  const at = invoice.paidAt ?? new Date(asOf);
  return daysLate(invoice, at) > GRACE_DAYS ? FLAT_FEE_CENTS : 0;
}
