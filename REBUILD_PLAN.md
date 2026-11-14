# Tendie Studio – Rebuild Plan

This branch replaces the V1 placeholder prototype with a real editor foundation.

## Product rule

A successful Xcode build is not sufficient for a release. A feature is complete only when it is implemented, build-verified, and its behavior is testable on an iPhone. Do not describe mock controls, stored-but-unplayed keyframes, or draft JSON as finished PosterBoard features.

## Current prototype audit

The previous `EditorView.swift` combines the data model, UI, import, motion preview, timeline, and export in one view. Its limitations include:

- The canvas is a static SwiftUI composition, not a robust transformable editing surface.
- The drag gesture only moves layers; there are no proper resize handles, pinch scaling, rotation handles, crop mode, or snapping.
- Imported data is stored as a single image byte array. Animated GIF/video playback is not implemented.
- Keyframes are appended to an array, but there is no playback engine or interpolation.
- Export serializes the layer array as JSON and merely gives the file a `.tendies` extension. This is not a verified PosterBoard format.
- Gyroscope input affects only the in-app preview.
- Import currently advertises image content only.

## Rebuild architecture

Split responsibilities into focused files and types:

- `Models/StudioProject.swift`: project document, canvas settings, serialization version.
- `Models/StudioLayer.swift`: stable layer identity, media reference, transform, appearance, visibility and lock state.
- `Models/AnimationTrack.swift`: typed property tracks, keyframes, interpolation and easing.
- `Services/MediaImporter.swift`: security-scoped file access, image/GIF/video inspection and asset copying.
- `Services/ProjectStore.swift`: project persistence and migration.
- `Services/PosterBoardExporter.swift`: isolated export implementation; no claimed compatibility until format is verified.
- `Motion/MotionController.swift`: CoreMotion input, smoothing and preview-only parallax.
- `Editor/StudioEditorView.swift`: editor composition.
- `Editor/CanvasView.swift`: canvas rendering and gestures.
- `Editor/LayerInspectorView.swift`: selected-layer controls.
- `Editor/TimelineView.swift`: timeline UI and playback controls.

## Delivery phases

### Phase 0 – Baseline and honesty
- Keep the current prototype available on `main`.
- Work on this rebuild branch.
- Establish clean project structure and build pipeline.
- Document which capabilities are app-preview-only and which can be exported.

### Phase 1 – Real canvas and layer editing
- Dark, polished editor shell with a large canvas.
- Add/import assets and show real thumbnails.
- Select, reorder, hide, lock, duplicate and delete layers.
- Move with one finger; pinch to resize; rotate with two fingers or a dedicated control.
- Explicit crop/fit/fill behavior.
- Undo/redo for editing operations.
- Persist and reopen a project without losing assets or transforms.

### Phase 2 – Media
- Animated GIF playback using a real frame/timing representation.
- Video import and preview with AVFoundation.
- Correct aspect-ratio and crop handling.
- Clear error messages for unsupported codecs or corrupt files.

### Phase 3 – Animation
- A real timeline with play/pause and time ruler.
- Typed tracks and keyframes for position, scale, rotation and opacity.
- Interpolation and easing.
- Loop, ping-pong and one-shot playback.
- Evaluate blur, glow, color and mask tracks after core playback is reliable.

### Phase 4 – Motion preview
- Per-layer parallax depth and axes.
- Sensitivity, smoothing and limits.
- Make clear this is an in-app preview unless the target wallpaper format demonstrably supports runtime motion.

### Phase 5 – Verified export
- Obtain genuine Descriptor and Container examples or authoritative format documentation.
- Reverse-engineer only where legally and technically appropriate; validate structure and assets against known-good examples.
- Implement each format as a separate exporter.
- Never label generic JSON as a compatible `.tendies` file.
- Test import/use in the target app or PosterBoard workflow before claiming compatibility.

## Release acceptance checklist

- [ ] Clean Xcode build on the cloud macOS runner.
- [ ] Install and launch on a real iPhone.
- [ ] Add multiple assets and preserve them after app restart.
- [ ] Move, pinch-scale and rotate layers without drift.
- [ ] Reorder, duplicate, hide, lock and delete layers.
- [ ] Undo and redo editing actions.
- [ ] GIF playback verified with a multi-frame test GIF.
- [ ] Video playback verified with a test clip, if included in the release.
- [ ] Timeline playback visibly interpolates between keyframes.
- [ ] Export is validated against the actual target format, not just a filename extension.
- [ ] No UI control is presented as functional if it is only decorative or a stub.

## Constraints

The developer/user workflow is iPhone-only. Use GitHub and cloud macOS Actions for source changes and builds. Keep commits small, inspect workflow logs, and do not send an IPA as a finished version until the relevant acceptance checks have been performed.
