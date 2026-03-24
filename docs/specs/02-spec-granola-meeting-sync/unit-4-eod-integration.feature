Feature: EOD Integration
  Wire the Granola ingest script into /eod so that Granola-sourced meetings
  are processed and appear in the daily note digest.

  Background:
    Given the second-brain vault is initialised
    And the "/eod" command file exists at ".claude/commands/eod.md"

  # --- Step 0.75: granola-ingest call ---

  Scenario: /eod command includes granola-ingest as Step 0.75
    Given the "/eod" command file
    Then it contains a step calling "05 Meta/scripts/granola-ingest"
    And that step is positioned after Step 0.5 (sb-ingest) and before Step 1 (inbox processing)

  # --- Tracking variable ---

  Scenario: Step 0 tracking variables include granola_ingest_count
    Given the "/eod" command file
    Then Step 0's tracking variables include "granola_ingest_count"

  # --- Output capture ---

  Scenario: Step 0.75 output is captured in commit_details
    Given a staged Granola note exists in the staging folder
    When /eod runs Step 0.75
    Then the ingest summary output is appended to "commit_details"

  # --- Meeting summary passthrough (Step 3) ---

  Scenario: Granola-sourced meetings are included in Step 3 meeting summaries
    Given a Granola meeting note exists with "type: meeting" and today's date
    When /eod runs Step 3 (Meeting Summary Generation)
    Then the Granola meeting appears in the meeting summary output
    And it is processed identically to manually-created meetings

  # --- Daily note passthrough (Step 5) ---

  Scenario: Granola meetings appear in the daily note Meetings section
    Given a Granola meeting note exists with "type: meeting" and today's date
    When /eod runs Step 5 (Enrich Daily Note)
    Then the "### Meetings" section of the daily note includes the Granola meeting
    And the format is indistinguishable from manually-created meetings

  # --- Commit summary (Step 10) ---

  Scenario: Step 10 commit includes Granola count when meetings were ingested
    Given granola_ingest_count is 3
    When /eod runs Step 10 (commit)
    Then the commit message includes "3 granola meetings ingested"

  Scenario: Step 10 commit omits Granola count when no meetings were ingested
    Given granola_ingest_count is 0
    When /eod runs Step 10 (commit)
    Then the commit message does not mention "granola meetings ingested"

  # --- No changes needed to existing steps ---

  Scenario: Step 3 requires no modification for Granola support
    Given a Granola meeting note has "type: meeting"
    Then it appears in the "Meetings.base" Today view automatically
    And Step 3 processes it without any Granola-specific logic

  Scenario: Step 5 requires no modification for Granola support
    Given a Granola meeting note has "type: meeting"
    Then it is read by Step 5 from today's meetings query
    And Step 5 formats it without any Granola-specific logic
