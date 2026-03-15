#!/usr/bin/env python3
"""
Convert Z-Anatomy Blender model to muscle_body.usdz for DUNE app.

Reads Z-Anatomy Startup.blend, extracts muscle meshes, groups them
into 13 MuscleGroup categories, applies decimation for mobile performance,
creates a body_shell from skin mesh, and exports as USDZ.

Entity naming: muscle_{rawValue} for each MuscleGroup case.
Body shell entity: body_shell

Usage:
    blender --background --python scripts/convert-zanatomy-to-usdz.py -- [--ratio 0.3] [--input /path/to/Startup.blend]
"""

import bpy
import bmesh
import os
import sys
import math

# Parse arguments after "--"
argv = sys.argv
if "--" in argv:
    argv = argv[argv.index("--") + 1:]
else:
    argv = []

# Defaults
DECIMATE_RATIO = 1.0  # 1.0 = no decimation (original quality)
INPUT_BLEND = "/tmp/z-anatomy/Z-Anatomy/Startup.blend"
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                          "DUNE", "Resources", "Models")

# Parse optional args
i = 0
while i < len(argv):
    if argv[i] == "--ratio" and i + 1 < len(argv):
        DECIMATE_RATIO = float(argv[i + 1])
        i += 2
    elif argv[i] == "--input" and i + 1 < len(argv):
        INPUT_BLEND = argv[i + 1]
        i += 2
    else:
        i += 1

# ── Muscle Group Mapping ──────────────────────────────────────────────
# Maps MuscleGroup enum rawValue -> list of Z-Anatomy object name patterns
# Only .l/.r suffixed objects are selected (actual muscle bodies)

MUSCLE_MAPPING = {
    "chest": [
        "Sternocostal head of pectoralis major muscle",
        "Clavicular head of pectoralis major muscle",
        "(Abdominal part of pectoralis major muscle)",
        "Pectoralis minor muscle",
    ],
    "back": [
        "Iliocostalis colli muscle",
        "Iliocostalis lumborum muscle",
        "Iliocostalis thoracis muscle",
        "Longissimus capitis muscle",
        "Longissimus colli muscle",
        "Longissimus thoracis muscle",
        "Multifidus colli muscle",
        "Multifidus lumborum muscle",
        "Multifidus thoracis muscle",
        "Semispinalis colli muscle",
        "Semispinalis thoracis muscle",
        "Spinalis capitis muscle",
        "Spinalis colli muscle",
        "Spinalis thoracis muscle",
        "Rhomboid major muscle",
        "Rhomboid minor muscle",
        "Serratus posterior inferior muscle",
        "Serratus posterior superior muscle",
    ],
    "shoulders": [
        "Acromial part of deltoid muscle",
        "Clavicular part of deltoid muscle",
        "Scapular spinal part of deltoid muscle",
        "Supraspinatus muscle",
        "Infraspinatus muscle",
        "Teres minor muscle",
        "Teres major muscle",
        "Subscapularis muscle",
    ],
    "biceps": [
        "Long head of biceps brachii",
        "Short head of biceps brachii",
        "Brachialis muscle",
        "Coracobrachialis muscle",
    ],
    "triceps": [
        "Long head of triceps brachii",
        "Lateral head of triceps brachii",
        "Medial head of triceps brachii",
    ],
    "forearms": [
        "Brachioradialis muscle",
        "Extensor carpi radialis longus",
        "Extensor carpi radialis brevis",
        "Humeral head of extensor carpi ulnaris",
        "Ulnar head of extensor carpi ulnaris",
        "Flexor carpi radialis",
        "Humeral head of flexor carpi ulnaris",
        "Ulnar head of flexor carpi ulnaris",
        "Deep head of pronator teres",
        "Superficial head of pronator teres",
        "Pronator quadratus",
        "Supinator",
        "Anconeus muscle",
        "Flexor digitorum superficialis",
        "Humero-ulnar head of flexor digitorum superficialis",
        "Radial head of flexor digitorum superficialis",
        "Flexor digitorum profundus",
        "Extensor digitorum",
        "Palmaris longus muscle",
        "Extensor pollicis longus",
        "Extensor pollicis brevis",
        "Abductor pollicis longus",
        "Extensor indicis",
        "Extensor digiti minimi",
    ],
    "core": [
        "Rectus abdominis muscle",
        "External abdominal oblique muscle",
        "Internal abdominal oblique muscle",
        "Transversus abdominis muscle",
        "Serratus anterior muscle",
    ],
    "quadriceps": [
        "Rectus femoris muscle",
        "Vastus lateralis muscle",
        "Vastus medialis muscle",
        "Vastus intermedius muscle",
        "Articularis genus muscle",
    ],
    "hamstrings": [
        "Long head of biceps femoris",
        "Short head of biceps femoris",
        "Semimembranosus muscle",
        "Semitendinosus muscle",
    ],
    "glutes": [
        "Gluteus maximus muscle",
        "Gluteus medius muscle",
        "Gluteus minimus muscle",
        "Tensor fasciae latae",
    ],
    "calves": [
        "Lateral head of gastrocnemius",
        "Medial head of gastrocnemius",
        "Soleus muscle",
        "Tibialis anterior muscle",
        "Tibialis posterior muscle",
        "Fibularis longus muscle",
        "Fibularis brevis muscle",
        "Peroneus longus",
        "Peroneus brevis",
        "Plantaris muscle",
    ],
    "traps": [
        "Ascending part of trapezius muscle",
        "Descending part of trapezius muscle",
        "Transverse part of trapezius muscle",
        "Levator scapulae muscle",
    ],
    "lats": [
        "Latissimus dorsi muscle",
    ],
}

