use super::*;
use crate::rendering::tree_study::{Crown_Layout, Tree_Parameters};

#[derive(Default)]
struct Forest_Mesh {
    positions: Vec<[f32; 3]>,
    normals: Vec<[f32; 3]>,
    colors: Vec<[f32; 4]>,
    uv: Vec<[f32; 2]>,
    indices: Vec<u32>,
}
impl Forest_Mesh {
    fn vertex(&mut self, point: Vec3, normal: Vec3, color: Color, uv: Vec2) {
        self.positions.push(point.to_array());
        self.normals.push(normal.to_array());
        self.colors.push(color.to_linear().to_f32_array());
        self.uv.push(uv.to_array());
    }

    fn grid(
        &mut self,
        rows: u32,
        columns: u32,
        mut sample: impl FnMut(f32, f32) -> (Vec3, Vec3, Color, Vec2),
    ) {
        let base = self.positions.len() as u32;
        for row in 0..=rows {
            for column in 0..=columns {
                let (point, normal, color, uv) =
                    sample(row as f32 / rows as f32, column as f32 / columns as f32);
                self.vertex(point, normal, color, uv);
                if row < rows && column < columns {
                    let a = base + row * (columns + 1) + column;
                    self.indices.extend([
                        a,
                        a + 1,
                        a + columns + 2,
                        a,
                        a + columns + 2,
                        a + columns + 1,
                    ]);
                }
            }
        }
    }

    fn stem(
        &mut self,
        centerline: impl Fn(f32) -> Vec3,
        radius: f32,
        tip: f32,
        color: Color,
        rows: u32,
    ) {
        let point = |t: f32, angle: f32| {
            let center = centerline(t);
            let axis = (centerline(t + 0.001) - centerline(t - 0.001)).normalize();
            let u = axis.cross(Vec3::Z).normalize_or(Vec3::X);
            let v = axis.cross(u);
            let radial = u * angle.cos() + v * angle.sin();
            let flute =
                1. + (angle * 5. + t * 1.7).sin() * 0.045 + (angle * 9. - t * 2.).sin() * 0.018;
            center + radial * (radius + (tip - radius) * t) * flute
        };
        self.grid(rows, 32, |t, s| {
            let angle = s * std::f32::consts::TAU;
            let p = point(t, angle);
            let tangent = point(t + 0.001, angle) - point(t - 0.001, angle);
            let across = point(t, angle + 0.001) - point(t, angle - 0.001);
            let normal = across.cross(tangent).normalize_or(Vec3::Y);
            (
                p,
                normal,
                color,
                Vec2::new(
                    s * radius * std::f32::consts::TAU,
                    centerline(0.).distance(centerline(t)),
                ),
            )
        });
    }

    fn branch(&mut self, start: Vec3, end: Vec3, radius: f32, tip: f32, color: Color) {
        let bend = Vec3::Y * start.distance(end) * 0.09;
        self.stem(
            |t| start.lerp(end, t) + bend * (t * std::f32::consts::PI).sin(),
            radius,
            tip,
            color,
            8,
        );
    }

    fn rock(&mut self, center: Vec3, size: Vec3, color: Color, seed: u32) {
        let phase = random(seed) * std::f32::consts::TAU;
        let point = |t: f32, s: f32| {
            let latitude = t * std::f32::consts::PI;
            let longitude = s * std::f32::consts::TAU;
            let normal = Vec3::new(
                latitude.sin() * longitude.cos(),
                latitude.cos(),
                latitude.sin() * longitude.sin(),
            );
            let uneven = 1.
                + (normal.x * 2.7 + normal.y * 1.8 + phase).sin() * 0.10
                + (normal.z * 4.3 - normal.y * 2.1 + phase).sin() * 0.06;
            center + normal * size * uneven
        };
        self.grid(18, 32, |t, s| {
            let dt = point(t + 0.001, s) - point(t - 0.001, s);
            let ds = point(t, s + 0.001) - point(t, s - 0.001);
            let p = point(t, s);
            let normal = ds
                .cross(dt)
                .normalize_or((p - center).normalize_or(Vec3::Y));
            (p, normal, color, Vec2::new(s, t))
        });
    }

