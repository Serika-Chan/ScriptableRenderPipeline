using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering.HighDefinition.Attributes;
using UnityEngine.Video;

using UnityEngine.Experimental.Rendering;

namespace UnityEngine.Rendering.HighDefinition.Compositor
{
    // Defines a single compositor layer and it's properties.
    [System.Serializable]
    internal class CompositorLayer
    {
        public enum LayerType
        {
            Camera = 0,
            Video = 1,
            Image = 2
        };

        // The graphics format options exposed in the UI 
        public enum UIColorBufferFormat
        {
            R11G11B10 = GraphicsFormat.B10G11R11_UFloatPack32,
            R16G16B16A16 = GraphicsFormat.R16G16B16A16_UNorm,
            R32G32B32A32 = GraphicsFormat.R32G32B32A32_SFloat
        };

        // Specifies if this layer will be used in the compositor or a camera stack
        public enum OutputTarget
        {
            CompositorLayer = 0,
            CameraStack
        }

        public enum ResolutionScale
        {
            Full = 1,
            Half = 2,
            Quarter = 4
        }

        public string m_LayerName;
        public bool m_Show = true;          // Used to toggle visibility of layers
        public OutputTarget m_OutputTarget; // Specifies if this layer will be used in the compositor or a camera stack
        public bool m_ClearDepth = false;   // Specifies if the depth will be cleared when stacking this camera over the previous one (for overlays)
        public bool m_ClearAlpha = true;    // Specifies if the Alpha channel will be cleared when stacking this camera over the previous one (for overlays)
        public Renderer m_OutputRenderer = null; // Specifies the output surface/renderer
        public LayerType m_Type;
        public Camera m_Camera;
        public VideoPlayer m_InputVideo;
        public Texture m_InputTexture;
        public BackgroundFitMode m_BackgroundFit;
        public ResolutionScale m_ResolutionScale = ResolutionScale.Full;
        public UIColorBufferFormat m_ColorBufferFormat = UIColorBufferFormat.R16G16B16A16;

        // Layer overrides
        public bool m_OverrideAntialiasing = false;
        public HDAdditionalCameraData.AntialiasingMode m_Antialiasing;

        public bool m_OverrideClearMode = false;
        public HDAdditionalCameraData.ClearColorMode m_ClearMode;

        public bool m_OverrideCullingMask = false;
        public LayerMask m_CullingMask;

        public bool m_OverrideVolumeMask = false;
        public LayerMask m_VolumeMask;

        // Layer filters
        [HideInInspector]
        public List<CompositionFilter> m_InputFilters = new List<CompositionFilter>();

        // AOVs
        [HideInInspector]
        public MaterialSharedProperty m_AOVBitmask = 0;
        [HideInInspector]
        public Dictionary<string, int> m_AOVMap;
        List<RTHandle> m_AOVHandles;
        List<RenderTexture> m_AOVRenderTargets;

        [HideInInspector]
        public bool m_ExpandLayer = true;

        RTHandle m_RTHandle;
        RenderTexture m_RenderTarget;
        RTHandle m_AOVTmpRTHandle;

        Camera m_LayerCamera;
        bool m_ClearsBackGround = false;

        //static HashSet<Camera> s_CameraPool = new HashSet<Camera>();
        //static bool s_DisableCameraPool = true;

        public bool enabled
        {
            get => m_Show;
            set
            {
                m_Show = value;
            }
        }

        public float aspectRatio
        {
            get
            {
                if (m_Camera != null)
                {
                    return (float)m_Camera.pixelWidth / m_Camera.pixelHeight;
                }
                return 1.0f;
            }
        }

        private CompositorLayer()
        {
        }

        public static CompositorLayer CreateStackLayer(LayerType type = CompositorLayer.LayerType.Camera, string layerName = "New Layer")
        {
            var newLayer = new CompositorLayer();
            newLayer.m_LayerName = layerName;
            newLayer.m_Type = type;
            newLayer.m_OverrideCullingMask = true;
            newLayer.m_CullingMask = 0; //LayerMask.GetMask("None");
            newLayer.m_Camera = CompositionManager.GetSceceCamera();
            newLayer.m_OutputTarget = CompositorLayer.OutputTarget.CameraStack;
            newLayer.m_ClearDepth = true;

            if (newLayer.m_Type == LayerType.Image || newLayer.m_Type == LayerType.Video)
            {
                newLayer.m_OverrideVolumeMask = true;
                newLayer.m_VolumeMask = 0;
                newLayer.m_ClearAlpha = false;
                newLayer.m_OverrideAntialiasing = true;
                newLayer.m_Antialiasing = HDAdditionalCameraData.AntialiasingMode.None;
            }

            return newLayer;
        }

