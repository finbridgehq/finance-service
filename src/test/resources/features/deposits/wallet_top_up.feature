@US14
Feature: Wallet top-up
  As an investor
  I want to add funds to my wallet
  So that I have capital available to invest in invoices

  Background:
    Given an investor account "0198a3f2-6c1e-7d4b-9a10-3b2c1d0e9f8a" with a PEN wallet balance of 0

  Scenario: Register a top-up as pending until the provider confirms it
    When the investor requests a deposit of 1500.00 PEN with Stripe and a new Idempotency-Key
    Then the response status is 202
    And the deposit has a deposit id and status "PENDING"
    And a Stripe charge is created for the deposit
    And the wallet balance is still 0.00 PEN

  Scenario: Credit the wallet when the provider confirms the payment
    Given the investor has a pending deposit of 1500.00 PEN
    When Stripe sends a signed webhook confirming the payment of that deposit
    Then the webhook response status is 200
    And the deposit status becomes "SUCCEEDED"
    And the wallet balance is 1500.00 PEN
    And the wallet movements include a CREDIT of 1500.00 PEN linked to that deposit

  Scenario: Do not credit the wallet when the payment fails
    Given the investor has a pending deposit of 1500.00 PEN
    When Stripe sends a signed webhook reporting that the payment of that deposit failed
    Then the deposit status becomes "FAILED"
    And the wallet balance is still 0.00 PEN

  Scenario: Reject a duplicated deposit reference
    Given the investor already requested a deposit of 1500.00 PEN with the Idempotency-Key "topup-2026-10-06-001"
    When the investor sends the same deposit request again with the Idempotency-Key "topup-2026-10-06-001"
    Then the response status is 202
    And the response returns the deposit id of the first request
    And only one deposit exists for that Idempotency-Key
    And only one Stripe charge exists for that deposit

  Scenario: Credit the wallet only once when the provider repeats the webhook
    Given the investor has a deposit of 1500.00 PEN confirmed by Stripe
    When Stripe sends the same signed confirmation webhook again
    Then the webhook response status is 200
    And the wallet balance is 1500.00 PEN
    And the wallet movements include exactly one CREDIT linked to that deposit
