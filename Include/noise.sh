#if !defined(NOISE_INCLUDED)
#define NOISE_INCLUDED

/* Hash from "Hahs without Sine"
 * Author: David Hoskins
 * https://www.shadertoy.com/view/4djSRW
*/
float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}
float hash12(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);

    return fract((p3.x + p3.y) * p3.z);
}
float hash13(vec3 p3) {
	p3  = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);

    return fract((p3.x + p3.y) * p3.z);
}
vec2 hash22(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

/* Tileable Gradient Noise by rge15.
 * https://www.shadertoy.com/view/7lSfzD
*/

float gradientNoise(vec2 p, vec2 freq) {
    vec2 imin = floor(p);
    vec2 imax = ceil(p);
    vec2 f = fract(p);
    
    vec2 func = f * f * (3.0 - 2.0 * f);

    /*
    imin = modulo(imin, freq);
    imax = modulo(imax, freq);
    */

    vec2 a = hash22(imin);
    vec2 b = hash22(vec2(imax.x, imin.y));
    vec2 c = hash22(vec2(imin.x, imax.y));
    vec2 d = hash22(imax);

    float gA = dot(a, f - vec2(0.0, 0.0));
    float gB = dot(b, f - vec2(1.0, 0.0));
    float gC = dot(c, f - vec2(0.0, 1.0));
    float gD = dot(d, f - vec2(1.0, 1.0));

    return gA + (gB - gA) * func.x + (gC - gA) * func.y + (gA - gB - gC + gD) * func.x * func.y;
}

float fBM(const int octaves, const float lowerBound, const float upperBound, vec2 st) {
    const float shift = 100.0;

    // Initial values
    float value = 0.0;
    float amplitude = 0.5;

    // Loop of octaves
    for (int i = 0; i < octaves; i++) {
        value += amplitude * (gradientNoise(st, vec2_splat(64.0)) * 0.5 + 0.5);

        if (value >= upperBound) {
            break;
        }
        else if (value + amplitude <= lowerBound) {
            break;
        }

        // Rotate to reduce axial bias
        st = mul(mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5)), st * 2.0 + shift);

        amplitude *= 0.5;
    }

    return smoothstep(lowerBound, upperBound, value);
}

#endif /* !defined(NOISE_INCLUDED) */