        public static CompositorLayer CreateOutputLayer(string layerName)
        {
            var newLayer = new CompositorLayer();
            newLayer.m_LayerName = layerName;
            newLayer.m_OutputTarget = CompositorLayer.OutputTarget.CompositorLayer;

            return newLayer;
        }

        static float EnumToScale(ResolutionScale scale)
        {
            float resScale = 1.0f;// / (int)m_ResolutionScale;
            switch (scale)
            {
                case ResolutionScale.Half:
                    resScale = 0.5f;
                    break;
                case ResolutionScale.Quarter:
                    resScale = 0.25f;
                    break;
                default:
                    resScale = 1.0f;
                    break;
            }
            return resScale;
        }

        public int pixelWidth
        {
            get
            {
                if (m_Camera)
                {
                    float resScale = EnumToScale(m_ResolutionScale);
                    return (int)(resScale * m_Camera.pixelWidth);
                }
                return 0;
            }
        }
        public int pixelHeight
        {
            get
            {
                if (m_Camera)
                {
                    float resScale = EnumToScale(m_ResolutionScale);
                    return (int)(resScale * m_Camera.pixelHeight);
                }
                return 0;
            }
        }
        public void Init(string layerID)
        {
            if (m_LayerName == "")
            {
                m_LayerName = layerID;
            }

            // Note: Movie & image layers are rendered at the output resolution (and not the movie/image resolution)
            // This is required to have post-processing effects like film grain at full res.
            if (m_Camera == null)
            {
                m_Camera = CompositionManager.GetSceceCamera();
            }

            // Create a new camera if necessary or use the one specified by the user
            if (m_LayerCamera == null && m_OutputTarget == OutputTarget.CameraStack)
            {
                m_LayerCamera = Object.Instantiate(m_Camera);

                // delete any audio listeners from the clone camera
                var listener = m_LayerCamera.GetComponent<AudioListener>();
                if (listener)
                {
                    CoreUtils.Destroy(listener);
                }
                m_LayerCamera.name = "CompositorLayer_" + layerID;
                m_LayerCamera.gameObject.hideFlags = HideFlags.HideInInspector | HideFlags.HideInHierarchy | HideFlags.HideAndDontSave;

                // Remove the compositor copy (if exists) from the cloned camera. This will happen if the compositor script was attached to the camera we are cloning 
                var compositionManager = m_LayerCamera.GetComponent<CompositionManager>();
                if (compositionManager != null)
                {
                    CoreUtils.Destroy(compositionManager);
                }

            }
            m_ClearsBackGround = false;

            if (m_OutputTarget != OutputTarget.CameraStack && m_RTHandle == null)
            {
                m_RenderTarget = new RenderTexture(pixelWidth, pixelHeight, 24, (GraphicsFormat)m_ColorBufferFormat);
                m_RTHandle = RTHandles.Alloc(m_RenderTarget);

                int aovMask = (1 << (int)m_AOVBitmask);
                if (aovMask > 1)
                {
                    m_AOVMap = new Dictionary<string, int>();
                    m_AOVRenderTargets = new List<RenderTexture>();
                    m_AOVHandles = new List<RTHandle>();

                    var aovNames = System.Enum.GetNames(typeof(MaterialSharedProperty));
                    int NUM_AOVs = aovNames.Length;
                    int outputIndex = 0;
                    for (int i = 0; i < NUM_AOVs; ++i)
                    {
                        if ((aovMask & (1 << i)) != 0)
                        {
                            m_AOVMap[aovNames[i]] = outputIndex;
                            m_AOVRenderTargets.Add(new RenderTexture(pixelWidth, pixelHeight, 24, (GraphicsFormat)m_ColorBufferFormat));
                            m_AOVHandles.Add(RTHandles.Alloc(m_AOVRenderTargets[outputIndex]));
                            outputIndex++;
                        }
                    }
                }
            }

            if (m_LayerCamera)
            {
                m_LayerCamera.enabled = m_Show;
                var cameraData = m_LayerCamera.GetComponent<HDAdditionalCameraData>();
                var layerData = m_LayerCamera.GetComponent<AdditionalCompositorData>();
                {
                    // create the component if it is required and does not exist
                    //bool requiresAdditionalData = (m_AlphaMask || m_ChromaKeying || m_Type == LayerType.Image);
                    if (layerData == null)
                    {
                        layerData = m_LayerCamera.gameObject.AddComponent<AdditionalCompositorData>();
                        layerData.hideFlags = HideFlags.HideAndDontSave;
                    }
                    // Reset the layer params (in case we cloned a camera which already had AdditionalCompositorData)
                    if (layerData != null)
                    {
                        layerData.Reset();
                    }
                }

                // layer overrides 
                SetLayerMaskOverrides();

                if (m_Type == LayerType.Video && m_InputVideo != null)
                {
                    m_InputVideo.targetCamera = m_LayerCamera;
                    m_InputVideo.renderMode = VideoRenderMode.CameraNearPlane;
                }
                else if (m_Type == LayerType.Image && m_InputTexture != null)
                {
                    cameraData.clearColorMode = HDAdditionalCameraData.ClearColorMode.None;

                    layerData.m_clearColorTexture = m_InputTexture;
                    layerData.m_imageFitMode = m_BackgroundFit;
                }

                // Custom pass to inject an alpha mask 
                SetAdditionalLayerData();

                if (m_InputFilters == null)
                {
                    m_InputFilters = new List<CompositionFilter>();
                }
            }
        }

