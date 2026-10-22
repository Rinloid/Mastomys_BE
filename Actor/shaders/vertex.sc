$input a_position, a_color0, a_texcoord0, a_indices, a_normal
#ifdef INSTANCING__ON
    $input i_data0, i_data1, i_data2
#endif

$output v_color0, v_light, v_texcoord0, v_worldPos, v_clipPos

#include "bgfx_shader.sh"

#if BGFX_SHADER_LANGUAGE_GLSL
	precision highp float;
	precision highp int;
#endif

#include "DynamicUtil.dragonh"
#include "TAAUtil.dragonh"
#include "filter.sh"

uniform vec4 OverlayColor;
uniform vec4 TileLightColor;
uniform vec4 UVAnimation;
uniform mat4 Bones[8];

void main() {
    //StandardTemplate_InvokeVertexPreprocessFunction
    mat4 World = mul(u_model[0], Bones[int(a_indices)]);

    vec2 texcoord0 = applyUvAnimation(a_texcoord0, UVAnimation);

    float lightIntensity = calculateLightIntensity(World, vec4(a_normal.xyz, 0.0), TileLightColor);
    lightIntensity += OverlayColor.a * 0.35;
    v_light = vec4(vec3_splat(lightIntensity) * grayScaleCIE(TileLightColor.rgb), 1.0);
    
    //StandardTemplate_VertSharedTransform
    #ifdef INSTANCING__ON
        mat4 model;
        model[0] = vec4(i_data0.x, i_data1.x, i_data2.x, 0);
        model[1] = vec4(i_data0.y, i_data1.y, i_data2.y, 0);
        model[2] = vec4(i_data0.z, i_data1.z, i_data2.z, 0);
        model[3] = vec4(i_data0.w, i_data1.w, i_data2.w, 1);
        vec3 worldPosition = mul(vec4(a_position, 1.0), model).xyz;
    #else
        vec3 worldPosition = mul(World, vec4(a_position, 1.0)).xyz;
    #endif
    
    vec4 position;// = mul(u_viewProj, vec4(worldPosition, 1.0));

    //StandardTemplate_InvokeVertexOverrideFunction
    position = jitterVertexPosition(worldPosition);

    #if defined(DEPTH_ONLY_PASS)
        v_texcoord0 = vec2_splat(0.0);
        v_color0 = vec4_splat(0.0);
    #else
        v_texcoord0 = texcoord0;
        v_color0 = a_color0;
    #endif

    v_worldPos = worldPosition;
    v_clipPos = position;

    gl_Position = position;
}