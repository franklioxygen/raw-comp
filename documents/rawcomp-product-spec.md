# RawComp macOS Product Specification

## Overview

RawComp is a native macOS desktop application for comparing multiple images side by side with synchronized inspection tools. It is intended for photographers, retouchers, designers, and reviewers who need to compare RAW files, compressed exports, camera variants, edits, crops, color treatments, sharpness, noise, and metadata differences quickly.

The first production version should focus on fast local viewing, reliable format support, precise side-by-side comparison, and an interface that stays out of the way while inspecting image quality.

## Goals

- Compare 2, 3, 4, or 6 images on one screen.
- Open common compressed image formats and broad camera RAW formats.
- Provide smooth zoom, pan, rotate, and fit controls.
- Let users link or unlink viewport position, zoom, rotation, and navigation across images.
- Show useful image metadata for technical comparison.
- Support keyboard-driven review workflows.
- Preserve color accuracy as much as possible using macOS color management.
- Handle very large images without freezing the interface.

## Non-Goals for Version 1

- Full RAW development controls like Lightroom or Capture One.
- Destructive image editing.
- Cloud sync, account login, or online libraries.
- Catalog management across a whole photo archive.
- Batch export pipelines beyond simple comparison-session export.

## Target Platform

- macOS native desktop app.
- Recommended minimum: macOS 14 Sonoma or later.
- Architecture: Apple Silicon first, with Intel support if dependencies remain practical.
- Distribution targets:
  - Direct `.dmg` download for early builds.
  - Optional Mac App Store release later, depending on native dependency and sandboxing constraints.

## Suggested Technology Stack

- UI: SwiftUI for the main app shell and controls.
- Image interaction surface: AppKit-backed `NSViewRepresentable` or Metal-backed custom view for high-performance zooming and panning.
- Native image decoding: Apple Image I/O and Core Image.
- RAW decoding: LibRaw integrated as a native dependency.
- Metadata reading: Image I/O metadata first, ExifTool-compatible parser or bundled metadata helper later if deeper maker-note support is needed.
- Rendering acceleration: Core Image and Metal.
- Persistence: local JSON or SQLite for recent sessions, view state, and preferences.

## Format Support

RawComp should accept files by extension, MIME type, and decoder probing. Extension checks should be treated as a user-facing convenience, not the final source of truth.

### RAW and Camera Formats

Target RAW support includes:

- `.dng`
- `.arw`
- `.srf`
- `.sr2`
- `.cr2`
- `.cr3`
- `.crw`
- `.nef`
- `.nrw`
- `.raf`
- `.rw2`
- `.rw1`
- `.orf`
- `.ori`
- `.pef`
- `.ptx`
- `.kdc`
- `.dcr`
- `.k25`
- `.erf`
- `.mef`
- `.mos`
- `.iiq`
- `.3fr`
- `.fff`
- `.x3f`
- `.srw`
- `.bay`
- `.cap`
- `.tif`
- `.tiff`

### Compressed and Standard Formats

Target compressed or standard image support includes:

- `.jpg`
- `.jpeg`
- `.png`
- `.webp`
- `.heic`
- `.heif`
- `.gif`
- `.tif`
- `.tiff`

### Decode Strategy

1. Try Apple Image I/O first for standard formats and platform-supported camera formats.
2. Use LibRaw for RAW formats or when Image I/O cannot decode a supported camera file.
3. Prefer embedded previews for fast initial display of large RAW files.
4. Decode full-resolution RAW data asynchronously after the preview appears.
5. Cache decoded thumbnails, previews, and full-resolution tiles.
6. Surface a clear error state when a file extension is recognized but the actual file cannot be decoded.

## Core Comparison Modes

RawComp should provide fixed comparison layouts:

- 2-up horizontal
- 2-up vertical
- 3-up row
- 3-up primary plus two secondary panes
- 4-up grid
- 6-up grid

The user should be able to switch layouts without losing loaded images or viewport state.

## Image View Controls

Each image pane should support:

- Zoom in and out.
- Pan by mouse drag or trackpad.
- Rotate clockwise and counterclockwise.
- Reset rotation.
- Fit to pane.
- Fill pane.
- Actual pixels / 100% zoom.
- Center image.
- Temporary loupe view.
- Toggle background color: black, white, gray, checkerboard.