        public void DestroyRT()
        {
            if (m_LayerCamera != null && m_LayerCamera.name.Contains("CompositorLayer"))
            {
                var cameraData = m_LayerCamera.GetComponent<HDAdditionalCameraData>();
                if (cameraData)
                {
                    CoreUtils.Destroy(cameraData);
                }
                m_LayerCamera.targetTexture = null;
                CoreUtils.Destroy(m_LayerCamera);
            }

            RTHandles.Release(m_RTHandle);
            CoreUtils.Destroy(m_RenderTarget);

            if (m_AOVHandles != null)
            {
                foreach (var handle in m_AOVHandles)
                {
                    CoreUtils.Destroy(handle);
                }
            }
            if (m_AOVRenderTargets != null)
            {
                foreach (var rt in m_AOVRenderTargets)
                {
                    CoreUtils.Destroy(rt);
                }
            }
            m_AOVMap?.Clear();


            m_RTHandle = null;
            m_LayerCamera = null;
            m_AOVMap = null;
        }

        public void Destroy()
        {
            DestroyRT();
        }

        public void SetLayerMaskOverrides()
        {
            if (m_OverrideCullingMask && m_LayerCamera)
            {
                m_LayerCamera.cullingMask = m_ClearsBackGround ? (LayerMask)0 : m_CullingMask;
            }

            if (m_LayerCamera)
            {
                var cameraData = m_LayerCamera.GetComponent<HDAdditionalCameraData>();
                if (cameraData)
                {
                    if (m_OverrideVolumeMask && m_LayerCamera)
                    {
                        cameraData.volumeLayerMask = m_VolumeMask;
                    }
                    cameraData.volumeLayerMask |= 1 << 31;

                    if (m_OverrideAntialiasing)
                    {
                        cameraData.antialiasing = m_Antialiasing;
                    }

                    if (m_OverrideClearMode)
                    {
                        cameraData.clearColorMode = m_ClearMode;
                    }
                }
            }
        }

        public void SetAdditionalLayerData()
        {
            if (m_LayerCamera)
            {
                var layerData = m_LayerCamera.GetComponent<AdditionalCompositorData>();
                if (layerData != null)
                {
                    layerData.Init(m_InputFilters, m_ClearAlpha);
                }
            }
        }

        public void UpdateOutputCameraAndTexture(bool isPlaying)
        {
            if (m_OutputRenderer != null)
            {
                m_OutputRenderer.enabled = m_Show || m_ClearsBackGround;
                if (isPlaying)
                {
                    foreach (var material in m_OutputRenderer.materials)
                    {
                        material?.SetTexture("_BaseColorMap", m_RenderTarget);
                    }
                }
            }

            if (m_LayerCamera == null)
            {
                return;
            }

            m_LayerCamera.enabled = m_Show || m_ClearsBackGround;

            //TODO: maybe we can spawn the clone camera as child of the original one
            m_LayerCamera.gameObject.transform.position = m_Camera.gameObject.transform.position;
            m_LayerCamera.gameObject.transform.rotation = m_Camera.gameObject.transform.rotation;
            m_LayerCamera.gameObject.transform.localScale = m_Camera.gameObject.transform.localScale;
        }

