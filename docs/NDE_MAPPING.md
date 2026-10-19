<!-- Silicon LogiX / SLX EchoBench
Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
Author: Marco Pezzullo
License: Silicon LogiX Evaluation License 1.0. See LICENSE. -->

# NDE 4.4 single-A-scan subset

The operational mapping is `slx.echobench.nde-single-ascan/v1`. It exports one
selected complete, coupled, unsaturated acquisition. It imports only files using
this same documented mapping. General instrument .nde files and DICONDE are
outside the subset. No volumetric coverage, physical acquisition unit or instrument
compatibility is inferred from a successful file roundtrip.

The implementation follows the official [HDF5 structure](https://ndeformat.com/4.4/hdf5-structure/)
and [UT A-scan writing guidance](https://ndeformat.com/4.4/examples/code-samples/writing-ut-ascans/).
The exact upstream Properties/Setup 4.4.0 JSON schemas are included under
api/nde-schemas with a SHA-256 lock and the upstream MIT license. Both documents
are validated independently during qualification. Runtime import applies an exact,
stricter match to this qualified metadata subset. Optional hardware-process metadata is omitted because the
source is synthetic software output; no real probe, serial number or hardware
acquisition process is invented.

| HDF5 object | Mapping |
| --- | --- |
| `/Properties` | Fixed-length UTF-8 JSON; format 4.4.0, UT method, synthetic SLX producer and UTC creation time |
| `/Public/Setup` | Validated General Mapping metadata; one group and one AScanAmplitude dataset |
| `/Public/Groups/0/Datasets/0-AScanAmplitude` | Little-endian float64, exactly `[1,1,512]`, no filters or compression |
| UCoordinate / VCoordinate | One laboratory X/Y position in native Blender metres; resolution 0.001 m is nominal for the single cell and establishes no raster coverage |
| Ultrasound | 512 samples, offset 0 s, resolution 4e-8 s (25 MS/s) |
| Data value | Stored normalized full scale −1…1, mapped to −100…100 Percent |
| `/Private/SLX/Session` | Mapping ID, source, selected index, original input hash, exact 16-bit quantization convention and checksummed native session document |

The public RF is reconstructed exactly from signed model integers divided by
32767. No gain, envelope, defect inference or calibration correction is baked
into the raw public waveform. Applied configuration, calibration, poses, events,
quality flags, annotations and compiled firmware/RTL evidence remain in the
native SLX extension. The entire native session is included, even though the
standard public dataset contains only the selected A-scan. `/Private` is an HDF5
vendor-extension namespace, not encryption or an access-control boundary.

Exports validate the actual generated file and recover the identical native
session before committing. Import checks the declared shape/type, every sample
with zero numerical tolerance, time/position axes, unit mapping and session
checksum. The C++ core then validates the native session transactionally and
reconstructs the host processing before replacing the current session. Imported
data enters recorded replay and does not execute firmware.

Files are bounded to 128 MiB; individual JSON metadata to 64 MiB. External/soft
links, external storage, virtual datasets, variable-length text and data filters
are rejected. The static C++/HDF5 adapter runs as a separate cancellable native process
with a 30-second host deadline; no system Python, network service or HDF5 install
is required. The local independent qualification reads the file with h5py,
validates both official schemas, checks exact RF and session roundtrip, and verifies
that altered RF, unsupported links, invalid-quality exports and traversal are rejected.