# ── Skin/Shell objects ────────────────────────────────────────────────
SKIN_PATTERNS = [
    "Skin",
    "Subcutaneous tissue",
]


def is_target_mesh(obj, patterns):
    """Check if object name matches any pattern and has .l or .r suffix."""
    if obj.type != "MESH":
        return False
    name = obj.name
    if not (name.endswith(".l") or name.endswith(".r")):
        return False
    name_base = name.rsplit(".", 1)[0]
    for pattern in patterns:
        if name_base.lower() == pattern.lower():
            return True
        if pattern.lower() in name.lower():
            return True
    return False


def find_skin_objects():
    """Find skin mesh objects for body shell."""
    results = []
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        name_lower = obj.name.lower()
        # Look for full-body skin mesh
        if "skin" in name_lower and not any(
            skip in name_lower
            for skip in ["muscle", "nerve", "artery", "vein", "bone"]
        ):
            if obj.name.endswith(".l") or obj.name.endswith(".r"):
                results.append(obj)
    return results


def join_objects_into_one(objects, name):
    """Join multiple objects into a single mesh using bmesh (no selection needed)."""
    if not objects:
        return None

    import mathutils

    combined = bmesh.new()

    for obj in objects:
        # Ensure mesh data is evaluated
        depsgraph = bpy.context.evaluated_depsgraph_get()
        eval_obj = obj.evaluated_get(depsgraph)
        mesh = eval_obj.to_mesh()

        # Transform vertices to world space
        temp_bm = bmesh.new()
        temp_bm.from_mesh(mesh)
        bmesh.ops.transform(temp_bm, matrix=obj.matrix_world, verts=temp_bm.verts)

        # Merge into combined
        temp_mesh = bpy.data.meshes.new(f"_temp_{obj.name}")
        temp_bm.to_mesh(temp_mesh)
        temp_bm.free()

        combined.from_mesh(temp_mesh)
        bpy.data.meshes.remove(temp_mesh)
        eval_obj.to_mesh_clear()

    # Create new object from combined mesh
    new_mesh = bpy.data.meshes.new(name)
    combined.to_mesh(new_mesh)
    combined.free()

    new_obj = bpy.data.objects.new(name, new_mesh)
    bpy.context.collection.objects.link(new_obj)

    return new_obj


