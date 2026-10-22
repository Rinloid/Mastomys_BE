$input a_color0, a_position
#ifdef INSTANCING__ON
    $input i_data0, i_data1, i_data2
#endif

$output v_color0

#include "bgfx_shader.sh"

void main() {
    #ifdef INSTANCING__ON
        mat4 model = mtxFromCols(i_data0, i_data1, i_data2, vec4(vec3_splat(0.0), 1.0));
    #else
        mat4 model = u_model[0];
    #endif

    vec3 worldPos = mul(model, vec4(a_position, 1.0)).xyz;

    gl_Position = vec4_splat(0.0); // mul(u_viewProj, vec4(worldPos, 1.0));

    v_color0 = a_color0;
}