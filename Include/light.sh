#if !defined(LIGHT_INCLUDED)
#define LIGHT_INCLUDED

// True fresnel calculation but it's slow!
vec3 getFresnel(vec3 V, vec3 N, const vec3 n1, const vec3 n2) {
    float cosThetaI = clamp(max(0.0, dot(V, N)), 0.0, 1.0);
    float sinThetaI = sqrt(max(0.0, 1.0 - cosThetaI * cosThetaI));
    
    vec3 sinThetaT = (n1 / n2) * sinThetaI;
    
    if (sinThetaT.r >= 1.0 || sinThetaT.g >= 1.0 || sinThetaT.b >= 1.0) {
        return vec3_splat(1.0); 
    }
    
    vec3 cosThetaT = sqrt(max(vec3_splat(0.0), 1.0 - sinThetaT * sinThetaT));
    
    vec3 r_s = (n1 * cosThetaI - n2 * cosThetaT) / (n1 * cosThetaI + n2 * cosThetaT);
    vec3 r_p = (n2 * cosThetaI - n1 * cosThetaT) / (n2 * cosThetaI + n1 * cosThetaT);
    
    return 0.5 * (r_s * r_s + r_p * r_p);
}

// A famous approximation by Schlick
vec3 getFresnelSchlick(vec3 V, vec3 N, const vec3 F0) {
    return F0 + (1.0 - F0) * pow5(clamp(1.0 - max(0.0, dot(V, N)), 0.0, 1.0));
}

// https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile
vec3 getEnvironmentBRDF(vec3 V, vec3 N, const float R, const vec3 F0) {
	vec4 r = R * vec4(-1.0, -0.0275, -0.572,  0.022) + vec4(1.0, 0.0425, 1.04, -0.04);
	vec2 AB = vec2(-1.04, 1.04) * min(r.x * r.x, exp2(-9.28 * max(0.0, dot(V, N)))) * r.x + r.y + r.zw;

	return F0 * AB.x + AB.y;
}

/* Calculate physical specular light factor.
 * See: https://learnopengl.com/PBR/Theory
*/
float getVisibleGGX(vec3 V, vec3 L, vec3 N, const float R) {
	float dotLN = max(0.0, dot(L, N));
	float dotVN = max(0.0, dot(V, N));

	float gv = dotLN * sqrt(dotVN * (dotVN - dotVN * R * R) + R * R);
	float gl = dotVN * sqrt(dotLN * (dotLN - dotLN * R * R) + R * R);
	
	return 0.5 / max(0.001, gv + gl);
}

float getDistributionGGX(vec3 V, vec3 L, vec3 N, const float R) {
	vec3 H = normalize(V + L);
	float dotHN = max(0.0, dot(H, N));
	float denominator = (dotHN * R * R - dotHN) * dotHN + 1.0;
	
	return (R * R) / (PI * denominator * denominator);
}

float getGeometrySchlickGGX(float N, const float R) {
    float k = ((R + 1.0) * (R + 1.0)) * 0.125;
	
    return N / (N * (1.0 - k) + k);
}
float getGeometrySmith(vec3 V, vec3 L, vec3 N, const float R) {
    float dotVN = max(dot(V, N), 0.0);
    float dotLN = max(dot(L, N), 0.0);

    return getGeometrySchlickGGX(dotVN, R) * getGeometrySchlickGGX(dotLN, R);
}
vec3 getPBRSpecular(vec3 V, vec3 L, vec3 N, const float R, const vec3 F0) {
	vec3 H = normalize(V + L);
	
	float dotVN = max(dot(V, N), 0.0);
    float dotLN = max(dot(L, N), 0.0);

	float GGX = getDistributionGGX(V, L, N, R) * getVisibleGGX(V, L, N, R);
	float G = getGeometrySmith(V, L, N, R);
	vec3 F = getFresnelSchlick(H, N, F0);

    vec3 specular = (GGX * G * F) / max(0.001, 4.0 * dotVN * dotLN);

	return specular * dotLN;
}

struct LightState {
    vec3 color;
    vec3 direction;
    float intensity;
    float diffusion;
    float shieldFactor;
};

void addDiffusedLight(LightState ls, inout vec3 diffusedLight, vec3 normal, float roughness, bool metallic, float wetness) {
    float lightDiffusionFactor = max(0.0, dot(normal, ls.direction));
    lightDiffusionFactor = mix(lightDiffusionFactor, 1.0, ls.diffusion);

    diffusedLight += ls.color * ls.intensity * lightDiffusionFactor
                     * (1.0 - ls.shieldFactor) 
                     * float(!metallic)
                     * mix(0.0, 1.0, mix(1.0, roughness, wetness));
}

void addReflectedLight(LightState ls, inout vec4 reflectedLight, vec3 reflectedImg, vec3 normal, vec3 playerPos, const vec3 F0, const float roughness, const bool metallic, const float emission) {
    vec3 reflectedPos = reflect(normalize(playerPos), normal);
    vec3 viewDir = -normalize(playerPos);

    vec3 fresnel = getFresnelSchlick(viewDir, normal, F0);
    vec3 specular = getPBRSpecular(viewDir, ls.direction, normal, roughness, F0);

    reflectedLight.rgb += reflectedImg * (metallic ? getEnvironmentBRDF(viewDir, normal, roughness, fresnel) : fresnel) * (1.0 - roughness);
    reflectedLight.rgb += ls.color * ls.intensity * (fresnel * F0 * ls.diffusion + specular * (1.0 - ls.diffusion)) * (1.0 - ls.shieldFactor);

    float alphaCoeff = grayScaleCIE(reflectedLight.rgb);
    reflectedLight.a += alphaCoeff;
}

void applyLight(inout vec4 totalColor, vec3 diffusedLight, vec4 reflectedLight, const vec3 F0) {
    totalColor.rgb *= diffusedLight;

    totalColor.rgb *= 1.0 - F0;
    totalColor += reflectedLight;
}

#endif /* !defined(LIGHT_INCLUDED) */