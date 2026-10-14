use anyhow::Result;
use hollie::content::Room_Registry;
fn main() -> Result<()> {
    let root = std::env::args().nth(1).unwrap_or_else(|| "res".into());
    let registry = Room_Registry::load(std::path::Path::new(&root))?;
    println!(
        "Validated {} rooms and their door links",
        registry.rooms.len()
    );
    Ok(())
}
