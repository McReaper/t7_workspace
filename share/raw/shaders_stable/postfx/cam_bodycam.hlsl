#include "postfx/postfx_common.h"

// ============================================================================
//  cam_bodycam.hlsl  —  "our own" bodycam camera filter for zm_rainy_d2om
//
//  A single fullscreen post-process pass that stacks the four effects that
//  define the UNRECORD / KILLFEED bodycam look:
//     1. Fisheye     — radial UV warp (barrel distortion)   [reuses the exact
//                       math of the shipping postfx/fisheye.hlsl]
//     2. Chromatic   — per-channel UV offset, stronger at the frame edges
//        aberration
//     3. Vignette    — radial darkening toward the edges
//     4. Film grain  — animated hash noise
//
//  Built on Treyarch's postfx scaffolding (postfx_common.h ->
//  PostFx_GenerateFullscreenQuad, resolvedScene sampling) so it compiles the
//  same way the stock fisheye filter does. All strengths come in as material
//  constants (see cam_bodycam.techsetdef) so the look is tuned in APE without
//  recompiling the shader.
// ============================================================================

// --- Fisheye (cg00.xyz) ---
float fisheyeRadius;      // reach of the lens gradient
float fisheyeDensity;     // falloff curve of the gradient
float fisheyeIntensity;   // strength of the barrel warp

// --- Vignette (cg00.w, cg01.xy) ---
float vignetteStrength;   // 0 = off, 1 = fully dark edges
float vignetteRadius;     // where the darkening begins (smaller = darker)
float vignetteDensity;    // falloff softness of the vignette

// --- Chromatic aberration (cg01.z) ---
float chromaticStrength;  // per-channel UV split amount at the edges

// --- Film grain (cg01.w, cg02.x) ---
float grainStrength;      // amount of noise added to the image
float grainScale;         // grain cells across the screen (lower = coarser/bigger)

#if TOOLSGFX

SamplerState bilinearClampler : register(s0);
Texture2D<float3> sceneTexture : register(t0);

#else

SamplerState bilinearClampler : register(s1);
Texture2D<float3> sceneTexture : register(t0);

#endif

struct VertexInput
{
	float3 position : POSITION;
	float2 texCoords : TEXCOORD0;
};

struct PixelInput
{
	float4 position : SV_POSITION;
	float2 texCoords : TEXCOORD0;
#if TOOLSGFX
	float1 fakeInput : TEXCOORD1;
#endif
};

PixelInput vs_main(const VertexInput vertex, const uint instance : INSTANCE_SEMANTIC)
{
	PixelInput pixel;

	PostFx_GenerateFullscreenQuad(vertex.position, vertex.texCoords, instance, pixel.position, pixel.texCoords);

	#if TOOLSGFX
	// We need to have the vertex inputs used in this shader otherwise it won't compile
	pixel.fakeInput.x = vertex.position.x;
	#endif

	return pixel;
}

float4 ps_main(const PixelInput pixel) : SV_TARGET
{
	float2 texCoords = pixel.texCoords;

	PostFx_FixPreviewResolution(pixel.position.xy, texCoords);

	// --- 1) Fisheye: warp UVs toward the centre (identical math to fisheye.hlsl) ---
	float fishGradient = RadialGradientExponential(texCoords, 0.5, fisheyeRadius, fisheyeDensity, false);
	float2 uv = texCoords - ((texCoords - 0.5) * fishGradient * fisheyeIntensity);

	// --- 2) Chromatic aberration: split R/B along the vector from the centre,
	//        ramped up toward the frame edges for a lens-edge fringe ---
	float2 fromCenter = uv - 0.5;
	float  edge = saturate(length(fromCenter) * 2.0);      // ~0 centre -> ~1 edge
	float2 caOffset = fromCenter * chromaticStrength * edge;

	float3 color;
	color.r = sceneTexture.Sample(bilinearClampler, uv + caOffset).r;
	color.g = sceneTexture.Sample(bilinearClampler, uv).g;
	color.b = sceneTexture.Sample(bilinearClampler, uv - caOffset).b;

	// --- 3) Vignette: darken toward the edges (1 at centre -> vig at edge) ---
	float vig = RadialGradientExponential(texCoords, 0.5, vignetteRadius, vignetteDensity, false);
	float vigFactor = lerp(1.0, vig, saturate(vignetteStrength));
	color *= vigFactor;

	// --- 4) Film grain: noise quantised into cells so the grains are chunkier
	//        than one pixel. grainScale = cells across the screen -> LOWER is
	//        coarser/bigger grain, HIGHER is finer. Refreshed in ~16 Hz steps so
	//        temporal AA can't average the motion to gray. GetTime() is seconds;
	//        cg01_w = strength. Tune grainScale to taste. ---
	float  grainStep = fmod(floor(GetTime() * 16.0), 64.0);
	float2 grainXY   = float2(texCoords.x * GetAspectRatio(), texCoords.y);  // square cells, not stretched by 16:9
	float2 cell      = floor(grainXY * grainScale);
	float2 seed      = (cell + grainStep * float2(37.0, 17.0)) / max(grainScale, 1.0);
	float  n         = Random2D(seed);
	color *= 1.0 + (n - 0.5) * grainStrength;

	#if TOOLSGFX
	color = LinearToSRGB(color);
	#endif

	return float4(color, 1);
}
