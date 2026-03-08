#!/usr/bin/env python3
"""
Generate muscle_body.usdz with 13 anatomical muscle group meshes.

Uses USD Python (pxr) to create capsule/cylinder-based approximations
of each muscle group, arranged on a humanoid body frame.

Entity naming: muscle_{rawValue} for each MuscleGroup case.
Body shell entity: body_shell

Usage:
    source /tmp/usdz-gen/bin/activate
    python3 scripts/generate-muscle-usdz.py
"""

import os
import math
import tempfile
import shutil
from pxr import Usd, UsdGeom, UsdShade, Sdf, Gf, UsdUtils

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                          "DUNE", "Resources", "Models")
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "muscle_body.usdz")

# Body height = 1.72m, centered at origin
BODY_HEIGHT = 1.72
BODY_HALF = BODY_HEIGHT / 2  # 0.86

# Vertical reference points (from top of head downward, origin at center)
HEAD_TOP = 0.86
NECK = 0.70
SHOULDER = 0.62
CHEST_TOP = 0.58
CHEST_BOTTOM = 0.35
WAIST = 0.20
HIP = 0.08
GROIN = -0.06
KNEE = -0.50
ANKLE = -0.86


def create_capsule(stage, path, height, radius, position, rotation_deg=None):
    """Create a capsule mesh at the given path."""
    capsule = UsdGeom.Capsule.Define(stage, path)
    capsule.GetHeightAttr().Set(float(height))
    capsule.GetRadiusAttr().Set(float(radius))
    capsule.GetAxisAttr().Set("Y")

    xform = UsdGeom.Xformable(capsule.GetPrim())
    xform.ClearXformOpOrder()

    if rotation_deg:
        rx, ry, rz = rotation_deg
        if rz != 0:
            xform.AddRotateZOp().Set(float(rz))
        if ry != 0:
            xform.AddRotateYOp().Set(float(ry))
        if rx != 0:
            xform.AddRotateXOp().Set(float(rx))

    xform.AddTranslateOp().Set(Gf.Vec3d(*position))
    return capsule


def create_cylinder(stage, path, height, radius, position, rotation_deg=None):
    """Create a cylinder mesh at the given path."""
    cylinder = UsdGeom.Cylinder.Define(stage, path)
    cylinder.GetHeightAttr().Set(float(height))
    cylinder.GetRadiusAttr().Set(float(radius))
    cylinder.GetAxisAttr().Set("Y")

    xform = UsdGeom.Xformable(cylinder.GetPrim())
    xform.ClearXformOpOrder()

    if rotation_deg:
        rx, ry, rz = rotation_deg
        if rz != 0:
            xform.AddRotateZOp().Set(float(rz))
        if ry != 0:
            xform.AddRotateYOp().Set(float(ry))
        if rx != 0:
            xform.AddRotateXOp().Set(float(rx))

    xform.AddTranslateOp().Set(Gf.Vec3d(*position))
    return cylinder


def create_sphere(stage, path, radius, position):
    """Create a sphere mesh at the given path."""
    sphere = UsdGeom.Sphere.Define(stage, path)
    sphere.GetRadiusAttr().Set(float(radius))

    xform = UsdGeom.Xformable(sphere.GetPrim())
    xform.ClearXformOpOrder()
    xform.AddTranslateOp().Set(Gf.Vec3d(*position))
    return sphere


def add_default_material(stage, prim, r=0.8, g=0.8, b=0.8):
    """Add a simple material to a prim."""
    mat_path = str(prim.GetPath()) + "/material"
    material = UsdShade.Material.Define(stage, mat_path)
    shader = UsdShade.Shader.Define(stage, mat_path + "/shader")
    shader.CreateIdAttr("UsdPreviewSurface")
    shader.CreateInput("diffuseColor", Sdf.ValueTypeNames.Color3f).Set(Gf.Vec3f(r, g, b))
    shader.CreateInput("roughness", Sdf.ValueTypeNames.Float).Set(0.4)
    material.CreateSurfaceOutput().ConnectToSource(shader.ConnectableAPI(), "surface")
    UsdShade.MaterialBindingAPI(prim).Bind(material)


