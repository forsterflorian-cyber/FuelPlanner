# How to Publish FuelPlanner to the Connect IQ Store

## Overview

This project produces one app:

| App | Type | Jungle file | Store listing |
|-----|------|-------------|---------------|
| FuelPlanner | Data Field | `monkey.jungle` | One listing |

---

## Prerequisites

1. Install the Garmin Connect IQ SDK from https://developer.garmin.com/connect-iq/sdk/
2. Generate a developer key at https://developer.garmin.com/connect-iq/
3. Keep the key as `%USERPROFILE%\developer_key.der` or pass an explicit `-KeyPath`
4. Ensure Java is in `PATH`
5. Use a Garmin developer account at https://apps.garmin.com/

---

## Step 1 - Build the .iq File

Run the build script from the project root:

```powershell
.\build.ps1
```

This auto-detects the newest installed SDK and produces `bin\FuelPlanner-DataField.iq`.

Custom SDK or key path:

```powershell
.\build.ps1 -SdkPath "C:\MySDKs" -KeyPath "C:\keys\my_key.der"
```

---

## Step 2 - Publish the Data Field

1. Go to https://apps.garmin.com/ and sign in.
2. Click `Create App` and choose `Data Field`.
3. Fill in the store fields:
   - Name (EN): `FuelPlanner`
   - Name (DE): `FuelPlanner`
   - Description (EN): copy from `garmin.md`, `DATA FIELD - English`, `Full Description`
   - Description (DE): copy from `garmin.md`, `DATA FIELD - Deutsch`, `Vollstandige Beschreibung`
   - Short Description (EN/DE): from `garmin.md`
   - Changelog: from `garmin.md`
4. Upload `bin\FuelPlanner-DataField.iq`.
5. Set minimum API level to match `manifest.xml`: `3.3.0`.
6. Add the launcher icon.
7. Submit for review.

---

## Icon Requirements

The launcher icon is defined in `resources/drawables/drawables.xml` as `launcher_icon.svg`.

| Use | Size |
|-----|------|
| Watch display | 24x24 px minimum |
| Store listing | 80x80 px PNG recommended |
| Store banner | 480x270 px PNG recommended |

The SDK scales the SVG for devices, but the store listing still needs separate PNG uploads.

---

## Debugging in VS Code

Use the `Run Data Field` launch configuration in `.vscode/launch.json`.

Recommended test devices: `epix2pro47mm` or `fr965`.

Do not use `Run Tests` when you intend to launch the data field simulator.

---

## Version Bumps

Before each release:

1. Update `manifest.xml` if `minApiLevel` changes.
2. Add a changelog entry in `garmin.md`.
3. Run `.\build.ps1` to produce a new `.iq`.
4. Upload to the store and update the changelog field.
