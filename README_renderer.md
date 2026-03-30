# GLSL 3D Renderer (Shaders0980)

This repository now includes a minimal WebGL2 renderer that consumes a **combined** SpaceEngine shader file from `Shaders0980` and renders a rotating 3D cube.

## Source shader used

- `Shaders0980/prim_fill_obj.glsl`

The loader in `main.js` handles this file format by:

1. Removing `#auto_defines`.
2. Splitting the `_VERTEX_` and fragment branches.
3. Converting GLSL `#version 330 core` to WebGL2-compatible `#version 300 es`.

## Run

From the repository root:

```bash
python3 -m http.server 8080
```

Then open:

- <http://localhost:8080/index.html>

