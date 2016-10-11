// GENERATED BY SHADER GRAPH
// Question for shader graph: how to handle dynamic parameter data like matData0 that can change name

// No guard header!

#define UNITY_MATERIAL_LIT // Need to be define before including Material.hlsl
#include "Lighting/Lighting.hlsl" // This include Material.hlsl
#include "ShaderVariables.hlsl"
#include "Debug/DebugViewMaterial.hlsl"

// This files is generated by the ShaderGraph or written by hand

// Note for ShaderGraph:
// ShaderGraph should generate the vertex shader output to add the variable that may be required
// For example if we require view vector in shader graph, the output must contain positionWS and we calcualte the view vector with it.
// Still some input are mandatory depends on the type of loop. positionWS is mandatory in this current framework. So the ShaderGraph should always generate it.


#define PROP_DECL(type, name) type name, name##0, name##1, name##2, name##3;
#define PROP_SAMPLE(name, samplerName, texcoord, swizzle)\
    name##0 = tex2D(samplerName##0, texcoord).##swizzle; \
    name##1 = tex2D(samplerName##1, texcoord).##swizzle; \
    name##2 = tex2D(samplerName##2, texcoord).##swizzle; \
    name##3 = tex2D(samplerName##3, texcoord).##swizzle;
#define PROP_MUL(name, multiplier, swizzle)\
    name##0 *= multiplier##0.##swizzle; \
    name##1 *= multiplier##1.##swizzle; \
    name##2 *= multiplier##2.##swizzle; \
    name##3 *= multiplier##3.##swizzle;
#define PROP_ASSIGN(name, input, swizzle)\
    name##0 = input##0.##swizzle; \
    name##1 = input##1.##swizzle; \
    name##2 = input##2.##swizzle; \
    name##3 = input##3.##swizzle;
#define PROP_ASSIGN_VALUE(name, input)\
    name##0 = input; \
    name##1 = input; \
    name##2 = input; \
    name##3 = input;
#define PROP_BLEND_COLOR(name, mask) name = BlendLayeredColor(name##0, name##1, name##2, name##3, mask);
#define PROP_BLEND_SCALAR(name, mask) name = BlendLayeredScalar(name##0, name##1, name##2, name##3, mask);

//-------------------------------------------------------------------------------------
// variable declaration
//-------------------------------------------------------------------------------------

// Set of users variables
PROP_DECL(float4, _BaseColor);
PROP_DECL(sampler2D, _BaseColorMap);
PROP_DECL(float, _Metalic);
PROP_DECL(float, _Smoothness);
PROP_DECL(sampler2D, _MaskMap);
PROP_DECL(sampler2D, _SpecularOcclusionMap);
PROP_DECL(sampler2D, _NormalMap);
PROP_DECL(sampler2D, _Heightmap);
PROP_DECL(float, _HeightScale);
PROP_DECL(float, _HeightBias);
PROP_DECL(float4, _EmissiveColor);
PROP_DECL(float, _EmissiveIntensity);

float _AlphaCutoff;
sampler2D _LayerMaskMap;

//-------------------------------------------------------------------------------------
// Lighting architecture
//-------------------------------------------------------------------------------------

// TODO: Check if we will have different Varyings based on different pass, not sure about that...

// Forward
struct Attributes
{
    float3 positionOS	: POSITION;
    float3 normalOS		: NORMAL;
    float2 uv0			: TEXCOORD0;
    float4 tangentOS	: TANGENT;
    float4 color        : TANGENT;
};

struct Varyings
{
    float4 positionHS;
    float3 positionWS;
    float2 texCoord0;
    float4 tangentToWorld[3]; // [3x3:tangentToWorld | 1x3:viewDirForParallax]
    float4 vertexColor;

#ifdef SHADER_STAGE_FRAGMENT
    #if defined(_DOUBLESIDED_LIGHTING_FLIP) || defined(_DOUBLESIDED_LIGHTING_MIRROR)
    FRONT_FACE_TYPE cullFace;
    #endif
#endif
};

struct PackedVaryings
{
    float4 positionHS : SV_Position;
    float4 interpolators[6] : TEXCOORD0;

#ifdef SHADER_STAGE_FRAGMENT
    #if defined(_DOUBLESIDED_LIGHTING_FLIP) || defined(_DOUBLESIDED_LIGHTING_MIRROR)
    FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMATIC;
    #endif
#endif
};

