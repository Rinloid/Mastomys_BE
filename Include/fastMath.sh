#if !defined(FAST_MATH_INCLUDED)
#define FAST_MATH_INCLUDED

#define pow2(x) (x * x)
#define pow3(x) (x * x * x)
#define pow4(x) (x * x * x * x)
#define pow5(x) (x * x * x * x * x)

/* Fast approximation of gamma correction by Jodie:
 * https://www.shadertoy.com/user/Jodie
*/
void srgbToLinearJodie(inout vec4 c) {
    c = c * (0.047281196 + c * (0.54866482 + c * 0.40405399));
}
void linearToSrgbJodie(inout vec4 c) {
    vec4 u = sqrt(c + 0.00051523639);
    c = -0.028046833 + u * (1.2404333 + u * -0.21259643);
}
void srgbToLinearJodie3(inout vec3 c) {
    c = c * (0.047281196 + c * (0.54866482 + c * 0.40405399));
}
void linearToSrgbJodie3(inout vec3 c) {
    vec3 u = sqrt(c + 0.00051523639);
    c = -0.028046833 + u * (1.2404333 + u * -0.21259643);
}

#endif /* !defined(FAST_MATH_INCLUDED) */