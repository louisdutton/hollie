// Shared environment colours, authored in sRGB. Keep foliage shades derived
// from the meadow greens so changing the palette cannot split their hues.
const GRASS_LOW: vec3<f32> = vec3<f32>(0.44,0.65,0.38);
const GRASS_HIGH: vec3<f32> = vec3<f32>(0.56,0.79,0.38);
const LEAF_TIP: vec3<f32> = vec3<f32>(0.70,0.85,0.43);
const CANOPY_LIGHT: f32 = 1.35;
const WATER_DEEP: vec3<f32> = vec3<f32>(0.10,0.47,0.56);
const WATER_LIGHT: vec3<f32> = vec3<f32>(0.19,0.56,0.61);
const WATER_SHALLOW: vec3<f32> = vec3<f32>(0.37,0.71,0.66);
const FOAM: vec3<f32> = vec3<f32>(0.90,0.94,0.82);
const WOOD_LIGHT: vec3<f32> = vec3<f32>(0.40,0.33,0.24);

fn grass_colour(tone: f32) -> vec3<f32> {
    return mix(GRASS_LOW,GRASS_HIGH,tone);
}

fn moss_colour(tone: f32) -> vec3<f32> {
    return mix(GRASS_LOW*0.50,GRASS_HIGH*0.60,tone);
}

fn foliage_colour(brightness: f32, brush: f32) -> vec3<f32> {
    var colour=GRASS_LOW*vec3<f32>(0.32,0.40,0.30);
    if brightness>0.02 { colour=GRASS_LOW*0.66; }
    if brightness>0.38 { colour=GRASS_LOW; }
    if brightness>0.70 { colour=grass_colour(0.75); }
    if brightness>0.90 && brush>0.54 { colour=LEAF_TIP; }
    return colour;
}
