use bevy::{prelude::*, render::render_resource::AsBindGroup, shader::ShaderRef};

#[derive(AsBindGroup, Asset, TypePath, Clone, Debug)]
pub(crate) struct Logo_Material {
    #[uniform(0)]
    ink: Vec4,
    #[texture(1)]
    #[sampler(2)]
    #[dependency]
    mask: Handle<Image>,
}
impl UiMaterial for Logo_Material {
    fn fragment_shader() -> ShaderRef {
        "shaders/title_logo.wesl".into()
    }
}

#[derive(Resource)]
pub(super) struct Title_Logo(pub Handle<Logo_Material>);
impl FromWorld for Title_Logo {
    fn from_world(world: &mut World) -> Self {
        let mask = world
            .resource::<AssetServer>()
            .load("ui/title/hollie-mask.png");
        Self(
            world
                .resource_mut::<Assets<Logo_Material>>()
                .add(Logo_Material {
                    ink: Color::srgb(1., 0.961, 0.835).to_linear().to_vec4(),
                    mask,
                }),
        )
    }
}
