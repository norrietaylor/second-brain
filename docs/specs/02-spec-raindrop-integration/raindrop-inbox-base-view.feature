# Source: docs/specs/02-spec-raindrop-integration/02-spec-raindrop-integration.md
# Pattern: CLI/Process + State
# Recommended test type: Integration

Feature: Raindrop Inbox Base View

  Scenario: Base view returns only unprocessed Raindrop items
    Given the vault contains three Raindrop-imported notes with "type: inbox", "source: raindrop", and "status: unprocessed"
    And the vault contains one Raindrop-imported note that has been promoted to "type: reference"
    And the vault contains one non-Raindrop inbox note with "type: inbox" and "source: manual"
    When the user runs "obsidian vault=second-brain base:query path='05 Meta/bases/Raindrop Inbox.base' format=json"
    Then exactly three results are returned
    And every result has "type: inbox", "source: raindrop", and "status: unprocessed"

  Scenario: Base view displays required columns
    Given the vault contains at least one unprocessed Raindrop inbox item
    When the user queries the Raindrop Inbox base view
    Then each result includes the fields: file name, raindrop_type, url, tags, and created date

  Scenario: Base view sorts by created date descending
    Given the vault contains Raindrop inbox items created on "2026-03-20", "2026-03-22", and "2026-03-21"
    When the user queries the Raindrop Inbox base view
    Then the first result has a created date of "2026-03-22"
    And the second result has a created date of "2026-03-21"
    And the third result has a created date of "2026-03-20"

  Scenario: Promoted items no longer appear in the base view
    Given a Raindrop inbox item exists with "status: unprocessed"
    When the item is reclassified to "type: reference" and "status: processed"
    And the user queries the Raindrop Inbox base view
    Then the promoted item does not appear in the results
