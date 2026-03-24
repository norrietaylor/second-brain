Feature: Person Stub Creation
  Automatically create person note stubs for meeting attendees who don't
  have existing vault notes, and link them in the meeting note.

  Background:
    Given the second-brain vault is initialised
    And the script "05 Meta/scripts/granola-ingest" exists and is executable
    And "05 Meta/config.yaml" has self_name "Mack Hogan"

  # --- Person search ---

  Scenario: Existing person is found by name match (case-insensitive)
    Given a vault person note exists with "name: Alice Smith"
    And a staged Granola note with attendee "alice smith"
    When I run "granola-ingest"
    Then no new person stub is created for "Alice Smith"

  Scenario: Existing person is found by alias match
    Given a vault person note exists with aliases containing "alice-smith"
    And a staged Granola note with attendee "Alice Smith"
    When I run "granola-ingest"
    Then no new person stub is created for "Alice Smith"

  # --- Stub creation ---

  Scenario: Person stub is created for unknown attendee
    Given no vault person note exists matching "Bob Jones"
    And a staged Granola note dated "2026-03-22" with attendee "Bob Jones" for meeting "weekly-sync"
    When I run "granola-ingest"
    Then a person stub is created at "04 Data/2026/03/2026.03.22-bob-jones.md"

  Scenario: Person stub has correct frontmatter
    Given no vault person note exists matching "Bob Jones"
    And a staged Granola note dated "2026-03-22" with attendee "Bob Jones" for meeting "weekly-sync"
    When I run "granola-ingest"
    Then the person stub frontmatter contains:
      | field          | expected                                |
      | type           | person                                  |
      | name           | Bob Jones                               |
      | context        | Met in weekly-sync meeting              |
      | last_touched   | 2026-03-22                              |
      | aliases        | [bob-jones]                             |
      | created        | (current timestamp)                     |
      | modified       | (current timestamp)                     |
      | classified_at  | (current timestamp)                     |
      | confidence     | 0.8                                     |

  Scenario: Person stub has correct body content
    Given no vault person note exists matching "Bob Jones"
    And a staged Granola note dated "2026-03-22" for meeting "weekly-sync" with attendee "Bob Jones"
    When I run "granola-ingest"
    Then the person stub body contains "## Notes"
    And the person stub body contains "Auto-created from Granola meeting [[2026.03.22-weekly-sync|weekly-sync]]"

  # --- Self-name exclusion ---

  Scenario: No person stub is created for self
    Given "05 Meta/config.yaml" has self_name "Mack Hogan"
    And a staged Granola note with attendees "Mack Hogan, Bob Jones"
    When I run "granola-ingest"
    Then no person stub is created for "Mack Hogan"
    And a person stub is created for "Bob Jones"

  # --- last_touched update ---

  Scenario: Existing person's last_touched is updated when meeting is newer
    Given a vault person note exists for "Alice Smith" with "last_touched: 2026-01-15"
    And a staged Granola note dated "2026-03-22" with attendee "Alice Smith"
    When I run "granola-ingest"
    Then the person note for "Alice Smith" has "last_touched: 2026-03-22"

  Scenario: Existing person's last_touched is not updated when meeting is older
    Given a vault person note exists for "Alice Smith" with "last_touched: 2026-04-01"
    And a staged Granola note dated "2026-03-22" with attendee "Alice Smith"
    When I run "granola-ingest"
    Then the person note for "Alice Smith" still has "last_touched: 2026-04-01"

  # --- Meeting note attendee linking ---

  Scenario: Meeting note attendees section has wiki-links to person note filenames
    Given a vault person note exists at "04 Data/2026/01/2026.01.10-alice-smith.md" for "Alice Smith"
    And no vault person note exists for "Bob Jones"
    And a staged Granola note dated "2026-03-22" with attendees "Alice Smith, Bob Jones"
    When I run "granola-ingest"
    Then the meeting note's "## Attendees" section contains "[[2026.01.10-alice-smith|Alice Smith]]"
    And the meeting note's "## Attendees" section contains "[[2026.03.22-bob-jones|Bob Jones]]"

  Scenario: Plugin-generated wiki-links for matched people are preserved
    Given the staged note attendee list already contains "[[2026.01.10-alice-smith|Alice Smith]]"
    When I run "granola-ingest"
    Then no new person stub is created for "Alice Smith"
    And the existing wiki-link is preserved in the meeting note

  # --- Summary output ---

  Scenario: Script reports person stubs created
    Given a staged Granola note with two unknown attendees "Bob Jones" and "Carol Diaz"
    When I run "granola-ingest"
    Then the output contains "Created 2 person stub(s): bob-jones, carol-diaz"

  Scenario: No person stub report when all attendees are known
    Given all attendees in the staged note already have person notes
    When I run "granola-ingest"
    Then the output does not contain "Created" followed by "person stub"