    fn leaf(&mut self, center: Vec3, axis: Vec3, width: f32, length: f32, color: Color) {
        let side = axis.cross(Vec3::Y).normalize_or(Vec3::X);
        let up = side.cross(axis).normalize();
        let point = |t: f32, s: f32| {
            let outline = (t * std::f32::consts::PI).sin().max(0.).powf(0.72);
            let lateral = s * 2. - 1.;
            center
                + axis * (t * 1.7 - 0.7) * length
                + side * lateral * outline * width
                + up * (outline * width * 0.24 * (1. - lateral * lateral) - t * t * length * 0.14)
        };
        self.grid(8, 2, |t, s| {
            let dt = point((t + 0.001).min(1.), s) - point((t - 0.001).max(0.), s);
            let ds = point(t, s + 0.001) - point(t, s - 0.001);
            let normal = ds.cross(dt).normalize_or(up);
            (point(t, s), normal, color, Vec2::new(s, t))
        });
    }

    // The connected volume guides leaf placement and broad lighting, but is
    // never rendered: its smooth skin previously made the crowns look solid.
    fn crown(&mut self, center: Vec3, size: Vec3, seed: u32, glade_opening: bool) {
        let phase = random(seed) * std::f32::consts::TAU;
        let lobes: Vec<_> = (0..9)
            .map(|i| {
                let n = seed + i * 37;
                let angle = i as f32 * 2.4 + phase;
                (
                    Vec3::new(
                        angle.cos() * (0.48 + random(n + 5) * 0.42),
                        (random(n + 1) - 0.45) * 1.25,
                        angle.sin() * (0.48 + random(n + 6) * 0.42),
                    ),
                    Vec3::new(
                        0.40 + random(n + 2) * 0.22,
                        0.42 + random(n + 3) * 0.24,
                        0.40 + random(n + 4) * 0.22,
                    ),
                )
            })
            .collect();
        let point = |t: f32, s: f32| {
            let latitude = t * std::f32::consts::PI;
            let longitude = s * std::f32::consts::TAU;
            let n = Vec3::new(
                latitude.sin() * longitude.cos(),
                latitude.cos(),
                latitude.sin() * longitude.sin(),
            );
            // Find the outer boundary of overlapping crown lobes along each
            // ray. A smooth union joins their shoulders into one closed mesh.
            let mut outline: f32 = 0.45;
            for &(offset, radii) in &lobes {
                let ray = n / radii;
                let origin = offset / radii;
                let a = ray.length_squared();
                let b = -ray.dot(origin);
                let c = origin.length_squared() - 1.;
                let discriminant = b * b - a * c;
                if discriminant >= 0. {
                    let distance = (-b + discriminant.sqrt()) / a;
                    let h = (0.18 - (outline - distance).abs()).max(0.) / 0.18;
                    outline = outline.max(distance) + h * h * 0.18 * 0.25;
                }
            }
            center + n * size * outline
        };
        let leaf_count = if center.z > -400. { 2400 } else { 1200 };
        for leaf in 0..leaf_count {
            let n = seed + leaf * 53;
            let y = 1. - 2. * (leaf as f32 + 0.5) / leaf_count as f32;
            let angle = leaf as f32 * 2.399963 + phase;
            let t = y.acos() / std::f32::consts::PI;
            let s = angle / std::f32::consts::TAU;
            let surface_point = point(t, s);
            let p = center + (surface_point - center) * (0.86 + random(n + 1) * 0.17);
            if glade_opening
                && ((p.xz() - Vec2::new(198., -314.)) / Vec2::new(83., 98.)).length() < 1.
            {
                continue;
            }
            let guide = ((p - center) / size / size).normalize();
            let dt = point(t + 0.001, s) - point(t - 0.001, s);
            let ds = point(t, s + 0.001) - point(t, s - 0.001);
            let normal = guide
                .lerp(ds.cross(dt).normalize_or(guide), 0.65)
                .normalize();
            let variation = Vec3::new(random(n + 7), random(n + 8), random(n + 9)) * 2. - Vec3::ONE;
            self.leaf_patch(
                p,
                (normal + variation * 0.40).normalize(),
                Vec2::new(4. + random(n + 2) * 3., 4. + random(n + 3) * 4.),
                n,
            );
        }
    }

