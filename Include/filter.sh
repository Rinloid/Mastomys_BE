#if !defined(FILTER_INCLUDED)
#define FILTER_INCLUDED

/* Based on Timothy Lottes’ tonemapper (2016).
 * See: https://www.gdcvault.com/play/1023512/Advanced-Graphics-Techniques-Tutorial-Day
*/
CONST(float a  = 1.2;)
CONST(float d  = 0.977;)
CONST(float w  = 128.0;)
CONST(float mI = 0.6;)
CONST(float mO = 0.267;)
void lottes(inout vec4 x) {
    float b = (-pow(mI, a) + pow(w, a) * mO)
            / ((pow(w, a * d) - pow(mI, a * d)) * mO);
    float c = (pow(w, a * d) * pow(mI, a) - pow(w, a) * pow(mI, a * d) * mO)
            / ((pow(w, a * d) - pow(mI, a * d)) * mO);

    x = clamp(pow(x, vec4_splat(a)) / (pow(x, vec4_splat(a * d)) * b + c), 0.0, 1.0);
}
void lottes3(inout vec3 x) {
    float b = (-pow(mI, a) + pow(w, a) * mO)
            / ((pow(w, a * d) - pow(mI, a * d)) * mO);
    float c = (pow(w, a * d) * pow(mI, a) - pow(w, a) * pow(mI, a * d) * mO)
            / ((pow(w, a * d) - pow(mI, a * d)) * mO);

    x = clamp(pow(x, vec3_splat(a)) / (pow(x, vec3_splat(a * d)) * b + c), 0.0, 1.0);
}

void hdrExposure(inout vec4 x, const float overExposure, const float underExposure) {
    vec4 overExposed = x / overExposure;
    vec4 normalExposed = x;
    vec4 underExposed = x * underExposure;

    x = mix(overExposed, underExposed, normalExposed);
}
void hdrExposure3(inout vec3 x, const float overExposure, const float underExposure) {
    vec3 overExposed = x / overExposure;
    vec3 normalExposed = x;
    vec3 underExposed = x * underExposure;

    x = mix(overExposed, underExposed, normalExposed);
}

// For sRGB
float grayScaleNTSC(vec3 x) {
	return dot(x, vec3(0.298912, 0.586611, 0.114478));
}

// For linear
float grayScaleCIE(vec3 x) {
	return dot(x, vec3(0.2126, 0.7152, 0.0722));
}

#endif /* !defined(FILTER_INCLUDED) */