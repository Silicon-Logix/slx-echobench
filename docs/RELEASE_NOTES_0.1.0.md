<!-- Silicon LogiX / SLX EchoBench
Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
License: Silicon LogiX Evaluation License 1.0. See LICENSE. -->
# SLX EchoBench 0.1.0 — development preview

An offline Windows virtual ultrasonic laboratory with reproducible acquisition,
compiled firmware and inspection evidence.

The demo includes synthetic normal-beam A/B/C scans, calibration, coupling and
sample-loss faults, synchronized recording/replay, reports and the documented
NDE 4.4 single-A-scan mapping. Two included ThreadX builds execute in native
Renode on the same saved input, optionally through a Verilated FIFO.

The desktop layout supports resizing, maximized and ultrawide windows, adjustable
100–200% interface scale and physical-pixel rendering of the 3D view.

## Downloads

- **SLX-EchoBench-0.1.0-preview.zip**: complete Windows portable. Extract all files
  and launch `EchoBench.exe`; no Godot installation or Python/WSL is needed.
- **SLX-EchoBench-0.1.0-preview-public-source.zip**: public interface and complete
  binary demo SDK, including the native upstream runtime, for offline evaluation.
- **SHA256SUMS.txt**: SHA-256 checksums of the attached files. The manifest is
  unsigned; these checksums detect changes and do not constitute a digital signature.

The repository's automatically generated source archive contains the public Git
tree. Install pinned Renode using `python scripts/setup-runtime.py` before running
its firmware profiles. The complete SDK download above already contains it.

## Scope

This is an unsigned Windows x64 development evaluation under the included SLX
Evaluation License. The core implementation remains proprietary. Third-party
components retain their original licenses and notices.

The model is simplified and synthetic. General instrument NDE/DICONDE interchange,
validated real-world flaw sizing, advanced UT/AI, real hardware and enterprise
integration require dedicated development and validation.

Local checks include domain behavior, native firmware/RTL and cancellation,
official NDE-schema validation and exact roundtrip, responsive layout, and clean
portable/SDK execution without private sources. See `docs/VALIDATION.md` and
`validation/` for the actual scope and recorded results.

[Discuss a custom development](https://www.siliconlogix.it/contatti).