        public void Update(bool isPlaying)
        {
            UpdateOutputCameraAndTexture(isPlaying);
            SetLayerMaskOverrides();
            SetAdditionalLayerData();
        }

        public void SetPriotiry(float priority)
        {
            if (m_LayerCamera)
            {
                m_LayerCamera.depth = priority;
            }
        }

        public RenderTexture GetRenderTarget(bool allowAOV = true)
        {
            if (m_Show)
            {
                if (m_AOVMap != null && allowAOV)
                {
                    foreach (var aov in m_AOVMap)
                    {
                        return m_AOVRenderTargets[aov.Value];
                    }
                }

                return m_RenderTarget;
            }
            return null;
        }

        public Camera GetLayerCamera()
        {
            return m_LayerCamera;
        }

        public OutputTarget GetOutputTarget()
        {
            return m_OutputTarget;
        }

        public void SetupClearColor()
        {
            m_LayerCamera.enabled = true;
            m_LayerCamera.cullingMask = 0;
            var cameraData = m_LayerCamera.GetComponent<HDAdditionalCameraData>();
            var cameraDataOrig = m_Camera.GetComponent<HDAdditionalCameraData>();

            cameraData.clearColorMode = cameraDataOrig.clearColorMode;
            cameraData.clearDepth = true;

            m_ClearsBackGround = true;
        }

        public void AddInputFilter(CompositionFilter filter)
        {
            // avoid duplicate filters
            foreach (var f in m_InputFilters)
            {
                if (f.m_Type == filter.m_Type)
                {
                    return;
                }
            }
            m_InputFilters.Add(filter);
        }
        public void SetupLayerCamera(CompositorLayer targetLayer, bool shouldClearColor = false)
        {
            if (targetLayer.GetRenderTarget() == null)
            {
                m_LayerCamera.enabled = false;
                return;
            }

            var cameraData = m_LayerCamera.GetComponent<HDAdditionalCameraData>();
            cameraData.clearDepth = m_ClearDepth;

            m_LayerCamera.targetTexture = targetLayer.GetRenderTarget(false);

            if (targetLayer.m_AOVBitmask == 0)
            {
                if (!shouldClearColor)
                {
                    // The next layer in the stack should clear with the texture of the previous layer: this will copy the content of the target RT to the RTHandle and preserve post process
                    cameraData.clearColorMode = HDAdditionalCameraData.ClearColorMode.None;
                    var compositorData = m_LayerCamera.GetComponent<AdditionalCompositorData>();
                    if (!compositorData)
                    {
                        compositorData = m_LayerCamera.gameObject.AddComponent<AdditionalCompositorData>();
                    }
                    compositorData.m_clearColorTexture = targetLayer.GetRenderTarget(false);
                    cameraData.volumeLayerMask |= 1 << 31;
                }
            }

            // The target layer expects AOVs, so this stacked layer should also generate AOVs
            int aovMask = (1 << (int)targetLayer.m_AOVBitmask);
            if (aovMask > 1)
            {
                var aovRequestBuilder = new AOVRequestBuilder();

                var aovNames = System.Enum.GetNames(typeof(MaterialSharedProperty));
                int NUM_AOVs = aovNames.Length;
                int outputIndex = 0;
                for (int i = 0; i < NUM_AOVs; ++i)
                {
                    if ((aovMask & (1 << i)) != 0)
                    {
                        int aovType = i;

                        var aovRequest = new AOVRequest(AOVRequest.NewDefault());
                        aovRequest.SetFullscreenOutput((MaterialSharedProperty)aovType);

                        int indexLocalCopy = outputIndex; //< required to properly capture the variable in the lambda
                        aovRequestBuilder.Add(
                            aovRequest,
                            bufferId => targetLayer.m_AOVTmpRTHandle ?? (targetLayer.m_AOVTmpRTHandle = RTHandles.Alloc(targetLayer.pixelWidth, targetLayer.pixelHeight)),
                            null,
                            new[] { AOVBuffers.Color },
                            (cmd, textures, properties) =>
                            {
                            // copy result to the output buffer
                            cmd.Blit(textures[0], targetLayer.m_AOVRenderTargets[indexLocalCopy]);
                            }
                        );
                        outputIndex++;
                    }
                }

                cameraData.SetAOVRequests(aovRequestBuilder.Build());
                m_LayerCamera.enabled = true;
            }
        }

    }
}
