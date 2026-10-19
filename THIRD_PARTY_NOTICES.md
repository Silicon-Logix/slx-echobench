<!-- Silicon LogiX / SLX EchoBench
Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
License: Silicon LogiX Evaluation License 1.0. See LICENSE. -->

# Third-party components

Godot 4.5.2: MIT; full engine license and dependency attribution are provided in
licenses/godot-LICENSE.txt and licenses/godot-COPYRIGHT.txt. The portable development
package includes the unmodified Godot runtime. See https://godotengine.org/license/.

nlohmann/json 3.12.0: MIT, statically included in the private product core.
See licenses/json-LICENSE.MIT. The public interface bundle does not include core C++.

MinGW-w64 runtime, GCC 13.1 and winpthreads: the core is statically linked.
Preserved runtime notices and GCC Runtime Library Exception are under licenses/gcc,
licenses/mingw-w64 and licenses/winpthreads. Compiler tools are not distributed.

Eclipse ThreadX 6.4.1 (commit 07eac307405dbf09d409844e31c37b0649d6c074), MIT:
statically included in both demonstration ELFs. Its exact upstream LICENSE.txt
is in licenses/threadx-LICENSE.txt. Renode 1.16.1 self-contained Windows/.NET
runtime is redistributed unmodified under its MIT license, with all upstream
dependency notices retained in runtime/renode/licenses. No Renode GUI is required.

Verilator 4.038 generates the demonstration FIFO library. Its unmodified runtime
is used under the alternative Perl Artistic License 2.0; the exact upstream
copyright and license texts are preserved in licenses/verilator-copyright.txt.
The Verilator compiler itself is not distributed. Original SLX RTL/bridge and
generated model code retain their own rights, as described in the Verilator FAQ.

HDF5 1.14.6 is statically linked into the native NDE data adapter. Its original
license is in licenses/HDF5-COPYING.txt. Compression and external plugins are
disabled for the supported subset. Generated build metadata is scrubbed of local
paths; the library algorithms are unmodified. NDE Properties/Setup schemas 4.4.0
are MIT, Copyright Evident; see licenses/nde-format-LICENSE.txt.

System fonts (Segoe UI / Noto Sans / Arial) are resolved from the host; no font
files are redistributed. Python, WSL and the ARM toolchain are not bundled or
required by the released desktop application.

Original laboratory geometry, artwork and Silicon LogiX branding are supplied
for EchoBench. The original asset NOTICE is preserved internally. No UR robot,
ROS, Qt, Blender runtime, commercial model or customer dataset is included in
the application distribution. Technical product names imply no vendor endorsement.
