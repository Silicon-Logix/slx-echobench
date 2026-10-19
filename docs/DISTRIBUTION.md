<!-- Silicon LogiX / SLX EchoBench
Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
License: Silicon LogiX Evaluation License 1.0. See LICENSE. -->

# Distribution boundary

| Content | Internal checkout | Public source candidate | Portable demo |
| --- | --- | --- | --- |
| Godot shell, client, theme, public API | Source | Source | Packed resource |
| Normal-beam core and orchestration | Private C++ | Stripped demo binary | Stripped demo binary |
| Engineering-only build marker | INTERNAL only | Excluded | Excluded |
| Approved runtime GLB/logo | Included | Included | Packed resource |
| Blender source, authoring scripts and original pack audits | Included | Excluded | Excluded |
| ThreadX A/B ELFs, native RTL library, peripheral contract | Included | Matching binary runtime | Matching binary runtime |
| Renode runtime and complete upstream notices | Build cache | Matching binary runtime | Matching binary runtime |
| NDE data adapter and published schemas | Source + native binary | Data-adapter source + native binary | Native binary |
| Original demonstration firmware/RTL sources | Included | Excluded from this SDK candidate | Compiled demo only |
| Customer algorithms, keys, datasets, private debug symbols | Never present in demo capability set | Excluded | Excluded |
| Planning/reference notes, build caches, logs, temporary jobs | Internal | Excluded | Excluded |

`scripts/package.py` creates fresh immutable directories under dist from explicit
file lists. It never copies the internal repository wholesale. A SHA-256 inventory
binds every staged file; the public audit checks the exact inventory, unexpected
files, private source extensions, personal paths and common secret markers in
authored text. Upstream runtime/license files are separately attributed and kept
within their own subtree. Generated Godot caches are not source exports.

The product core rejects unsupported capabilities and arbitrary firmware/plugin
paths. Hashes verify that the included two firmware builds and FIFO library match
the staged runtime. These are integrity measures, not absolute protection against
reverse engineering or an authenticity scheme for a modified local installation.

The portable demo is unsigned development evaluation. It contains no private
signing key, license issuer or automatic updater. Before a production publication,
use SLX's existing external-key Authenticode/Ed25519 release procedure and verify
the signed installer/manifest. No production signature or certification is claimed
by this candidate. Building a preview does not publish or send files anywhere.

Public source editing uses only Godot 4.5.2 and the included binary SDK. The core
and firmware can be replaced only by a matching approved demo build, supplied
through release packaging. Rebuilding private algorithms is an internal workflow.
