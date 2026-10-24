#if !defined(WATER_INCLUDED)
#define WATER_INCLUDED

#include "noise.sh"

float waterWave(vec3 pos, float time) {
    vec2 freq = vec2_splat(MC_CHUNK_SCALE);

    float wave = 0.0;

    #if !defined(LOW_QUALITY)
        wave += (gradientNoise(pos.xz * vec2(1.0, 0.8) + vec2(time * 1.2, time * 1.3), freq) + 1.0) * 0.5;
        wave += (gradientNoise(pos.xz * vec2(0.9, 0.7) + vec2(16.0 - time * 1.6, 12.0 - time * 1.4), freq) + 1.0) * 0.5;
    #endif

    return wave * 0.5;
}

vec3 getWaterNormal(vec3 pos, float time, const float scale) {
    float resolution = 0.5;

    float height = waterWave(pos, time);
    vec2 delta = vec2_splat(height);

    delta.x -= waterWave(pos + vec3(resolution, 0.0, 0.0), time);
    delta.y -= waterWave(pos + vec3(0.0, resolution, 0.0), time);

	return normalize(vec3(delta * scale / resolution, 1.0));
}

/*
 * Generate ripples based on Ripple Splatter by AntoninHS.
 * See: https://www.shadertoy.com/view/fdfSzs
*/
vec2 scale(vec2 pos,vec2 pivotPoint, const float scale, const float minScale, const float maxScale) {
    vec2 p = pos - pivotPoint;
    p *= 1.0 / (max(mix(minScale, maxScale, scale), 0.01));
    p += pivotPoint;

    return p;
}
vec3 offset(vec2 pos, vec2 intPos, vec2 offset, float time){
    vec2 p = intPos + offset;
    float rand13 = hash12(p + vec2(25.0, 48.0));
    vec2 timeOffsetRand = vec2(hash11(floor(rand13 + time)), hash11(floor(rand13 + time))) + p;
    float rand11 = hash12(timeOffsetRand);
    float rand12 = hash12(timeOffsetRand + vec2(17.0, 33.0));
    vec2 rand21 = vec2(rand11, rand12);
    
    vec2 newPos = pos - offset;
    newPos -= rand21;
    
    float newScale = cos(time + rand11 * PI * 2.0) * 0.5 + 0.5;
    newPos = scale(newPos, vec2(0.5, 0.5), 0.0, 1.0, newScale);
    
    vec3 randPos = vec3(newPos, rand13);

    return randPos;
}
float getRippleSplatter(vec3 randPos, float time){
    vec2 p = randPos.xy;
    p += 0.5;
    p += clamp(p, vec2_splat(-0.5), vec2_splat(0.5));

    float cone = 1.0 - length(p);
    
    float cycleTime = fract(randPos.z + time);
    float animatedCone = cone + cycleTime;
    float rippleArea = clamp(animatedCone, 0.0, 1.0) - clamp((animatedCone -0.5) * 1.5, 0.0, 1.0);
    float activateRipples = sin(cycleTime * PI);
    
    float result = animatedCone * 18.0;
    result = cos(result);
    result *= rippleArea * activateRipples;
    result = clamp(result, 0.0, 1.0);
    
    float randMask = floor(randPos.z + time) + randPos.z * 512.0;
    randMask = step(hash12(vec2_splat(randMask)), 1.0);

    result *= cone * randMask;
    result = clamp(result, 0.0, 1.0);
    
    return result;
}
float getRipples(vec2 fragPos, float time) {
    vec2 p = fragPos * 2.5;
    
    vec3 offset00 = offset(p - floor(p), floor(p), vec2(0.0, 0.0), time);
    vec3 offset01 = offset(p - floor(p), floor(p), vec2(0.0, 1.0), time);
    vec3 offset10 = offset(p - floor(p), floor(p), vec2(1.0, 0.0), time);
    vec3 offset11 = offset(p - floor(p), floor(p), vec2(1.0, 1.0), time);
    
    float ripple00 = getRippleSplatter(offset00, time);
    float ripple01 = getRippleSplatter(offset01, time);
    float ripple10 = getRippleSplatter(offset10, time);
    float ripple11 = getRippleSplatter(offset11, time);
    
    float ripples = max(max(ripple00, ripple01), max(ripple10, ripple11));

    return ripples;
}

float getRainRipples(vec3 normal, vec2 fragPos, float rainLevel, float lightmap, float time) {
    float ripples = 0.0;

    if (rainLevel > 0.0 && lightmap > 0.92) {
        ripples = getRipples(fragPos, time) * smoothstep(0.92, 0.9375, lightmap) * rainLevel * clamp(dot(normal, vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
    }

    return clamp(ripples, 0.0, 1.0);
}

vec3 getRainRipplesNormal(vec3 normal, vec2 fragPos, float rainLevel, float lightmap, float time, const float scale) {
	const float texStep = 0.02;
    
	float height = getRainRipples(normal, fragPos, rainLevel, lightmap, time);
	vec2  delta  = vec2(height, height);

    delta.x -= getRainRipples(normal, fragPos + vec2(texStep, 0.0), rainLevel, lightmap, time);
    delta.y -= getRainRipples(normal, fragPos + vec2(0.0, texStep), rainLevel, lightmap, time);
    
	return normalize(vec3(delta * scale / texStep, 1.0));
}



#endif /* !defined(WATER_INCLUDED) */