name: Data Update
description: For game data updates and modifications
body:

- type: markdown
  attributes:
  value: |
  ## Data Update
- type: textarea
  id: summary
  attributes:
  label: Summary
  description: Describe what this data update includes
  placeholder: "Adding new Valentines 2024 characters"
  validations:
  required: true
- type: textarea
  id: new-additions
  attributes:
  label: New Additions
  description: List new items being added, grouped by type
  value: |
  ##### Characters
  -
  ##### Weapons
  -
  ##### Summons
  -
- type: textarea
  id: modifications
  attributes:
  label: Modifications
  description: List existing items being modified
  value: |
  ##### Characters
  -
  ##### Weapons
  -
  ##### Summons
  -
- type: textarea
  id: csv-files
  attributes:
  label: CSV Files Added
  description: List all CSV files included in this update
  value: |
    - [ ] `YYYYMMDD-characters-XXX.csv`
    - [ ] `YYYYMMDD-weapons-XXX.csv`
    - [ ] `YYYYMMDD-summons-XXX.csv`
- type: checkboxes
  id: data-checklist
  attributes:
  label: Checklist
  options:
    - label: CSV files use the correct naming format (`YYYYMMDD-{type}-XXX.csv`)
    - label: CSV files are in the correct location (`db/seed/updates/`)
    - label: All required fields are filled out
    - label: Dates use the correct format (`YYYY-MM-DD`)
    - label: Boolean values are either `true` or `false`
    - label: Arrays use the correct format (e.g., `{value1,value2}`)
    - label: Ran import in test mode (`bin/rails granblue:import_data TEST=true`)
- type: textarea
  id: test-results
  attributes:
  label: Test Results
  description: Paste the output from running the import in test mode
  validations:
  required: true