def decimate_object(obj, ratio):
    """Apply decimate modifier to reduce polygon count."""
    if ratio >= 1.0:
        return

    # Ensure object is selectable and visible
    obj.hide_select = False
    obj.hide_viewport = False
    obj.hide_set(False)

    mod = obj.modifiers.new(name="Decimate", type="DECIMATE")
    mod.ratio = ratio
    mod.use_collapse_triangulate = False

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def apply_all_transforms(obj):
    """Apply location, rotation, scale transforms."""
    obj.hide_select = False
    obj.hide_viewport = False
    obj.hide_set(False)

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def create_shell_from_muscles(export_objects):
    """Create a simplified body shell by combining and smoothing all muscle meshes."""
    import mathutils

    combined = bmesh.new()
    for obj in export_objects:
        temp_bm = bmesh.new()
        temp_bm.from_mesh(obj.data)
        temp_mesh = bpy.data.meshes.new("_temp_shell")
        temp_bm.to_mesh(temp_mesh)
        temp_bm.free()
        combined.from_mesh(temp_mesh)
        bpy.data.meshes.remove(temp_mesh)

    shell_mesh = bpy.data.meshes.new("body_shell")
    combined.to_mesh(shell_mesh)
    combined.free()

    shell_obj = bpy.data.objects.new("body_shell", shell_mesh)
    bpy.context.collection.objects.link(shell_obj)
    return shell_obj