    fn leaf_patch(&mut self, center: Vec3, normal: Vec3, size: Vec2, seed: u32) {
        let side = normal.cross(Vec3::Y).normalize_or(Vec3::X);
        let up = side.cross(normal).normalize();
        let phase = random(seed) * std::f32::consts::TAU;
        let u = side * phase.cos() + up * phase.sin();
        let v = -side * phase.sin() + up * phase.cos();
        let base = self.positions.len() as u32;
        let uv = Vec2::new(random(seed + 4), 0.);
        self.vertex(
            center + normal * size.x * 0.08,
            normal,
            normal_colour(normal),
            uv,
        );
        const EDGES: u32 = 24;
        for edge in 0..EDGES {
            let angle = edge as f32 / EDGES as f32 * std::f32::consts::TAU;
            let outline =
                0.87 + (angle * 3. + phase).sin() * 0.13 + (angle * 7. - phase).cos() * 0.06;
            let p = center + (u * angle.cos() * size.x + v * angle.sin() * size.y) * outline;
            self.vertex(p, normal, normal_colour(normal), uv);
            self.indices
                .extend([base, base + 1 + (edge + 1) % EDGES, base + 1 + edge]);
        }
    }

    // Transfer the parent volume's normals to small foliage masses so their
    // shading stays grouped, while closed geometry supplies a soft silhouette.
    fn tuft(
        &mut self,
        center: Vec3,
        size: Vec3,
        envelope: (Vec3, Vec3),
        paint_normals: bool,
        seed: u32,
        local_weight: f32,
    ) {
        let phase = random(seed) * std::f32::consts::TAU;
        let (rows, columns) = if paint_normals && size.max_element() > 15. {
            (16, 32)
        } else if local_weight < 0.5 {
            (10, 24)
        } else if local_weight < 0.75 {
            (16, 32)
        } else if center.z > -400. {
            (12, 24)
        } else {
            (8, 16)
        };
        let leaf_fan = paint_normals && size.max_element() < 15.;
        let rotation = if leaf_fan {
            Quat::from_rotation_z((random(seed + 13) - 0.5) * 1.5)
                * Quat::from_rotation_x((random(seed + 17) - 0.5) * 1.3)
        } else {
            Quat::IDENTITY
        };
        let point = |t: f32, s: f32| {
            let latitude = t * std::f32::consts::PI;
            let longitude = s * std::f32::consts::TAU;
            let radial = Vec3::new(
                latitude.sin() * longitude.cos(),
                latitude.cos(),
                latitude.sin() * longitude.sin(),
            );
            let detail = if local_weight < 0.5 { 0.5 } else { 1. };
            let softness = if paint_normals { 0.65 } else { 1. };
            let mut lobes = 1.
                + ((radial.x * 7. + radial.y * 4.) * softness + phase).sin() * 0.10 * softness
                + ((radial.z * 8. - radial.y * 6.) * softness + phase).sin()
                    * 0.07
                    * detail
                    * softness;
            if leaf_fan {
                lobes += (radial.x * 13. + radial.y * 6. + phase).sin()
                    * (radial.z * 11. - phase).cos()
                    * 0.09;
            }
            let mut offset = radial * size * lobes;
            if paint_normals {
                // Uneven leaf fans overlap in broad strokes. Shear their tips
                // instead of leaving concentric ellipsoids on each branch.
                offset.x += radial.y * size.x * (phase.sin() * 0.28);
                offset.y +=
                    (radial.x * 3. + phase).sin() * size.y * 0.16 * (1. - radial.y * radial.y);
                offset.z += radial.x * size.z * (phase.cos() * 0.22);
            }
            center + rotation * offset
        };
        self.grid(rows, columns, |t, s| {
            let p = point(t, s);
            let local_normal =
                (rotation * ((rotation.inverse() * (p - center)) / size / size)).normalize();
            let crown_normal =
                ((p - envelope.0) / envelope.1 / envelope.1).normalize_or(local_normal);
            let shade = crown_normal.lerp(local_normal, local_weight).normalize();
            let dt = point(t + 0.001, s) - point(t - 0.001, s);
            let ds = point(t, s + 0.001) - point(t, s - 0.001);
            // Shadow bias needs the real surface normal; transferred foliage
            // normals belong to the lighting lobe only. RGB stores that guide.
            let geometry = ds.cross(dt).normalize_or(local_normal);
            (
                p,
                if paint_normals { geometry } else { shade },
                if paint_normals {
                    normal_colour(shade)
                } else {
                    Color::WHITE
                },
                Vec2::new(random(seed), t),
            )
        });
    }

