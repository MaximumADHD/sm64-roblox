import bpy
import sys
import time

from fast64.fast64_internal.sm64 import *
argv = sys.argv

try:
    index = argv.index("--") + 1
except ValueError:
    index = len(argv)

argv = argv[index:]

offset = argv[0]
name = argv[1]

romfileSrc = open("sm64.z64", 'rb')
mario_geo = bpy.data.objects['mario_geo']

levelParsed = sm64_level_parser.parseLevelAtPointer(romfileSrc, sm64_level_parser.level_pointers[bpy.context.scene.levelAnimImport])
segmentData = levelParsed.segmentData

animStart = int(offset, 16)
sm64_anim.importAnimationToBlender(romfileSrc, animStart, mario_geo, segmentData, True)

bpy.ops.export_scene.fbx(filepath="C:/Users/clone/Desktop/MarioAnims/" + name + ".fbx", add_leaf_bones=False, global_scale=3)
mario_geo.animation_data_clear()

print("Exported: " + name)
romfileSrc.close()

bpy.ops.wm.quit_blender()