Shared toolbar controls should apply to either the selected pane or all linked panes depending on link mode.

## Linked View Behavior

RawComp should support linking and unlinking:

- Pan position.
- Zoom level.
- Rotation.
- Fit mode.
- Image navigation.

Recommended link modes:

- Unlinked: every pane moves independently.
- Link pan and zoom: position and zoom synchronize, rotation remains independent.
- Link all transforms: pan, zoom, rotation, and fit mode synchronize.
- Link selected panes: only chosen panes synchronize.

When linked panes have different dimensions or aspect ratios, synchronization should be normalized by image-relative coordinates. For example, the center point should map to percentage coordinates rather than raw pixels.

## Synchronized Highlight Border

RawComp should provide a simple synchronized highlight border tool so small detail differences are easier to spot across images.

The user should be able to:

- Turn highlight borders on or off.
- Draw or position a rectangular highlight region in the active pane.
- Synchronize the same highlight region across linked panes using image-relative coordinates.
- Move and resize the highlight region in any linked pane and see the matching region update in the other linked panes.
- Choose a small set of high-visibility border colors, such as yellow, cyan, red, white, and black.
- Adjust border thickness.
- Hide highlight borders temporarily without deleting them.
- Reset all highlight borders.

The highlight border should be an overlay only. It should never modify image pixels or exported source files. When exporting the current comparison view, the user should be able to choose whether highlight borders are included.

## Session Workflow

Users should be able to:

- Open individual image files.
- Drag and drop images into panes.
- Open a folder and choose images from a filmstrip.
- Replace an image in a pane without rebuilding the whole layout.
- Save a comparison session.
- Reopen recent sessions.
- Copy the current comparison view as an image.
- Export the current comparison layout as PNG or TIFF.

## Helpful Review Features

Recommended additional features for a useful first version:

- Metadata panel showing camera, lens, focal length, aperture, shutter speed, ISO, dimensions, file size, color profile, date captured, and file path.
- Histogram panel per selected image.
- RGB value readout under cursor.
- Difference overlay for two-image mode.
- A/B blink comparison for two selected images.
- Split-view wipe comparison for two selected images.
- Synchronized highlight border overlay for calling attention to matching regions across panes.
- Rating and flag markers stored in the RawComp session.
- Filename labels and optional metadata badges in each pane.
- Keyboard shortcuts for layout changes, zoom, fit, rotate, linking, next image, previous image, and pane selection.
- Recent files and recent folders.
- Missing-file handling when reopening saved sessions.

## User Interface Structure

Recommended main window layout:

- Top toolbar:
  - Open files.
  - Open folder.
  - Layout selector: 2, 3, 4, 6.
  - Link mode selector.
  - Highlight border toggle and color selector.
  - Zoom controls.
  - Rotate controls.
  - Fit / 100% controls.
  - Export comparison.

- Center workspace:
  - Resizable comparison grid.
  - Each pane contains the image canvas, filename, zoom percentage, and decode status.

- Bottom filmstrip:
  - Optional thumbnail browser for loaded files or current folder.
  - Drag thumbnails into panes.

- Right inspector:
  - Metadata.
  - Histogram.
  - File details.
  - View transform values.

The filmstrip and inspector should be collapsible to maximize comparison space.

## Interaction Details

Recommended mouse and trackpad behavior:

- Scroll or pinch: zoom.
- Space + drag: pan.
- Double click: toggle fit and 100%.
- Click pane: select active pane.
- Drag file over pane: highlight drop target.
- Hold Option while linked: temporarily manipulate only the active pane.
- Hold Shift while panning: constrain horizontal or vertical movement.

Recommended keyboard shortcuts:

- `Command+O`: open images.
- `Command+Shift+O`: open folder.
- `1`: select 2-up layout.
- `2`: select 3-up layout.
- `3`: select 4-up layout.
- `4`: select 6-up layout.
- `Command++`: zoom in.
- `Command+-`: zoom out.
- `Command+0`: fit to pane.
- `Command+1`: actual pixels.
- `R`: rotate clockwise.
- `Shift+R`: rotate counterclockwise.
- `L`: cycle link mode.
- Arrow keys: move selection or navigate images.