    fn finish(self) -> Mesh {
        Mesh::new(
            PrimitiveTopology::TriangleList,
            RenderAssetUsages::default(),
        )
        .with_inserted_attribute(Mesh::ATTRIBUTE_POSITION, self.positions)
        .with_inserted_attribute(Mesh::ATTRIBUTE_NORMAL, self.normals)
        .with_inserted_attribute(Mesh::ATTRIBUTE_COLOR, self.colors)
        .with_inserted_attribute(Mesh::ATTRIBUTE_UV_0, self.uv)
        .with_inserted_indices(Indices::U32(self.indices))
    }
}

fn normal_colour(normal: Vec3) -> Color {
    let rgb = normal * 0.5 + Vec3::splat(0.5);
    Color::linear_rgb(rgb.x, rgb.y, rgb.z)
}

fn random(mut seed: u32) -> f32 {
    seed ^= seed >> 16;
    seed = seed.wrapping_mul(0x7feb352d);
    seed ^= seed >> 15;
    seed = seed.wrapping_mul(0x846ca68b);
    seed ^= seed >> 16;
    seed as f32 / u32::MAX as f32
}

pub(super) struct Forest_Geometry {
    pub wood: Mesh,
    pub canopy: Mesh,
    pub understory: Mesh,
    pub sprays: Mesh,
    pub stone: Mesh,
}

pub(in crate::rendering) fn study_tree(parameters: &Tree_Parameters) -> (Mesh, Mesh) {
    let mut wood = Forest_Mesh::default();
    let mut leaves = Forest_Mesh::default();
    let bark = Color::srgb(0.30, 0.24, 0.15);
    wood.stem(
        |t| Vec3::new((t * 2.8).sin() * 9., t * 210., t * t * -12.),
        13.,
        2.,
        bark,
        28,
    );
    for i in 0..7 {
        let angle = i as f32 * 2.4;
        let end = Vec3::new(angle.cos() * 62., 95. + i as f32 * 15., angle.sin() * 55.);
        wood.branch(
            Vec3::Y * (38. + i as f32 * 15.),
            end,
            6. - i as f32 * 0.5,
            0.8,
            bark,
        );
    }
    for i in 0..5 {
        let angle = i as f32 * std::f32::consts::TAU / 5.;
        wood.branch(
            Vec3::Y * 7.,
            Vec3::new(angle.cos() * 28., 0., angle.sin() * 28.),
            5.,
            0.5,
            bark,
        );
    }
    if parameters.layout == Crown_Layout::Joined_Crown {
        study_joined_crown(&mut leaves, parameters);
    } else {
        study_tiers(&mut leaves, parameters);
    }
    let scale = Vec3::new(parameters.width, parameters.height, parameters.depth);
    (
        wood.finish().scaled_by(scale),
        leaves.finish().scaled_by(scale),
    )
}

