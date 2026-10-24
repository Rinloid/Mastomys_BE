$input v_color0, v_fog, v_texcoord0, v_texcoord1, v_waterFlag, v_playerPos, v_worldPos, v_viewPos, v_screenPos

#include "bgfx_shader.sh"

#if BGFX_SHADER_LANGUAGE_GLSL
	precision highp float;
	precision highp int;
#endif

#include "magic.sh"
#include "fastMath.sh"
#include "hack.sh"
#include "filter.sh"
#include "light.sh"
#include "water.sh"
#include "sky.sh"

uniform vec4 FogColor;
uniform vec4 ViewPositionAndTime;
uniform vec4 FogAndDistanceControl;
uniform vec4 MinecraftCameraPosition;
uniform vec4 MinecraftTimeOfDay;

SAMPLER2D_AUTOREG(s_MatTexture);
SAMPLER2D_AUTOREG(s_LightMapTexture);
SAMPLER2D_AUTOREG(s_SeasonsTexture);

// Calculate normal from texture brightness
vec3 getTexNormal(vec2 texcoord, const float scale) {
    vec2 resolution = vec2(textureSize(s_MatTexture, 0));
    vec2 texStep = 1.0 / resolution;

    float height = grayScaleNTSC(texture2DLod(s_MatTexture, texcoord, 0.0).rgb);
    vec2 delta = vec2_splat(height);

    delta.x -= grayScaleNTSC(texture2DLod(s_MatTexture, texcoord + vec2(texStep.x, 0.0), 0.0).rgb);
    delta.y -= grayScaleNTSC(texture2DLod(s_MatTexture, texcoord + vec2(0.0, texStep.y), 0.0).rgb);

	return normalize(vec3(delta * scale / texStep, 1.0));
}

