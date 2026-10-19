<!-- Silicon LogiX / SLX EchoBench
Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
License: Silicon LogiX Evaluation License 1.0. See LICENSE. -->

# Architecture and model scope

`godot/` is the public presentation/client. `api/` and the API document define
the public transport. `private/core/` implements scenarios, pulse-echo, processing,
jobs, calibration, comparison, session validation and reports in C++20. Its release
is a separate stripped executable. `private/internal/` is excluded at configure
time from PUBLIC builds. No advanced customer algorithm is included in this demo.

The core owns a single session and sample clock. UI work does not execute the
inspection algorithm. A bounded non-blocking pipe client keeps rendering independent
of acquisition and emulation. Renode runs as a cancellable native Windows child
process group, without a server or WSL requirement in the released application.

The normal-beam model assumes homogeneous isotropic longitudinal velocity, 40 mm
thickness, a Gaussian lateral beam sensitivity, exponentially attenuated independent
reflectors, a 5 MHz Gaussian-windowed pulse, deterministic Q15 noise and scalar
coupling. Reflectors match the delivered geometry at (−301,−120,17),
(−296,15,27), (−304,130,13) mm (X/Y/depth). Their geometry is a known reference,
separate from threshold-based indications. No diffraction, refraction, mode
conversion, anisotropy or real flaw amplitude calibration is asserted.

Sampling is 512 points at 25 MS/s. The envelope is a local seven-sample peak of
absolute RF, not a Hilbert transform. ToF uses the actual absolute RF maximum in
the gate, avoiding the envelope window's leading-edge bias. Thickness uses the
recorded calibration's time offset and velocity. Saturation, insufficient coupling,
no backwall and incomplete acquisition have explicit states and nullable estimates.

Model A intentionally ignores overflow admission; B requires complete valid data.
Firmware A/B apply the same restricted gate rule on signed Q15 samples and differ
at the admission check in the compiled ThreadX task. Renode models Cortex-M3,
SysTick at 100 Hz, flash/RAM and `EchoAcquisition` MMIO at 0x50000000. Verilator
compiles a 256-word ready/valid FIFO. The Renode peripheral invokes that actual
native library on handshakes. The RTL overflow signal is read by the peripheral;
firmware reads its MMIO flag. It is not an electrical ADC or a full board timing model.

3D axes preserve the supplied hierarchy/pivots. Interactive cables are regenerated
from connector anchors. The recorded asset clip owns transforms only during its
explicit presentation; it is stopped before interactive control. The two display
surfaces use live viewport textures from the selected acquisition. Section mode
is an explanation layer; the schematic asset beam is hidden in live operation.

Windows x64 is the tested desktop target. Linux/WSL is used only to build/qualify
the ARM ELF and generate Verilator C++. No ROS 2, MoveIt, Gazebo, Qt or Blender
runtime is introduced. No telemetry, customer-data upload, registration or license
store is present. Production updates require the existing SLX signing/release
infrastructure; this build is explicitly unsigned development evaluation.
