# thin-wall-transport-01: bounded observations and fixed shadow reference

Task c2c_a702 iteration7. Original v1 observer failures and A-v3 native exit failure remain preserved. A-v3's120-frame/135-stage observation is valid but shutdownAccepted=false; its original run.json is unchanged. The resource01c repair was then validated independently, followed by exactly one B and one C run under Pro's iteration6 plan. No transport algorithm modification or image tuning occurred.

## Collection, reference and exit are separate

| Configuration | Collection/query gate | Fixed C reference | Exit evidence |
| --- | --- | --- | --- |
| A feedback1, original5 lights | Passed120frames/135stages | Not applicable | Failed: parent ownership symptom/Persistent29, retained |
| B feedback0, original5 lights | Passed120frames/135stages | Not applicable | Exit0; full native log has no same-class failure signature |
| C feedback1, original wall point light only | Passed120frames/135stages | Passed nine samples | Exit0; full native log has no same-class failure signature |

B PID22064 final exec chunkeb7250; C PID23032 chunk8ec70e. Sources, exact helpers, configurations, execution receipts, stage buffers/textures, final HDR and original logs are under LocalComparison/Review/thin-wall-transport-01/retry-v4/ and instrumentation-v4/. Original A is retry-v3/. Collection and exit summaries remain separate; B/C log-based exit gates do not claim the independent12-frame per-ticket attribution was repeated inside each120-frame run.

The full scene/settings snapshots match: A/B differ only in bounceFeedback1→0; A/C differ only in enabling the original wall lamp and disabling the other4 lights. Probe shaders/helpers are byte-identical between A and B/C. Product sources differ only in the ResourceRetirement progress predicate; do not claim byte-identical Runtime. All temporary instrumentation and the previous A asset settings were restored by archived hashes after C.

All sampled selected receiver identities/directions/t, raw-depth reconstruction, exact triangle/material-known final state and necessary owner readiness pass. Fixed ROI coverage is2750 receiver pixels and4200 pixels on each wall region. Raw row coordinates are used; PNG previews are vertically flipped relative to raw data, confirming the existing capture metadata caveat.

## C numerical result

Actual packed GPU data contains the single point lamp at(8,2,2), RGB(12,12,12), correct receiver/shadow masks and shadow strength1. The fixed blocked connection reports known blocking by Thin wall3cm: GPU t=1.379765272140503 versus independent double t=1.3797652738404476, direct RGB0. The clear connection reports known unblocked, direct RGB1.1331003904342651 versus independent double1.1331001923629862, within the predeclared relative2e-4+absolute1e-6 tolerance. All nine samples pass, not only the last one. A miss's recorded maxT is not an actual hit distance.

The first analysis inherited numpy.float32 arithmetic through packed-light scalar inputs. The oracle was corrected to explicitly promote every input before arithmetic; its old source/result are preserved as reference.before-explicit-double.py.txt and C-analysis-before-explicit-double.json. Only existing C data were reanalyzed, with unchanged tolerances and no extra GPU run. The final reference is reference.executed.py.txt, C-analysis.json and series-analysis.json.

## A/B interpretation and remaining limits

At the final sampled frame, receiver mean final RGB changes from approximately(.519,.527,.519) at feedback1 to(.488,.492,.488) at feedback0. The left-wall means are(.519,.544,.520) versus(.498,.511,.498); right-wall means are(2.320,2.327,2.320) versus(2.222,2.225,2.222). The saved summaries also retain raw/history/filtered means for all fixed regions and sample frames. These are descriptive feedback dependence, not a correctness tolerance or an exact higher-bounce decomposition: sampling guidance and cache state may differ.

ROI validPixels means independently verified surface membership, not valid GI measurement count. The analyzer's nonzeroAlpha is literally a nonzero-value count and can include negative unknown sentinels; it must not be interpreted as a valid/confident GI count. Stage means include the geometrically selected samples and are descriptive only.

This package found no counterexample for the two fixed shadow connections. It does not establish whole-image physical correctness, actual gather RNG/screen-vs-world choices, or cache tap/anchor visibility. The four camera probes are receiver-identity queries. No open-boundary dark side is assumed to require zero brightness. No bias, visibility, cache or denoise formula was changed to make the image darker.

Please assess whether this bounded transport package is sufficient to retain as diagnostic coverage, and choose the next small architectural/correctness package. Actual cache tap visibility, feedback convergence and independent energy/image references remain higher-level gaps; no additional parameter matrix is proposed. The complete original plan remains active.
