# Mastomys Shaders BE

**Mastomys** is a shaderpack for Minecraft Bedrock Edition.

This is a complete rewrite and evolution of my previous shader project [Musk Rose](https://github.com/Rinloid/musk_rose_rd), containing all much of the knowledge I’ve acquired through 6 years of shader work.
[Screenshots](https://github.com/Rinloid/Mastomys_BE/blob/master/SCREENSHOT.md)

## Key Features
* Physically based rendering for diffused/specular lights and reflections, with all possible optimizations
* Material recognition through alpha channel of textures
* Non-infinity-distant cloud rendering (yes you can be above clouds!)
* Non-fogcolor-based detection of the sun position
* No seams of water waves at chunk borders
* HDR with Lottes tone-mapper, and gamma correction

## Supported platforms
* Windows (Direct3D Shader Model 5.0+)
* Android (OpenGL ES 3.1+)
* iOS (Untested & Unrecommended)

## Installations
Install these tools depending on your device:

* Windows: [BetterRenderDragon](https://github.com/QYCottage/BetterRenderDragon) or [Wyvern Loader](https://github.com/mcbegamerxx954/wyvern_releases)
* Android: [MB Loader](https://play.google.com/store/apps/details?id=io.github.bambosan.mbloader)

And now, your game is able to load shaders from resource packs.
See [releases](https://github.com/Rinloid/Mastomys_BE/releases) to download the .mcpack and apply it!

If your are on iOS, unfortunately you have to relpace the material.bin files inside your application file manually.

## Building
Install [Lazurite](https://github.com/veka0/lazurite) and follow its documentation to build.
You also need uniform overrides for the base vanilla materials which is also described on the documentation: add `BUILTIN_MinecraftCameraPosition` as `MinecraftCameraPosition` and `BUILTIN_MinecraftTimeOfDay` as `MinecraftTimeOfDay`.

## License
[The Unlicense](https://unlicense.org/)