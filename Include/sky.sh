#if !defined(SKY_INCLUDED)
#define SKY_INCLUDED

#include "filter.sh"
#include "noise.sh"

CONST(float rayleighScatteringIntensity = 4.0;)
CONST(float mieScatteringIntensity = 0.1;)
CONST(vec3 rayleighCoeffColor = vec3(0.3, 0.5, 1.0);)
CONST(vec3 mieCoeffColor = vec3(1.0, 0.6, 0.0);)

CONST(float duskDayTransition = 0.4;)
CONST(float nightDayTransition = 0.08;)
CONST(float minSkyBrightness = 0.015;)

CONST(float overExposure = 3.0);
CONST(float underExposure = 3.0);

CONST(float cloudHeight = 128.0;)
CONST(int cloudOctavesHigh = 6;)
CONST(int cloudShadeOctavesHigh = 4;)
CONST(int cloudRaymarchingStepsHigh = 1;) // Only one step to prevent lags
CONST(int cloudOctavesLow = 4;)
CONST(int cloudShadeOctavesLow = 2;)
CONST(int cloudRaymarchingStepsLow = 1;)

// Compute rayleigh and mie phases.
// See: https://ebruneton.github.io/precomputed_atmospheric_scattering/atmosphere/functions.glsl.html#single_scattering_computation	
float computeRayleighPhase(vec3 pos, vec3 sunPos) {
    float m = dot(pos, sunPos);
    float m2 = m * m;

    return 3.0 / (16.0 * PI) * (1.0 + m2);
}
float computeMiePhase(vec3 pos, vec3 sunPos) {
    // Mie scattering direction.
    const float g = 0.758;

    float m = dot(pos, sunPos);
    float m2 = m * m;
    float g2 = g * g;

    return 3.0 / (8.0 * PI) * ((1.0 - g2) * (m2 + 1.0)) / pow(1.0 + g2 - 2.0 * m * g, 1.5) * (2.0 + g2);
}

// Generate stars from hash
float starMap(vec3 pos, float time) {
	const float resolution = 256.0;

	return smoothstep(0.999, 1.0, hash13(floor((pos + time * 0.001) * resolution)));
}

float diffuseSphere(vec3 spherePos, vec3 lightPos, const float radius) {
    float sq = pow2(radius) - pow2(spherePos.x) - pow2(spherePos.y) - pow2(spherePos.z);

    if (sq < 0.0) {
        return 0.0;
    } else {
        float z = sqrt(sq);
        vec3 normal = normalize(vec3(spherePos.yx, z));
		
        return max(0.0, dot(normal, lightPos));
    }
}

