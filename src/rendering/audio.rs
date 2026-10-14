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
    preferences: Res<crate::app::Preferences>,
    audio: Audio_Players,
) {
    let Audio_Players { players, mut sinks } = audio;
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
                        volume: layer.volume(&preferences),
                        ..PlaybackSettings::LOOP
                    },
                    layer,
                ));
            }
            *current = path.into();
        }
    }
    for (layer, mut sink) in &mut sinks {
        sink.set_volume(layer.volume(&preferences));
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
            Update,
            (play_music, play_impacts).in_set(crate::app::Game_Systems::Presentation),
        );
    }
}

#[derive(bevy::ecs::system::SystemParam)]
struct Audio_Players<'w, 's> {
    players: Query<'w, 's, (Entity, &'static Audio_Layer)>,
    sinks: Query<'w, 's, (&'static Audio_Layer, &'static mut AudioSink)>,
}
fn play_impacts(
    mut commands: Commands,
    game: Res<Game_State>,
    server: Res<AssetServer>,
    preferences: Res<crate::app::Preferences>,
    mut last: Local<Option<(u64, u32)>>,
) {
    let frame = (game.generation, game.elapsed.to_bits());
    if *last == Some(frame) {
        return;
    }
    *last = Some(frame);
    for _ in &game.effects {
        commands.spawn((
            AudioPlayer::new(server.load("audio/fx/impact/hit-short-04.wav")),
            PlaybackSettings {
                mode: bevy::audio::PlaybackMode::Despawn,
                volume: bevy::audio::Volume::Linear(preferences.master * preferences.effects),
                ..default()
            },
        ));
    }
}
