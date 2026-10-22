$input v_color0, v_light, v_texcoord0, v_worldPos, v_clipPos

#include "bgfx_shader.sh"

#if BGFX_SHADER_LANGUAGE_GLSL
	precision highp float;
	precision highp int;
#endif

#include "ActorUtil.dragonh"

uniform vec4 ColorBased;
uniform vec4 ChangeColor;
uniform vec4 UseAlphaRewrite;
uniform vec4 TintedAlphaTestEnabled;
uniform vec4 MatColor;
uniform vec4 OverlayColor;
uniform vec4 MultiplicativeTintColor;
uniform vec4 HudOpacity;
uniform vec4 ActorFPEpsilon;
uniform vec4 UVAnimation;
uniform vec4 DitherParams2[3];
uniform vec4 DitherParams;
uniform vec4 DitheringEnabledToggle;

SAMPLER2D(s_MatTexture, 0);
SAMPLER2D(s_MatTexture1, 1);

void main() {
#if defined(DEPTH_ONLY_PASS)
    gl_FragColor = vec4_splat(0.0);
    return;
#elif defined(DEPTH_ONLY_OPAQUE_PASS)
    gl_FragColor = vec4_splat(1.0);
    return;
#else

    vec4 finalColor = getActorAlbedoNoColorChange(v_texcoord0, s_MatTexture, s_MatTexture1, MatColor);

    #ifdef ALPHA_TEST_PASS
        float alpha = mix(finalColor.a, (finalColor.a * OverlayColor.a), TintedAlphaTestEnabled.x);
        bool shouldDither = false;

        if (DitheringEnabledToggle.x != 0.0) {
            vec2 ditherUV0 = floor(((((v_clipPos.xyz / vec3_splat(v_clipPos.w)).xy * 0.5) + vec2_splat(0.5)) * DitherParams.xy) / vec2_splat(DitherParams2[0].z)) * DitherParams2[0].z;
            vec2 ditherUV1 = floor(ditherUV0 * 0.25);
            vec2 ditherUV2 = floor(ditherUV0 * 0.5);
            vec2 ditherUV3 = floor(ditherUV0);
            shouldDither = bool(smoothstep(DitherParams2[0].x, DitherParams2[0].y, dot(-normalize(u_view[2].xyz), v_worldPos - (vec4_splat(0.0) * u_invView[0]).xyz)) <= (((((((fract((ditherUV1.x * 0.5) + ((ditherUV1.y * ditherUV1.y) * 0.75)) * 0.25) + fract((ditherUV2.x * 0.5) + ((ditherUV2.y * ditherUV2.y) * 0.75))) * 0.25) + fract((ditherUV3.x * 0.5) + ((ditherUV3.y * ditherUV3.y) * 0.75))) * 64.0) + 0.5) * 0.015625));
        }

        if (shouldDither || shouldDiscard(finalColor.rgb, alpha, ActorFPEpsilon.x)) {
            discard;
        }
    #endif

    #if defined(CHANGE_COLOR__MULTI)
        finalColor = applyMultiColorChange(finalColor, ChangeColor.rgb, MultiplicativeTintColor.rgb);
    #else
        #if defined(CHANGE_COLOR__ON)
            finalColor = applyColorChange(finalColor, ChangeColor, finalColor.a);
            finalColor.a *= ChangeColor.a;
        #endif
    #endif

    #ifdef ALPHA_TEST_PASS
        finalColor.a = max(UseAlphaRewrite.r, finalColor.a);
    #endif

    finalColor = applyActorDiffuse(finalColor, v_color0.rgb, v_light, ColorBased.x, OverlayColor);

    #ifdef TRANSPARENT_PASS
        finalColor = applyHudOpacity(finalColor, HudOpacity.x);
    #endif

    gl_FragColor = finalColor;
#endif
}