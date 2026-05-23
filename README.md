# RawComp

<p align="center">
<img width="300" height="300" alt="Gemini_Generated_Image_abysf5abysf5abys" src="https://github.com/user-attachments/assets/f243fc9f-c521-4b75-a801-7424d81ad1ad" />
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
- Apply shared comparison adjustments across all loaded panes: exposure, brightness, contrast, saturation, and detail sharpening.
- Inspect file metadata for the active pane.

## Current Status

RawComp is currently an early usable MVP.

What works well now:

- multi-pane side-by-side viewing
- linked viewport inspection
- synchronized highlight region
- shared image adjustments for making subtle differences easier to see
- metadata inspection

What is still in progress:

- deeper RAW decoding with LibRaw
- folder browser / filmstrip workflow
- session save and reopen
- export
- advanced comparison tools such as difference, wipe, and blink modes

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
7. Use the inspector sliders to adjust all loaded images together and make hard-to-see differences stand out.

## Why Shared Adjustments Matter

Some image differences are hard to notice in a neutral view, especially in shadows, low-contrast textures, edges, compression artifacts, or fine noise patterns.

The shared adjustment controls let you push every image in the same way, so the comparison stays fair while making those differences easier to spot.

## Planned Direction

RawComp is intended to become a focused comparison tool rather than a full photo library or RAW editor.

Planned improvements include:

- stronger RAW decoding coverage
- better highlight tools
- folder and filmstrip browsing
- saved sessions
- comparison export
- more technical inspection tools

## Product Spec

The longer planning document is here:

[rawcomp-product-spec.md](documents/rawcomp-product-spec.md)
