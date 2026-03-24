Feature: Granola Ingest Script
  Transform staged Granola notes into second-brain meeting notes with proper
  schema, file naming, and location.

  Background:
    Given the second-brain vault is initialised
    And the script "05 Meta/scripts/granola-ingest" exists and is executable
    And "05 Meta/config.yaml" contains a valid "granola" section

  # --- Script basics ---

  Scenario: Script exists at the expected path
    Then a file exists at "05 Meta/scripts/granola-ingest"
    And the file is executable

  Scenario: Script uses bash strict mode
    Given the script "05 Meta/scripts/granola-ingest"
    Then its header includes "set -euo pipefail"

  # --- Dry-run mode ---

  Scenario: Dry-run previews transformations without writing
    Given a staged Granola note exists in the staging folder with title "Weekly Sync - March 22"
    When I run "granola-ingest --dry-run"
    Then the output shows the planned target path "04 Data/2026/03/2026.03.22-weekly-sync.md"
    And the output shows the derived meeting_name "weekly-sync"
    And no files are created in "04 Data/"
    And the staged note remains in the staging folder

  # --- Frontmatter parsing ---

  Scenario: Script parses required frontmatter from staged note
    Given a staged Granola note with frontmatter containing:
      | field       | value                                    |
      | granola_id  | abc-123                                  |
      | title       | Design Review                            |
      | date        | 2026-03-22                               |
      | start_time  | 10:00                                    |
      | granola_url | https://granola.ai/note/abc-123          |
      | source      | granola                                  |
    When I run "granola-ingest"
    Then the created note's frontmatter contains all parsed fields

  # --- Meeting name derivation ---

  Scenario Outline: Title normalization strips trailing dates and numbers
    Given a staged Granola note with title "<title>"
    When I run "granola-ingest --dry-run"
    Then the derived meeting_name is "<meeting_name>"

    Examples:
      | title                            | meeting_name       |
      | Weekly Sync - March 22           | weekly-sync        |
      | Sprint Planning #5               | sprint-planning    |
      | Design Review (2026-03-22)       | design-review      |
      | 1:1 with Alice                   | 1-1-with-alice     |
      | Team Standup                     | team-standup       |

  Scenario: Series overrides take precedence over title normalization
    Given "05 Meta/config.yaml" has a series_overrides entry mapping "Weird Title v3.2" to "weird-title"
    And a staged Granola note with title "Weird Title v3.2"
    When I run "granola-ingest"
    Then the created note has meeting_name "weird-title"

  # --- 1-on-1 detection ---

  Scenario: Detect 1-on-1 meeting when one attendee besides self
    Given "05 Meta/config.yaml" has self_name "Mack Hogan"
    And a staged Granola note with attendees "Mack Hogan, Alice Smith"
    When I run "granola-ingest"
    Then the created note has "is_1on1: true"
    And the created note has meeting_name "1on1-alice-smith"
    And the created note has tags containing "1on1"

  Scenario: Multi-person meeting is not flagged as 1-on-1
    Given "05 Meta/config.yaml" has self_name "Mack Hogan"
    And a staged Granola note with attendees "Mack Hogan, Alice Smith, Bob Jones"
    When I run "granola-ingest"
    Then the created note has "is_1on1: false"
    And the created note does not have tags containing "1on1"

  # --- Idempotency / dedup ---

  Scenario: Skip staged note when vault already has a note with the same granola_id
    Given a vault note exists with frontmatter "granola_id: abc-123"
    And a staged Granola note with frontmatter "granola_id: abc-123"
    When I run "granola-ingest"
    Then the staged note is skipped
    And no new note is created
    And the output indicates the note was skipped due to existing granola_id

  Scenario: Running ingest twice produces no duplicates
    Given a staged Granola note with granola_id "def-456"
    When I run "granola-ingest"
    And I run "granola-ingest" again
    Then only one vault note exists with granola_id "def-456"

  # --- File naming and placement ---

  Scenario: Note is created in the correct data folder with proper filename
    Given a staged Granola note with date "2026-03-22" and meeting_name "weekly-sync"
    When I run "granola-ingest"
    Then a file exists at "04 Data/2026/03/2026.03.22-weekly-sync.md"

  Scenario: Collision avoidance appends suffix for duplicate filenames
    Given a vault note already exists at "04 Data/2026/03/2026.03.22-weekly-sync.md" with a different granola_id
    And a staged Granola note with date "2026-03-22" and meeting_name "weekly-sync"
    When I run "granola-ingest"
    Then a file is created at "04 Data/2026/03/2026.03.22-weekly-sync-2.md"

  # --- Full frontmatter schema ---

  Scenario: Created note has complete second-brain meeting frontmatter
    Given a staged Granola note with all required fields
    When I run "granola-ingest"
    Then the created note's frontmatter contains:
      | field          | expected                |
      | type           | meeting                 |
      | meeting_name   | (derived value)         |
      | date           | (from staged note)      |
      | attendees      | (YAML list of names)    |
      | is_1on1        | (boolean)               |
      | granola_id     | (from staged note)      |
      | granola_url    | (from staged note)      |
      | source         | granola                 |
      | aliases        | (kebab-case name)       |
      | created        | (current timestamp)     |
      | modified       | (current timestamp)     |
      | classified_at  | (current timestamp)     |
      | confidence     | 1.0                     |

  # --- Body preservation ---

  Scenario: Body sections from the template are preserved
    Given a staged Granola note with Attendees, Log, AI Summary callout, and Transcript callout
    When I run "granola-ingest"
    Then the created note body contains "## Attendees" with wiki-links
    And the created note body contains "## Log"
    And the created note body contains "> [!note]- Granola AI Summary"
    And the created note body contains "> [!note]- Transcript"

  # --- Staging cleanup ---

  Scenario: Staged file is deleted after successful creation
    Given a staged Granola note "Granola/Weekly Sync.md"
    When I run "granola-ingest"
    Then the file "Granola/Weekly Sync.md" no longer exists

  # --- Summary output ---

  Scenario: Script outputs ingest summary
    Given two staged Granola notes for "weekly-sync" and "design-review"
    When I run "granola-ingest"
    Then the output contains "Ingested 2 meeting(s): weekly-sync, design-review"

  # --- Empty staging folder ---

  Scenario: Empty staging folder is a no-op
    Given the staging folder contains no .md files
    When I run "granola-ingest"
    Then the script exits with code 0
    And there is no output
