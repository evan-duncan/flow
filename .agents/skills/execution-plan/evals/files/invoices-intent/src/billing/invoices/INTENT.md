# Invoices

Follows the intent-docs skill.

## Purpose

Customers are billed with invoices that have an amount and a due date.
Finance needs to know when an invoice has been paid and what late fee, if
any, the customer owes, so that late payment is discouraged without
penalising customers who are only a few days behind.

## Glossary

- **Invoice**: a bill for one customer, with an amount in cents and a due
  date.
- **Paid**: an invoice that has a payment date recorded.
- **Days late**: whole days between the due date and the day the invoice
  is judged. A paid invoice is judged as of its payment date; an unpaid
  one as of the day asked about.
- **Grace period**: the number of days late an invoice may be before a
  late fee applies.
- **Late fee**: the amount in cents owed on top of the invoice amount.

## Public surface

`src/billing/invoices.js` exports:

- `createInvoice`: creates an unpaid invoice for a customer, amount and
  due date.
- `markPaid`: records the payment date on an invoice.
- `lateFee`: the late fee owed on an invoice as of a given day.
- `InvalidAmount`, `AlreadyPaid`: the errors callers can catch.

## Decisions

| Id | Decision | Rejected alternative | Why |
| --- | --- | --- | --- |
| decision-1 | Amounts are positive whole cents. | Decimal currency amounts. | Whole cents can't carry rounding errors into totals. |
| decision-2 | The grace period is 3 days. | No grace period. | Payments made over a weekend shouldn't be penalised. |
| decision-3 | The late fee is a flat 2500 cents. | A percentage of the amount. | Finance wanted a fee customers can predict. |
| decision-4 | A paid invoice is judged as of its payment date. | Judging every invoice as of the day asked about. | Paying on time must never produce a fee later. |
| decision-5 | Paying an already-paid invoice is an error. | Silently keeping the first payment date. | A double payment points to a bug the caller should see. |

## Non-goals

- Currencies, taxes and discounts.
- Partial payments.
- Persisting invoices.

## Acceptance

- `src/billing/invoices/invoices.feature`
- `src/billing/invoices.contract.test.js`
