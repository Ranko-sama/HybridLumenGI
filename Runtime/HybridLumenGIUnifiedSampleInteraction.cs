using System;
using System.Collections.Generic;
using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>Ordinary single-camera controls for the generated sample. No benchmark or quality verdict.</summary>
    [DisallowMultipleComponent]
    public sealed class HybridLumenGIUnifiedSampleInteraction : MonoBehaviour
    {
        [SerializeField] private Camera targetCamera;
        [SerializeField] private HybridLumenGIUnifiedSample sample;
        [SerializeField] private HybridLumenGIValidationMotion door;
        [SerializeField] private Renderer colorWall;
        [SerializeField] private Light[] lights = Array.Empty<Light>();
        [SerializeField] private GameObject connectedRooms;
        [SerializeField] private HybridLumenGIValidationMotion roomPortal;
        [SerializeField] private Transform entryCeiling, sourceCeiling;
        [SerializeField] private PassageSpan[] passageSpans;
        private Vector3 entryCeilingPosition, entryCeilingScale, sourceCeilingPosition, sourceCeilingScale;
        private bool[] originalLights;
        private MaterialPropertyBlock originalBlock, changedBlock;
        private readonly List<(int index, MaterialPropertyBlock original, MaterialPropertyBlock changed)> wallSlotBlocks = new();
        private float yaw, pitch, doorTime;
        private bool initialized, closed, showControls = true;
        private MeshFilter filter;
        private MeshRenderer meshRenderer;
        private bool originalRendererEnabled;
        private HybridLumenGIProxy deformationProxy;
        private HybridLumenGIUnifiedSampleSkin skin;
        private Mesh originalMesh, producer;
        private HybridLumenGIDeformedMesh deformation;
        private Vector3[] originalPositions, originalNormals, positions, normals;
        private Vector4[] originalTangents, tangents;
        private double deformationTime;
        public bool ColorChanged { get; private set; }
        public bool LightsEnabled { get; private set; } = true;
        public bool DoorMoving { get; private set; }
        public bool DeformationRunning { get; private set; }
        public bool SkinnedDeformation { get; private set; }
        public float Shear { get; private set; }
        public float BendDegrees { get; private set; }
        public bool HasConnectedRooms => connectedRooms && roomPortal;
        public bool RoomsEnabled => HasConnectedRooms && connectedRooms.activeSelf;
        public bool PortalOpen { get; private set; }
        public bool HasTurnedPassage => HasConnectedRooms && entryCeiling && sourceCeiling && passageSpans?.Length == 3;
        public bool TurnedPassage { get; private set; }

        // One continuous floor or side wall can cover both the color room and its extension.
        [Serializable]
        public struct PassageSpan
        {
            [SerializeField] private Transform source;
            [SerializeField] private GameObject entryPiece;
            [NonSerialized] private Vector3 originalPosition, originalScale;
            [NonSerialized] private bool wasActive;
            public PassageSpan(Transform source, GameObject entryPiece) : this()
            { this.source = source; this.entryPiece = entryPiece; }
            internal bool Matches(Transform room) => source && entryPiece && entryPiece.transform.parent == room &&
                !source.IsChildOf(room) && source.gameObject.scene == room.gameObject.scene;
            internal void Join(Vector3 forward)
            {
                originalPosition = source.localPosition; originalScale = source.localScale;
                wasActive = entryPiece.activeSelf;
                source.position -= 3f * forward;
                source.localScale = new Vector3(originalScale.x, originalScale.y, originalScale.z * (14f / 8f));
                entryPiece.SetActive(false);
            }
            internal void Restore()
            {
                if (source) { source.localPosition = originalPosition; source.localScale = originalScale; }
                if (entryPiece) entryPiece.SetActive(wasActive);
            }
        }

        public void Configure(Camera camera, HybridLumenGIUnifiedSample controller,
            HybridLumenGIValidationMotion movingDoor, Renderer wall, Light[] sceneLights)
        {
            if (Application.isPlaying) throw new InvalidOperationException("Configure before Play.");
            if (!camera || !controller) throw new ArgumentException("A camera and sample controller are required.");
            targetCamera = camera; sample = controller; door = movingDoor; colorWall = wall;
            lights = sceneLights == null ? Array.Empty<Light>() : (Light[])sceneLights.Clone();
        }
        public void ConfigureConnectedRooms(GameObject root, HybridLumenGIValidationMotion portal)
            => ConfigureConnectedRooms(root, portal, null, null, null);

        public void ConfigureConnectedRooms(GameObject root, HybridLumenGIValidationMotion portal,
            Transform entryRoof, Transform sourceRoof, PassageSpan[] spans)
        {
            if (Application.isPlaying) throw new InvalidOperationException("Configure before Play.");
            if (!root || !portal || !root.scene.IsValid() || root.scene != gameObject.scene || root.activeSelf ||
                portal.gameObject == root || !portal.transform.IsChildOf(root.transform) || (door && door.transform.IsChildOf(root.transform)) ||
                transform.IsChildOf(root.transform) || (targetCamera && targetCamera.transform.IsChildOf(root.transform)))
                throw new ArgumentException("Use an inactive room root in this scene and a portal below it. Keep the original door, controls and camera outside.");
            if ((entryRoof || sourceRoof) && (!entryRoof || !sourceRoof || entryRoof == sourceRoof ||
                entryRoof.parent != root.transform || sourceRoof.parent != root.transform || entryRoof == portal.transform || sourceRoof == portal.transform))
                throw new ArgumentException("The turned passage needs the two separate ceiling pieces of the generated rooms.");
            if (spans != null && (spans.Length != 3 || Array.Exists(spans, span => !span.Matches(root.transform))))
                throw new ArgumentException("Use the generated floor and both side walls with their matching entry pieces.");
            connectedRooms = root;
            roomPortal = portal;
            entryCeiling = entryRoof;
            sourceCeiling = sourceRoof;
            passageSpans = spans == null ? null : (PassageSpan[])spans.Clone();
        }
        private void Start()
        {
            if (!targetCamera || !sample) throw new InvalidOperationException("Incomplete sample navigation references.");
            originalLights = new bool[lights.Length];
            for (int i = 0; i < lights.Length; i++) originalLights[i] = lights[i] && lights[i].enabled;
            if (colorWall) CaptureWallBlocks();
            HybridLumenGIResourceRetirement.RegisterShutdownOwner(Close);
            initialized = true; SyncAngles(); Application.runInBackground = true;
        }
        private void SyncAngles()
        { var angles = targetCamera.transform.eulerAngles; yaw = angles.y; pitch = Mathf.DeltaAngle(0, angles.x); }
        private static float Keys(KeyCode positive, KeyCode negative) => (Input.GetKey(positive) ? 1 : 0) - (Input.GetKey(negative) ? 1 : 0);
        private void CaptureWallBlocks()
        {
            var blue = new Color(.05f, .15f, .8f, 1);
            originalBlock = new MaterialPropertyBlock(); colorWall.GetPropertyBlock(originalBlock);
            if (originalBlock.isEmpty) originalBlock = null;
            changedBlock = new MaterialPropertyBlock(); colorWall.GetPropertyBlock(changedBlock);
            changedBlock.SetColor("_BaseColor", blue);
            if (!colorWall.HasPropertyBlock()) return;

            // Only authored slot blocks override the renderer block. Leave inheriting slots alone.
            int slotCount = colorWall.sharedMaterials.Length;
            for (int i = 0; i < slotCount; i++)
            {
                var original = new MaterialPropertyBlock(); colorWall.GetPropertyBlock(original, i);
                if (original.isEmpty) continue;
                var changed = new MaterialPropertyBlock(); colorWall.GetPropertyBlock(changed, i);
                changed.SetColor("_BaseColor", blue);
                wallSlotBlocks.Add((i, original, changed));
            }
        }
        private void ApplyWallColor(bool value)
        {
            colorWall.SetPropertyBlock(value ? changedBlock : originalBlock);
            foreach (var block in wallSlotBlocks)
                colorWall.SetPropertyBlock(value ? block.changed : block.original, block.index);
            ColorChanged = value;
        }
        public void SetColorChanged(bool value)
        { if (initialized && !closed && colorWall) ApplyWallColor(value); }
        public void SetLightsEnabled(bool value)
        {
            if (!initialized || closed) return; LightsEnabled = value;
            for (int i = 0; i < lights.Length; i++) if (lights[i]) lights[i].enabled = value && originalLights[i];
        }
        public void SetDoorMoving(bool value) { if (initialized && !closed && door) DoorMoving = value; }
        public void SetConnectedRooms(bool value)
        {
            if (!initialized || closed || !HasConnectedRooms || RoomsEnabled == value) return;
            if (!value) { if (TurnedPassage) SetTurnedPassage(false); RestoreRooms(); return; }
            ApplyPortalPose(true);
            connectedRooms.SetActive(true);
            sample.GoNear();
            SyncAngles();
        }
        public void SetPortalOpen(bool value)
        {
            if (!initialized || closed || !RoomsEnabled) return;
            ApplyPortalPose(value);
        }
        public void SetTurnedPassage(bool value)
        {
            if (!initialized || closed || !RoomsEnabled || !HasTurnedPassage || value == TurnedPassage) return;
            if (value)
            {
                if (Array.Exists(passageSpans, span => !span.Matches(connectedRooms.transform))) return;
                entryCeilingPosition = entryCeiling.localPosition; entryCeilingScale = entryCeiling.localScale;
                sourceCeilingPosition = sourceCeiling.localPosition; sourceCeilingScale = sourceCeiling.localScale;
                // The single roof covers both straight ceiling spans. Reuse the other cube for the offset opening.
                entryCeiling.localPosition = new Vector3(0, 4, -5);
                entryCeiling.localScale = new Vector3(8.3f, .3f, 10);
                sourceCeiling.localPosition = new Vector3(-1.25f, 2, -7);
                sourceCeiling.localScale = new Vector3(5.5f, 4, .2f);
                for (int i = 0; i < passageSpans.Length; i++) passageSpans[i].Join(connectedRooms.transform.forward);
                TurnedPassage = true;
                targetCamera.transform.SetPositionAndRotation(connectedRooms.transform.TransformPoint(2.65f, 1.5f, -8.8f), connectedRooms.transform.rotation);
            }
            else
            {
                RestoreStraightLayout();
                sample.GoNear();
            }
            SyncAngles();
        }
        private void RestoreStraightLayout()
        {
            if (!TurnedPassage) return;
            if (entryCeiling) { entryCeiling.localPosition = entryCeilingPosition; entryCeiling.localScale = entryCeilingScale; }
            if (sourceCeiling) { sourceCeiling.localPosition = sourceCeilingPosition; sourceCeiling.localScale = sourceCeilingScale; }
            for (int i = 0; i < passageSpans.Length; i++) passageSpans[i].Restore();
            TurnedPassage = false;
        }
        private void ApplyPortalPose(bool open)
        { roomPortal.ApplyFrame(open ? 179 : 120); PortalOpen = open; }
        private void RestoreRooms()
        {
            RestoreStraightLayout();
            if (roomPortal) roomPortal.Restore();
            if (connectedRooms && connectedRooms.activeSelf) connectedRooms.SetActive(false);
            PortalOpen = false;
        }
        public void SetDeformationRunning(bool value)
        {
            if (!initialized || closed || !door || DeformationRunning == value) return;
            if (value && !producer) CreateProducer();
            DeformationRunning = value;
            if (!value && producer && !SkinnedDeformation) deformation.RequestCoalescedCapture(producer);
        }
        public void SetSkinnedDeformation(bool value)
        {
            if (!initialized || closed || !door || SkinnedDeformation == value) return;
            if (!producer) CreateProducer();
            if (value && skin == null) skin = new HybridLumenGIUnifiedSampleSkin(meshRenderer, originalMesh);
            if (value) skin.SetBend(BendDegrees);
            // Withdraw the previous renderer's snapshot and cancel its worker before
            // selecting the new source. Clearing explicitSource is essential: skin
            // captures must use the existing automatic BakeMesh path.
            deformation.enabled = false;
            if (!value) ApplyMeshPose();
            deformationProxy.SetSources(value ? skin.Renderer : meshRenderer, deformationProxy.SourceCollider);
            deformation.RequestCapture(value ? null : producer);
            meshRenderer.enabled = !value && originalRendererEnabled;
            if (skin != null) skin.Renderer.enabled = value && originalRendererEnabled;
            SkinnedDeformation = value;
            deformation.enabled = true;
        }
        private void CreateProducer()
        {
            filter = door.GetComponent<MeshFilter>(); originalMesh = filter ? filter.sharedMesh : null;
            meshRenderer = door.GetComponent<MeshRenderer>(); deformationProxy = door.GetComponent<HybridLumenGIProxy>();
            if (!originalMesh || !originalMesh.isReadable || !meshRenderer || !deformationProxy ||
                deformationProxy.SourceRenderer != meshRenderer || door.GetComponent<HybridLumenGIDeformedMesh>())
                throw new InvalidOperationException("The ordinary deformation example requires an owned readable static door mesh.");
            originalRendererEnabled = meshRenderer.enabled;
            originalPositions = originalMesh.vertices; originalNormals = originalMesh.normals; originalTangents = originalMesh.tangents;
            if (originalNormals.Length != originalPositions.Length || originalTangents.Length != originalPositions.Length)
                throw new InvalidOperationException("Door normal/tangent streams are incomplete.");
            positions = new Vector3[originalPositions.Length]; normals = new Vector3[positions.Length]; tangents = new Vector4[positions.Length];
            producer = Instantiate(originalMesh); producer.name = "Unified sample deformation producer";
            producer.hideFlags = HideFlags.HideAndDontSave; filter.sharedMesh = producer;
            deformation = door.gameObject.AddComponent<HybridLumenGIDeformedMesh>();
            deformation.RequestCoalescedCapture(producer);
        }
        private void Advance(float dt)
        {
            if (DoorMoving) { doorTime += dt; door.ApplyFrame(120 + (int)(doorTime * 30f) % 120); }
            if (!DeformationRunning) return;
            deformationTime += dt; Shear = (float)(.4 * Math.Sin(Math.PI * .5 * deformationTime));
            BendDegrees = (float)(20 * Math.Sin(Math.PI * .5 * deformationTime));
            if (SkinnedDeformation) { skin.SetBend(BendDegrees); return; }
            ApplyMeshPose();
            deformation.RequestCoalescedCapture(producer);
        }
        private void ApplyMeshPose()
        {
            for (int i = 0; i < positions.Length; i++)
            {
                Vector3 p = originalPositions[i], n = originalNormals[i]; Vector4 t = originalTangents[i];
                positions[i] = new Vector3(p.x + Shear * p.y, p.y, p.z);
                normals[i] = new Vector3(n.x, n.y - Shear * n.x, n.z).normalized;
                Vector3 tangent = new Vector3(t.x + Shear * t.y, t.y, t.z).normalized;
                tangents[i] = new Vector4(tangent.x, tangent.y, tangent.z, t.w);
            }
            producer.vertices = positions; producer.normals = normals; producer.tangents = tangents; producer.RecalculateBounds();
        }
        private void Update()
        {
            if (!initialized || closed) return;
            float dt = Mathf.Min(Time.unscaledDeltaTime, .05f);
            if (Application.isFocused)
            {
                if (Input.GetKeyDown(KeyCode.Escape)) Application.Quit();
                if (Input.GetKeyDown(KeyCode.F1)) { showControls = !showControls; sample.ShowControls = showControls; }
                if (!sample.IsEditingGpuTarget)
                {
                    if (Input.GetKeyDown(KeyCode.F2)) sample.LogLedger();
                    if (HasConnectedRooms && Input.GetKeyDown(KeyCode.F3)) SetConnectedRooms(!RoomsEnabled);
                    if (RoomsEnabled && Input.GetKeyDown(KeyCode.F4)) SetTurnedPassage(!TurnedPassage);
                    if (RoomsEnabled && Input.GetKeyDown(KeyCode.O)) SetPortalOpen(!PortalOpen);
                    if (Input.GetKeyDown(KeyCode.R) || Input.GetKeyDown(KeyCode.Alpha1)) { sample.GoNear(); SyncAngles(); }
                    if (Input.GetKeyDown(KeyCode.Alpha2)) { sample.GoFar(); SyncAngles(); }
                    if (Input.GetKeyDown(KeyCode.Alpha3)) { sample.Leave(); SyncAngles(); }
                    if (Input.GetKeyDown(KeyCode.Alpha4)) sample.SetHardwarePreference(false);
                    if (Input.GetKeyDown(KeyCode.Alpha5)) sample.SetHardwarePreference(true);
                    if (Input.GetKeyDown(KeyCode.C)) SetColorChanged(!ColorChanged);
                    if (Input.GetKeyDown(KeyCode.L)) SetLightsEnabled(!LightsEnabled);
                    if (Input.GetKeyDown(KeyCode.M)) SetDoorMoving(!DoorMoving);
                    if (Input.GetKeyDown(KeyCode.Space)) SetDeformationRunning(!DeformationRunning);
                    if (Input.GetKeyDown(KeyCode.K)) SetSkinnedDeformation(!SkinnedDeformation);
                    if (Input.GetKeyDown(KeyCode.B)) sample.enabled = !sample.enabled;
                    // Buttons can teleport the camera between Updates; read its current orientation before keyboard rotation.
                    SyncAngles(); yaw += Keys(KeyCode.RightArrow, KeyCode.LeftArrow) * 90f * dt;
                    pitch = Mathf.Clamp(pitch + Keys(KeyCode.DownArrow, KeyCode.UpArrow) * 90f * dt, -85f, 85f);
                    targetCamera.transform.rotation = Quaternion.Euler(pitch, yaw, 0);
                    Vector3 move = Vector3.ClampMagnitude(new Vector3(Keys(KeyCode.D, KeyCode.A), Keys(KeyCode.E, KeyCode.Q), Keys(KeyCode.W, KeyCode.S)), 1);
                    targetCamera.transform.position += Quaternion.Euler(0, yaw, 0) * move * (3f * dt);
                }
            }
            Advance(dt);
        }
        private void OnGUI()
        {
            if (!initialized || closed || !showControls) return;
            GUILayout.BeginArea(new Rect(12, Screen.height - 115, Mathf.Min(850, Screen.width - 24), 103), GUI.skin.box);
            GUILayout.Label("WASD / Q E: move   Arrows: turn   1/2/3: near/far/leave   4/5: software/DXR   F1: hide   Esc: quit");
            GUILayout.BeginHorizontal();
            if (colorWall && GUILayout.Button(ColorChanged ? "C: restore red wall" : "C: blue wall")) SetColorChanged(!ColorChanged);
            if (lights.Length > 0 && GUILayout.Button(LightsEnabled ? "L: lights off" : "L: lights on")) SetLightsEnabled(!LightsEnabled);
            if (door && GUILayout.Button(DoorMoving ? "M: stop door" : "M: move door")) SetDoorMoving(!DoorMoving);
            if (door && GUILayout.Button(DeformationRunning ? "Space: stop deformation" : "Space: deform door")) SetDeformationRunning(!DeformationRunning);
            if (door && GUILayout.Button(SkinnedDeformation ? "K: use mesh" : "K: use skin")) SetSkinnedDeformation(!SkinnedDeformation);
            if (GUILayout.Button(sample.enabled ? "B: release group" : "B: reload group")) sample.enabled = !sample.enabled;
            GUILayout.EndHorizontal();
            if (HasConnectedRooms)
            {
                GUILayout.BeginHorizontal();
                if (GUILayout.Button(RoomsEnabled ? "F3: hide connected rooms" : "F3: explore connected rooms")) SetConnectedRooms(!RoomsEnabled);
                if (RoomsEnabled && HasTurnedPassage && GUILayout.Button(TurnedPassage ? "F4: two rooms" : "F4: three rooms")) SetTurnedPassage(!TurnedPassage);
                if (RoomsEnabled && GUILayout.Button(PortalOpen ? "O: close room door" : "O: open room door")) SetPortalOpen(!PortalOpen);
            }
            GUILayout.Label(lights.Length > 0 ? "F2: log current status. Lights off keeps emissive surfaces." : "F2: log current status.");
            if (HasConnectedRooms) GUILayout.EndHorizontal();
            if (door) GUILayout.Label((SkinnedDeformation ? "Skinned bones" : "Readable mesh") + ": asynchronous snapshots; lighting may catch up after motion stops.");
            GUILayout.EndArea();
        }
        private void Close()
        {
            if (closed) return; closed = true; DoorMoving = DeformationRunning = false;
            HybridLumenGIResourceRetirement.UnregisterShutdownOwner(Close);
            if (!initialized) return;
            RestoreRooms();
            if (colorWall) ApplyWallColor(false);
            for (int i = 0; i < lights.Length; i++) if (lights[i]) lights[i].enabled = originalLights[i];
            if (door) door.Restore();
            // Withdraw/cancel GI snapshots before restoring and retiring the producer-owned mesh.
            if (deformation) deformation.enabled = false;
            if (deformationProxy && (deformationProxy.SourceRenderer == meshRenderer ||
                (skin != null && deformationProxy.SourceRenderer == skin.Renderer)))
                deformationProxy.SetSources(meshRenderer, deformationProxy.SourceCollider);
            if (filter && producer && ReferenceEquals(filter.sharedMesh, producer)) filter.sharedMesh = originalMesh;
            if (meshRenderer && producer) meshRenderer.enabled = originalRendererEnabled;
            skin?.Dispose(); skin = null;
            if (producer) { Mesh owned = producer; HybridLumenGIResourceRetirement.Retire(() => Destroy(owned)); producer = null; }
        }
        private void OnDisable() => Close();
        private void OnDestroy() => Close();
        private void OnApplicationQuit() => Close();
    }
}