## Performance Requirements

- Initial window launch should feel immediate.
- Standard compressed images should appear within a few hundred milliseconds when practical.
- Large RAW files should show embedded preview first, then full decode.
- UI should remain responsive while decoding.
- Decoding should be cancellable if the user replaces or closes an image.
- Memory use should be bounded by tile caching and downsampled display buffers.
- The app should avoid decoding six full-resolution RAW files at once unless needed for the current zoom level.

## Color and Rendering Requirements

- Respect embedded ICC profiles.
- Convert display output through macOS color management.
- Provide a warning or fallback label for missing or unsupported color profiles.
- Preserve bit depth internally where practical for RAW and TIFF workflows.
- Avoid applying opinionated RAW development looks by default.
- Use a neutral default preview profile when full RAW color processing is not available.

## Error Handling

RawComp should show clear, non-blocking errors for:

- Unsupported file.
- Corrupt file.
- Missing file.
- Permission denied.
- RAW decode failed.
- Metadata read failed.
- File too large for current memory limits.

Each failed pane should still show filename, path, and the reason it failed.

## Accessibility

- Full keyboard access for main comparison workflows.
- VoiceOver labels for toolbar controls and panes.
- High-contrast friendly UI.
- Adjustable pane label size.
- No color-only status indicators.

## File and Session Model

A RawComp session should store:

- Loaded file paths.
- Layout mode.
- Pane assignment.
- View transforms for each pane.
- Link mode.
- Ratings and flags.
- Collapsed or visible panels.
- Background color.

Session files can use a simple `.rawcomp` JSON document for version 1.

## Proposed App Modules

- `RawCompApp`: app entry point and window scene.
- `ComparisonWorkspace`: main layout and pane orchestration.
- `ImagePaneView`: single pane canvas and controls.
- `ImageDecodeService`: async decode pipeline.
- `RawDecodeService`: LibRaw integration.
- `MetadataService`: EXIF, IPTC, XMP, and file metadata.
- `ThumbnailCache`: disk and memory cache for thumbnails.
- `SessionStore`: save and restore `.rawcomp` sessions.
- `LinkController`: synchronizes transforms between panes.
- `ExportService`: renders current comparison layout.

## Version 1 Milestone Plan

### Milestone 1: App Foundation

- Create SwiftUI macOS app.
- Implement main window, toolbar, and comparison grid.
- Support 2-up, 3-up, 4-up, and 6-up empty layouts.
- Add drag and drop into panes.

### Milestone 2: Standard Image Viewing

- Load JPEG, PNG, TIFF, GIF, HEIC, HEIF, and WebP through Image I/O where available.
- Add zoom, pan, fit, fill, 100%, and rotate.
- Add selected-pane state and keyboard shortcuts.

### Milestone 3: Linked Comparison

- Add link modes for pan, zoom, rotation, and selected panes.
- Normalize linked pan positions across different image sizes.
- Add reset and temporary unlink behavior.

### Milestone 4: RAW Support

- Integrate LibRaw.
- Show embedded preview first.
- Decode full-resolution RAW asynchronously.
- Add RAW decode errors and fallback states.

### Milestone 5: Review Tools

- Add metadata inspector.
- Add histogram.
- Add RGB cursor readout.
- Add filmstrip for folder browsing.

### Milestone 6: Sessions and Export

- Save and reopen `.rawcomp` sessions.
- Export comparison view as PNG and TIFF.
- Add recent files and folders.

## Open Technical Questions

- Whether to ship LibRaw inside the app bundle or link it through a package manager during development only.
- Whether Mac App Store sandboxing is required for the first public release.
- How deep RAW color processing should go in version 1.
- Whether animated GIF should compare first frame only or support playback.
- Whether HEIC/HEIF behavior should rely entirely on system codecs or include an additional decoder.
- Whether `.tif` and `.tiff` should be treated as standard files first and RAW-like files only when decoder probing requires it.

## References

- [Apple Image I/O documentation](https://developer.apple.com/documentation/imageio)
- [Apple Image I/O Programming Guide: supported image formats](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/ImageIOGuide/imageio_basics/ikpg_basics.html)
- [LibRaw documentation](https://www.libraw.org/docs)
