# FuelPlaner

[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](https://github.com/forsterflorian-cyber/FuelPlaner)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Garmin%20Connect%20IQ-orange.svg)](https://developer.garmin.com/connect-iq/)

A Garmin Connect IQ Data Field for carbohydrate fueling during endurance activities.

## Features

- **Smart Fueling Reminders**: Vibration alerts when it's time to consume carbs
- **Three Reminder Modes**:
  - **Auto**: Deficit-based with fixed g/h target
  - **Fixed**: Fixed interval from last intake
  - **Calorie Auto**: Target derived from watch calorie data
- **Session Management**: Pause/resume with automatic recovery
- **FIT Integration**: Records deficit and consumption data for Garmin Connect analysis
- **Multi-Device Support**: Fenix, Epix, Forerunner, Instinct3, Venu series
- **Touch & Non-Touch**: Auto-flow for button-only devices

## Quick Start

### Prerequisites

- [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (min API Level 3.0.0)
- [Visual Studio Code](https://code.visualstudio.com/) with [Monkey C extension](https://marketplace.visualstudio.com/items?itemName=garmin.monkey-c)
- Garmin Connect IQ device or simulator

### Installation

1. Clone the repository:
```bash
git clone https://github.com/forsterflorian-cyber/FuelPlaner.git
cd FuelPlaner
```

2. Open in VS Code:
```bash
code .
```

3. Build the project:
```bash
# Using VS Code task (Ctrl+Shift+B → "Build")
# Or via command line:
monkeyc -f monkey.jungle -o bin/FuelPlaner.prg -y <developer_key>
```

4. Deploy to device/simulator:
```bash
# Using VS Code task (Ctrl+Shift+P → "Tasks: Run Task" → "Deploy")
# Or via command line:
monkeydo bin/FuelPlaner.prg <device>
```

## Usage

### Adding as Data Field

1. On your Garmin device, go to **Settings** → **Activities & Apps**
2. Select an activity (e.g., Run, Bike)
3. Select **Data Screens** → **Add New** → **Connect IQ**
4. Choose **FuelPlaner**

### Configuration

Access settings via **Garmin Connect Mobile** app:

| Setting | Range | Default | Description |
|---------|-------|---------|-------------|
| Carbs Target | 20-120 g/h | 60 g/h | Target carbohydrate intake rate |
| Dose Size | 5-100 g | 25 g | Amount per intake reminder |
| Reminder Mode | Auto/Fixed/Calorie | Auto | How reminders are calculated |
| Carb Fraction | 40-80% | 60% | % of calories from carbs (Calorie Auto mode) |
| Fixed Interval | 5-60 min | 20 min | Time between reminders (Fixed mode) |
| Start Delay | 0-60 min | 15 min | Delay before first reminder |
| Snooze Time | 1-15 min | 5 min | Maximum snooze duration |

### Presets

- **Run**: 60 g/h, 25 g dose
- **Bike**: 90 g/h, 30 g dose
- **Hike**: 40 g/h, 20 g dose

## Architecture

```
FuelPlaner/
├── source/
│   ├── FuelPlannerApp.mc          # App entry point
│   ├── FuelPlannerFieldView.mc    # Main data field view (:full)
│   ├── FuelPlannerFieldViewInstinct3.mc  # Simplified view (:lite)
│   ├── FuelPlannerFieldDelegate.mc  # Touch input handling
│   ├── FuelPlannerMenuView.mc     # Settings menu
│   ├── FuelPlannerMenuDelegate.mc # Settings input handling
│   └── model/
│       ├── FuelModel.mc           # Core calculation engine
│       ├── StorageManager.mc      # Persistent storage
│       └── ReminderManager.mc     # Vibration/backlight alerts
├── tests/
│   ├── FuelModelTests.mc          # Unit tests
│   ├── TestHelper.mc              # Mock objects
│   ├── MemoryTests.mc             # Memory stress tests
│   ├── ReminderTests.mc           # Reminder logic tests
│   ├── StorageTests.mc            # Storage tests
│   └── StressTests.mc             # Stress tests
├── resources/
│   ├── strings/strings.xml        # English strings
│   ├── drawables/drawables.xml    # Icons
│   ├── properties.xml             # App properties
│   ├── settings.xml               # Settings schema
│   └── fitfields.xml              # FIT field definitions
├── manifest.xml                   # App manifest
├── monkey.jungle                  # Build configuration
└── build.ps1                      # PowerShell build script
```

## Development

### Build Commands

```powershell
# Full build
.\build.ps1 -Device fenix7

# Build all devices
.\build.ps1 -All

# Run tests
.\build.ps1 -Test

# Clean build
.\build.ps1 -Clean
```

### Running Tests

```bash
# Via build script
.\build.ps1 -Test

# Via monkeyc directly
monkeyc -f monkey.tests.jungle -o bin/FuelPlanerTests.prg -y <developer_key>
monkeydo bin/FuelPlanerTests.prg <device>
```

### Code Style

- **Indentation**: 4 spaces
- **Naming**: camelCase for variables/methods, PascalCase for classes
- **Comments**: JSDoc-style for public methods
- **Attributes**: Use `(:full)` and `(:lite)` for device-specific code

## Supported Devices

| Family | Models |
|--------|--------|
| Fenix | 6, 6 Pro, 6S, 6S Pro, 6X Pro, 7, 7 Pro, 7S, 7S Pro, 7X, 7X Pro |
| Epix | 2, 2 Pro (42mm, 47mm, 51mm) |
| Forerunner | 255, 255M, 255S, 255SM, 265, 265S, 745, 945, 945 LTE, 955, 965 |
| Instinct | 3 AMOLED (45mm, 50mm), 3 Solar (45mm) |
| Venu | 3, 3S |

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit changes: `git commit -am 'Add my feature'`
4. Push to branch: `git push origin feature/my-feature`
5. Submit a Pull Request

### Development Guidelines

- Write tests for new functionality
- Update documentation for API changes
- Follow existing code style
- Test on real devices before submitting

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Garmin Connect IQ team for the SDK
- Community testers for feedback and bug reports

## Support

- **Issues**: [GitHub Issues](https://github.com/forsterflorian-cyber/FuelPlaner/issues)
- **Discussions**: [GitHub Discussions](https://github.com/forsterflorian-cyber/FuelPlaner/discussions)

---

**Version**: 0.1.0 | **Min API Level**: 3.0.0 | **Languages**: English, German