// Function to pack data to use as few interpolator as possible, the ShaderGraph should generate these functions
PackedVaryings PackVaryings(Varyings input)
{
    PackedVaryings output;
    output.positionHS = input.positionHS;
    output.interpolators[0].xyz = input.positionWS.xyz;
    output.interpolators[0].w = input.texCoord0.x;
    output.interpolators[1] = input.tangentToWorld[0];
    output.interpolators[2] = input.tangentToWorld[1];
    output.interpolators[3] = input.tangentToWorld[2];
    output.interpolators[4].x = input.texCoord0.y;
    output.interpolators[4].yzw = float3(0.0, 0.0, 0.0);
    output.interpolators[5] = input.vertexColor;

    return output;
}

Varyings UnpackVaryings(PackedVaryings input)
{
    Varyings output;
    output.positionHS = input.positionHS;
    output.positionWS.xyz = input.interpolators[0].xyz;
    output.texCoord0.x = input.interpolators[0].w;
    output.texCoord0.y = input.interpolators[4].x;
    output.tangentToWorld[0] = input.interpolators[1];
    output.tangentToWorld[1] = input.interpolators[2];
    output.tangentToWorld[2] = input.interpolators[3];
    output.vertexColor = input.interpolators[5];

#ifdef SHADER_STAGE_FRAGMENT
    #if defined(_DOUBLESIDED_LIGHTING_FLIP) || defined(_DOUBLESIDED_LIGHTING_MIRROR)
    output.cullFace = input.cullFace;
    #endif
#endif

    return output;
}

// TODO: Here we will also have all the vertex deformation (GPU skinning, vertex animation, morph target...) or we will need to generate a compute shaders instead (better! but require work to deal with unpacking like fp16)
PackedVaryings VertDefault(Attributes input)
{
    Varyings output;

    output.positionWS = TransformObjectToWorld(input.positionOS);
    // TODO deal with camera center rendering and instancing (This is the reason why we always perform tow steps transform to clip space + instancing matrix)
    output.positionHS = TransformWorldToHClip(output.positionWS);

    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

    output.texCoord0 = input.uv0;

    float4 tangentWS = float4(TransformObjectToWorldDir(input.tangentOS.xyz), input.tangentOS.w);

    float3x3 tangentToWorld = CreateTangentToWorld(normalWS, tangentWS.xyz, tangentWS.w);
    output.tangentToWorld[0].xyz = tangentToWorld[0];
    output.tangentToWorld[1].xyz = tangentToWorld[1];
    output.tangentToWorld[2].xyz = tangentToWorld[2];

    output.tangentToWorld[0].w = 0;
    output.tangentToWorld[1].w = 0;
    output.tangentToWorld[2].w = 0;

    output.vertexColor = input.color;

    return PackVaryings(output);
}


//-------------------------------------------------------------------------------------
// Fill SurfaceData/Lighting data function
//-------------------------------------------------------------------------------------

float3 TransformTangentToWorld(float3 normalTS, float4 tangentToWorld[3])
{
    // TODO check: do we need to normalize ?
    return normalize(mul(normalTS, float3x3(tangentToWorld[0].xyz, tangentToWorld[1].xyz, tangentToWorld[2].xyz)));
}

#if SHADER_STAGE_FRAGMENT

float3 BlendLayeredColor(float3 rgb0, float3 rgb1, float3 rgb2, float3 rgb3, float weight[4])
{
    return rgb0 * weight[0] + rgb1 * weight[1] + rgb2 * weight[2] + rgb3 * weight[3];
}

float3 BlendLayeredNormal(float3 normal0, float3 normal1, float3 normal2, float3 normal3, float weight[4])
{
    // TODO : real normal map blending function
    return normal0 * weight[0] + normal1 * weight[1] + normal2 * weight[2] + normal3 * weight[3];
}

float BlendLayeredScalar(float x0, float x1, float x2, float x3, float weight[4])
{
    return x0 * weight[0] + x1 * weight[1] + x2 * weight[2] + x3 * weight[3];
}

#define MAX_LAYER 4

void ComputeMaskWeights(float4 inputMasks, out float outWeights[MAX_LAYER])
{
    float masks[MAX_LAYER];
    masks[0] = inputMasks.r;
    masks[1] = inputMasks.g;
    masks[2] = inputMasks.b;
    masks[3] = inputMasks.a;

    // calculate weight of each layers
    float left = 1.0f;

    // ATTRIBUTE_UNROLL
    for (int i = MAX_LAYER - 1; i > 0; --i)
    {
        outWeights[i] = masks[i] * left;
        left -= outWeights[i];
    }
    outWeights[0] = left;
}

