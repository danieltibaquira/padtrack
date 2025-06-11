# Resources

This directory contains non-code resources for the DigitonePad application.

## Resource Categories

- **Audio**: Sample files, wavetables, impulse responses
- **Images**: App icons, UI graphics, background images
- **Localization**: String files for multiple languages
- **Data**: Configuration files, preset data, factory content
- **Documentation**: User guides, help files, tutorials

## Organization

Resources are organized by type and module:
```
Resources/
├── Audio/
│   ├── Samples/
│   ├── Wavetables/
│   └── Impulses/
├── Images/
│   ├── Icons/
│   ├── UI/
│   └── Backgrounds/
├── Localization/
│   ├── en.lproj/
│   └── [other languages]/
├── Data/
│   ├── Presets/
│   ├── Configs/
│   └── Factory/
└── Documentation/
    ├── UserGuide/
    ├── Help/
    └── Tutorials/
```

## Usage

Resources are accessed through the Bundle system and integrated into the application through the build process. 