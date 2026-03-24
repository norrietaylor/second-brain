# Source: docs/specs/02-spec-raindrop-integration/02-spec-raindrop-integration.md
# Pattern: CLI/Process + State
# Recommended test type: Integration

Feature: /today and /eod Integration

  Scenario: Morning briefing includes Raindrop item count
    Given five unprocessed Raindrop inbox items exist in the vault
    When the user runs the "/today" command
    Then the briefing output includes the line "5 Raindrop items waiting for triage"

  Scenario: Morning briefing triggers a Raindrop sync before counting
    Given two unprocessed Raindrop inbox items exist in the vault
    And one new bookmark has been saved to Raindrop since the last sync
    When the user runs the "/today" command
    Then a make-it-rain sync is triggered before the Raindrop count is reported
    And the briefing output includes "3 Raindrop items waiting for triage"

  Scenario: Morning briefing shows zero when no Raindrop items exist
    Given no unprocessed Raindrop inbox items exist in the vault
    When the user runs the "/today" command
    Then the briefing output does not include a "Raindrop items waiting for triage" line

  Scenario: /eod lists unprocessed Raindrop items in the daily note
    Given three unprocessed Raindrop inbox items exist with titles "Article A", "Article B", and "Article C"
    And each item has a url and raindrop_type in its frontmatter
    When the user runs the "/eod" command
    Then the daily note contains a "### Raindrop Inbox" subsection under "## Day Summary"
    And the subsection lists each item in the format "- [title](url) -- raindrop_type, tags"

  Scenario: /eod omits Raindrop subsection when no items exist
    Given no unprocessed Raindrop inbox items exist in the vault
    When the user runs the "/eod" command
    Then the daily note does not contain a "### Raindrop Inbox" subsection

  Scenario: /eod classifies Raindrop items through the standard inbox pipeline
    Given two unprocessed Raindrop inbox items exist in the vault
    When the user runs the "/eod" command
    And the classification pipeline processes inbox items
    Then the Raindrop items are evaluated for reclassification alongside all other inbox items
    And items classified with confidence above 0.6 receive their new type (e.g., "reference" or "idea")

  Scenario: Promoted Raindrop items retain the source field
    Given a Raindrop inbox item exists with "source: raindrop" and "type: inbox"
    When the "/eod" classification pipeline promotes it to "type: reference"
    Then the note's frontmatter still contains "source: raindrop"
    And the note's "type" field is "reference"
    And the note's "status" field is no longer "unprocessed"
