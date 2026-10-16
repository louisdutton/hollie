use super::*;
use bevy::ecs::query::QueryData;
use std::borrow::Cow;

#[derive(Component, Clone, Debug)]
#[component(immutable)]
#[require(
    Locomotion,
    Wander,
    Vitality,
    Puzzle,
    Ram,
    Attachment_Pose,
    crate::visuals::Motion_Pose
)]
pub struct Actor_Identity {
    pub id: u64,
    pub source_id: String,
    pub properties: Entity_Properties,
}
#[derive(Component, Clone, Debug)]
pub struct Locomotion {
    pub facing: Vec2,
    pub coasting: bool,
    pub dismount_air_control: bool,
}
impl Default for Locomotion {
    fn default() -> Self {
        Self {
            facing: Vec2::X,
            coasting: false,
            dismount_air_control: false,
        }
    }
}
#[derive(Component, Clone, Debug, Default)]
pub struct Wander {
    pub direction: Vec2,
    pub move_timer: f32,
    pub wait_timer: f32,
}
#[derive(Component, Clone, Debug)]
pub struct Vitality {
    pub health: i32,
    pub death_timer: f32,
}
impl Default for Vitality {
    fn default() -> Self {
        Self {
            health: 100,
            death_timer: 0.,
        }
    }
}
#[derive(Component, Clone, Debug, Default)]
pub struct Puzzle {
    pub active: bool,
    pub open: bool,
}
#[derive(Component, Clone, Debug, Default)]
pub struct Ram {
    pub charge: f32,
    pub ready: bool,
}
#[derive(Component, Clone, Debug, Default)]
pub struct Attachment_Pose {
    pub held_anchor: Option<Vec3>,
    pub held_origin: Option<Vec3>,
    pub riding_anchor: Option<Vec3>,
    pub riding_origin: Option<Vec3>,
    pub mount_time: f32,
    pub mount_start: Vec3,
}

#[derive(Component, Clone, Copy, Debug, PartialEq, Eq)]
#[relationship(relationship_target = Riders)]
pub struct Mounted_On(pub Entity);
#[derive(Component, Debug)]
#[relationship_target(relationship = Mounted_On)]
pub struct Riders(Entity);
impl Riders {
    pub fn rider(&self) -> Entity {
        self.0
    }
}
#[derive(Component, Clone, Copy, Debug, PartialEq, Eq)]
#[relationship(relationship_target = Carried_Items)]
pub struct Carried_By(pub Entity);
#[derive(Component, Debug)]
#[relationship_target(relationship = Carried_By)]
pub struct Carried_Items(Entity);
impl Carried_Items {
    pub fn item(&self) -> Entity {
        self.0
    }
}
#[derive(Component, Clone, Copy, Debug, PartialEq, Eq)]
#[relationship(relationship_target = Released_Items)]
pub struct Released_By(pub Entity);
#[derive(Component, Debug, Default)]
#[relationship_target(relationship = Released_By)]
pub struct Released_Items(Vec<Entity>);

#[derive(QueryData)]
#[query_data(mutable)]
pub struct Actor_Query {
    pub entity: Entity,
    pub identity: &'static Actor_Identity,
    pub body: &'static mut Body,
    pub locomotion: &'static mut Locomotion,
    pub wander: &'static mut Wander,
    pub vitality: &'static mut Vitality,
    pub puzzle: &'static mut Puzzle,
    pub ram: &'static mut Ram,
    pub attachment: &'static mut Attachment_Pose,
    pub pose: &'static mut crate::visuals::Motion_Pose,
    riding: Option<&'static Mounted_On>,
    riders: Option<&'static Riders>,
    carrier: Option<&'static Carried_By>,
    items: Option<&'static Carried_Items>,
    released: Option<&'static Released_By>,
}
macro_rules! actor_access {
    ($item:ident) => {
        impl Deref for $item<'_, '_> {
            type Target = Actor_Identity;
            fn deref(&self) -> &Self::Target {
                self.identity
            }
        }
        impl $item<'_, '_> {
            pub fn mounted(&self) -> Option<Entity> {
                self.riding
                    .map(|r| r.0)
                    .or_else(|| self.riders.map(|r| r.0))
            }
            pub fn carrying(&self) -> Option<Entity> {
                self.items.map(|r| r.0)
            }
            pub fn held_by(&self) -> Option<Entity> {
                self.carrier.map(|r| r.0)
            }
            pub fn release_player(&self) -> Option<Entity> {
                self.released.map(|r| r.0)
            }
            pub fn solid(&self) -> bool {
                matches!(self.properties, Entity_Properties::Pressure_Plate(_))
                    || matches!(self.properties, Entity_Properties::Gate(_)) && !self.puzzle.open
                    || matches!(self.properties, Entity_Properties::Holdable(_))
                        && self.held_by().is_none()
            }
        }
    };
}
actor_access!(Actor_QueryItem);
actor_access!(Actor_QueryReadOnlyItem);

