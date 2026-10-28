# GPT-6 Astra Max prebuild review

Priority is correct: current Player source/platform coverage is missing, especially
runtime pump/Application.quitting, while the dark area has no established defect.

One blocker identified and fixed before execution: explicitly include actual
Pipeline and project-settings-referenced URP GlobalSettings/dependencies, plus
readable asset .meta files, in build input manifest. Hashing the settings YAML alone
does not bind the referenced assets. Builder now collects their referenced GUID
roots and actual current pipeline before recursive dependency selection.

No other concrete startup blocker found. Scope is consistent with Pro19; no new
preflight matrix needed. Existing119 readbacks precede next Update/Finish.

Analysis semantics: hardwareFallbacks is recomputed unrepresented published-instance
count, not cumulative backend switching. Report it as a coverage gauge. Both moments
formats are only assigned at existing30/119 readback branches; do not demand these
fields on other frame rows. Candidate analysis follows these distinctions.
