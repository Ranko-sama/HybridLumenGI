# A lane: stopped at first baseline launch

The first authorized baseline command was `py -3 -B run_surface.py baseline`.
It exited 101 before Python could create a process. The installed Windows
launcher selected `C:\Program Files\ComfyUI-aki\ComfyUI-aki-v3\Python312\python.exe`
and reported “Unable to create process”. The exact command, UTC timestamps,
exit code and unmodified output are in baseline-command.json and
baseline-command.log.

No Python script, DXC compilation or WARP dispatch ran; neither baseline/
nor candidate/ exists. Surface.shader remains byte-identical to its frozen
baseline (SHA256 b8e529a4cb019896ce03f77e852a582aff8071d766d555bca34fbdae6d68c961),
as recorded in launch-failure-state.json. No Runtime file was modified by
this lane, no candidate was attempted, and no retry or input change occurred.

Under Pro65's first-infrastructure-failure stop rule, this lane is paused
for the root agent's consolidated disposition. The proposed arithmetic
counterexample remains source-supported but has not been executed here.
This failure supplies no product adoption or rejection evidence.
