# Source: docs/specs/02-spec-raindrop-integration/02-spec-raindrop-integration.md
# Pattern: CLI/Process + State
# Recommended test type: Integration

Feature: Plugin Installation and Template Configuration

  Scenario: make-it-rain plugin is installed and available in Obsidian
    Given the Obsidian vault "second-brain" is open
    When the user opens the command palette and searches for "make-it-rain"
    Then at least one command matching "make-it-rain" or "Fetch Raindrops" appears in the results

  Scenario: Synced bookmark produces vault-compatible frontmatter
    Given make-it-rain is configured with the custom Handlebars template
    And at least one bookmark exists in the configured Raindrop collection
    When the user triggers a Raindrop sync via the command palette
    Then a new markdown file appears in "04 Data/2026/03/" with the "rd-" prefix in its filename
    And the file's frontmatter contains "type: inbox"
    And the file's frontmatter contains "status: unprocessed"
    And the file's frontmatter contains "source: raindrop"
    And the file's frontmatter contains a numeric "raindrop_id" field
    And the file's frontmatter contains a "url" field with an HTTP or HTTPS link

  Scenario: Output files follow vault naming conventions
    Given make-it-rain is configured with the output folder and filename template
    And a bookmark titled "My Example Article" exists in Raindrop
    When the user triggers a Raindrop sync
    Then a file matching the pattern "YYYY.MM.DD-rd-my-example-article.md" is created in the date-appropriate "04 Data/YYYY/MM/" subfolder

  Scenario: Vault search finds imported Raindrop items by source
    Given at least one Raindrop bookmark has been synced to the vault
    When the user runs "obsidian vault=second-brain search query='source: raindrop' path='04 Data' format=json"
    Then the command output includes at least one result
    And each result has "source: raindrop" in its frontmatter

  Scenario: Collection or tag filters restrict which bookmarks sync
    Given make-it-rain is configured to sync only the "To Read" collection
    And bookmarks exist in both "To Read" and "Archive" collections
    When the user triggers a Raindrop sync
    Then only bookmarks from the "To Read" collection appear as new vault files
    And no files with bookmarks from the "Archive" collection are created
