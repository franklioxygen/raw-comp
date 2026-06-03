# RawComp

<p align="center">
<img width="300" height="300" alt="Gemini_Generated_Image_abysf5abysf5abys" src="https://github.com/user-attachments/assets/f243fc9f-c521-4b75-a801-7424d81ad1ad" />
</p>

<p align="center">
  <a href="README.zh-CN.md">中文文档</a>
</p>

RawComp is a macOS app for comparing multiple images side by side.

It is built for photographers, retouchers, and reviewers who need to inspect subtle differences between RAW files, compressed exports, edits, crops, sharpness, color, and local detail.

<p align="center">
<img width="862" height="567"  alt="Screenshot 2026-05-23 at 11 25 34 AM" src="https://github.com/user-attachments/assets/f92833ea-7fe3-42f5-9f39-2aa92a5f3f3f" />
</p>


## What You Can Do

- Compare `2`, `3`, `4`, or `6` images in one window.
- Open standard image formats and many common camera RAW formats.
- Zoom, pan, rotate, fit-to-window, and jump to `100%`.
- Link or unlink pane movement so all images move together or independently.
- Mark a synchronized highlight region to call attention to matching detail areas.
- Apply shared, non-destructive comparison adjustments across all loaded panes (Light, tone curve, color, B&W, presence, noise, optics, geometry).
- Use professional compare modes: clipping overlay, edge map, false color, noise emphasis, absolute difference, Delta E, blink, and wipe (2-up).
- Save and reopen `.rawcomp` comparison sessions with layout restoration; export the comparison grid as PNG or TIFF using each pane's current zoomed viewport.
- Inspect histogram, pixel readout, and file metadata for the active pane.

## Current Status

RawComp is a focused comparison tool in active development.

What works well now:

- Multi-pane side-by-side viewing (2 / 3 / 4 / 6)
- Linked or free viewport inspection
- Synchronized highlight region
- Sectioned comparison inspector with bypass, presets, and autosave
- Histogram, clipping indicators, and cursor readout
- Compare modes including difference, wipe, and blink (2-up layout)
- Session save/open with multi-pane layout restoration, and comparison export from the current viewport
- Metadata inspection and 8 UI languages

What is still planned (see [product spec](documents/rawcomp-product-spec.md)):

- Deeper RAW decoding with LibRaw
- Folder browser / filmstrip workflow
- Ratings and flags in sessions
- Manufacturer lens profiles and calibrated flat-field workflows

Adjustment-system details: [comparison-adjustments-dev-spec.md](documents/comparison-adjustments-dev-spec.md)

## Supported Formats

RawComp is designed to work with compressed images and broad RAW camera formats.

Target extensions currently recognized:

- RAW and camera formats:
  `dng`, `arw`, `srf`, `sr2`, `cr2`, `cr3`, `crw`, `nef`, `nrw`, `raf`, `rw2`, `rw1`, `orf`, `ori`, `pef`, `ptx`, `kdc`, `dcr`, `k25`, `erf`, `mef`, `mos`, `iiq`, `3fr`, `fff`, `x3f`, `srw`, `bay`, `cap`, `tif`, `tiff`
- Standard formats:
  `jpg`, `jpeg`, `png`, `webp`, `heic`, `heif`, `gif`, `tif`, `tiff`

Important note:

The current build uses macOS image decoders and Quick Look preview fallback. That means support for some RAW files depends on what the local system can decode or preview. Some RAW files may open as previews rather than full decoded sensor data in the current version.

## macOS Requirements

- macOS 14 or newer
- Xcode with Swift 6 support if you want to run from source

## Download

Download the latest build from [Releases](https://github.com/franklioxygen/raw-comp/releases).

## Run RawComp

From this repository:

```bash
swift run RawComp
```

You can also open `Package.swift` in Xcode and run the app there.

## Basic Workflow

1. Launch RawComp.
2. Click `Open` to load images, or drag a file onto a pane.
3. Choose a layout: `2 Up`, `3 Up`, `4 Up`, or `6 Up`.
4. Switch between `Free` and `Synced` link mode depending on whether you want panes to move together.
5. Use zoom, fit, `100%`, and rotate controls from the toolbar.
6. Use `Mark Region` to capture the current visible area as a synchronized highlight region.
7. Expand inspector sections (Light, Color, Compare Modes, etc.) and drag sliders to amplify subtle differences.
8. Save a `.rawcomp` session when you want to restore the same pane layout later, or export the grid from the toolbar when you need to share the current zoomed view.

## Why Shared Adjustments Matter

Some image differences are hard to notice in a neutral view, especially in shadows, low-contrast textures, edges, compression artifacts, or fine noise patterns.

The shared adjustment controls let you push every image in the same way, so the comparison stays fair while making those differences easier to spot.

## Adjustable Controls

- Light: exposure, brightness, contrast, highlights, shadows, whites, blacks, gamma
- Tone Curve: master curve preset/custom curve, red curve preset/custom curve, green curve preset/custom curve, blue curve preset/custom curve
- Color: temperature, tint, vibrance, saturation, global hue shift
- Color Mixer: per-band hue, saturation, and luminance for red, orange, yellow, green, aqua, blue, purple, and magenta
- Black & White: monochrome compare plus per-band luminance for red, orange, yellow, green, aqua, blue, purple, and magenta
- Presence: clarity, texture, sharpening amount, sharpening radius, sharpening detail, sharpening masking, edge-map preview
- Noise: luminance noise reduction, luminance detail, luminance contrast, color noise reduction, color detail, color smoothness, purple defringe, green defringe, noise-emphasis preview
- Optics: lens profile correction, distortion amount, vignetting amount, chromatic aberration removal, flat-field correction
- Geometry: fine rotate, horizontal flip, vertical flip, crop aspect lock, crop overlay, crop rectangle
- Compare Modes: normal, luma only, clipping overlay, false color, edge map, noise emphasis, absolute difference, Delta E, blink, wipe
- Compare Mode Settings: reference pane, analysis gain, wipe position, blink interval

## Development

Verify the comparison-adjustments stack:

```bash
./scripts/verify_comparison_adjustments.sh
```

When debugging in Xcode, prefer launching as a real app bundle (avoids `CFBundleIdentifier` / window-tab console noise from bare `swift run` executables):

```bash
./scripts/run-debug-app.sh
```

Or set the Xcode scheme **Run** executable to `dist/RawComp-Debug.app`.

RawComp remains a comparison tool, not a full photo library or destructive RAW editor.

## Product Spec

The longer planning document is here:

[rawcomp-product-spec.md](documents/rawcomp-product-spec.md)
