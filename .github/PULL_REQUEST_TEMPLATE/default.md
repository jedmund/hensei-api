name: Default Pull Request
description: For general changes and updates
body:

- type: markdown
  attributes:
  value: |
  ## Description
  Please provide a clear description of your changes.
- type: textarea
  id: changes
  attributes:
  label: Changes Made
  description: List the main changes in this PR
  placeholder: "- Added feature X\n- Fixed bug Y\n- Updated documentation for Z"
  validations:
  required: true
- type: checkboxes
  id: checks
  attributes:
  label: Checklist
  options:
    - label: I have tested my changes
    - label: I have updated relevant documentation
    - label: My changes generate no new warnings
    - label: I have added tests if applicable