def build_muscle_group(stage, root_path, name, parts):
    """
    Build a muscle group under root_path/muscle_{name}.
    parts: list of (shape, kwargs) tuples.
    """
    group_path = f"{root_path}/muscle_{name}"
    group = UsdGeom.Xform.Define(stage, group_path)

    for i, (shape_fn, kwargs) in enumerate(parts):
        part_path = f"{group_path}/part_{i}"
        prim = shape_fn(stage, part_path, **kwargs)
        add_default_material(stage, prim.GetPrim(), 0.75, 0.75, 0.75)

    return group


def build_body_shell(stage, root_path):
    """Build a semi-transparent body shell for context."""
    shell_path = f"{root_path}/body_shell"
    shell = UsdGeom.Xform.Define(stage, shell_path)

    parts = [
        # Head
        (create_sphere, dict(radius=0.10, position=(0, 0.76, 0))),
        # Neck
        (create_cylinder, dict(height=0.08, radius=0.05, position=(0, 0.68, 0))),
        # Torso upper
        (create_capsule, dict(height=0.30, radius=0.16, position=(0, 0.46, 0))),
        # Torso lower
        (create_capsule, dict(height=0.18, radius=0.14, position=(0, 0.14, 0))),
        # Hip
        (create_capsule, dict(height=0.12, radius=0.15, position=(0, 0.02, 0))),
        # Upper arm L
        (create_capsule, dict(height=0.26, radius=0.042,
                              position=(-0.28, 0.38, 0), rotation_deg=(0, 0, 12))),
        # Upper arm R
        (create_capsule, dict(height=0.26, radius=0.042,
                              position=(0.28, 0.38, 0), rotation_deg=(0, 0, -12))),
        # Forearm L
        (create_capsule, dict(height=0.24, radius=0.035,
                              position=(-0.32, 0.10, 0), rotation_deg=(0, 0, 6))),
        # Forearm R
        (create_capsule, dict(height=0.24, radius=0.035,
                              position=(0.32, 0.10, 0), rotation_deg=(0, 0, -6))),
        # Upper leg L
        (create_capsule, dict(height=0.40, radius=0.08,
                              position=(-0.10, -0.28, 0))),
        # Upper leg R
        (create_capsule, dict(height=0.40, radius=0.08,
                              position=(0.10, -0.28, 0))),
        # Lower leg L
        (create_capsule, dict(height=0.38, radius=0.055,
                              position=(-0.10, -0.68, 0))),
        # Lower leg R
        (create_capsule, dict(height=0.38, radius=0.055,
                              position=(0.10, -0.68, 0))),
    ]

    for i, (shape_fn, kwargs) in enumerate(parts):
        prim = shape_fn(stage, f"{shell_path}/part_{i}", **kwargs)
        add_default_material(stage, prim.GetPrim(), 0.85, 0.85, 0.85)