def main():
    print(f"\n{'='*60}")
    print(f"Z-Anatomy → USDZ Converter")
    print(f"Input: {INPUT_BLEND}")
    print(f"Decimate ratio: {DECIMATE_RATIO}")
    print(f"{'='*60}\n")

    # Open Z-Anatomy blend file
    bpy.ops.wm.open_mainfile(filepath=INPUT_BLEND)

    # ── Phase 1: Collect and group muscle meshes ──────────────────────
    print("Phase 1: Collecting muscle meshes...")

    export_objects = []
    total_original_faces = 0

    for group_name, patterns in MUSCLE_MAPPING.items():
        entity_name = f"muscle_{group_name}"
        matching = [
            obj for obj in bpy.data.objects if is_target_mesh(obj, patterns)
        ]

        if not matching:
            print(f"  WARNING: No meshes found for {entity_name}")
            continue

        original_faces = sum(len(o.data.polygons) for o in matching)
        total_original_faces += original_faces

        # Join all matching meshes into one object per group
        joined = join_objects_into_one(matching, entity_name)
        if joined:
            face_count = len(joined.data.polygons)
            print(f"  {entity_name}: {len(matching)} meshes → {face_count:,} faces")
            export_objects.append(joined)

    # ── Phase 2: Create body shell ────────────────────────────────────
    print("\nPhase 2: Creating body shell...")
    skin_objects = find_skin_objects()
    if skin_objects:
        shell = join_objects_into_one(skin_objects, "body_shell")
        if shell:
            shell_faces = len(shell.data.polygons)
            print(f"  body_shell from skin: {len(skin_objects)} meshes → {shell_faces:,} faces")
            export_objects.append(shell)
    else:
        print("  No skin meshes found. Creating shell from muscle envelope...")
        shell = create_shell_from_muscles(export_objects)
        if shell:
            shell_faces = len(shell.data.polygons)
            print(f"  body_shell from muscles: {shell_faces:,} faces")
            export_objects.append(shell)

    # ── Phase 3: Decimate ─────────────────────────────────────────────
    total_before = sum(len(obj.data.polygons) for obj in export_objects)

    if DECIMATE_RATIO < 1.0:
        print(f"\nPhase 3: Decimating (ratio={DECIMATE_RATIO})...")
        total_after = 0
        for obj in export_objects:
            before = len(obj.data.polygons)

            ratio = DECIMATE_RATIO
            if obj.name == "body_shell":
                ratio = DECIMATE_RATIO * 0.5

            decimate_object(obj, ratio)
            apply_all_transforms(obj)

            after = len(obj.data.polygons)
            total_after += after
            print(f"  {obj.name}: {before:,} → {after:,} faces ({after/before*100:.0f}%)")

        pct = (total_after / total_before * 100) if total_before > 0 else 0
        print(f"\n  TOTAL: {total_before:,} → {total_after:,} faces ({pct:.0f}%)")
    else:
        total_after = total_before
        print(f"\nPhase 3: Skipping decimation (ratio=1.0, {total_before:,} faces)")
        for obj in export_objects:
            apply_all_transforms(obj)

    # ── Phase 4: Center, orient, and scale ────────────────────────────
    print("\nPhase 4: Centering, orienting, and scaling...")

    import mathutils

    # Calculate bounds in world space
    min_co = [float("inf")] * 3
    max_co = [float("-inf")] * 3
    for obj in export_objects:
        for v in obj.bound_box:
            world_v = obj.matrix_world @ mathutils.Vector(v)
            for i in range(3):
                min_co[i] = min(min_co[i], world_v[i])
                max_co[i] = max(max_co[i], world_v[i])

    # Blender uses Z-up: height is along Z axis
    height = max_co[2] - min_co[2]
    target_height = 1.72  # meters
    scale_factor = target_height / height if height > 0 else 1.0

    center = [(min_co[i] + max_co[i]) / 2 for i in range(3)]

    print(f"  Bounds X: {min_co[0]:.3f} → {max_co[0]:.3f} (width: {max_co[0]-min_co[0]:.3f})")
    print(f"  Bounds Y: {min_co[1]:.3f} → {max_co[1]:.3f} (depth: {max_co[1]-min_co[1]:.3f})")
    print(f"  Bounds Z: {min_co[2]:.3f} → {max_co[2]:.3f} (height: {height:.3f})")
    print(f"  Scale factor: {scale_factor:.4f}")
    print(f"  Center offset: ({center[0]:.3f}, {center[1]:.3f}, {center[2]:.3f})")

    for obj in export_objects:
        # Center the model
        obj.location[0] = (obj.location[0] - center[0]) * scale_factor
        obj.location[1] = (obj.location[1] - center[1]) * scale_factor
        obj.location[2] = (obj.location[2] - center[2]) * scale_factor
        obj.scale = (scale_factor, scale_factor, scale_factor)

    # Apply transforms
    bpy.ops.object.select_all(action="DESELECT")
    for obj in export_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = export_objects[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Rotate 180° around Z so the body faces -Y in Blender (= +Z in USDZ = toward camera)
    print("  Rotating model 180° to face camera...")
    rot_matrix = mathutils.Matrix.Rotation(math.pi, 4, 'Z')
    for obj in export_objects:
        obj.data.transform(rot_matrix)
        obj.data.update()

    # ── Phase 5: Clean scene and export ───────────────────────────────
    print("\nPhase 5: Preparing export scene...")

    # Create a fresh scene with only our export objects
    new_scene = bpy.data.scenes.new("ExportScene")
    bpy.context.window.scene = new_scene

    # Create a new collection for export
    export_col = bpy.data.collections.new("ExportCollection")
    new_scene.collection.children.link(export_col)

    # Create parent empty
    root_empty = bpy.data.objects.new("muscle_body", None)
    export_col.objects.link(root_empty)

    # Link export objects to new collection and parent them
    for obj in export_objects:
        export_col.objects.link(obj)
        obj.parent = root_empty

    # Ensure everything is visible and selectable
    for obj in export_col.objects:
        obj.hide_viewport = False
        obj.hide_select = False
        obj.hide_render = False

    print(f"  Export scene: {len(export_objects)} muscle groups + root empty")

    # ── Phase 6: Export USDZ ──────────────────────────────────────────
    print("\nPhase 6: Exporting USDZ...")

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output_path = os.path.join(OUTPUT_DIR, "muscle_body.usdz")

    # Select all export objects
    bpy.ops.object.select_all(action="DESELECT")
    for obj in export_col.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root_empty

    bpy.ops.wm.usd_export(
        filepath=output_path,
        selected_objects_only=True,
        export_textures_mode="KEEP",
        export_materials=True,
        export_mesh_colors=False,
        export_normals=True,
        generate_preview_surface=True,
        root_prim_path="/muscle_body",
    )

    file_size = os.path.getsize(output_path)
    print(f"\n{'='*60}")
    print(f"SUCCESS: {output_path}")
    print(f"File size: {file_size / 1024:.1f} KB ({file_size / 1024 / 1024:.1f} MB)")
    print(f"Objects: {len(export_objects)}")
    print(f"Total faces: {total_after:,}")
    print(f"{'='*60}")

    # Summary
    print("\nEntity hierarchy:")
    print("  /muscle_body")
    for obj in sorted(export_objects, key=lambda o: o.name):
        faces = len(obj.data.polygons)
        print(f"    /{obj.name} ({faces:,} faces)")


if __name__ == "__main__":
    main()