// Calculate simple skies!
vec4 calculateSky(vec3 pos, vec3 vPos, vec3 cPos, float depth, vec3 sunPos, vec3 moonPos, float dayTime, float rainLevel, float time, bool cloudOnly, bool lowDetail) {
    vec4 clouds = vec4_splat(0.0);
    float cloudShadeFactor = 0.0;

    float cloudDist = cloudHeight - cPos.y;
    float cloudFog = clamp(length(pos.xz / (pos.y * float(12))), 0.0, 1.0);

    int cloudOctaves = lowDetail ? cloudOctavesLow : cloudOctavesHigh;
    int cloudShadeOctaves = lowDetail ? cloudShadeOctavesLow : cloudShadeOctavesHigh;
    int cloudRaymarchingSteps = lowDetail ? cloudRaymarchingStepsLow : cloudRaymarchingStepsHigh;

    // Check to not render false clouds.
    if (cloudFog < 1.0 && cloudDist < 0.0 && pos.y < 0.0 || cloudDist > 0.0 && pos.y > 0.0) {
        vec3 cloudPos = vec3_splat(cloudDist);
        cloudPos.xz *= pos.xz / pos.y;

        float cloudLength = length(cloudPos);
        cloudLength -= 0.01; // Bias to prevent z-fighting.

        cloudPos.xz += cPos.xz;
        cloudPos.z += time * 0.002;

        // Check if terrain is hiding clouds.
        if (depth == 1.0 || length(vPos.xyz) > cloudLength) {
            clouds.a = fBM(cloudOctaves, mix(0.48, 0.0, rainLevel), 0.56, cloudPos.xz * 0.015);
            if (clouds.a > 0.0 && !lowDetail) {
                vec3 rayPos = vec3_splat(cloudDist);
                rayPos.xz *= pos.xz / pos.y;
                float cloudLengthRay = length(cloudPos);
                cloudLengthRay -= 0.01; // Bias to prevent z-fighting.

                rayPos.xz += cPos.xz;
                rayPos.z += time * 0.002;

                for (int j = 0; j < cloudRaymarchingSteps; j++) {
                    rayPos += sunPos * 7.0;
                    cloudShadeFactor += fBM(cloudShadeOctaves, mix(0.43, 0.0, rainLevel), 0.6, rayPos.xz * 0.015);
                }
            }
            clouds.a = mix(clouds.a, 0.0, cloudFog);
        }
    }

    vec4 aurora = vec4(0.0, 0.6, 0.4, 0.0);
    aurora.rgb = mix(aurora.rgb, vec3(0.2, 0.6, 0.7), pos.y);
    aurora.a = fBM(1, 0.2, 0.5, pos.xz * 2.0 - time * 0.005);

    vec3 sky = vec3_splat(0.0);

    float sunIntensity = dayTime;
    float moonIntensity = 1.0 - dayTime;

    float zenithFactor = pow2(pow3(clamp(1.0 - pos.y, 0.0, 1.0)));

    float sun = smoothstep(0.04, 0.035, distance(pos, sunPos));
    sun *= smoothstep(0.5, 0.0, distance(pos, sunPos));
    float moon = diffuseSphere(cross(pos, moonPos), vec3(sin(0.8), 0.0, -cos(0.8)), 0.05);
    moon *= smoothstep(0.5, 0.0, distance(pos, moonPos));
    float stars = starMap(pos, time * 0.01);

    // Compute rayleigh/mie phases.
    float rayleighPhase = computeRayleighPhase(pos, sunPos);
    float miePhase = computeMiePhase(pos, sunPos);
    
    // Calculate base color.
    vec3 voidColor = mieCoeffColor;
    voidColor = mix(voidColor, vec3_splat(grayScaleCIE(voidColor)), smoothstep(0.0, duskDayTransition, sunIntensity));
    voidColor = mix(vec3_splat(minSkyBrightness), voidColor, smoothstep(0.0, nightDayTransition, sunIntensity));
    voidColor *= mix(minSkyBrightness, 1.0, smoothstep(0.0, nightDayTransition, sunIntensity));
    vec3 skyColor = rayleighCoeffColor;
    skyColor = mix(mieCoeffColor, rayleighCoeffColor, smoothstep(0.0, duskDayTransition, sunIntensity));
    skyColor *= mix(minSkyBrightness, 1.0, smoothstep(0.0, duskDayTransition, sunIntensity));
    sky = mix(skyColor, voidColor, zenithFactor);

    // Apply scattering.
    float rayleighScatteringFactor = mix(minSkyBrightness, smoothstep(0.0, nightDayTransition, sunIntensity), rayleighPhase);
    float mieScatteringFactor = mix(0.0, smoothstep(0.0, nightDayTransition, sunIntensity), miePhase);

    vec3 totalRayleigh = rayleighCoeffColor * rayleighScatteringFactor * rayleighScatteringIntensity;
    vec3 totalMie = mieCoeffColor * mieScatteringFactor * mieScatteringIntensity;
    vec3 totalSun = mieCoeffColor * sun * mieScatteringIntensity * 16.0;
    vec3 totalMoon = rayleighCoeffColor * moon * rayleighScatteringIntensity * 2.0;
    vec3 totalAurora = aurora.rgb * aurora.a * mix(0.2, 0.0, smoothstep(0.0, nightDayTransition, sunIntensity));

    sky += totalRayleigh;
    sky += totalMie;

    if (!cloudOnly) {
        sky += totalAurora;
        sky += stars * smoothstep(nightDayTransition, 0.0, sunIntensity);
    }
    
    if (!cloudOnly && !lowDetail) {
        sky += totalSun;
        sky += totalMoon;
    }

    vec3 cloudColor = mix(vec3_splat(grayScaleCIE(totalRayleigh)), mieCoeffColor, smoothstep(0.0, nightDayTransition, sunIntensity));
    vec3 cloudShadeColor = mix(cloudColor, totalRayleigh, 0.3) * 0.4;
    
    vec3 cloudLight = mix(cloudColor, cloudShadeColor, cloudShadeFactor);
    cloudLight += totalMie * mix(0.0, 8.0, clamp((1.0 - cloudShadeFactor), 0.0, 1.0));
    
    sky += cloudLight * clouds.a;

    hdrExposure3(sky, overExposure, underExposure);
    lottes3(sky);

    return vec4(sky, cloudOnly ? clouds.a : 1.0);
}

