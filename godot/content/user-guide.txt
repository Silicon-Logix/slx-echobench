<!-- Silicon LogiX / SLX EchoBench
Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
License: Silicon LogiX Evaluation License 1.0. See LICENSE. -->

# EchoBench user guide

Run the portable application offline. No account or physical equipment is needed.
Choose Guided visit and start the 75-second inspection, or open Technical analysis.
The core computes the RF samples; plots never use the asset pack's illustrative CSV.

The desktop layout fills the window, including maximized and ultrawide sizes.
Scene and analysis panels resize together; drag their divider to change the ratio.
Interface scale in the sidebar adjusts text and controls from 100% to 200%,
initially following display DPI. The 3D view renders at its actual pixel size.
SLX services lists the advanced capabilities offered as custom development.
Discuss a custom development opens the SLX contact page; Save enquiry locally
creates a local template without sending data.

Right-drag the 3D view to orbit and scroll to zoom. The four camera presets show
the laboratory, probe, instrument and synthetic reference section. Reveal reference
is separate from the signal-derived indication. Training hides the reference until
it is explicitly revealed. The 32-second asset presentation is a recorded animation,
not an acquisition. End presentation returns to the authoritative core pose.

In Setup & calibration, apply a probe position or signal setup, then acquire a point.
An upright coupled probe at X −301 / Y −120 mm detects the first reflector. X −550 mm
is away from the reflectors. Coupling zero or an air lift makes data not evaluable.
Tilt is permitted only with at least 75 mm lift. A declared 0.5 mm nominal couplant
layer accounts for the visual gap. This does not model an inclined wedge.

Scan executes a bounded serpentine raster. Pause, resume, STOP and reset are explicit.
The sample clock advances by 0.1 simulated seconds per point; host time is separate.
The application STOP does not implement a physical safety function.

A-scan shows RF or peak envelope in normalized full scale. Gate A selects reflector
echoes, gate B the nominal backwall. Click to place a time cursor. Gain/filter settings
affect new acquisitions; previously recorded samples retain their own parameters.
Freeze pauses an active raster and holds the inspection view after the pause is
acknowledged. Resume explicitly continues the scan. Selecting a point or starting
a new acquisition releases the frozen view.

C-scan displays gate A peak amplitude; quality, executed path and sampled points
are distinct selectable maps. Grey means unsampled; red means not evaluable.
B-scan shows envelope amplitude against sample time on the selected Y pass.
Maps show surface samples and do not establish volumetric ultrasonic coverage.
Click a map point or indication to select that acquisition in all views.
Details beside the result shows the selected acquisition's actual pose, input hash,
applied configuration/calibration, decision and compiled processing history. It also
shows the actual RF/envelope sample at the time cursor and can copy that context.

Read the two synthetic calibration references, inspect their time of flight and
apply the fit. This estimates model delay and velocity; it is not an instrument
calibration certificate. Invalid input, missing backwall, saturation and acquisition
loss remain explicit. No uncalibrated confidence percentage is used.

Evidence & replay saves `.echo.json` bundles, loads them transactionally, adds
annotations and exports HTML/JSON/CSV reports. The default directory is
Documents / SLX EchoBench; Storage folder selects an existing user directory.
Enter a simple file base name. Session checksums detect corruption; they are not
digital signatures. Reports include a selected signal image, indication coordinates,
quality counts, setup and calibration. Per-acquisition setup is retained in the bundle.

Model A and B comparison reprocesses the exact same recorded inputs. A deliberately
ignores overflow admission; B rejects incomplete data. Both are C++ host processors.
The firmware processing profiles execute both compiled ThreadX builds in a native
Renode child process on the selected saved Q15 input. Select ThreadX / Renode or
ThreadX + Verilator FIFO, then Execute firmware A/B. Execution can be cancelled.
The raster maps remain the explicitly labelled host acquisition model. Embedded
results are saved separately with firmware/RTL hashes and measured RTOS ticks.
The embedded FIFO burst drops 256 words, while the host model overflow drops 64;
their distinct acquisition contracts are shown. Arbitrary firmware, plugins and
scripts are rejected. No WSL, Python, compiler or hardware is needed at runtime.
Export selected .nde maps a complete valid raw A-scan to the documented NDE 4.4
subset and includes the whole native session for replay roundtrip. Import SLX .nde
accepts only this mapping, not general instrument files or DICONDE. File jobs are
cancellable and failed imports leave the current session unchanged. Return live
exits replay and restores the final recorded pose/sample clock for new acquisition.

F1 opens this guide; F12 opens About; Escape stops; Ctrl+S saves; Ctrl+O loads.
Tab navigates controls. Reduced motion suppresses guided camera changes. Split
position and reduced-motion preference persist locally. No telemetry is sent.

The model assumes normal-beam longitudinal pulse-echo in an isotropic 40 mm coupon,
Gaussian lateral sensitivity and independent point reflectors. It does not predict
real defect response, diffraction, mode conversion or real instrument accuracy.
Customer physics, advanced UT, AI and hardware/robot integration require a dedicated
implementation and validation project.