void GetSurfaceAndBuiltinData(Varyings input, out SurfaceData surfaceData, out BuiltinData builtinData)
{
    float4 maskValues = float4(1.0, 1.0, 1.0, 1.0);// input.vertexColor;

#ifdef _LAYERMASKMAP
    float4 maskMap = tex2D(_LayerMaskMap, input.texCoord0);
    maskValues *= maskMap;
#endif

    float weights[MAX_LAYER];
    ComputeMaskWeights(maskValues, weights);

    PROP_DECL(float3, baseColor);
    PROP_SAMPLE(baseColor, _BaseColorMap, input.texCoord0, rgb);
    PROP_MUL(baseColor, _BaseColor, rgb);
    PROP_BLEND_COLOR(baseColor, weights);

    surfaceData.baseColor = baseColor;

    PROP_DECL(float, alpha);
#ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
    PROP_ASSIGN(alpha, _BaseColor, a);
#else
    PROP_SAMPLE(alpha, _BaseColorMap, input.texCoord0, a);
    PROP_MUL(alpha, _BaseColor, a);
#endif
    PROP_BLEND_SCALAR(alpha, weights);

#ifdef _ALPHATEST_ON
    clip(alpha - _AlphaCutoff);
#endif

    builtinData.opacity = alpha;

    PROP_DECL(float, specularOcclusion);
#ifdef _SPECULAROCCLUSIONMAP
    // TODO: Do something. For now just take alpha channel
    PROP_SAMPLE(specularOcclusion, _SpecularOcclusionMap, input.texCoord0, a);
#else
    // Horizon Occlusion for Normal Mapped Reflections: http://marmosetco.tumblr.com/post/81245981087
    //surfaceData.specularOcclusion = saturate(1.0 + horizonFade * dot(r, input.tangentToWorld[2].xyz);
    // smooth it
    //surfaceData.specularOcclusion *= surfaceData.specularOcclusion;
    PROP_ASSIGN_VALUE(specularOcclusion, 1.0);
#endif
    PROP_BLEND_SCALAR(specularOcclusion, weights);
    surfaceData.specularOcclusion = specularOcclusion;

    // TODO: think about using BC5
    float3 vertexNormalWS = input.tangentToWorld[2].xyz;

#ifdef _NORMALMAP
    #ifdef _NORMALMAP_TANGENT_SPACE
    float3 normalTS0 = UnpackNormalAG(tex2D(_NormalMap0, input.texCoord0));
    float3 normalTS1 = UnpackNormalAG(tex2D(_NormalMap1, input.texCoord0));
    float3 normalTS2 = UnpackNormalAG(tex2D(_NormalMap2, input.texCoord0));
    float3 normalTS3 = UnpackNormalAG(tex2D(_NormalMap3, input.texCoord0));

    float3 normalTS = BlendLayeredNormal(normalTS0, normalTS1, normalTS2, normalTS3, weights);

    surfaceData.normalWS = TransformTangentToWorld(normalTS, input.tangentToWorld);
    #else // Object space (TODO: We need to apply the world rotation here!)
    surfaceData.normalWS = tex2D(_NormalMap, input.texCoord0).rgb;
    #endif
#else
    surfaceData.normalWS = vertexNormalWS;
#endif

#if defined(_DOUBLESIDED_LIGHTING_FLIP) || defined(_DOUBLESIDED_LIGHTING_MIRROR)
    #ifdef _DOUBLESIDED_LIGHTING_FLIP	
    float3 oppositeNormalWS = -surfaceData.normalWS;
    #else
    // Mirror the normal with the plane define by vertex normal
    float3 oppositeNormalWS = reflect(surfaceData.normalWS, vertexNormalWS);
    #endif
        // TODO : Test if GetOdddNegativeScale() is necessary here in case of normal map, as GetOdddNegativeScale is take into account in CreateTangentToWorld();
    surfaceData.normalWS = IS_FRONT_VFACE(input.cullFace, GetOdddNegativeScale() >= 0.0 ? surfaceData.normalWS : oppositeNormalWS, -GetOdddNegativeScale() >= 0.0 ? surfaceData.normalWS : oppositeNormalWS);
#endif


    PROP_DECL(float, perceptualSmoothness);
#ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
    PROP_SAMPLE(perceptualSmoothness, _BaseColorMap, input.texCoord0, a);
#elif defined(_MASKMAP)
    PROP_SAMPLE(perceptualSmoothness, _MaskMap, input.texCoord0, a);
#else
    PROP_ASSIGN_VALUE(perceptualSmoothness, 1.0);
#endif
    PROP_MUL(perceptualSmoothness, _Smoothness, r);
    PROP_BLEND_SCALAR(perceptualSmoothness, weights);

    surfaceData.perceptualSmoothness = perceptualSmoothness;

    surfaceData.materialId = 0;

    // MaskMap is Metalic, Ambient Occlusion, (Optional) - emissive Mask, Optional - Smoothness (in alpha)
    PROP_DECL(float, metalic);
    PROP_DECL(float, ambientOcclusion);
#ifdef _MASKMAP
    PROP_SAMPLE(metalic, _MaskMap, input.texCoord0, a);
    PROP_SAMPLE(ambientOcclusion, _MaskMap, input.texCoord0, g);
#else
    PROP_ASSIGN_VALUE(metalic, 1.0);
    PROP_ASSIGN_VALUE(ambientOcclusion, 1.0);
#endif
    PROP_MUL(metalic, _Metalic, r);
    
    PROP_BLEND_SCALAR(metalic, weights);
    PROP_BLEND_SCALAR(ambientOcclusion, weights);

    surfaceData.metalic = metalic;
    surfaceData.ambientOcclusion = ambientOcclusion;

    surfaceData.tangentWS = float3(1.0, 0.0, 0.0);
    surfaceData.anisotropy = 0;
    surfaceData.specular = 0.04;

    surfaceData.subSurfaceRadius = 1.0;
    surfaceData.thickness = 0.0;
    surfaceData.subSurfaceProfile = 0;

    surfaceData.coatNormalWS = float3(1.0, 0.0, 0.0);
    surfaceData.coatPerceptualSmoothness = 1.0;
    surfaceData.specularColor = float3(0.0, 0.0, 0.0);

    // Builtin Data

    // TODO: Sample lightmap/lightprobe/volume proxy
    // This should also handle projective lightmap
    // Note that data input above can be use to sample into lightmap (like normal)
    builtinData.bakeDiffuseLighting = float3(0.0, 0.0, 0.0);// tex2D(_DiffuseLightingMap, input.texCoord0).rgb;

    // If we chose an emissive color, we have a dedicated texture for it and don't use MaskMap
    PROP_DECL(float3, emissiveColor);
#ifdef _EMISSIVE_COLOR
    #ifdef _EMISSIVE_COLOR_MAP
        PROP_SAMPLE(emissiveColor, _EmissiveColorMap, input.texCoord0, rgb);
    #else
        PROP_ASSIGN(emissiveColor, _EmissiveColor, rgb);
    #endif
#elif defined(_MASKMAP) // If we have a MaskMap, use emissive slot as a mask on baseColor
    PROP_SAMPLE(emissiveColor, _MaskMap, input.texCoord0, bbb);
    PROP_MUL(emissiveColor, baseColor, rgb);
#else
    PROP_ASSIGN_VALUE(emissiveColor, float3(0.0, 0.0, 0.0));
#endif
    PROP_BLEND_COLOR(emissiveColor, weights);
    builtinData.emissiveColor = emissiveColor;

    PROP_DECL(float, emissiveIntensity);
    PROP_ASSIGN(emissiveIntensity, _EmissiveIntensity, r);
    PROP_BLEND_SCALAR(emissiveIntensity, weights);
    builtinData.emissiveIntensity = emissiveIntensity;

    builtinData.velocity = float2(0.0, 0.0);

    builtinData.distortion = float2(0.0, 0.0);
    builtinData.distortionBlur = 0.0;
}

void GetVaryingsDataDebug(uint paramId, Varyings input, inout float3 result, inout bool needLinearToSRGB)
{
    switch (paramId)
    {
    case DEBUGVIEW_VARYING_DEPTH:
        // TODO: provide a customize parameter (like a slider)
        float linearDepth = frac(LinearEyeDepth(input.positionHS.z, _ZBufferParams) * 0.1);
        result = linearDepth.xxx;
        break;
    case DEBUGVIEW_VARYING_TEXCOORD0:
        // TODO: require a remap
        result = float3(input.texCoord0, 0.0);
        break;
    case DEBUGVIEW_VARYING_VERTEXNORMALWS:
        result = input.tangentToWorld[2].xyz * 0.5 + 0.5;
        break;
    case DEBUGVIEW_VARYING_VERTEXTANGENTWS:
        result = input.tangentToWorld[0].xyz * 0.5 + 0.5;
        break;
    case DEBUGVIEW_VARYING_VERTEXBITANGENTWS:
        result = input.tangentToWorld[1].xyz * 0.5 + 0.5;
        break;
    case DEBUGVIEW_VARYING_VERTEXCOLOR:
        result = input.vertexColor.xyz;
        break;
    }
}

#endif // #if SHADER_STAGE_FRAGMENT