fn study_tiers(leaves: &mut Forest_Mesh, parameters: &Tree_Parameters) {
    let crown_center = Vec3::new(0., 150., 0.);
    let crown_size = Vec3::new(110., 140., 85.);
    let mut cluster = 0_u32;
    for (height, spread, depth, count, radius) in [
        (66., 73., 39., 8_u32, 29.),
        (110., 70., 41., 9, 29.),
        (155., 57., 35., 8, 28.),
        (196., 36., 26., 6, 26.),
        (222., 14., 14., 3, 22.),
    ] {
        for i in 0..count {
            let seed = parameters.seed + cluster * 199;
            cluster += 1;
            let angle = i as f32 / count as f32 * std::f32::consts::TAU + height * 0.027;
            let center = Vec3::new(
                (angle.cos() * spread * (0.9 + random(seed) * 0.2) - (height - 66.) * 0.05) * 1.15,
                height + (random(seed + 1) - 0.5) * (parameters.irregularity * 28.),
                angle.sin() * depth,
            );
            let size = Vec3::new(
                radius * (0.92 + random(seed + 2) * 0.2) * 1.1,
                radius * (0.85 + random(seed + 3) * 0.22) * (0.7 + parameters.lobes * 0.46),
                radius * 0.92,
            );
            leaves.tuft(
                center,
                size,
                (crown_center, crown_size),
                true,
                seed,
                parameters.local_shading,
            );
            let count = (110. * parameters.leaf_density) as u32;
            for leaf in 0..count {
                let n = seed + leaf * 37;
                let y = 1. - 2. * (leaf as f32 + 0.5) / count as f32;
                let angle = leaf as f32 * 2.399963 + random(seed) * 6.;
                let ring = (1. - y * y).sqrt();
                let radial = Vec3::new(ring * angle.cos(), y, ring * angle.sin());
                let p = center + radial * size * (0.98 + random(n + 1) * 0.07);
                study_leaf(leaves, p, (center, size), n, parameters);
            }
        }
    }
}

fn study_leaf(
    leaves: &mut Forest_Mesh,
    point: Vec3,
    guide: (Vec3, Vec3),
    seed: u32,
    parameters: &Tree_Parameters,
) {
    let rounded = parameters.layout == Crown_Layout::Rounded_Tiers;
    let radius = if rounded {
        3.5 + random(seed + 2) * 3.
    } else {
        4. + random(seed + 2) * 3.5
    } * parameters.leaf_size;
    let size = if rounded {
        Vec3::new(radius, radius * 0.85, radius)
    } else {
        Vec3::new(
            radius * (0.95 + random(seed + 3) * 0.5),
            radius * (0.55 + random(seed + 4) * 0.25),
            radius * (0.7 + random(seed + 5) * 0.5),
        )
    };
    leaves.tuft(point, size, guide, true, seed, 0.10);
}

// One closed crown avoids seams and dark gaps between independent branch balls.
// Broad, non-repeating lobes change the silhouette continuously in all directions.
fn study_crown_point(radial: Vec3, parameters: &Tree_Parameters) -> Vec3 {
    let phase = random(parameters.seed) * std::f32::consts::TAU;
    let bulges = (radial.x * 4.1 + radial.y * 3.2 + radial.z * 1.7 + phase).sin() * 0.19
        + (radial.z * 5.3 - radial.y * 2.1 + radial.x * 1.3 - phase).sin() * 0.12;
    let shape = 1. + bulges * parameters.lobes;
    let broad = 1. - radial.y * 0.17;
    let skew = Vec3::new(
        (radial.y * 2.7 + phase).sin() * 13.,
        (radial.x * 2.3 + radial.z * 3.1 + phase).sin() * 10.,
        (radial.y * 3.2 - phase).sin() * 12.,
    ) * parameters.irregularity;
    Vec3::Y * 150. + radial * Vec3::new(105. * broad, 108., 105. * broad) * shape + skew
}

