# First finite-wall execution: observer failure retained

The hidden DX12 Editor executed 180 StandardRequest renders. Camera begin/end and
context begin/end receipts were each 180. The whole Feature reported two exact
hardware meshes, two published charted owners, two ready cards, no fallback and
no unknown material records. Thus the explicit complete rendering route works.

No raw color sample was selected: the observer incorrectly required
`lightCapacityOmitted == 0` while spatial light selection was explicitly disabled.
That diagnostic is then the uncollected sentinel `-1`, not a measured omission.
The scene had one real light and reported one selected light throughout.

Editor scene restoration also attempted to restore an empty saved scene setup.
The outer ownership script still verified/restored all 112 product sources,
QualitySettings, GraphicsSettings and the existing Functional scene, and archived
then removed only the temporary reference root. Source geometry and radiometry
were not evaluated; there is no product color failure or passed reference here.

The recorded first two public diagnostic frame values were both 1. The next
observer therefore arms the next actual Gather callback and obtains its Work.frame
there, rather than guessing it from a prior public frame counter. Camera aspect
is explicitly fixed and recorded after binding the target texture. The next
attempt also corrects the two harness conditions above. It keeps the source scene, mathematical oracle,
180-render/180-second limit and comparison bounds unchanged. This directory is
retained in its original failed state.
