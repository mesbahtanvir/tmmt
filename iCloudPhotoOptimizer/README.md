# iCloud Photo Optimizer

A native macOS app to optimize your iCloud Photos library by detecting and removing duplicates, similar photos, and low-quality images. **All processing is done locally** - no photos are ever uploaded to external servers.

## Features

### 🔍 Duplicate Detection
- **Exact duplicates** - SHA256 hash matching
- **Near-duplicates** - Perceptual hashing (pHash, dHash)
- **Same content** - Visual similarity analysis

### 📸 Similar Photo Grouping
- Groups burst shots and sequential photos
- Finds visually similar images across your library
- Recommends the best quality photo to keep

### ✨ Quality Analysis
- **Blur detection** - Laplacian variance analysis
- **Exposure issues** - Detects under/overexposed photos
- **Resolution check** - Flags low-resolution images

### 🔒 Privacy First
- All processing runs locally on your Mac
- Uses Apple's on-device ML (Vision framework)
- No cloud uploads, no external API calls
- Your photos never leave your device

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building)

## Installation

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/iCloudPhotoOptimizer.git
cd iCloudPhotoOptimizer

# Build the project
swift build

# Run the app
swift run
```

### Using Xcode

1. Open `Package.swift` in Xcode
2. Select the `iCloudPhotoOptimizer` scheme
3. Build and run (⌘R)

## Usage

### 1. Grant Photo Access
On first launch, the app will request access to your Photos library. This is required to scan and analyze your photos.

### 2. Add Photo Sources
- **iCloud Photos Library** - Automatically added
- **Local Folders** - Click "Add" to include additional folders

### 3. Start Scanning
Click "Scan Now" to begin analyzing your photos. The scan is:
- **Incremental** - Only new photos are analyzed
- **Resumable** - Progress is saved if interrupted
- **Non-blocking** - Browse results while scanning continues

### 4. Review Results
Navigate through the tabs to review:
- **Duplicates** - Exact and near-duplicate groups
- **Similar** - Groups of similar photos
- **Quality** - Photos with quality issues

### 5. Clean Up
Select photos to delete and click "Move to Trash". Photos remain in Trash for 30 days and can be recovered.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Space` | Toggle selection |
| `→` / `←` | Navigate photos in group |
| `K` | Keep focused photo |
| `D` | Mark for deletion |
| `S` | Skip group |
| `⌘A` | Select all |
| `⌘⇧A` | Deselect all |
| `⌘Z` | Undo |
| `⌘⏎` | Execute deletion |

## Architecture

```
iCloudPhotoOptimizer/
├── Sources/
│   ├── App/                  # App entry point and state
│   ├── Models/               # Data models
│   ├── Views/                # SwiftUI views
│   │   ├── Dashboard/
│   │   ├── Duplicates/
│   │   ├── Similar/
│   │   ├── Quality/
│   │   ├── Settings/
│   │   └── Components/       # Reusable UI components
│   ├── Services/             # Business logic
│   │   ├── PhotoLibraryManager.swift
│   │   ├── ImageAnalyzer.swift
│   │   └── ScanPersistenceManager.swift
│   └── Utilities/            # Helpers and extensions
└── Tests/                    # Unit tests
```

## Technical Details

### Image Analysis Pipeline

1. **Thumbnail Loading** - Load thumbnails first for efficiency
2. **Perceptual Hashing** - Generate pHash for similarity detection
3. **Quality Metrics** - Calculate blur, brightness, noise scores
4. **Feature Extraction** - Use Vision framework for ML features
5. **Grouping** - Cluster similar photos together

### Performance Optimizations

- **Batch Processing** - Process photos in batches of 100
- **Lazy Loading** - Load thumbnails on-demand
- **Background Processing** - Analysis runs on background threads
- **Caching** - Analysis results are cached to disk
- **Incremental Scanning** - Only analyze new/modified photos

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Apple's PhotoKit and Vision frameworks
- SwiftUI for the native macOS interface
