# Data Update

## Summary

<!-- Describe what this data update includes -->
<!-- Example: Adding new Valentines 2024 characters -->

## New Additions

<!-- Copy the list of newly added items from the Import Summary -->

##### Characters
- 

##### Weapons
- 

##### Summons
- 

## Modifications

<!-- Copy the list of modified items from the Import Summary -->

##### Characters
- 

##### Weapons
- 

##### Summons
-

## Checklist

- [ ] CSV files use the correct naming format (`YYYYMMDD-{type}-XXX.csv`)
- [ ] CSV files are in the correct location (`db/seed/updates/`)
- [ ] All required fields are filled out
- [ ] Dates use the correct format (`YYYY-MM-DD`)
- [ ] Boolean values are either `true` or `false`
- [ ] Arrays use the correct format (e.g., `{value1,value2}`)
- [ ] Ran import in test mode (`bin/rails granblue:import_data TEST=true`)
- [ ] Weapon-skill data edited? Exported it and `bin/rails granblue:weapon_skill_curation_drift` is clean ([docs](../../docs/weapon-skill-curation.md))
- [ ] Character skill parsing or a character's sources changed? `bin/rails granblue:character_skill_drift` reports only the differences you expect ([docs](../../docs/weapon-skill-pipeline/README.md#contracts))

## Test Results

<!-- Paste the completion section from running the import in test mode -->
