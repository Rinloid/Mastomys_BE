$input a_color0, a_position
#ifdef INSTANCING__ON
    $input i_data0, i_data1, i_data2
#endif

$output v_playerPos, v_viewPos, v_camDis

#include "bgfx_shader.sh"

#if BGFX_SHADER_LANGUAGE_GLSL
	precision highp float;
	precision highp int;
#endif

void main() {
    #ifdef INSTANCING__ON
        mat4 model = mtxFromCols(i_data0, i_data1, i_data2, vec4(vec3_splat(0.0), 1.0));
    #else
        mat4 model = u_model[0];
    #endif

    vec3 worldPos = a_position;
    v_playerPos = mul(model, vec4(worldPos, 1.0)).xyz;
    v_playerPos.y -= length(v_playerPos.xz);
    v_viewPos = mul(u_view, vec4(v_playerPos, 1.0)).xyz;

    worldPos.y -= length(worldPos.xz);
    v_camDis = length(worldPos);

    gl_Position = mul(u_proj, vec4(v_viewPos, 1.0));

    /* Needed offset to match terrain */
    v_playerPos.y += 0.128;

}