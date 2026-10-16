// Quantize the renderer's actual received light, including shadow maps and
// local lights. Whole exposure stops keep bands flat while intensity and
// coloured world lighting remain meaningful; zero light remains black.
fn banded_light(received: vec3<f32>) -> vec3<f32> {
    let light = max(received, vec3<f32>(0.0));
    let luminance = dot(light, vec3<f32>(0.2126, 0.7152, 0.0722));
    if luminance < 0.000001 { return vec3<f32>(0.0); }
    let energy = exp2(floor(log2(luminance) + 0.5));
    let colour = floor(light / luminance * 4.0 + 0.5) / 4.0;
    return colour * energy;
}
