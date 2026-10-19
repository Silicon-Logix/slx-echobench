<!-- Silicon LogiX / SLX EchoBench
Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
License: Silicon LogiX Evaluation License 1.0. See LICENSE. -->

# Verification and limitations

The local verification records are kept in validation/. No hardware qualification
or continuous collision proof is inferred from these checks.

| Requirement | Implementation and executed check |
| --- | --- |
| SLX family consistency | Reused CellProof theme, pipe client and About; compared actual workspace/About screenshots |
| Responsive desktop | 1200/1440/1920/2560-pixel widths, maximized mode, 150% UI scale, full window bounds and native 3D render resolution; contact visible |
| Causal pulse-echo | integration.py changes pose/coupling and verifies different samples and classifications |
| Intact / indication / not evaluable | Known reflector, off-reflector, intact variant, air/coupling/overflow cases |
| Model calibration | Two synthetic references; backwall thickness within 0.25 mm of the 40 mm model |
| Scan lifecycle | Start, pause, tick while paused, resume, completion and STOP; bounded buffers |
| A/B comparison | Exact saved input hashes, isolated overflow-admission rule, amplitude tolerance 1e-12 |
| NDE 4.4 subset | Official schema validation, independent exact RF/session roundtrip, tampering/link/quality/path rejection |
| Session and report | Atomic bundle save/load, SHA-256 cross-check, invalid import transaction, HTML escaping, unit-labelled CSV |
| Replay | Seek/play/stop; selected frame and pose agree; Return live restores sample time |
| Real embedded execution | Eight Linux Renode cases plus native Windows firmware/RTL jobs and cancellation |
| Firmware provenance | ARM ELFs, hashes, actual ThreadX ticks and gate result from executed mailbox |
| RTL | Verilated FIFO full/empty, ready/valid, ordered words, overflow, IRQ and reset; called from Renode |
| 3D contract | 18 extreme/intermediate interactive poses; contact and cable endpoint errors recorded |
| Cable obstacles | Centreline and four 1.8 mm offset rays against five selected rigid owners; sampled bend radius |
| Asset presentation | Imported 32-second clip sampled at 0/8/16/24/32 s and stopped before interactive ownership |
| Distribution | Separate allowlisted candidate, inventory audit, private-source exclusion and clean-copy smoke checks |

Run internally:

```powershell
./scripts/build-windows.ps1
python tests/embedded_native.py
python -m venv build/nde-tools
./build/nde-tools/Scripts/python.exe -m pip install -r scripts/nde-dependencies.lock.txt
./build/nde-tools/Scripts/python.exe tests/nde_workflow.py
./build/tools/godot/Godot_v4.5.2-stable_win64_console.exe --path godot --script ../tests/ui_workflow.gd
./build/tools/godot/Godot_v4.5.2-stable_win64_console.exe --path godot --script ../tests/responsive.gd
./build/tools/godot/Godot_v4.5.2-stable_win64_console.exe --path godot --script ../tests/performance.gd
python scripts/package.py
python scripts/verify-package.py
```

Reference desktop: Windows x64, Intel Core i7-14700KF, NVIDIA RTX 3060, Godot
4.5.2 OpenGL compatibility at 1440×900 and 2× MSAA. The exact local wall-clock
frame statistics and test length are in validation/performance.json. They are
observations on that PC, not minimum hardware claims. Reduced graphics disables
MSAA and light shadows; reduce window size for lower rendering load.
User reduced-motion preference disables guided camera
changes. No performance promise is made for other PCs.

The interactive cable audit excludes terminal connector contact and checks only
the named sampled poses/obstacles. It does not establish full-scene clearance,
continuous safety, mechanical stress or physical cable behavior. The old Blender
asset audits are retained internally and do not validate newly introduced motion.

The acoustic model, calibration and coverage are synthetic. No instrument
certification, POD statistics, calibrated confidence score, real flaw sizing,
AI performance, hardware safety or volumetric coverage is claimed. Firmware
execution is real emulation; the virtual peripheral/clock are a declared model.
Only the documented NDE 4.4 raw single-A-scan subset is included. General device
files, DICONDE and enterprise interchange require separate mappings and tests.
