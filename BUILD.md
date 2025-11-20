# Build Instructions

## Creating a Release Build

This project uses git tags for versioning. Follow these steps to create a release:

### 1. Create a Git Tag

First, create and push a git tag with the version number:

```powershell
# Create a tag (e.g., v1.0.0, v1.0.1, v1.1.0, etc.)
git tag v1.0.0

# Push the tag to remote (optional)
git push origin v1.0.0
```

### 2. Run the Build Script

The build script will automatically:
- Extract the version from the latest git tag
- Update `pubspec.yaml` with that version
- Build the Windows release
- Create a zip file named `ble_per_monitor_<version>_release.zip`

```powershell
# Run the build script
.\build_release.ps1
```

### 3. Distribute

The zip file will be created in the project root directory and is ready to distribute.

## Version Numbering

We use [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** (e.g., 1.0.0)
  - **MAJOR**: Incompatible API changes
  - **MINOR**: New functionality (backwards compatible)
  - **PATCH**: Bug fixes (backwards compatible)

Examples:
- `v1.0.0` - Initial release
- `v1.0.1` - Bug fix
- `v1.1.0` - New feature
- `v2.0.0` - Breaking changes

## Manual Build (without script)

If you prefer to build manually:

```powershell
# Update version in pubspec.yaml manually
# Then build:
flutter build windows --release --build-name=1.0.0

# Create zip:
Compress-Archive -Path build\windows\x64\runner\Release -DestinationPath ble_per_monitor_release.zip
```

## Troubleshooting

### "No git tags found" Error
Create a tag first:
```powershell
git tag v1.0.0
```

### Build Fails
Make sure Flutter is installed and in your PATH:
```powershell
flutter doctor
```