// The ordered contact solver borrows component storage directly. Owned data is
// used only while validating a room transaction and by display-free solver tests.
#[derive(Debug)]
pub enum Component_Data<'w, T> {
    Owned(T),
    Borrowed(Mut<'w, T>),
}
impl<T> Deref for Component_Data<'_, T> {
    type Target = T;
    fn deref(&self) -> &T {
        match self {
            Self::Owned(v) => v,
            Self::Borrowed(v) => v,
        }
    }
}
impl<T> DerefMut for Component_Data<'_, T> {
    fn deref_mut(&mut self) -> &mut T {
        match self {
            Self::Owned(v) => v,
            Self::Borrowed(v) => v,
        }
    }
}
impl<T: Clone> Clone for Component_Data<'_, T> {
    fn clone(&self) -> Self {
        Self::Owned((**self).clone())
    }
}
impl<T> From<T> for Component_Data<'_, T> {
    fn from(value: T) -> Self {
        Self::Owned(value)
    }
}
impl<T: Clone> Component_Data<'_, T> {
    fn into_owned(self) -> T {
        match self {
            Self::Owned(v) => v,
            Self::Borrowed(v) => (*v).clone(),
        }
    }
}
#[derive(Clone, Debug)]
pub struct Actor<'w> {
    pub entity: Entity,
    pub identity: Cow<'w, Actor_Identity>,
    pub body: Component_Data<'w, Body>,
    pub locomotion: Component_Data<'w, Locomotion>,
    pub wander: Component_Data<'w, Wander>,
    pub vitality: Component_Data<'w, Vitality>,
    pub puzzle: Component_Data<'w, Puzzle>,
    pub ram: Component_Data<'w, Ram>,
    pub attachment: Component_Data<'w, Attachment_Pose>,
    pub pose: Component_Data<'w, crate::visuals::Motion_Pose>,
    pub mounted: Option<Entity>,
    pub carrying: Option<Entity>,
    pub held_by: Option<Entity>,
    pub release_player: Option<Entity>,
}
impl Deref for Actor<'_> {
    type Target = Actor_Identity;
    fn deref(&self) -> &Self::Target {
        &self.identity
    }
}
impl<'w> Actor<'w> {
    pub fn new(identity: Actor_Identity, body: Body) -> Self {
        Self {
            entity: Entity::from_raw_u32(identity.id as u32).expect("room actor index"),
            identity: Cow::Owned(identity),
            body: body.into(),
            locomotion: Locomotion::default().into(),
            wander: Wander::default().into(),
            vitality: Vitality::default().into(),
            puzzle: Puzzle::default().into(),
            ram: Ram::default().into(),
            attachment: Attachment_Pose::default().into(),
            pose: crate::visuals::Motion_Pose::default().into(),
            mounted: None,
            carrying: None,
            held_by: None,
            release_player: None,
        }
    }
    pub fn solid(&self) -> bool {
        matches!(self.properties, Entity_Properties::Pressure_Plate(_))
            || matches!(self.properties, Entity_Properties::Gate(_)) && !self.puzzle.open
            || matches!(self.properties, Entity_Properties::Holdable(_)) && self.held_by.is_none()
    }
    pub(crate) fn borrowed(item: Actor_QueryItem<'w, '_>) -> Self {
        let mounted = item.mounted();
        let carrying = item.carrying();
        let held_by = item.held_by();
        let release_player = item.release_player();
        Self {
            entity: item.entity,
            identity: Cow::Borrowed(item.identity),
            body: Component_Data::Borrowed(item.body),
            locomotion: Component_Data::Borrowed(item.locomotion),
            wander: Component_Data::Borrowed(item.wander),
            vitality: Component_Data::Borrowed(item.vitality),
            puzzle: Component_Data::Borrowed(item.puzzle),
            ram: Component_Data::Borrowed(item.ram),
            attachment: Component_Data::Borrowed(item.attachment),
            pose: Component_Data::Borrowed(item.pose),
            mounted,
            carrying,
            held_by,
            release_player,
        }
    }
    pub(crate) fn snapshot(item: Actor_QueryReadOnlyItem<'w, '_>) -> Self {
        let mounted = item.mounted();
        let carrying = item.carrying();
        let held_by = item.held_by();
        let release_player = item.release_player();
        Self {
            entity: item.entity,
            identity: Cow::Borrowed(item.identity),
            body: item.body.clone().into(),
            locomotion: item.locomotion.clone().into(),
            wander: item.wander.clone().into(),
            vitality: item.vitality.clone().into(),
            puzzle: item.puzzle.clone().into(),
            ram: item.ram.clone().into(),
            attachment: item.attachment.clone().into(),
            pose: item.pose.clone().into(),
            mounted,
            carrying,
            held_by,
            release_player,
        }
    }
    pub(crate) fn into_bundle(self) -> impl Bundle {
        (
            self.identity.into_owned(),
            self.body.into_owned(),
            self.locomotion.into_owned(),
            self.wander.into_owned(),
            self.vitality.into_owned(),
            self.puzzle.into_owned(),
            self.ram.into_owned(),
            self.attachment.into_owned(),
            self.pose.into_owned(),
        )
    }
}
impl Actor_Identity {
    pub fn is_player(&self) -> bool {
        matches!(self.properties, Entity_Properties::Player(_))
    }
    pub fn kind(&self) -> Option<Character_Kind> {
        if let Entity_Properties::Enemy(p) = &self.properties {
            Some(p.kind)
        } else {
            None
        }
    }
    pub fn movable(&self) -> bool {
        matches!(
            self.properties,
            Entity_Properties::Player(_)
                | Entity_Properties::Enemy(_)
                | Entity_Properties::Npc(_)
                | Entity_Properties::Holdable(_)
        )
    }
}