fn study_crown_normal(radial: Vec3, parameters: &Tree_Parameters) -> Vec3 {
    let tangent = radial.cross(Vec3::Y).normalize_or(Vec3::X);
    let bitangent = radial.cross(tangent).normalize();
    let along = |axis: Vec3| {
        study_crown_point((radial + axis * 0.001).normalize(), parameters)
            - study_crown_point((radial - axis * 0.001).normalize(), parameters)
    };
    along(tangent).cross(along(bitangent)).normalize_or(radial)
}

fn study_joined_crown(leaves: &mut Forest_Mesh, parameters: &Tree_Parameters) {
    leaves.grid(64, 128, |t, s| {
        let latitude = t * std::f32::consts::PI;
        let longitude = s * std::f32::consts::TAU;
        let radial = Vec3::new(
            latitude.sin() * longitude.cos(),
            latitude.cos(),
            latitude.sin() * longitude.sin(),
        );
        let point = study_crown_point(radial, parameters);
        let normal = study_crown_normal(radial, parameters);
        let shade = radial.lerp(normal, parameters.local_shading).normalize();
        (point, normal, normal_colour(shade), Vec2::new(0.4, t))
    });
    let count = (3800. * parameters.leaf_density) as u32;
    for leaf in 0..count {
        let seed = parameters.seed + leaf * 37;
        let y = 1. - 2. * (leaf as f32 + 0.5) / count as f32;
        let angle = leaf as f32 * 2.399963 + random(parameters.seed) * 6.;
        let ring = (1. - y * y).sqrt();
        let radial = Vec3::new(ring * angle.cos(), y, ring * angle.sin());
        let point = study_crown_point(radial, parameters);
        let normal = study_crown_normal(radial, parameters);
        let shade = radial.lerp(normal, parameters.local_shading).normalize();
        study_leaf(
            leaves,
            point,
            (point - shade * 65., Vec3::splat(65.)),
            seed,
            parameters,
        );
    }
}

