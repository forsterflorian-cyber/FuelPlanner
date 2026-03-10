# Release Template

## Release

- Version:
- Date:
- Manifest version:

## Verification

- `monkeyc -f monkey.jungle -o bin\FuelPlanner-fr955.prg -y developer_key -d fr955 -w`
- `monkeyc -f monkey.jungle -o bin\FuelPlanner-DataField.iq -e -y developer_key -w`
- Confirm `README.md` device matrix matches `manifest.xml`.
- Confirm `docs/CHANGELOG.md` and `docs/STORE_DESCRIPTION.md` are updated.
- Confirm no new device-specific code paths were added.

## Release Notes

### Deutsch

- ...

### English

- ...

## Store Submission

- IQ package:
- Screenshots:
- Support URL:
