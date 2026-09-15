Feature: Search owners
  As a clinic user
  I want to filter owners by typing a fragment of anything the list shows
  So that I can find an owner without remembering which column the detail sits in

  Background:
    Given the clinic has these owners
      | Harry Potter   |
      | Beatrix Potter |
      | Ronald Weasley |

  Scenario Outline: Filter owners by a fragment of any listed column
    When I open the owners page
    And I search owners for "<search>"
    Then exactly these owners are listed: "<owners>"

    Examples: The fragment may sit anywhere in the value, in any letter case
      | search | owners                       |
      | Potter | Harry Potter, Beatrix Potter |
      | potter | Harry Potter, Beatrix Potter |
      | POTTER | Harry Potter, Beatrix Potter |

    Examples: Every column the table shows is searched, not just the last name
      | search        | owners                                       |
      | Harry         | Harry Potter                                 |
      | Privet Drive  | Harry Potter                                 |
      | Whinging      | Harry Potter                                 |
      | 0119084455    | Harry Potter                                 |
      | Hedwig        | Harry Potter                                 |
      | otter         | Harry Potter, Beatrix Potter, Ronald Weasley |

    Examples: A fragment matching nothing lists nobody
      | search | owners |
      | Zzzz   |        |

  Scenario: A fragment may span the first and last name, as the Name column shows them
    When I open the owners page
    And I search owners for "Harry Pot"
    Then exactly these owners are listed: "Harry Potter"

  @generate_sequence
  Scenario: Searching with an empty fragment lists every owner
    When I open the owners page
    And I search owners for ""
    Then every owner in the clinic is listed
