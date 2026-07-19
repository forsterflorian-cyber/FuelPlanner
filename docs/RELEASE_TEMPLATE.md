# Release Template

## Release

- Version:
- Date:
- Manifest version:

## Verification

- `.\build.ps1`
- `.\build.ps1 -Test -Device fr955`
- `.\build.ps1 -Test -Device edge1040`
- `.\build.ps1 -Test -Device edge840`
- `.\build.ps1 -Test -Device edge540`
- `.\build.ps1 -Test -Device edge520plus`
- `.\build.ps1 -Test -Device edge1050`
- `.\build.ps1 -Test -Device edgemtb`
- Confirm `README.md` device matrix matches `manifest.xml`.
- Confirm `docs/CHANGELOG.md`, the versioned release notes, and `docs/STORE_DESCRIPTION.md` are updated.
- Confirm no new unsupported device-specific code paths were added.
- Simulator spot checks: `edge1040`, `edge840`, `edge540` or `edgemtb`, and `edge1050`.
- Edge layout checks: 1-, 2-, 4-, 6-, and 10-field layouts have no text overlap or unreadable ring.
- Lifecycle checks: `PAUSED` and `STOPPED` remain resumable; `RESET` and terminal `OFF` finalize exactly once.
- Timer checks: switch between `timerTime` and the `elapsedTime` fallback before, during, and after a pause without counting paused time.
- Persistence checks: exercise partial active writes, failed recovery writes, interrupted cleanup, and confirmed-recovery precedence.
- Input checks: touch-capable data fields, including Edge 820 and Edge Explore, receive intake/snooze/undo actions; non-touch products use automatic flow.
- Alert checks: native `DataFieldAlert` is used only on compatible Connect IQ 3.2+ products; other products retain the in-field reminder overlay.
- Validation status: state compile, simulator, and physical-device results separately, including the exact device or simulated product.
- Do not infer physical-device validation from a successful compile, package export, simulator run, or simulator memory result.
- Accepted waiver: launcher icon scaling warnings on 35px/36px/54px/56px/60px/65px/68px/70px targets are known and accepted for this release.

## Release Notes

### Deutsch

- ...

### English

- ...

## Store Submission

- IQ package:
- Screenshots:
- Support URL:
