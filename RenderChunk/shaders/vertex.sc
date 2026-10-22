$input a_color0, a_position, a_texcoord0, a_texcoord1
#ifdef INSTANCING__ON
    $input i_data0, i_data1, i_data2
#endif
$output v_color0, v_fog, v_texcoord0, v_texcoord1, v_waterFlag, v_playerPos, v_worldPos, v_viewPos

#include "bgfx_shader.sh"

#if BGFX_SHADER_LANGUAGE_GLSL
	precision highp float;
	precision highp int;
#endif

#include "magic.sh"
#include "fastMath.sh"
#include "hack.sh"

uniform vec4 FogColor;
uniform vec4 RenderChunkFogAlpha;
uniform vec4 FogAndDistanceControl;
uniform vec4 ViewPositionAndTime;
uniform vec4 MinecraftCameraPosition;

void main() {
    bool underwater = isUnderwater(FogColor, FogAndDistanceControl.xy);
    bool nether = isNehter(FogColor, FogAndDistanceControl.xy);
    bool theEnd = isTheEnd(FogColor, FogAndDistanceControl.xy);
    float rainLevel = (underwater || nether || theEnd) ? 0.0 : getRainLevel(FogColor, FogAndDistanceControl.xy);

    #ifdef INSTANCING__ON
        mat4 model = mtxFromCols(i_data0, i_data1, i_data2, vec4(vec3_splat(0.0), 1.0));
    #else
        mat4 model = u_model[0];
    #endif

    v_playerPos = mul(model, vec4(a_position, 1.0)).xyz;

    #ifdef RENDER_AS_BILLBOARDS__ON
        v_playerPos += 0.5;
        vec3 viewDir = normalize(v_playerPos - ViewPositionAndTime.xyz);
        vec3 boardPlane = normalize(vec3(viewDir.z, 0.0, -viewDir.x));
        v_playerPos = (v_playerPos -
            ((((viewDir.yzx * boardPlane.zxy) - (viewDir.zxy * boardPlane.yzx)) *
            (a_color0.z - 0.5)) +
            (boardPlane * (a_color0.x - 0.5))));
    #endif

    v_worldPos = v_playerPos + MinecraftCameraPosition.xyz;
    v_viewPos = mul(u_view, vec4(v_playerPos, 1.0)).xyz;

    #ifdef RENDER_AS_BILLBOARDS__ON
		v_color0 = vec4_splat(1.0);
	#else
		v_color0 = a_color0;
	#endif

    uvec2 texcoord0Temp = uvec2(round(a_texcoord0 * 65535.0));
    v_texcoord0 = vec2((texcoord0Temp & 32767u) << 1u) * 1.5259021893143653e-05;
    v_texcoord0 += 3.0517578125e-05 * (2.0 * vec2((texcoord0Temp & 32768u) >> 15u) - 1.0);
    v_texcoord1 = fract(a_texcoord1.y * vec2(256.0, 4096.0));

    float camDis = length(v_playerPos) / FogAndDistanceControl.z;

    // Apply fog.
    float fogStart = 0.7;
    float fogEnd = 1.0;

    fogStart = mix(fogStart, mix(fogStart, 0.0, rainLevel), v_texcoord1.y);

    if (underwater) {
        fogStart = 0.0;
        fogEnd = 0.5;
    }
    v_fog = clamp((camDis + RenderChunkFogAlpha.x - fogStart) / (fogEnd - fogStart), 0.0, 1.0);

    v_waterFlag = 0.0;
    #if defined(TRANSPARENT_PASS) && !defined(SEASONS__ON)
        if (a_color0.a < 0.95) {
            v_waterFlag = 1.0;
        }
    #endif

    gl_Position = mul(u_proj, vec4(v_viewPos, 1.0));

    // Apply foliage waves.
    if (isFoliage(a_color0, a_position)) {
        vec3 posw = v_worldPos.xyz;
        float wave = sin(ViewPositionAndTime.w * 3.5 + 2.0 * posw.x + 2.0 * posw.z + posw.y);
        float wind = smoothstep(0.0, 1.0, sin(ViewPositionAndTime.w - 0.05 * posw.x - 0.05 * posw.z + posw.y));

        gl_Position.x += wave * wind * 0.015 * smoothstep(0.7, 1.0, v_texcoord1.y);
    }
}