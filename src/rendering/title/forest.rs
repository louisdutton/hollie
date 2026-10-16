use super::*;

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

    // Closed, overlapping clumps avoid the visible sheets of the previous
    // canopy. Blend local and crown normals to keep both scales readable in
    // the painted light bands (Lightning Boy Studio's Ghibli tree approach).
    fn tuft(&mut self, center: Vec3, size: Vec3, envelope: (Vec3, Vec3), color: Color, seed: u32) {
        let phase = random(seed) * std::f32::consts::TAU;
        let (rows, columns) = if center.z > -400. { (12, 24) } else { (8, 16) };
        self.grid(rows, columns, |t, s| {
            let latitude = t * std::f32::consts::PI;
            let longitude = s * std::f32::consts::TAU;
            let radial = Vec3::new(
                latitude.sin() * longitude.cos(),
                latitude.cos(),
                latitude.sin() * longitude.sin(),
            );
            let lobes = 1.
                + (radial.x * 7. + radial.y * 4. + phase).sin() * 0.10
                + (radial.z * 8. - radial.y * 6. + phase).sin() * 0.07;
            let p = center + radial * size * lobes;
            let crown_normal = ((p - envelope.0) / envelope.1 / envelope.1).normalize_or(radial);
            let local_normal = (radial / size).normalize();
            (
                p,
                crown_normal.lerp(local_normal, 0.78).normalize(),
                color,
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
            let leaf_count = if z > -400. { 52 } else { 32 };
            for leaf in 0..leaf_count {
                let n = seed + branch * 1277 + leaf * 17;
                let y = random(n + 1) * 2. - 1.;
                let angle = random(n + 2) * std::f32::consts::TAU;
                let ring = (1. - y * y).sqrt();
                let radial = Vec3::new(ring * angle.cos(), y * 0.65, ring * angle.sin());
                let center = crown + radial * (24. + random(n + 3) * 19.);
                // Leave a canopy opening on the sunward side of the clearing.
                if ((center.xz() - Vec2::new(198., -314.)) / Vec2::new(83., 98.)).length() < 1. {
                    continue;
                }
                let tone = 0.90 + random(n + 4) * 0.18;
                canopy.tuft(
                    center,
                    Vec3::new(
                        10. + random(n + 5) * 7.,
                        9. + random(n + 6) * 6.,
                        11. + random(n + 7) * 6.,
                    ),
                    (crown, Vec3::new(48., 31., 48.)),
                    Color::srgb(tone, tone, tone),
                    n,
                );
            }
        }
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
                    Color::WHITE,
                    n,
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
