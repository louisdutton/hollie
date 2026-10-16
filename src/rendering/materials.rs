use super::*;

#[derive(Asset, AsBindGroup, Reflect, Debug, Clone)]
pub struct Painted_Surface {
    #[uniform(100)]
    pub parameters: Vec4,
    #[uniform(101)]
    pub water: Water_Uniform,
}
impl Default for Painted_Surface {
    fn default() -> Self {
        Self {
            parameters: Vec4::new(0., 0.04, 0.04, 0.),
            water: default(),
        }
    }
}
#[derive(ShaderType, Reflect, Debug, Clone)]
pub struct Water_Uniform {
    pub contacts: [Vec4; 16],
    pub headings: [Vec4; 16],
    pub starts: [Vec4; 64],
    pub ends: [Vec4; 64],
}
impl Default for Water_Uniform {
    fn default() -> Self {
        Self {
            contacts: [Vec4::ZERO; 16],
            headings: [Vec4::ZERO; 16],
            starts: [Vec4::ZERO; 64],
            ends: [Vec4::ZERO; 64],
        }
    }
}
#[derive(ShaderType, Reflect, Debug, Clone)]
pub struct Meadow_Uniform {
    pub time: Vec4,
    pub contacts: [Vec4; 32],
    pub motion: [Vec4; 32],
    pub trails: [Vec4; 64],
    pub trail_motion: [Vec4; 64],
}
impl Default for Meadow_Uniform {
    fn default() -> Self {
        Self {
            time: Vec4::ZERO,
            contacts: [Vec4::ZERO; 32],
            motion: [Vec4::ZERO; 32],
            trails: [Vec4::ZERO; 64],
            trail_motion: [Vec4::ZERO; 64],
        }
    }
}
#[derive(Asset, AsBindGroup, Reflect, Debug, Clone, Default)]
pub struct Meadow_Surface {
    #[uniform(100)]
    pub meadow: Meadow_Uniform,
}
impl MaterialExtension for Meadow_Surface {
    fn vertex_shader() -> ShaderRef {
        "shaders/grass_vertex.wesl".into()
    }
    fn prepass_vertex_shader() -> ShaderRef {
        "shaders/grass_vertex.wesl".into()
    }
    fn fragment_shader() -> ShaderRef {
        "shaders/grass_fragment.wesl".into()
    }
}
pub type Meadow_Material = ExtendedMaterial<StandardMaterial, Meadow_Surface>;
impl MaterialExtension for Painted_Surface {
    fn fragment_shader() -> ShaderRef {
        "shaders/painted.wesl".into()
    }
}
pub type Painted_Material = ExtendedMaterial<StandardMaterial, Painted_Surface>;

#[derive(Clone, Copy, PartialEq, Eq)]
pub(crate) enum Woodland_Kind {
    Bark,
    Stone,
    Foliage,
    Soil,
    Canopy,
}

#[derive(Asset, AsBindGroup, Reflect, Debug, Clone)]
pub(crate) struct Woodland_Surface {
    #[uniform(100)]
    pub parameters: Vec4,
}
impl MaterialExtension for Woodland_Surface {
    fn fragment_shader() -> ShaderRef {
        "shaders/woodland.wesl".into()
    }
}
pub(crate) type Woodland_Material = ExtendedMaterial<StandardMaterial, Woodland_Surface>;

pub(crate) fn woodland_material(kind: Woodland_Kind) -> Woodland_Material {
    let leaves = matches!(kind, Woodland_Kind::Foliage | Woodland_Kind::Canopy);
    Woodland_Material {
        base: StandardMaterial {
            cull_mode: if leaves {
                None
            } else {
                Some(bevy::render::render_resource::Face::Back)
            },
            double_sided: kind == Woodland_Kind::Foliage,
            diffuse_transmission: if leaves { 0.35 } else { 0. },
            perceptual_roughness: 1.,
            reflectance: 0.,
            ..default()
        },
        extension: Woodland_Surface {
            parameters: Vec4::new(kind as u32 as f32, 0., 0., 0.),
        },
    }
}
