#![allow(non_camel_case_types)]
pub mod app;
#[cfg(debug_assertions)]
pub mod automation;
pub mod content;
#[cfg(debug_assertions)]
mod debug;
pub mod editor;
pub mod input;
pub mod rendering;
pub mod simulation;
pub mod ui;
pub mod visuals;
