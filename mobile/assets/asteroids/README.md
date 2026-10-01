# Asteroid artwork

`ore-atlas.png` is the original generated 1536×1024 atlas, arranged in six 512×512 cells: cyan ice, ash crystals, magma, fractured olive rock, scorched blue rock, and a second ash boulder. It was made with the built-in image-generation tool from the user's five asteroid references. The generation brief and final background-preparation prompt are in `ore-atlas.prompt.txt`.

The green canvas is a production key, not an in-game background. `asteroid_ore.gdshader` removes it and unmattes filtered edges while rendering, leaving the source image unchanged. Import mipmaps and use linear mipmap filtering to keep fine texture stable at gameplay size. The shader adds restrained reflections, heat movement, hit flashes and damage shading.

`asteroid.gd` selects ore from a stable spawn seed independently of size. A fragment inherits its parent's material; the two ash silhouettes provide variation. Artwork is scaled around the existing collision radius, so detailed art does not change durability, hit detection, splitting or rewards. The original generated drafts remain outside the project; the consumed atlas is stored here and committed.
