use super::*;

#[derive(Component, Clone, Copy, PartialEq, Eq, Debug)]
pub(crate) enum Audio_Layer {
    Music,
    Ambience,
}
impl Audio_Layer {
    fn volume(self, preferences: &crate::app::Preferences) -> bevy::audio::Volume {
        bevy::audio::Volume::Linear(
            preferences.master
                * match self {
                    Self::Music => preferences.music,
                    Self::Ambience => preferences.effects,
                },
        )
    }
}
pub(super) const TITLE_MUSIC: &str = "audio/A-Feather-Falls-Ian-Aisling-stream-preview.mp3";
pub(super) const TITLE_AMBIENCE: &str =
    "audio/Birdsong-River-Flow-Early-Morning-Woodland-stream-preview.mp3";
fn play_music(
    mut commands: Commands,
    game: Res<Game_State>,
    mode: Res<State<Mode>>,
    mut state: Local<Audio_State>,
    server: Res<AssetServer>,
    players: Query<(Entity, &Audio_Layer)>,
) {
    let (music, ambience) = if *mode.get() == Mode::Title {
        (TITLE_MUSIC, TITLE_AMBIENCE)
    } else {
        (
            if game.room.music_path.is_empty() {
                "audio/music/ambient.ogg"
            } else {
                &game.room.music_path
            },
            game.room.ambience_path.as_str(),
        )
    };
    for (layer, path) in [
        (Audio_Layer::Music, music),
        (Audio_Layer::Ambience, ambience),
    ] {
        let current = match layer {
            Audio_Layer::Music => &mut state.music,
            Audio_Layer::Ambience => &mut state.ambience,
        };
        if current.as_str() != path {
            for (entity, existing) in &players {
                if *existing == layer {
                    commands.entity(entity).despawn();
                }
            }
            if !path.is_empty() {
                commands.spawn((
                    AudioPlayer::new(server.load(path.to_string())),
                    PlaybackSettings {
                        volume: bevy::audio::Volume::Linear(0.),
                        ..PlaybackSettings::LOOP
                    },
                    layer,
                ));
            }
            *current = path.into();
        }
    }
}

#[derive(Default)]
struct Audio_State {
    music: String,
    ambience: String,
}
pub(super) struct Audio_Plugin;
impl Plugin for Audio_Plugin {
    fn build(&self, app: &mut App) {
        app.add_systems(
            PostUpdate,
            (play_music, play_impacts, update_volume)
                .chain()
                .after(crate::transition::Transition_Systems)
                // Bevy starts queued audio after transform propagation; set
                // its initial gain first so a new track cannot start at full volume.
                .before(bevy::transform::TransformSystems::Propagate),
        );
    }
}

#[derive(Component)]
struct Sound_Effect;
fn update_volume(
    preferences: Res<crate::app::Preferences>,
    transition: Res<crate::transition::Scene_Transition>,
    game: Res<Game_State>,
    mut players: Query<
        (
            &mut PlaybackSettings,
            Option<&Audio_Layer>,
            Option<&mut AudioSink>,
        ),
        Or<(With<Audio_Layer>, With<Sound_Effect>)>,
    >,
) {
    let gain = 1. - transition.opacity(&game);
    for (mut settings, layer, sink) in &mut players {
        let base = layer.map_or(preferences.master * preferences.effects, |layer| {
            layer.volume(&preferences).to_linear()
        });
        let volume = bevy::audio::Volume::Linear(base * gain);
        settings.volume = volume;
        if let Some(mut sink) = sink {
            sink.set_volume(volume);
        }
    }
}
fn play_impacts(
    mut commands: Commands,
    game: Res<Game_State>,
    server: Res<AssetServer>,
    mut impacts: MessageReader<crate::simulation::Impact>,
) {
    for _ in impacts
        .read()
        .filter(|impact| impact.generation == game.generation)
    {
        commands.spawn((
            AudioPlayer::new(server.load("audio/fx/impact/hit-short-04.wav")),
            PlaybackSettings {
                mode: bevy::audio::PlaybackMode::Despawn,
                volume: bevy::audio::Volume::Linear(0.),
                ..default()
            },
            Sound_Effect,
        ));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        app::Preferences,
        transition::{Phase, Scene_Transition},
    };
    use bevy::audio::Volume;

    #[test]
    fn queued_audio_follows_the_fade_and_preserves_each_bus_volume() {
        let game =
            Game_World::new(Room_Registry::load(std::path::Path::new("res")).unwrap()).unwrap();
        let mut app = App::new();
        app.add_plugins(MinimalPlugins)
            .insert_resource(*game.state)
            .insert_resource(Preferences {
                master: 0.6,
                music: 0.5,
                effects: 0.25,
                ..default()
            })
            .init_resource::<Scene_Transition>()
            .add_systems(Update, update_volume);
        let music = app
            .world_mut()
            .spawn((PlaybackSettings::LOOP, Audio_Layer::Music))
            .id();
        let ambience = app
            .world_mut()
            .spawn((PlaybackSettings::LOOP, Audio_Layer::Ambience))
            .id();
        let effect = app
            .world_mut()
            .spawn((PlaybackSettings::default(), Sound_Effect))
            .id();
        app.update();
        for entity in [music, ambience, effect] {
            assert_eq!(
                app.world().get::<PlaybackSettings>(entity).unwrap().volume,
                Volume::Linear(0.)
            );
        }
        for (alpha, gain) in [(0.5, 0.5), (0., 1.)] {
            {
                let mut transition = app.world_mut().resource_mut::<Scene_Transition>();
                transition.phase = Phase::Revealing;
                transition.alpha = alpha;
            }
            app.update();
            for (entity, level) in [(music, 0.3), (ambience, 0.15), (effect, 0.15)] {
                let volume = app
                    .world()
                    .get::<PlaybackSettings>(entity)
                    .unwrap()
                    .volume
                    .to_linear();
                assert!((volume - level * gain).abs() < 0.00001);
            }
        }
        app.world_mut().resource_mut::<Preferences>().master = 0.;
        app.update();
        for entity in [music, ambience, effect] {
            assert_eq!(
                app.world().get::<PlaybackSettings>(entity).unwrap().volume,
                Volume::Linear(0.)
            );
        }
    }
}
