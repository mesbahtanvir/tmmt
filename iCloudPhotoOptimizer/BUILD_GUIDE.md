# Xcode Build Guide

A comprehensive guide to building iCloud Photo Optimizer in Xcode.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [System Requirements](#system-requirements)
3. [Opening the Project](#opening-the-project)
4. [Understanding the Project Structure](#understanding-the-project-structure)
5. [Build Configuration](#build-configuration)
6. [Building the Application](#building-the-application)
7. [Running the Application](#running-the-application)
8. [Running Tests](#running-tests)
9. [Debugging](#debugging)
10. [Distribution](#distribution)
11. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before building the project, ensure you have the following installed:

### Required Software

| Software | Minimum Version | Download |
|----------|-----------------|----------|
| macOS | 14.0 (Sonoma) | System Software Update |
| Xcode | 15.0 | [Mac App Store](https://apps.apple.com/app/xcode/id497799835) |
| Command Line Tools | Latest | `xcode-select --install` |

### Verify Installation

Open Terminal and run:

```bash
# Check Xcode version
xcodebuild -version
# Expected: Xcode 15.0 or higher

# Check Swift version
swift --version
# Expected: Swift 5.9 or higher

# Check Command Line Tools
xcode-select -p
# Expected: /Applications/Xcode.app/Contents/Developer
```

---

## System Requirements

### Development Machine

- **Processor**: Apple Silicon (M1/M2/M3) or Intel Core i5+
- **Memory**: 8 GB RAM minimum (16 GB recommended)
- **Storage**: 10 GB free disk space
- **macOS**: 14.0 Sonoma or later

### Target Platform

- **Platform**: macOS
- **Minimum Deployment Target**: macOS 14.0 (Sonoma)
- **Architectures**: arm64 (Apple Silicon), x86_64 (Intel)

---

## Opening the Project

This project uses Swift Package Manager (SPM), so there is no `.xcodeproj` or `.xcworkspace` file. Instead, you open the `Package.swift` manifest directly.

### Method 1: Using Finder (Recommended)

1. Open Finder and navigate to the project folder:
   ```
   iCloudPhotoOptimizer/
   ```
2. Right-click on `Package.swift`
3. Select **Open With** > **Xcode**

### Method 2: Using Xcode Menu

1. Launch Xcode
2. Select **File** > **Open** (or press `Cmd + O`)
3. Navigate to `iCloudPhotoOptimizer/Package.swift`
4. Click **Open**

### Method 3: Using Terminal

```bash
cd /path/to/iCloudPhotoOptimizer
open Package.swift
```

Or explicitly with Xcode:

```bash
open -a Xcode Package.swift
```

### What Happens When You Open

When Xcode opens `Package.swift`:

1. Xcode reads the package manifest
2. Resolves any package dependencies (none for this project)
3. Generates an internal Xcode project structure
4. Creates a `.swiftpm/` directory for build data
5. Automatically selects the `iCloudPhotoOptimizer` scheme

---

## Understanding the Project Structure

### Source File Organization

```
iCloudPhotoOptimizer/
├── Package.swift              # Swift Package Manager manifest
├── README.md                  # Project documentation
├── BUILD_GUIDE.md             # This file
│
├── Sources/                   # Main source code
│   ├── App/                   # Application entry point
│   │   ├── iCloudPhotoOptimizerApp.swift   # @main entry
│   │   ├── ContentView.swift               # Root view
│   │   └── AppState.swift                  # State management
│   │
│   ├── Models/                # Data structures
│   │   ├── Photo.swift
│   │   ├── DuplicateGroup.swift
│   │   ├── SimilarGroup.swift
│   │   └── QualityIssue.swift
│   │
│   ├── Services/              # Business logic
│   │   ├── PhotoLibraryManager.swift      # PhotoKit integration
│   │   ├── ImageAnalyzer.swift            # Analysis engine
│   │   ├── ScanPersistenceManager.swift   # Session persistence
│   │   ├── ThumbnailCacheManager.swift    # Caching
│   │   ├── iCloudDownloadManager.swift    # iCloud sync
│   │   ├── UndoManager.swift              # Undo/redo
│   │   └── ReportExporter.swift           # Export functionality
│   │
│   ├── Views/                 # SwiftUI views
│   │   ├── Dashboard/
│   │   ├── Duplicates/
│   │   ├── Similar/
│   │   ├── Quality/
│   │   ├── Settings/
│   │   └── Components/
│   │
│   ├── Utilities/             # Helper code
│   │   ├── PerceptualHash.swift
│   │   └── Extensions.swift
│   │
│   └── ViewModels/
│       └── KeyboardNavigationHandler.swift
│
└── Tests/                     # Unit tests
    └── PerceptualHashTests.swift
```

### Framework Dependencies

The project uses only Apple frameworks (no external dependencies):

| Framework | Purpose |
|-----------|---------|
| SwiftUI | Native macOS UI |
| Combine | Reactive data flow |
| Photos | Photo library access (PhotoKit) |
| Vision | ML-based image analysis |
| CoreImage | Image processing |
| CryptoKit | SHA256 hashing |
| Accelerate | DCT calculations |
| PDFKit | PDF report generation |
| AppKit | macOS-specific UI elements |

---

## Build Configuration

### Package.swift Settings

The project is configured in `Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iCloudPhotoOptimizer",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "iCloudPhotoOptimizer",
            path: "Sources"
        ),
        .testTarget(
            name: "iCloudPhotoOptimizerTests",
            dependencies: ["iCloudPhotoOptimizer"],
            path: "Tests"
        )
    ]
)
```

### Build Settings in Xcode

After opening the project, you can view/modify build settings:

1. In the Navigator panel, select the package (top item)
2. In the Editor area, select your target
3. Click **Build Settings** tab

Key settings:

| Setting | Value |
|---------|-------|
| Swift Language Version | 5.9 |
| macOS Deployment Target | 14.0 |
| Build Active Architecture Only | Yes (Debug) / No (Release) |
| Optimization Level | None (Debug) / Optimize for Speed (Release) |

---

## Building the Application

### Quick Build

**Keyboard Shortcut**: `Cmd + B`

Or via menu: **Product** > **Build**

### Build for Specific Configuration

#### Debug Build (Default)

```
Product > Build
```

Or use keyboard: `Cmd + B`

Debug builds include:
- Debug symbols for breakpoints
- No optimization (faster build times)
- Assertions enabled
- Verbose logging

#### Release Build

1. Select **Product** > **Scheme** > **Edit Scheme** (or `Cmd + Shift + ,`)
2. In the left sidebar, select **Run**
3. Change **Build Configuration** from `Debug` to `Release`
4. Click **Close**
5. Build with `Cmd + B`

Release builds include:
- Full optimization
- Stripped debug symbols
- Smaller binary size
- Better runtime performance

### Clean Build

If you encounter build issues, try a clean build:

1. **Clean Build Folder**: `Cmd + Shift + K`
2. Then build: `Cmd + B`

Or from menu:
1. **Product** > **Clean Build Folder**
2. **Product** > **Build**

### Build Output Location

By default, build artifacts are placed in:

```
~/Library/Developer/Xcode/DerivedData/iCloudPhotoOptimizer-<hash>/
```

To find the built application:

1. **Product** > **Show Build Folder in Finder**
2. Navigate to `Build/Products/Debug/` or `Build/Products/Release/`

---

## Running the Application

### Run in Xcode

**Keyboard Shortcut**: `Cmd + R`

Or via menu: **Product** > **Run**

This will:
1. Build the project (if needed)
2. Launch the application
3. Attach the debugger

### Run Without Building

If you've already built and just want to run:

**Keyboard Shortcut**: `Cmd + Ctrl + R`

Or: **Product** > **Run Without Building**

### Stop Running

**Keyboard Shortcut**: `Cmd + .`

Or: **Product** > **Stop**

### First Launch

On first launch, the app will request permission to access your Photos library:

1. A system dialog will appear
2. Click **OK** to grant access
3. The app will begin scanning your photo library

---

## Running Tests

### Run All Tests

**Keyboard Shortcut**: `Cmd + U`

Or via menu: **Product** > **Test**

### Run Specific Test

1. Open the Test Navigator: `Cmd + 6`
2. Click the play button next to a specific test or test class

### Test Target

The test target is defined in `Package.swift`:

```swift
.testTarget(
    name: "iCloudPhotoOptimizerTests",
    dependencies: ["iCloudPhotoOptimizer"],
    path: "Tests"
)
```

### Current Test Files

- `Tests/PerceptualHashTests.swift` - Tests for perceptual hashing algorithms

### View Test Results

1. Open Report Navigator: `Cmd + 9`
2. Select the test run from the list
3. View pass/fail status for each test

---

## Debugging

### Setting Breakpoints

1. Click on the line number gutter in the source editor
2. A blue arrow appears indicating the breakpoint

### Breakpoint Types

- **Regular Breakpoint**: Click line number
- **Conditional Breakpoint**: Right-click breakpoint > **Edit Breakpoint** > Add condition
- **Exception Breakpoint**: Debug Navigator > **+** > **Exception Breakpoint**

### Debug Console

View the debug console: **View** > **Debug Area** > **Activate Console**

Or: `Cmd + Shift + C`

### Debug Navigator

View threads and call stacks: `Cmd + 7`

### LLDB Commands

In the debug console, you can use LLDB commands:

```lldb
// Print variable value
po variableName

// Print expression
p 1 + 1

// View memory
memory read address

// Continue execution
continue

// Step over
next

// Step into
step
```

### View Variables

While paused at a breakpoint:

1. Hover over variables in source code to see values
2. Use the Variables View in the Debug Area
3. Use `po` in the debug console

---

## Distribution

### Archive for Distribution

1. Set scheme to **Release** configuration
2. **Product** > **Archive**
3. Wait for the archive to complete
4. Organizer window will open

### Export Options

From the Organizer:

1. Select your archive
2. Click **Distribute App**
3. Choose distribution method:
   - **App Store Connect** - For Mac App Store
   - **Developer ID** - For direct distribution (notarized)
   - **Copy App** - For local testing
   - **Development** - For testing on registered devices

### Code Signing

For distribution, you need:

1. **Apple Developer Account** (free or paid)
2. **Signing Certificate**:
   - Development: `Apple Development`
   - Distribution: `Developer ID Application` or `Apple Distribution`
3. **Provisioning Profile** (if applicable)

### Notarization

For apps distributed outside the App Store:

1. Archive the app
2. Export with **Developer ID** distribution
3. Enable **Notarize** option
4. Xcode will upload to Apple for notarization
5. Wait for approval (usually minutes)
6. Export the notarized app

---

## Troubleshooting

### Common Build Errors

#### "No such module 'Photos'"

**Cause**: Framework not linked properly.

**Solution**:
1. Clean build folder: `Cmd + Shift + K`
2. Rebuild: `Cmd + B`

#### "Compiling for macOS 14.0, but module was compiled for macOS 13.0"

**Cause**: Cached modules from different deployment target.

**Solution**:
1. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/iCloudPhotoOptimizer-*
   ```
2. Rebuild

#### "Cannot find 'XXX' in scope"

**Cause**: Missing import or typo.

**Solution**: Check that the file imports required frameworks:
```swift
import SwiftUI
import Photos
import Vision
```

#### Package Resolution Failed

**Cause**: Network issues or corrupted cache.

**Solution**:
1. **File** > **Packages** > **Reset Package Caches**
2. **File** > **Packages** > **Resolve Package Versions**

### Runtime Issues

#### "Photos access denied"

**Cause**: App doesn't have photo library permission.

**Solution**:
1. Open System Settings
2. Go to **Privacy & Security** > **Photos**
3. Enable access for iCloud Photo Optimizer

#### App crashes on launch

**Cause**: Could be various issues.

**Solution**:
1. Check Console.app for crash logs
2. Run in Xcode debugger to see stack trace
3. Ensure macOS 14.0+ is installed

### Performance Issues

#### Build takes too long

**Solutions**:
1. Enable **Build Active Architecture Only** for Debug
2. Use `Cmd + Shift + K` to clean, then build
3. Close other Xcode projects
4. Increase RAM if possible

#### App runs slowly

**Solutions**:
1. Build in Release configuration
2. Check for memory leaks with Instruments
3. Profile with Xcode Instruments: **Product** > **Profile** (`Cmd + I`)

### Xcode Issues

#### Xcode freezes or becomes unresponsive

**Solutions**:
1. Force quit Xcode: `Cmd + Option + Escape`
2. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
3. Restart Mac

#### Autocomplete not working

**Solutions**:
1. Wait for indexing to complete (check progress bar)
2. **Product** > **Clean Build Folder**
3. Delete DerivedData and reopen project

---

## Keyboard Shortcuts Reference

| Action | Shortcut |
|--------|----------|
| Build | `Cmd + B` |
| Run | `Cmd + R` |
| Stop | `Cmd + .` |
| Test | `Cmd + U` |
| Clean Build Folder | `Cmd + Shift + K` |
| Archive | (via Product menu) |
| Show/Hide Navigator | `Cmd + 0` |
| Show Project Navigator | `Cmd + 1` |
| Show Debug Navigator | `Cmd + 7` |
| Show Breakpoint Navigator | `Cmd + 8` |
| Show Report Navigator | `Cmd + 9` |
| Toggle Debug Area | `Cmd + Shift + Y` |
| Open Quickly | `Cmd + Shift + O` |
| Find in Project | `Cmd + Shift + F` |
| Edit Scheme | `Cmd + Shift + ,` |

---

## Additional Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Swift Package Manager](https://swift.org/package-manager/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [PhotoKit Documentation](https://developer.apple.com/documentation/photokit)
- [Vision Framework](https://developer.apple.com/documentation/vision)

---

## Support

If you encounter issues not covered in this guide:

1. Check the project's GitHub Issues
2. Review Apple Developer Forums
3. Consult Stack Overflow with relevant tags

---

*Last updated: December 2024*
