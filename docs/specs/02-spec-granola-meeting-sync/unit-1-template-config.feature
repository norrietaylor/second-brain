Feature: Granola Plugin Template and Config
  Configure the philfreo/obsidian-granola-plugin to write structured
  intermediate notes to a staging folder, with required vault config entries.

  Background:
    Given the second-brain vault is initialised
    And the Obsidian Granola plugin is installed

  # --- Template file ---

  Scenario: Granola template exists at the correct path
    Then a file exists at "05 Meta/templates/Granola.md"

  Scenario: Template frontmatter contains all required fields
    Given the file "05 Meta/templates/Granola.md" exists
    Then its frontmatter contains the field "granola_id"
    And its frontmatter contains the field "title"
    And its frontmatter contains the field "date"
    And its frontmatter contains the field "granola_url"
    And its frontmatter contains the field "start_time"
    And its frontmatter contains the field "created"
    And its frontmatter contains the value "source: granola"

  Scenario: Template outputs attendees as a YAML list
    Given the file "05 Meta/templates/Granola.md" exists
    Then its frontmatter uses "{{granola_attendees_linked_list}}" for the attendees field

  Scenario: Template body contains required sections
    Given the file "05 Meta/templates/Granola.md" exists
    Then the body contains an "## Attendees" section with the linked attendee list
    And the body contains a "## Log" section wrapping private notes in a callout
    And the body contains a collapsed callout "> [!note]- Granola AI Summary" for enhanced notes
    And the body contains a collapsed callout "> [!note]- Transcript" for the transcript

  Scenario: Template uses plugin variable syntax, not Templater syntax
    Given the file "05 Meta/templates/Granola.md" exists
    Then the template uses "{{variable}}" and "{{#variable}}...{{/variable}}" syntax
    And the template does not contain Templater "<%" delimiters

  # --- Config entries ---

  Scenario: Config file contains a granola section
    Given the file "05 Meta/config.yaml" exists
    Then it contains a "granola" top-level section

  Scenario: Granola config includes self_name
    Given the "granola" section exists in "05 Meta/config.yaml"
    Then it contains a "self_name" field with a non-empty string value

  Scenario: Granola config includes staging_folder with default
    Given the "granola" section exists in "05 Meta/config.yaml"
    Then it contains a "staging_folder" field
    And its default value is "Granola"

  Scenario: Granola config includes series_overrides map
    Given the "granola" section exists in "05 Meta/config.yaml"
    Then it contains a "series_overrides" field that is a YAML mapping
