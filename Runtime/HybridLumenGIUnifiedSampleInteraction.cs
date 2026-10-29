using System;
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
        private bool[] originalLights;
        private MaterialPropertyBlock originalBlock, changedBlock;
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

        public void Configure(Camera camera, HybridLumenGIUnifiedSample controller,
            HybridLumenGIValidationMotion movingDoor, Renderer wall, Light[] sceneLights)
        {
            if (Application.isPlaying) throw new InvalidOperationException("Configure before Play.");
            if (!camera || !controller) throw new ArgumentException("A camera and sample controller are required.");
            targetCamera = camera; sample = controller; door = movingDoor; colorWall = wall;
            lights = sceneLights == null ? Array.Empty<Light>() : (Light[])sceneLights.Clone();
        }
        private void Start()
        {
            if (!targetCamera || !sample) throw new InvalidOperationException("Incomplete sample navigation references.");
            originalLights = new bool[lights.Length];
            for (int i = 0; i < lights.Length; i++) originalLights[i] = lights[i] && lights[i].enabled;
            if (colorWall)
            {
                originalBlock = new MaterialPropertyBlock(); colorWall.GetPropertyBlock(originalBlock);
                changedBlock = new MaterialPropertyBlock(); colorWall.GetPropertyBlock(changedBlock);
                changedBlock.SetColor("_BaseColor", new Color(.05f, .15f, .8f, 1));
            }
            HybridLumenGIResourceRetirement.RegisterShutdownOwner(Close);
            initialized = true; SyncAngles(); Application.runInBackground = true;
        }
        private void SyncAngles()
        { var angles = targetCamera.transform.eulerAngles; yaw = angles.y; pitch = Mathf.DeltaAngle(0, angles.x); }
        private static float Keys(KeyCode positive, KeyCode negative) => (Input.GetKey(positive) ? 1 : 0) - (Input.GetKey(negative) ? 1 : 0);
        public void SetColorChanged(bool value)
        { if (!initialized || closed || !colorWall) return; ColorChanged = value; colorWall.SetPropertyBlock(value ? changedBlock : originalBlock); }
        public void SetLightsEnabled(bool value)
        {
            if (!initialized || closed) return; LightsEnabled = value;
            for (int i = 0; i < lights.Length; i++) if (lights[i]) lights[i].enabled = value && originalLights[i];
        }
        public void SetDoorMoving(bool value) { if (initialized && !closed && door) DoorMoving = value; }
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
            if (lights.Length > 0) GUILayout.Label("Lights off keeps emissive surfaces.");
            if (door) GUILayout.Label((SkinnedDeformation ? "Skinned bones" : "Readable mesh") + ": asynchronous snapshots; lighting may catch up after motion stops.");
            GUILayout.EndArea();
        }
        private void Close()
        {
            if (closed) return; closed = true; DoorMoving = DeformationRunning = false;
            HybridLumenGIResourceRetirement.UnregisterShutdownOwner(Close);
            if (!initialized) return;
            if (colorWall) colorWall.SetPropertyBlock(originalBlock);
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