def build_muscles(stage, root_path):
    """Build all 13 muscle groups with anatomical placement."""

    # chest - front upper torso, two pectoralis shapes
    build_muscle_group(stage, root_path, "chest", [
        (create_capsule, dict(height=0.14, radius=0.065,
                              position=(-0.08, 0.50, 0.10), rotation_deg=(0, 0, 20))),
        (create_capsule, dict(height=0.14, radius=0.065,
                              position=(0.08, 0.50, 0.10), rotation_deg=(0, 0, -20))),
    ])

    # back - posterior upper torso
    build_muscle_group(stage, root_path, "back", [
        (create_capsule, dict(height=0.22, radius=0.07,
                              position=(-0.06, 0.46, -0.10))),
        (create_capsule, dict(height=0.22, radius=0.07,
                              position=(0.06, 0.46, -0.10))),
    ])

    # shoulders - deltoids
    build_muscle_group(stage, root_path, "shoulders", [
        (create_sphere, dict(radius=0.055, position=(-0.22, 0.58, 0))),
        (create_sphere, dict(radius=0.055, position=(0.22, 0.58, 0))),
    ])

    # biceps - front upper arm
    build_muscle_group(stage, root_path, "biceps", [
        (create_capsule, dict(height=0.16, radius=0.038,
                              position=(-0.28, 0.38, 0.03), rotation_deg=(0, 0, 12))),
        (create_capsule, dict(height=0.16, radius=0.038,
                              position=(0.28, 0.38, 0.03), rotation_deg=(0, 0, -12))),
    ])

    # triceps - back upper arm
    build_muscle_group(stage, root_path, "triceps", [
        (create_capsule, dict(height=0.16, radius=0.036,
                              position=(-0.28, 0.36, -0.03), rotation_deg=(0, 0, 12))),
        (create_capsule, dict(height=0.16, radius=0.036,
                              position=(0.28, 0.36, -0.03), rotation_deg=(0, 0, -12))),
    ])

    # forearms
    build_muscle_group(stage, root_path, "forearms", [
        (create_capsule, dict(height=0.18, radius=0.032,
                              position=(-0.32, 0.10, 0), rotation_deg=(0, 0, 6))),
        (create_capsule, dict(height=0.18, radius=0.032,
                              position=(0.32, 0.10, 0), rotation_deg=(0, 0, -6))),
    ])

    # core - abdominals + obliques
    build_muscle_group(stage, root_path, "core", [
        # rectus abdominis
        (create_capsule, dict(height=0.22, radius=0.06,
                              position=(0, 0.26, 0.10))),
        # obliques L
        (create_capsule, dict(height=0.14, radius=0.04,
                              position=(-0.12, 0.22, 0.06), rotation_deg=(0, 0, 8))),
        # obliques R
        (create_capsule, dict(height=0.14, radius=0.04,
                              position=(0.12, 0.22, 0.06), rotation_deg=(0, 0, -8))),
    ])

    # quadriceps - front upper leg
    build_muscle_group(stage, root_path, "quadriceps", [
        (create_capsule, dict(height=0.32, radius=0.065,
                              position=(-0.10, -0.26, 0.04))),
        (create_capsule, dict(height=0.32, radius=0.065,
                              position=(0.10, -0.26, 0.04))),
    ])

    # hamstrings - back upper leg
    build_muscle_group(stage, root_path, "hamstrings", [
        (create_capsule, dict(height=0.30, radius=0.058,
                              position=(-0.10, -0.28, -0.04))),
        (create_capsule, dict(height=0.30, radius=0.058,
                              position=(0.10, -0.28, -0.04))),
    ])

    # glutes - buttocks
    build_muscle_group(stage, root_path, "glutes", [
        (create_sphere, dict(radius=0.085, position=(-0.08, -0.02, -0.08))),
        (create_sphere, dict(radius=0.085, position=(0.08, -0.02, -0.08))),
    ])

    # calves - back lower leg
    build_muscle_group(stage, root_path, "calves", [
        (create_capsule, dict(height=0.22, radius=0.046,
                              position=(-0.10, -0.60, -0.02))),
        (create_capsule, dict(height=0.22, radius=0.046,
                              position=(0.10, -0.60, -0.02))),
    ])

    # traps - upper back / neck
    build_muscle_group(stage, root_path, "traps", [
        (create_capsule, dict(height=0.12, radius=0.055,
                              position=(-0.08, 0.62, -0.06), rotation_deg=(0, 0, 15))),
        (create_capsule, dict(height=0.12, radius=0.055,
                              position=(0.08, 0.62, -0.06), rotation_deg=(0, 0, -15))),
    ])

    # lats - lateral back
    build_muscle_group(stage, root_path, "lats", [
        (create_capsule, dict(height=0.22, radius=0.06,
                              position=(-0.14, 0.38, -0.08), rotation_deg=(0, 0, 8))),
        (create_capsule, dict(height=0.22, radius=0.06,
                              position=(0.14, 0.38, -0.08), rotation_deg=(0, 0, -8))),
    ])


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Create a temporary .usdc, then package as .usdz
    tmp_dir = tempfile.mkdtemp(prefix="muscle_body_")
    usda_path = os.path.join(tmp_dir, "muscle_body.usda")

    stage = Usd.Stage.CreateNew(usda_path)
    UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)
    UsdGeom.SetStageMetersPerUnit(stage, 1.0)

    root_path = "/muscle_body"
    root = UsdGeom.Xform.Define(stage, root_path)
    stage.SetDefaultPrim(root.GetPrim())

    build_body_shell(stage, root_path)
    build_muscles(stage, root_path)

    stage.GetRootLayer().Save()
    print(f"Created USDA: {usda_path}")

    # Convert to USDZ
    UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(usda_path), OUTPUT_FILE)
    print(f"Created USDZ: {OUTPUT_FILE}")

    # Cleanup
    shutil.rmtree(tmp_dir)
    file_size = os.path.getsize(OUTPUT_FILE)
    print(f"File size: {file_size / 1024:.1f} KB")


if __name__ == "__main__":
    main()
