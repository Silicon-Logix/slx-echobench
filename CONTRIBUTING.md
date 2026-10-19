<!-- Silicon LogiX / SLX EchoBench
Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
License: Silicon LogiX Evaluation License 1.0. See LICENSE. -->
# Evaluation feedback and verification

Reports about reproducibility, usability, incorrect units, inconsistent results and
runtime failures are welcome through Issues. Describe expected and actual behavior,
the scenario and exact reproduction steps. State whether the data is synthetic,
saved replay, or the compiled firmware-processing example.

Do not upload customer data, proprietary firmware, credentials or personal paths.
The in-app About dialog copies a diagnostic summary without those paths.

The SLX evaluation license permits private modifications within its terms and
restricts publication of modified versions and patches. Obtain written authorization
from Silicon LogiX before submitting modified SLX source or a code pull request.
This document grants no additional license rights.

## Local checks

Install the runtime using `python scripts/setup-runtime.py`. With Godot 4.5.2:

```powershell
python scripts/audit-public.py --require-runtime
& $Godot --headless --editor --path godot --import
& $Godot --headless --path godot --script ../tests/public_smoke.gd -- "build/public-smoke.json"
& $Godot --path godot --script ../tests/responsive.gd
```

Set `$Godot` to the console executable's path and create `build/` if needed for
the output. The responsive check needs graphical rendering and changes its test
window size; it also regenerates screenshots and its local validation record.

`repository-policy.json` declares allowed public files and fixed binary/asset
checksums. Source files may be edited without updating hashes. New paths require
an explicit policy update after review of the public/private boundary. Do not
regenerate binary hashes merely to bypass a failed integrity check.

Internal C++ and firmware builds belong to the private engineering checkout.
Keep all dependency notices when redistributing an unmodified allowed copy.