vec3 calculateFog(vec3 pos, vec3 sunPos, vec3 moonPos, float dayTime, float rainLevel) {
    vec3 sky = vec3_splat(0.0);

    float sunIntensity = dayTime;
    float zenithFactor = pow3(clamp(1.0 - pos.y, 0.0, 1.0));

    // Compute rayleigh/mie phases.
    float rayleighPhase = computeRayleighPhase(pos, sunPos);
    float miePhase = computeMiePhase(pos, sunPos);

    // Calculate base color.
    vec3 voidColor = mieCoeffColor;
    voidColor = mix(voidColor, vec3_splat(grayScaleCIE(voidColor)), smoothstep(0.0, duskDayTransition, sunIntensity));
    voidColor = mix(vec3_splat(minSkyBrightness), voidColor, smoothstep(0.0, nightDayTransition, sunIntensity));
    voidColor *= mix(minSkyBrightness, 1.0, smoothstep(0.0, nightDayTransition, sunIntensity));
    vec3 skyColor = rayleighCoeffColor;
    skyColor = mix(mieCoeffColor, rayleighCoeffColor, smoothstep(0.0, duskDayTransition, sunIntensity));
    skyColor *= mix(minSkyBrightness, 1.0, smoothstep(0.0, duskDayTransition, sunIntensity));
    sky = mix(skyColor, voidColor, zenithFactor);

    // Apply scattering.
    float rayleighScatteringFactor = mix(minSkyBrightness, smoothstep(0.0, nightDayTransition, sunIntensity), rayleighPhase);
    float mieScatteringFactor = mix(0.0, smoothstep(0.0, nightDayTransition, sunIntensity), miePhase);

    vec3 totalRayleigh = rayleighCoeffColor * rayleighScatteringFactor * rayleighScatteringIntensity;
    vec3 totalMie = mieCoeffColor * mieScatteringFactor * mieScatteringIntensity;

    totalRayleigh = mix(totalRayleigh, vec3_splat(grayScaleCIE(totalRayleigh)), rainLevel);

    sky += totalRayleigh;
    sky += totalMie;

    hdrExposure3(sky, overExposure, underExposure);
    lottes3(sky);

    linearToSrgbJodie3(sky);

    return sky;
}

vec3 calculateSkyLightColor(vec3 pos, vec3 sunPos, vec3 moonPos, float dayTime, float rainLevel) {
    vec3 sky = vec3_splat(0.0);

    float sunIntensity = dayTime;

    // Compute rayleigh phase.
    float rayleighPhase = computeRayleighPhase(pos, sunPos);

    vec3 skyColor = rayleighCoeffColor;
    skyColor = mix(mieCoeffColor, rayleighCoeffColor, smoothstep(0.0, duskDayTransition, sunIntensity));
    skyColor *= mix(minSkyBrightness, 1.0, smoothstep(0.0, duskDayTransition, sunIntensity));
    sky = skyColor;

    // Apply scattering.
    float rayleighScatteringFactor = mix(minSkyBrightness, smoothstep(0.0, nightDayTransition, sunIntensity), rayleighPhase);
    vec3 totalRayleigh = rayleighCoeffColor * rayleighScatteringFactor * rayleighScatteringIntensity;

    totalRayleigh = mix(totalRayleigh, vec3_splat(grayScaleCIE(totalRayleigh)), rainLevel);

    sky += totalRayleigh;

    hdrExposure3(sky, overExposure, underExposure);
    lottes3(sky);

    linearToSrgbJodie3(sky);

    return sky;
}

#endif /* !defined(SKY_INCLUDED) */