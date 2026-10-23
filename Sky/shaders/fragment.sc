$input v_playerPos, v_viewPos, v_camDis

#include "bgfx_shader.sh"

#if BGFX_SHADER_LANGUAGE_GLSL
	precision highp float;
	precision highp int;
#endif

#include "magic.sh"
#include "fastMath.sh"
#include "hack.sh"
#include "filter.sh"
#include "sky.sh"

uniform vec4 ViewPositionAndTime;
uniform vec4 SkyColor;
uniform vec4 FogColor;
uniform vec4 FogAndDistanceControl;
uniform vec4 MinecraftCameraPosition;
uniform vec4 MinecraftTimeOfDay;

void main() {
    vec4 finalColor = vec4(0.0, 0.0, 0.0, 1.0);

    bool underwater = isUnderwater(FogColor, FogAndDistanceControl.xy);
    bool nether = isNehter(FogColor, FogAndDistanceControl.xy);
    bool theEnd = isTheEnd(FogColor, FogAndDistanceControl.xy);
    float rainLevel = (underwater || nether || theEnd) ? 0.0 : getRainLevel(FogColor, FogAndDistanceControl.xy);
    // float sunAngle = sunHeight(FogColor);
    float sunAngle = MinecraftTimeOfDay.x * 2.0 * PI;
    vec3 sunPosition = normalize(vec3(sin(sunAngle), cos(sunAngle), SUN_PATH_ROTATION));
    float dayTime = max(0.0, sunPosition.y);
    vec3 moonPosition = -sunPosition;
    float nightTime = max(0.0, moonPosition.y);
    vec3 skyPos = normalize(v_playerPos);

    vec3 sky = calculateSky(skyPos, v_viewPos, MinecraftCameraPosition.xyz, 1.0, sunPosition, moonPosition, dayTime, rainLevel, ViewPositionAndTime.w, false, false).rgb;
    linearToSrgbJodie3(sky);

    finalColor.rgb = mix(sky.rgb, FogColor.rgb, smoothstep(0.0, 1.0, v_camDis));

    gl_FragColor = finalColor;
}