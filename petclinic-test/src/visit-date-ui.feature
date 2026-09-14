Feature: The Add Visit form rejects an out-of-range date (bug #40)
  As a clinic user
  I want the New Visit form to refuse dates outside the pet's allowed range
  So that I can't submit a visit the backend would reject anyway

  Background:
    Given an owner with a pet exists

  Scenario Outline: An out-of-range date is rejected before it can be submitted
    When I open the Add Visit form for that pet
    And I type a visit date "<offset>"
    Then the form shows a date-range error and the submit button is disabled

    Examples:
      | offset                           |
      | one day before the pet's birth   |
      | one day past one year from today |
