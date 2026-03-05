# How to Publish FuelPlanner to the Connect IQ Store

## Overview

This project produces **two separate apps** that must be published independently:

| App | Type | Jungle file | Store listing |
|-----|------|-------------|---------------|
| FuelPlanner | Data Field | `monkey.jungle` | Separate listing |
| FuelPlanner Settings | Widget | `monkey-widget.jungle` | Separate listing |

---

## Prerequisites

1. **Garmin Connect IQ SDK** — install the latest from https://developer.garmin.com/connect-iq/sdk/
2. **Developer key** — generate once at https://developer.garmin.com/connect-iq/
   - Save as `%USERPROFILE%\developer_key.der`
3. **Java** in PATH (bundled with the SDK or install separately)
4. **Garmin developer account** at https://apps.garmin.com/

---

## Step 1 — Build the .iq files

Run the build script from the project root:

```powershell
.\build.ps1
```

This auto-detects the newest installed SDK and produces:
- `bin\FuelPlanner-DataField.iq`
- `bin\FuelPlanner-Widget.iq`

**Custom SDK or key path:**
```powershell
.\build.ps1 -SdkPath "C:\MySDKs" -KeyPath "C:\keys\my_key.der"
```

---

## Step 2 — Publish the Data Field

1. Go to https://apps.garmin.com/ and sign in
2. Click **Create App** → Type: **Data Field**
3. Fill in:
   - **Name (EN):** `FuelPlanner`
   - **Name (DE):** `FuelPlanner`
   - **Description (EN):** copy from `garmin.md` → *DATA FIELD — English → Full Description*
   - **Description (DE):** copy from `garmin.md` → *DATA FIELD — Deutsch → Vollständige Beschreibung*
   - **Short Description (EN/DE):** from `garmin.md`
   - **Changelog:** from `garmin.md`
4. Upload `bin\FuelPlanner-DataField.iq`
5. Set minimum API level: `4.2.0`
6. Add launcher icon (see Icon Requirements below)
7. Submit for review

---

## Step 3 — Publish the Widget

1. Click **Create App** → Type: **Widget**
2. Fill in:
   - **Name (EN):** `FuelPlanner Settings`
   - **Name (DE):** `FuelPlanner Einstellungen`
   - **Description (EN/DE):** from `garmin.md` → *WIDGET* sections
3. Upload `bin\FuelPlanner-Widget.iq`
4. In the description, link to the Data Field listing so users know they need both
5. Submit for review

---

## Icon Requirements

The launcher icon is defined in `resources/drawables/drawables.xml` as `launcher_icon.svg`.

| Use | Size |
|-----|------|
| Watch display | 24×24 px minimum (SVG scales up) |
| Store listing | 80×80 px PNG recommended |
| Store banner | 480×270 px PNG recommended |

The SDK will scale the SVG automatically per device, but the store listing needs separate PNG uploads.

---

## Debugging in VS Code

Both apps are in one project. Use the debug dropdown to switch:

| F5 config | Builds | Jungle used |
|-----------|--------|-------------|
| **Run Data Field** | Data field for simulator | `monkey.jungle` |
| **Run Widget (Settings)** | Widget for simulator | `monkey-widget.jungle` |

Both configs are self-contained in `.vscode/launch.json` — no need to change `settings.json`.

The device used for both is selected via the **Garmin device picker** in VS Code (bottom status bar or `${command:GetTargetDevice}`).

**Tip:** Use `epix2pro47mm` or `fr965` as your default test device — both support glance views, touch, and all features.

---

## Version Bumps

Before each release:
1. Bump `minApiLevel` in both manifest files if needed
2. Add a new changelog entry in `garmin.md`
3. Run `.\build.ps1` to produce new `.iq` files
4. Upload to the store and update the changelog field