void main() {
    #if defined(DEPTH_ONLY_OPAQUE_PASS) || defined(DEPTH_ONLY_PASS)
        vec4 textureColor = vec4_splat(1.0);
        vec4 finalColor = vec4_splat(1.0);
    #else
        vec4 textureColor = texture2D(s_MatTexture, v_texcoord0);
        vec4 finalColor = textureColor;

        #if defined(ALPHA_TEST_PASS)
            if (finalColor.a < 0.5) {
                discard;
            }
        #endif

        #if defined(SEASONS__ON) && (defined(OPAQUE_PASS) || defined(ALPHA_TEST_PASS))
            finalColor.rgb *= mix(vec3_splat(1.0), texture2D(s_SeasonsTexture, v_color0.xy).rgb * 2.0, v_color0.b);
            finalColor.rgb *= v_color0.aaa;
        #else
            finalColor *= getAolessColor(v_color0);
        #endif
    #endif

    #ifndef TRANSPARENT_PASS
        finalColor.a = 1.0;
    #endif

    // sRGB -> Linear
    srgbToLinearJodie(finalColor);

    float depth = -v_viewPos.z;
    bool underwater = isUnderwater(FogColor, FogAndDistanceControl.xy);
    bool nether = isNehter(FogColor, FogAndDistanceControl.xy);
    bool theEnd = isTheEnd(FogColor, FogAndDistanceControl.xy);
    float rainLevel = (underwater || nether || theEnd) ? 0.0 : getRainLevel(FogColor, FogAndDistanceControl.xy);
    
    /* Prevents zero division and unstable normalization 
     * when the derivative value is extremely small.
    */
    vec3 normalRaw = cross(dFdx(v_worldPos), dFdy(v_worldPos));
    float normalLen = dot(normalRaw, normalRaw);
    vec3 fNormal = (normalLen > 1e-16) ? normalRaw * inversesqrt(normalLen) : vec3(0.0, 1.0, 0.0);
    vec3 normal = fNormal;
    
    bool isWater = (v_waterFlag > 0.5);
    float aoAmount = clamp(extractAo(v_color0) * AO_AMOUNT, 0.0, 1.0);
    
    // float sunAngle = sunHeight(FogColor);
    float sunAngle = MinecraftTimeOfDay.x * 2.0 * PI;
    vec3 sunPosition = normalize(vec3(sin(sunAngle), cos(sunAngle), SUN_PATH_ROTATION));
    float dayTime = max(0.0, sunPosition.y);
    vec3 moonPosition = -sunPosition;
    float nightTime = max(0.0, moonPosition.y);

    #if defined(NO_SHADOW)
        float shadowFactor = 1.0;
    #else
        float shadowFactor = smoothstep(0.92, 0.9375, v_texcoord1.y);
    #endif

    float causticFactor = 0.0;
    if (underwater) {
        causticFactor = waterWave(v_worldPos, ViewPositionAndTime.w);
    }

    // Define material info.
    int mID = 4;
    #if !defined(TRANSPARENT_PASS) && !defined(ALPHA_TEST_PASS) && !defined(SEASONS__ON)
        if ((0.9 < textureColor.a && textureColor.a < 1.0) && v_color0.r == v_color0.g && v_color0.g == v_color0.b) {
            mID = getMaterialIndex(textureColor.a);
        }
    #endif
    bool reflective = false;

    vec3 F0 = vec3_splat(DEFAULT_F0);
    float roughness = DEFAULT_ROUGHNESS;
    float wetness = 0.0;
    float emission = 0.0;
    bool  metallic = false;

    switch (mID) {
        case 0: // Iron
            F0 = finalColor.rgb;
            roughness = IRON_ROUGHNESS;
            metallic = true;
            break;
        case 1: // Gold
            F0 = finalColor.rgb;
            roughness = GOLD_ROUGHNESS;
            metallic = true;
            break;
        case 2: // Copper
            F0 = finalColor.rgb;
            roughness = COPPER_ROUGHNESS;
            metallic = true;
            break;
        case 3: // Other reflective blocks
            F0 = vec3_splat(OTHER_REFLECTIVE_F0);
            roughness = OTHER_REFLECTIVE_ROUGHNESS;
            reflective = true;
            metallic = false;
            break;
        default: break;
    }

    if (isWater) {
        F0 = vec3_splat(WATER_F0);
        roughness = WATER_ROUGHNESS;
        metallic = false;
        wetness = 1.0;
        finalColor = WATER_COLOR;
        if (!underwater) {
            normal = normalize(mul(getTBNMatrix(normal), getWaterNormal(v_worldPos, ViewPositionAndTime.w, WATER_WAVE_HEIGHT)));
        }
    }
    else if (metallic || reflective) {
        normal = normalize(mul(getTBNMatrix(normal), getTexNormal(v_texcoord0, REFLECTIVE_NORMAL_HEIGHT)));
    }

    // Translucent objects should be opaque in distance.
    #if defined(TRANSPARENT_PASS)
        if (textureColor.a > 0.05 && textureColor.a < 0.95) {
            vec3 fresnel = getFresnelSchlick(-normalize(v_playerPos), normal, F0);
            finalColor.a = mix(finalColor.a, 1.0, grayScaleNTSC(fresnel));
            if (!isWater) {
                roughness = TRANSLUCENT_ROUGHNESS;
                reflective = true;
            }
        }
    #endif

    // The default textures of metals are bright; reduce them.
    if (metallic) {
        F0 *= 0.5;
    }

    // Apply rainy effects
    if (rainLevel > 0.0) {
        float wet = 0.0;
        if (!isWater) {
            wet = mix(0.0, rainLevel * WET_GROUND_FACTOR, shadowFactor);
        }

        F0 = mix(F0, vec3_splat(WATER_F0), wet);
        roughness = mix(roughness, WATER_ROUGHNESS, wet);
        wetness = mix(wetness, 1.0, wet);
    }

    normal = normalize(mul(getTBNMatrix(normal), getRainRipplesNormal(fNormal, v_worldPos.xz, rainLevel, v_texcoord1.y, ViewPositionAndTime.w, RAIN_RIPPLES_HEIGHT)));

    vec3 skyPos = normalize(v_playerPos);
    vec3 skyReflPos = reflect(normalize(v_playerPos), normal);

    // Calculate light colors.
    vec3 skyLightColor = calculateSkyLightColor(skyPos, sunPosition, moonPosition, dayTime, rainLevel);
    vec3 sunLightColor = underwater ? SUN_LIGHT_COLOR_UNDERWATER : mix(SUN_LIGHT_COLOR_DUSKDAWN, SUN_LIGHT_COLOR, smoothstep(0.0, duskDayTransition, dayTime));
    vec3 moonLightColor = MOON_LIGHT_COLOR;
    vec3 torchLightColor = TORCH_LIGHT_COLOR;
    vec3 pointLightColor = POINT_LIGHT_COLOR;

    vec3 ambientOutsideColor = mix(skyLightColor.rgb, mix(moonLightColor, sunLightColor, dayTime), 0.9);
    vec3 ambientInsideColor = mix(vec3_splat(1.0), torchLightColor, pow3(v_texcoord1.x));
    vec3 ambientLightColor = mix(ambientInsideColor, ambientOutsideColor, v_texcoord1.y);

    vec3 diffusedLight = vec3_splat(0.0);
    vec4 reflectedLight = vec4_splat(0.0);
    vec4 reflectedImg = vec4(vec3_splat(0.0), 1.0);

    // Add whole lights.
    LightState terrainLight[TERRAIN_LIGHT_COUNT];

    /* Ambient Light */
    terrainLight[0].color = ambientLightColor;
    terrainLight[0].direction = DEFAULT_DIRECTION;
    terrainLight[0].intensity = AMBIENT_LIGHT_INTENSITY * (1.0 - aoAmount);
    terrainLight[0].diffusion = AMBIENT_LIGHT_DIFFUSION;
    terrainLight[0].shieldFactor = 0.0;

    /* Sky Light */
    terrainLight[1].color = skyLightColor.rgb;
    terrainLight[1].direction = sunPosition;
    terrainLight[1].intensity = SKY_LIGHT_INTENSITY * (1.0 - aoAmount);
    terrainLight[1].diffusion = SKY_LIGHT_DIFFUSION;
    terrainLight[1].shieldFactor = (1.0 - smoothstep(0.5, 1.0, v_texcoord1.y));

    /* Sun Light */
    terrainLight[2].color = sunLightColor;
    terrainLight[2].direction = sunPosition;
    terrainLight[2].intensity = SUN_LIGHT_INTENSITY * dayTime * (1.0 - aoAmount) * mix(1.0, RAIN_CUTTOFF, rainLevel);
    terrainLight[2].diffusion = underwater ? SUN_LIGHT_DIFFUSION_UNDERWATER : SUN_LIGHT_DIFFUSION;
    terrainLight[2].shieldFactor = (1.0 - (underwater ? mix(0.0, causticFactor, smoothstep(0.0, 1.0, v_texcoord1.y)) : shadowFactor));

    /* Moon Light */
    terrainLight[3].color = moonLightColor;
    terrainLight[3].direction = moonPosition;
    terrainLight[3].intensity = MOON_LIGHT_INTENSITY * smoothstep(0.0, nightDayTransition, nightTime) * (1.0 - aoAmount) * mix(1.0, RAIN_CUTTOFF, rainLevel);
    terrainLight[3].diffusion = MOON_LIGHT_DIFFUSION;
    terrainLight[3].shieldFactor = (1.0 - shadowFactor);

    /* Torch/Point Light */
    terrainLight[4].color = torchLightColor;
    terrainLight[4].direction = DEFAULT_DIRECTION;
    terrainLight[4].intensity = TORCH_LIGHT_INTENSITY * (1.0 - aoAmount);
    terrainLight[4].diffusion = TORCH_LIGHT_DIFFUSION;
    terrainLight[4].shieldFactor = (1.0 - pow3(clamp(v_texcoord1.x, 0.0, 1.0)));

    terrainLight[5].color = pointLightColor;
    terrainLight[5].direction = DEFAULT_DIRECTION;
    terrainLight[5].intensity = POINT_LIGHT_INTENSITY;
    terrainLight[5].diffusion = TORCH_LIGHT_DIFFUSION;
    terrainLight[5].shieldFactor = (1.0 - pow5(pow5(clamp(v_texcoord1.x, 0.0, 1.0))));

    // Add sky reflection.
    if (v_texcoord1.y > 0.7 && !underwater && (wetness > 0.0 || metallic || reflective)) {
        skyReflPos += bayerX64(v_screenPos.xy * 512.0) * ROUGHNESS_BLUR_STRENGTH * roughness;
        vec3 sky = calculateSky(skyReflPos, v_viewPos, MinecraftCameraPosition.xyz, 1.0, sunPosition, moonPosition, dayTime, rainLevel, ViewPositionAndTime.w, false, true).rgb;
        sky *= mix(0.0, 1.0, smoothstep(0.7, 1.0, v_texcoord1.y));
        reflectedImg.rgb += sky;
    }

    // Add lights and their reflections.
    for (int i = 0; i < TERRAIN_LIGHT_COUNT; i++) {
        addDiffusedLight(terrainLight[i], diffusedLight, normal, roughness, metallic, wetness);
        if (!underwater) {
            addReflectedLight(terrainLight[i], reflectedLight, reflectedImg.rgb, normal, v_playerPos, F0, roughness, metallic, emission);
        }
    }

    // Apply lights; LDR -> HDR.
    applyLight(finalColor, diffusedLight, reflectedLight, F0);

    // HDR -> LDR
    lottes(finalColor);

    // Linear -> sRGB
    linearToSrgbJodie(finalColor);

    // Apply fog.
    if (v_fog > 0.0) {
        vec3 fogColor = calculateFog(skyPos, sunPosition, moonPosition, dayTime, rainLevel);
        if (nether || theEnd) {
            fogColor = FogColor.rgb;
        }
        else if (underwater) {
            fogColor = skyLightColor;
        }

        finalColor.rgb = mix(finalColor.rgb, fogColor.rgb, v_fog).rgb;
    }

    // Apply cloud rendering on terrain.
    if (v_texcoord1.y > 0.5) {
        vec4 clouds = calculateSky(skyPos, v_viewPos, MinecraftCameraPosition.xyz, depth, sunPosition, moonPosition, dayTime, rainLevel, ViewPositionAndTime.w, true, false);
        linearToSrgbJodie3(clouds.rgb);
        finalColor.rgb = mix(finalColor.rgb, clouds.rgb, mix(0.0, clouds.a, v_texcoord1.y));
    }

    // Apply shadow disaturation.
    float lum = grayScaleNTSC(finalColor.rgb);
    finalColor.rgb = mix(vec3_splat(lum), finalColor.rgb, mix(0.5, 1.0, smoothstep(0.0, 0.5, lum)));

    gl_FragColor = finalColor;
}