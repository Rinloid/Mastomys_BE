#if !defined(HACK_INCLUDED)
#define HACK_INCLUDED

vec4 getAolessColor(vec4 vertexColor) {
    vec4 aolessColor = vertexColor;

    float rgbMax = max(vertexColor.r, max(vertexColor.g, vertexColor.b));
    float rgbSum = vertexColor.r + vertexColor.g + vertexColor.b;
    float diff = abs(rgbSum - rgbMax * 3.0);

    bool isRedstoneWire = (vertexColor.b == 0.0);

    if (!isRedstoneWire) {
        if (diff > 0.05) {
            aolessColor.rgb = normalize(aolessColor.rgb);
        } else {
            aolessColor.rgb = vec3_splat(1.0);
        }
    }

    return aolessColor;
}

float extractAo(vec4 vertexColor) {
    float aoAmount = 0.0;

    #if !defined SEASONS__ON
        float rgbMax = max(vertexColor.r, max(vertexColor.g, vertexColor.b));
        float rgbMin = min(vertexColor.r, min(vertexColor.g, vertexColor.b));
        float rgbSum = vertexColor.r + vertexColor.g + vertexColor.b;
        float diff = abs(rgbSum - rgbMax * 3.0);

        bool isRedstoneWire = (vertexColor.b == 0.0);
        if (!isRedstoneWire) {
            if (diff > 0.05) {
                aoAmount = smoothstep(rgbMin, 1.0, 1.0 - rgbMax);
            } else {
                aoAmount = 1.0 - vertexColor.r;
            }
        }
    #endif

    return aoAmount;
}

/* By bWFuanVzYWth:
 * https://github.com/bWFuanVzYWth/OriginShader/blob/main/OriginShader/shaders/glsl/shaderfunction.lin
*/
float sunHeight(vec4 fogColor) {
    return clamp(((349.305545 * fogColor.g - 159.858192) * fogColor.g + 30.557216) * fogColor.g - 1.628452, -1.0, 1.0);
}

bool isUnderwater(vec4 fogColor, vec2 fogControl) {
    bool result = false;

    if (fogControl.x == 0.0 && fogColor.b > 0.0) { // In lava, fogColor.b becomes 0.0
        result = true;
    }

    return result;
}

bool isNehter(vec4 fogColor, vec2 fogControl) {
    bool result = false;

    /* #330808 */
    bool isNetherWastes = fogColor.g == fogColor.b && fogColor.r > fogColor.g;
    
    /* #1B4745 */
    bool isSoulsandValley = fogColor.g > fogColor.b && fogColor.g > fogColor.r;

    /* #330303 */
    bool isCrimsonForest = fogColor.g == fogColor.b && fogColor.r > fogColor.g;

    /* #1A051A */
    bool isWarpedForest = fogColor.r == fogColor.g && fogColor.r > fogColor.b;

    /* #685F70 */
    bool isBasaltDeltas = fogColor.b > fogColor.r && fogColor.b > fogColor.g;

    if (bool(step(0.1, fogControl.x / fogControl.y) - step(0.12, fogControl.x / fogControl.y)) && 
       (isNetherWastes || isSoulsandValley || isCrimsonForest || isWarpedForest || isBasaltDeltas)) {
        result = true;
    }

    return result;
}

bool isTheEnd(vec4 fogColor, vec2 fogControl) {
    bool result = false;

    /* #0B080C */
    if (fogColor.r > fogColor.g && fogColor.b > fogColor.g
        && all(greaterThan(fogColor.rgb, vec3(0.03, 0.02, 0.03)))
        && all(lessThan(fogColor.rgb,    vec3(0.05, 0.04, 0.05)))) {
        result = true;
    }

    return result;
}

float getRainLevel(vec4 fogColor, vec2 fogControl) {
    return clamp(smoothstep(0.5, 0.3, fogControl.x), 0.0, 1.0);
}

mat3 getTBNMatrix(vec3 normal) {
    vec3 upVector  = abs(normal.z) < 0.995 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 tangent   = normalize(cross(upVector, normal));
    vec3 bitangent = normalize(cross(normal, tangent));

    return mtxFromCols(tangent, bitangent, normal);
}

int getMaterialIndex(float alpha) {
    bool iron   = 0.99 <= alpha && alpha < 1.00;
    bool gold   = 0.98 <= alpha && alpha < 0.99;
    bool copper = 0.97 <= alpha && alpha < 0.98;
    bool other  = 0.96 <= alpha && alpha < 0.97;

    return iron ? 0 : gold ? 1 : copper ? 2 : other ? 3 : 4;
}

/* Detect foliage based on its biome colors and hardcoded height. 
 * https://github.com/McbeEringi/esbe-3g/blob/master/ESBE_3G/shaders/glsl/terrain.vsh
*/
bool isFoliage(vec4 color, vec3 pos) {
    vec3 fractPos = fract(pos.xyz);
    #if defined(ALPHA_TEST_PASS)
        return (color.g != color.b && color.r < color.g + color.b) || (fractPos.y == 0.9375 && (fractPos.z == 0.0 || fractPos.x == 0.0));
    #else
        return false;
    #endif
}

#endif /* !defined(HACK_INCLUDED) */