pub(super) fn build() -> Forest_Geometry {
    let mut wood = Forest_Mesh::default();
    let mut canopy = Forest_Mesh::default();
    let mut floor = Forest_Mesh::default();
    let mut sprays = Forest_Mesh::default();
    let mut stone_mesh = Forest_Mesh::default();
    let mut trees = vec![
        (-175., 55., 230., 20.),
        (210., 20., 255., 23.),
        (-245., -100., 260., 19.),
        (270., -160., 290., 23.),
        (-95., -210., 220., 15.),
        (195., -325., 250., 17.),
    ];
    for row in 0..8 {
        for column in 0..10 {
            let seed = row * 173 + column * 23 + 19;
            let x = column as f32 * 100. - 480. + random(seed) * 65.;
            let z = -140. - row as f32 * 105. - random(seed + 1) * 65.;
            if Vec2::new(x - 45., (z + 180.) * 0.8).length() < 175. {
                continue;
            }
            trees.push((
                x,
                z,
                175. + random(seed + 2) * 115.,
                8. + random(seed + 3) * 9.,
            ));
        }
    }
    for (index, (x, z, height, radius)) in trees.into_iter().enumerate() {
        let seed = index as u32 * 199;
        let base = Vec3::new(x, terrain_height(Vec2::new(x, z)) - 1., z);
        let lean = Vec3::new(random(seed + 1) - 0.5, 0., random(seed + 2) - 0.5) * 35.;
        let bark = Color::srgb(
            0.25 + random(seed + 3) * 0.08,
            0.20 + random(seed + 4) * 0.07,
            0.13,
        );
        wood.stem(
            |t| {
                base + Vec3::Y * height * t
                    + lean * t * t
                    + Vec3::new((t * 3.1).sin(), 0., (t * 4.2).sin()) * radius * 0.15
            },
            radius,
            radius * 0.2,
            bark,
            24,
        );
        for root in 0..6 {
            let angle = root as f32 * std::f32::consts::TAU / 6. + random(seed + 9);
            let reach = Vec3::new(angle.cos(), 0., angle.sin()) * radius * 3.5;
            let end = base + reach;
            wood.branch(
                base + Vec3::Y * radius * 0.45,
                Vec3::new(end.x, terrain_height(end.xz()) - 1., end.z),
                radius * 0.45,
                0.5,
                bark,
            );
        }
        for branch in 0..6 {
            let angle = branch as f32 * 2.4 + random(seed + 5) * 6.;
            let direction = Vec3::new(angle.cos(), 0., angle.sin());
            let start = base + Vec3::Y * height * (0.57 + branch as f32 * 0.048) + lean * 0.5;
            let crown = base
                + Vec3::Y * height * (0.84 + random(seed + branch + 10) * 0.15)
                + lean
                + direction * (30. + random(seed + branch + 20) * 40.);
            let elbow = start.lerp(crown, 0.65) - Vec3::Y * 13.;
            wood.branch(start, elbow, radius * 0.45, radius * 0.22, bark);
            wood.branch(elbow, crown, radius * 0.22, 0.5, bark);
        }
        canopy.crown(
            base + Vec3::Y * height * 0.86 + lean,
            Vec3::new(height * 0.28 + 18., height * 0.31, height * 0.27 + 18.),
            seed + 1103,
            true,
        );
    }
    // Low, rounded shrubs and small flowers gather along the clearing's edge.
    for i in 0..260 {
        let x = random(i * 31 + 1) * 620. - 300.;
        let z = random(i * 31 + 2) * -640. + 90.;
        let base = Vec3::new(x, terrain_height(Vec2::new(x, z)), z);
        if clearing(Vec2::new(x, z)) < 0.22 {
            continue;
        }
        if i % 3 == 0 {
            let crown = base + Vec3::Y * 5.;
            let radii = Vec3::new(
                9. + random(i + 4) * 8.,
                5. + random(i + 5) * 7.,
                8. + random(i + 6) * 5.,
            );
            for patch in 0..22 {
                let n = i * 97 + patch * 19;
                let y = random(n + 1) * 0.95 + 0.05;
                let angle = patch as f32 * 2.4;
                let ring = (1. - y * y).sqrt();
                let radial = Vec3::new(ring * angle.cos(), y, ring * angle.sin());
                sprays.tuft(
                    crown + radial * radii,
                    Vec3::new(4.5, 4., 5.) * (0.8 + random(n + 2) * 0.6),
                    (crown, radii),
                    false,
                    n,
                    0.78,
                );
            }
        } else {
            for flower in 0..4 {
                let p = base
                    + Vec3::new(
                        random(i + flower) * 9.,
                        4. + flower as f32,
                        random(i + flower + 2) * 9.,
                    );
                let color = if i % 5 == 0 {
                    Color::srgb(0.94, 0.78, 0.42)
                } else {
                    Color::srgb(0.55, 0.77, 0.93)
                };
                for petal in 0..5 {
                    let angle = petal as f32 * std::f32::consts::TAU / 5.;
                    floor.leaf(
                        p,
                        Vec3::new(angle.cos(), 0.3, angle.sin()).normalize(),
                        0.9,
                        1.8,
                        color,
                    );
                }
            }
        }
    }
    for i in 0..42 {
        let x = random(i * 19 + 1) * 520. - 240.;
        let z = -random(i * 19 + 2) * 570.;
        let p = Vec3::new(x, terrain_height(Vec2::new(x, z)), z);
        let radius = 5. + random(i * 19 + 3) * 13.;
        stone_mesh.rock(
            p,
            Vec3::new(radius, radius * 0.55, radius * 0.8),
            Color::srgb(0.27, 0.34, 0.29),
            i,
        );
    }
    // A small, weathered standing stone gives the eye a destination in the light.
    let stone = Vec3::new(72., terrain_height(Vec2::new(72., -200.)), -200.);
    stone_mesh.rock(
        stone + Vec3::Y * 15.,
        Vec3::new(11., 27., 8.),
        Color::srgb(0.40, 0.48, 0.40),
        413,
    );
    Forest_Geometry {
        wood: wood.finish(),
        canopy: canopy.finish(),
        understory: floor.finish(),
        sprays: sprays.finish(),
        stone: stone_mesh.finish(),
    }
}
