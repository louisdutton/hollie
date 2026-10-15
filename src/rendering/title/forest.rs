use super::*;

#[derive(Default)]
struct Forest_Mesh {
    positions: Vec<[f32; 3]>,
    normals: Vec<[f32; 3]>,
    colors: Vec<[f32; 4]>,
}
impl Forest_Mesh {
    fn triangle(&mut self, a: Vec3, b: Vec3, c: Vec3, color: Color) {
        let normal = (b - a).cross(c - a).normalize_or_zero().to_array();
        for point in [a, b, c] {
            self.positions.push(point.to_array());
            self.normals.push(normal);
            self.colors.push(color.to_linear().to_f32_array());
        }
    }

    fn branch(&mut self, start: Vec3, end: Vec3, radius: f32, tip: f32, color: Color) {
        let axis = (end - start).normalize();
        let u = axis.any_orthonormal_vector();
        let v = axis.cross(u);
        for side in 0..9 {
            let ring = |i: u32| {
                let angle = i as f32 * std::f32::consts::TAU / 9.;
                u * angle.cos() + v * angle.sin()
            };
            let a = start + ring(side) * radius;
            let b = start + ring(side + 1) * radius;
            let c = end + ring(side + 1) * tip;
            let d = end + ring(side) * tip;
            self.triangle(a, b, c, color);
            self.triangle(a, c, d, color);
            self.triangle(end, d, c, color);
        }
    }

    fn rock(&mut self, center: Vec3, size: Vec3, color: Color, seed: u32) {
        for ring in 0..5 {
            for side in 0..9 {
                let point = |r: u32, s: u32| {
                    let latitude = r as f32 * std::f32::consts::PI / 5.;
                    let longitude = s as f32 * std::f32::consts::TAU / 9.;
                    let uneven = 0.85 + random(seed + s % 9 + r * 11) * 0.3;
                    center
                        + Vec3::new(
                            latitude.sin() * longitude.cos(),
                            latitude.cos(),
                            latitude.sin() * longitude.sin(),
                        ) * size
                            * uneven
                };
                let a = point(ring, side);
                let b = point(ring + 1, side);
                let c = point(ring + 1, side + 1);
                let d = point(ring, side + 1);
                self.triangle(a, c, b, color);
                self.triangle(a, d, c, color);
            }
        }
    }

    fn leaf(&mut self, center: Vec3, axis: Vec3, width: f32, length: f32, color: Color) {
        let side = axis.cross(Vec3::Y).normalize_or(Vec3::X) * width;
        let ridge = center + Vec3::Y * width * 0.25;
        let tip = center + axis * length;
        let base = center - axis * length * 0.7;
        self.triangle(base, center + side, ridge, color);
        self.triangle(center + side, tip, ridge, color);
        self.triangle(tip, center - side, ridge, color);
        self.triangle(center - side, base, ridge, color);
    }

    fn finish(self) -> Mesh {
        Mesh::new(
            PrimitiveTopology::TriangleList,
            RenderAssetUsages::default(),
        )
        .with_inserted_attribute(Mesh::ATTRIBUTE_POSITION, self.positions)
        .with_inserted_attribute(Mesh::ATTRIBUTE_NORMAL, self.normals)
        .with_inserted_attribute(Mesh::ATTRIBUTE_COLOR, self.colors)
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

pub(super) fn build() -> (Mesh, Mesh, Mesh) {
    let mut wood = Forest_Mesh::default();
    let mut canopy = Forest_Mesh::default();
    let mut floor = Forest_Mesh::default();
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
        for section in 0..5 {
            let a = section as f32 / 5.;
            let b = (section + 1) as f32 / 5.;
            wood.branch(
                base + Vec3::Y * height * a + lean * a * a,
                base + Vec3::Y * height * b + lean * b * b,
                radius * (1. - a * 0.8),
                radius * (1. - b * 0.8),
                bark,
            );
        }
        for root in 0..6 {
            let angle = root as f32 * std::f32::consts::TAU / 6. + random(seed + 9);
            let reach = Vec3::new(angle.cos(), 0., angle.sin()) * radius * 3.5;
            let end = base + reach;
            wood.branch(
                base + Vec3::Y * radius * 1.4,
                Vec3::new(end.x, terrain_height(end.xz()) - 1., end.z),
                radius * 0.6,
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
            for leaf in 0..160 {
                let n = seed + branch * 1277 + leaf * 17;
                let y = random(n + 1) * 2. - 1.;
                let angle = random(n + 2) * std::f32::consts::TAU;
                let ring = (1. - y * y).sqrt();
                let radial = Vec3::new(ring * angle.cos(), y * 0.5, ring * angle.sin());
                let center = crown + radial * (34. + random(n + 3) * 16.);
                // Leave a canopy opening on the sunward side of the clearing.
                if ((center.xz() - Vec2::new(198., -314.)) / Vec2::new(63., 78.)).length() < 1. {
                    continue;
                }
                let tone = random(n + 4);
                let color = Color::srgb(0.13 + tone * 0.15, 0.28 + tone * 0.19, 0.12 + tone * 0.08);
                canopy.leaf(
                    center,
                    Vec3::new(angle.cos(), 0.12, angle.sin()).normalize(),
                    4. + random(n + 5) * 4.,
                    9. + random(n + 6) * 7.,
                    color,
                );
            }
        }
    }
    // Ferns and blue-white flowers gather along the clearing's winding edge.
    for i in 0..260 {
        let x = random(i * 31 + 1) * 620. - 300.;
        let z = random(i * 31 + 2) * -640. + 90.;
        let base = Vec3::new(x, terrain_height(Vec2::new(x, z)), z);
        if clearing(Vec2::new(x, z)) < 0.22 {
            continue;
        }
        if i % 3 == 0 {
            for frond in 0..7 {
                let angle = frond as f32 * 2.4;
                let direction = Vec3::new(angle.cos(), 0., angle.sin());
                for leaflet in 1..7 {
                    let t = leaflet as f32 / 7.;
                    let center = base
                        + direction * t * 15.
                        + Vec3::Y * (t * std::f32::consts::PI * 0.8).sin() * 12.;
                    for side in [-1., 1.] {
                        let axis = Quat::from_rotation_y(side * 0.8) * direction;
                        floor.leaf(
                            center,
                            axis,
                            (1. - t) * 2.5,
                            (1. - t) * 6.,
                            Color::srgb(0.17, 0.39, 0.23),
                        );
                    }
                }
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
        floor.rock(
            p,
            Vec3::new(radius, radius * 0.55, radius * 0.8),
            Color::srgb(0.27, 0.34, 0.29),
            i,
        );
        floor.rock(
            p + Vec3::Y * radius * 0.3,
            Vec3::new(radius * 0.88, radius * 0.3, radius * 0.75),
            Color::srgb(0.27, 0.41, 0.19),
            i,
        );
    }
    // A small, weathered standing stone gives the eye a destination in the light.
    let stone = Vec3::new(72., terrain_height(Vec2::new(72., -200.)), -200.);
    floor.rock(
        stone + Vec3::Y * 15.,
        Vec3::new(11., 27., 8.),
        Color::srgb(0.40, 0.48, 0.40),
        413,
    );
    floor.rock(
        stone + Vec3::Y * 5.,
        Vec3::new(14., 7., 11.),
        Color::srgb(0.31, 0.44, 0.21),
        719,
    );
    (wood.finish(), canopy.finish(), floor.finish())
}
