# Astra correction and failed-run review

Reviewed 2026-10-28 using the existing failed-run reports and current identity producer/consumer source. No run, test, new sample or product edit was performed. The earlier plan and implementation-gate files are preserved unchanged; this addendum corrects the latter's conclusion.

My prebuild conclusion that no blocking issue remained was wrong for identity selection and object-row observation. I checked the sample byte layout but missed the meaning of its identity fields. The original gate is not evidence that those two contracts were sound.

The failure is attributable to the observer predicate. `HybridLumenGIReceiverIdentity.shader:69–72` places object-row-plus-one in candidate.x and primitive-plus-one in candidate.z. `HybridLumenGIReceiverIdentity.compute:46–50` validates the candidate, loads Objects[candidate.x-1], then writes resolved identity as `(owner.key, candidate.z, 1)`. The temporal consumer also compares candidate.z with resolved identity.z. Resolved identity.z is therefore a primitive number, not an object row.

`MaterialEventGpu.SameIdentity` instead required identity.z == source.row+1. The saved slot-0 primitive values are 3–6, whereas its expected row-plus-one was 15; the Green wall primitive values are 9/10, whereas its row-plus-one was 18. The predicate necessarily rejected those otherwise valid source pixels. `MaterialEventReadback.compute:40` contains the second instance of the same mistake, indexing Objects with identityNow.z-1. That branch was not reached in this run, so it is a latent observer error rather than another observed GPU failure.

The corrected offline report supplies a separate coverage limit. Frame 158 contains 139 valid slot-0 key pixels and 11,874 Green wall key pixels, with 66 and 10,947 reported source-interior candidates respectively. Slot 1 has zero matching key pixels even after the wrong row comparison is removed. Thus fixing the field interpretation alone cannot satisfy the original three-screen-point admission requirement on this saved view. Zero slot-1 coverage does not establish a renderer or GI defect, nor its geometric cause.

Keep the two findings distinct: the actual first stop falsely reported no slot-0 interior because of the observer bug; the saved data independently show that the mandatory slot-1 screen control is not covered. The original failed report must remain failed. Corrected counts do not supply frame 159, an MPB event, later history records or a successful propagation result.

The minimum observer correction is explicit:

- Source membership uses resolved key.xy, valid == 1 and primitive-plus-one > 0; it must not compare that primitive value with a CPU row index. If the interior rule means the exact same primitive identity, compare all resolved xyz fields with the center. If it means the same material source across adjacent triangles, name that narrower meaning explicitly rather than conflating the two.
- Object-row observation must use the actual candidate.x with an explicit range guard before loading Objects[candidate.x-1]. Check candidate ambiguity, candidate.z/identity.z and the loaded key against the resolved identity. A row inferred from a CPU key map is not a direct GPU object-row observation.

The available result is 159 rendered logical frames (0–158), twelve complete payloads, zero final images and zero MPB edits, followed by expected harness failure exit code 1. The first failure is preserved in the observer result; its later close wrapper is not a second product counterexample. The final shutdown log reports zero tracked pending/owned/unknown/failed items, material/arena/deformation bytes and jobs. That supports this bounded failure-cleanup path, not material propagation acceptance or general leak freedom.

Close this package and return it to Pro without an automatic replay or Runtime fix. No product counterexample has been established, so the original conditional fixed-product replay allowance does not apply. I recommend stopping this exact three-visible-point fixture rather than fixing two helper expressions and repeating it unchanged.

If Pro chooses to continue the material question, the least additional scope is the same visible slot-0 event and Green wall GPU control, retaining slot 1 as an actual CPU source/upload control and explicitly leaving its screen-history branch uncovered. That would be a new, declared coverage contract, not a retroactive pass or an authorization from this review. It avoids camera/object search and retains the product question. Otherwise keep the material-acceptance gap open and move to another original-plan item; do not turn this observer failure into a GI repair, a dark-area investigation or a larger observation framework.
