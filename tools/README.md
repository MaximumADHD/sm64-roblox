# Tools

These are some janky unmodified scripts I wrote to help me automate the process of extracting, importing, retargeting, and uploading mario's animations for an R15 Roblox rig. Some of these scripts **require elevated studio permissions (i.e. Roblox Internal)** to use without errors. How you choose to get access to that is at your discretion, but I'm not supposed to publicly disclose any strategies lol.

I utilized the fast64 blender plugin for the python scripts and as a baseline for extracting mario's animations:
https://github.com/Fast-64/fast64

I originally had a functional visualization of the SM64 mario rig in the `AnimRetarget.rbxl` place file, but stripped the meshes and textures to avoid any trouble with Nintendo. I also nuked any KeyframeSequences I had imported into the ServerStorage's AnimSaves folder. You'll have to figure out how to import those yourself :)