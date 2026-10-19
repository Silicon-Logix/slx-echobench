<!-- Silicon LogiX / SLX EchoBench
Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
License: Silicon LogiX Evaluation License 1.0. See LICENSE. -->

# SLX EchoBench API v1

UTF-8 JSON objects, one per line, inherited private stdin/stdout pipes. No listening
socket, shared secret or mandatory service. Requests use the CellProof envelope:

```json
{"api":"slx.echobench/v1","id":1,"op":"open","params":{"profile":"demo-ut-weld-v1"}}
```

Success returns `{api,id,ok:true,result}`. Failure returns
`{api,id,ok:false,error:{code,message}}`. The opaque session from `open` belongs in
the top-level `session` field of subsequent modifying requests. It correlates
this inherited connection; it is not DRM or a credential for a network service.

| Operations | Purpose |
| --- | --- |
| `open`, `capabilities`, `diagnostics`, `state` | Version, edition, implemented profiles and authoritative state |
| `scenario.load` | `weld`, `intact`, `training`; optional unsigned 32-bit `seed` |
| `configuration.set` | Bounded velocity, attenuation, noise, gain, gates, filter, model processor and raster pitches |
| `probe.position` | `x_m`, `y_m`, `lift_m`, `tilt_deg`, `coupling` |
| `fault.set` | `none`, `coupling_loss`, `overflow` |
| `acquire` | Compute and append one 512-sample acquisition |
| `scan.start` | Bounded serpentine raster; optional `x_min_m`, `x_max_m`, `y_min_m`, `y_max_m` |
| `tick` | Advance 1–8 discrete acquisition/replay points (`count`) |
| `pause`, `resume`, `stop`, `simulation.reset` | Explicit state transitions, cancellation and reset |
| `frames.read` | `offset`, `limit` 1–128, `full`; paged recordings |
| `replay.seek`, `replay.start`, `replay.exit` | Select `index`, synchronized replay and return to acquisition |
| `calibration.reference`, `calibration.apply` | Synthetic 20/40 mm reference; `tof_20mm_us`, `tof_40mm_us` |
| `comparison.run` | Reprocess the same saved RF input with host model A and B |
| `processing.start`, `processing.state`, `processing.cancel` | Asynchronous real ThreadX A/B jobs on selected `index`; `profile` = `threadx_renode` or `rtl_cosimulation` |
| `annotation.add`, `training.reveal` | Add bounded `text` on an acquisition; reveal separate known reference |
| `storage.set`, `session.save`, `session.load` | Explicit user directory; simple `name` ending `.echo.json` |
| `nde.export`, `nde.import`, `nde.state`, `nde.cancel` | Bounded asynchronous NDE 4.4 single-A-scan mapping; see NDE_MAPPING.md |
| `report.get`, `report.export` | Report data and local HTML/JSON/CSV files from a simple base `name` |

`firmware.load` and `plugin.load` return
`CAPABILITY_UNAVAILABLE`. Customer modules are absent from the public binary.
Only the two included, hash-checked firmware artifacts can be executed. Core
capabilities, rather than hidden UI controls, enforce this boundary.

Coordinates are metres in the original Blender frame, time is simulated seconds,
sample time is microseconds, amplitude is signed normalized full scale, and displayed
depth/thickness are mm. Geometry is already Y-up after glTF import. Only incoming
pose values convert to `(x,z,-y)` once. Probe X −0.62…0.02 m; Y ±0.15 m; lift
0…0.08 m; tilt 0…12 degrees with lift at least 0.075 m. The nominal 0.5 mm gap
is declared as couplant; lift above 1 mm is treated as an air separation.

Each RF record contains pose, seed-derived input, configuration, calibration,
acquisition ID, monotonically increasing simulated time, 0.04 µs interval,
model version, effective coupling, actual host dropped-sample count and processing.
Every `tick` is bounded and UI frame rate does not directly advance the sample
clock. Host elapsed time is separately measured. No board-cycle equivalence is
claimed. Replay uses saved records and is labelled recorded replay.

Host model overflow removes 64 trailing samples in X −0.4…−0.2 m. The embedded
example has its own explicit 256-word FIFO burst contract and drops 256 words;
it consumes the exact saved Q15 input, including any host-model losses. Normal
embedded input is streamed through the FIFO. A and B differ only at quality
admission. Firmware gate processing supports unfiltered input at 0 dB gain.
Embedded results are attached as separate processing evidence and never silently
replace the host acquisition record or its maps.

Embedded jobs return immediately and run a separate native Renode process. Polling
returns `running`, `completed`, `cancelled`, `timeout` or `failed`. The core checks
artifact hashes, both mailbox signatures, build IDs and actual ThreadX timer ticks.
Jobs time out after 30 host seconds; STOP and client loss terminate the process
group. State changes wait for job completion or explicit cancellation. Job metadata
contains the RF/Q15 and firmware/RTL hashes and distinct host/simulated times.

Limits: 64 KiB requests, JSON nesting 32, 4096 acquisitions per session, 8192
events, 256 annotations of 600 UTF-8 bytes, 64 MiB session files. Partial requests
expire after 3 seconds; a client absent for 5 seconds stops motion and jobs.
The client bounds queues to 32 requests and response accumulation to 4 MiB.
Read small pages of full RF records to stay inside that response bound.

The default output directory is Documents / SLX EchoBench. `storage.set` chooses
an existing absolute user directory; filenames cannot contain traversal or path
separators. Symlink targets are rejected. Saves commit atomically. A bundle stores
canonical JSON and SHA-256; import validates input sizes, units, kinematics, clocks,
input checksums and reproducible processing before replacing the current session.
Checksums detect corruption and are not publisher signatures. Imported evidence
and replay do not execute arbitrary firmware or scripts.

Session storage uses exact signed Q15 integer arrays, with an explicit encoding
marker. RF/envelope views are reconstructed and checked against saved processing
summaries, avoiding redundant arrays and preserving lossless model roundtrip.
At most 64 embedded processing executions are retained per session.

Schemas are `slx.echobench.session/v1`, `slx.echobench.bundle/v1`,
`slx.echobench.report/v1`, `slx.echobench.comparison/v1` and
`slx.echobench.points/v1`. CSV names include their units. A session remains usable
independently of the NDE adapter. The declared NDE 4.4 single-A-scan mapping is
validated and roundtripped; general device .nde and DICONDE remain unsupported.
