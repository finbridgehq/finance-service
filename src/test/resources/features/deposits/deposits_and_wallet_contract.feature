@TS06
Feature: Deposits, wallet and payments REST contract
  As a developer integrating the investor applications with Finance
  I want deposits, balances, movements and payment webhooks to follow a traceable and idempotent contract
  So that funds are never duplicated and never credited without verification

  Background:
    Given an investor account "0198a3f2-6c1e-7d4b-9a10-3b2c1d0e9f8a"
    And the requests carry the header "X-User-Id" with "0198a3f2-6c1e-7d4b-9a10-3b2c1d0e9f8a"

  Scenario: Accept a deposit with a new Idempotency-Key
    When I send a POST request to "/api/v1/deposits" with the Idempotency-Key "key-001" and the body:
      | accountId                            | amountMinor | currency | provider |
      | 0198a3f2-6c1e-7d4b-9a10-3b2c1d0e9f8a | 150000      | PEN      | STRIPE   |
    Then the response status is 202
    And the response contains a "depositId" and the status "PENDING"
    And I can retrieve the deposit with a GET request to "/api/v1/deposits/{depositId}"

  Scenario: Reject an Idempotency-Key reused with different content
    Given a deposit of 150000 PEN was accepted with the Idempotency-Key "key-002"
    When I send a POST request to "/api/v1/deposits" with the Idempotency-Key "key-002" and an amount of 99000 PEN
    Then the response status is 409
    And no second deposit is created

  Scenario: Reject a deposit without an Idempotency-Key
    When I send a POST request to "/api/v1/deposits" without the Idempotency-Key header
    Then the response status is 400

  Scenario Outline: Reject a deposit with invalid data
    When I send a POST request to "/api/v1/deposits" with the Idempotency-Key "<key>", an amount of <amountMinor> and the currency "<currency>"
    Then the response status is 400
    And no deposit is created

    Examples:
      | key     | amountMinor | currency |
      | key-010 | 0           | PEN      |
      | key-011 | -5000       | PEN      |
      | key-012 | 150000      | EUR      |

  Scenario: Reject a webhook with an invalid signature
    Given a pending deposit of 150000 PEN exists for the account
    When Stripe calls "/api/v1/payment-providers/stripe/webhooks" with a payment confirmation and an invalid "Stripe-Signature" header
    Then the response status is 400
    And the deposit status is still "PENDING"
    And the PEN wallet balance does not change

  Scenario: Reflect confirmed deposits in the balance and the movements
    Given two deposits of 150000 PEN and 50000 PEN were confirmed by Stripe
    When I send a GET request to "/api/v1/accounts/0198a3f2-6c1e-7d4b-9a10-3b2c1d0e9f8a/wallets/PEN"
    Then the response status is 200
    And the response contains the "balanceMinor" 200000
    When I send a GET request to "/api/v1/accounts/0198a3f2-6c1e-7d4b-9a10-3b2c1d0e9f8a/wallets/PEN/movements?page=0&size=20"
    Then the response status is 200
    And the page contains 2 movements with direction "CREDIT"

  Scenario: Report a wallet that does not exist yet
    When I send a GET request to "/api/v1/accounts/0198a3f2-6c1e-7d4b-9a10-3b2c1d0e9f8a/wallets/USD"
    Then the response status is 404

  Scenario: Forbid access to another account's wallet
    When I send a GET request to "/api/v1/accounts/0198ffff-0000-7000-8000-000000000001/wallets/PEN"
    Then the response status is 403

  Scenario: Report a deposit that does not exist
    When I send a GET request to "/api/v1/deposits/0198ffff-0000-7000-8000-000000000002"
    Then the response status is 404
