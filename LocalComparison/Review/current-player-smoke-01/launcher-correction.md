# Explicit correction after zero-render launcher failure

The first software process38036 exited1 with0camera frames/0captures. It consumed
120engine updates in about0.048seconds without a first render receipt. Keep its
attempt, log, run and failed analysis in software/; no backend or GI result exists.

The executor incorrectly combined Player -batchmode and Hidden window startup.
The previously existing I:/Unity test/Comparison/REPRODUCE.txt explicitly records
that hidden/batchmode Players did not produce receipts and ordinary visible Player
launch succeeded. A copy is retained as existing-reproduction-instructions.txt.
Unity's Player manual also defines -batchmode as headless; it does not by itself
prove which individual launch setting caused this process's lack of rendering:
https://docs.unity.cn/6000.0/Documentation/Manual/PlayerCommandLineArguments.html

This is a launcher error, not evidence of a GI defect. The executor corrects it
without modifying or rebuilding the283 hashed Player files: remove-batchmode and
use the ordinary rendered Player window, preserving all120frame/startup limits.
The original launcher/analyzer sources are retained separately. New attempts use
software-windowed/ and conditionally hardware-windowed/, never erase/reuse software/.

This deliberately revises the earlier one-software-process scope after a concrete
zero-render setup error. It is not counted as original contract success or hidden
as one process. At most one corrected rendered software launch and one hardware
launch are allowed. Another failure stops that route; no repeated luck-based runs,
no source changes, no extra events, dark-region investigation or parameter tuning.
The user authorized independent judgment and completion of the original local
development task; this correction implements that intent, not an approval request.
