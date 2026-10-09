Feature: Invoices

  Rule: An invoice amount is a positive whole number of cents

    @decision-1
    Scenario Outline: Invalid amounts are refused (<amount>)
      When a caller creates an invoice for <amount> cents
      Then the call fails with `InvalidAmount`

      Examples:
        | amount |
        | 0      |
        | -100   |
        | 10.5   |

    @decision-1
    Scenario: A valid invoice starts unpaid
      When a caller creates an invoice for 10000 cents
      Then the invoice is not paid

  Rule: A late fee applies only after the grace period

    @decision-2
    Scenario: No fee within the grace period
      Given an unpaid invoice due on 2026-01-01
      When the late fee is asked for as of 2026-01-04
      Then the late fee is 0 cents

    @decision-2 @decision-3
    Scenario: Flat fee once the grace period has passed
      Given an unpaid invoice due on 2026-01-01
      When the late fee is asked for as of 2026-01-05
      Then the late fee is 2500 cents

    @decision-4
    Scenario: Paying on time never produces a fee later
      Given an invoice due on 2026-01-01 and paid on 2026-01-02
      When the late fee is asked for as of 2026-03-01
      Then the late fee is 0 cents

  Rule: An invoice is paid once

    @decision-5
    Scenario: Paying twice is refused
      Given an invoice paid on 2026-01-02
      When a caller marks it paid again
      Then the call fails with `AlreadyPaid`
