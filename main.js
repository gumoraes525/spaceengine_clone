const SHADER_PATH = './Shaders0980/prim_fill_obj.glsl';

document.getElementById('shader-name').textContent = SHADER_PATH;

const canvas = document.getElementById('gl');
const gl = canvas.getContext('webgl2');
if (!gl) {
  throw new Error('WebGL2 is required to run this renderer.');
}

const mat4 = {
  perspective(fovY, aspect, near, far) {
    const f = 1.0 / Math.tan(fovY / 2);
    const nf = 1 / (near - far);
    return [
      f / aspect, 0, 0, 0,
      0, f, 0, 0,
      0, 0, (far + near) * nf, -1,
      0, 0, (2 * far * near) * nf, 0,
    ];
  },
  multiply(a, b) {
    const out = new Array(16).fill(0);
    for (let r = 0; r < 4; r += 1) {
      for (let c = 0; c < 4; c += 1) {
        for (let k = 0; k < 4; k += 1) {
          out[r * 4 + c] += a[r * 4 + k] * b[k * 4 + c];
        }
      }
    }
    return out;
  },
  rotationY(rad) {
    const c = Math.cos(rad);
    const s = Math.sin(rad);
    return [
      c, 0, s, 0,
      0, 1, 0, 0,
      -s, 0, c, 0,
      0, 0, 0, 1,
    ];
  },
  translation(x, y, z) {
    return [
      1, 0, 0, 0,
      0, 1, 0, 0,
      0, 0, 1, 0,
      x, y, z, 1,
    ];
  },
};

function convertCombinedShaderToWebGL(source, vertexStage) {
  const lines = source.split(/\r?\n/);
  const macros = {
    _VERTEX_: vertexStage,
    UNIFORM_VERTEXES: false,
  };

  const includeStack = [true];
  const result = [];

  for (const rawLine of lines) {
    const line = rawLine.trim();

    if (line.startsWith('#version')) {
      continue;
    }
    if (line === '#auto_defines') {
      continue;
    }

    const ifdefMatch = line.match(/^#ifdef\s+(\w+)/);
    if (ifdefMatch) {
      const key = ifdefMatch[1];
      includeStack.push(includeStack[includeStack.length - 1] && Boolean(macros[key]));
      continue;
    }

    const ifndefMatch = line.match(/^#ifndef\s+(\w+)/);
    if (ifndefMatch) {
      const key = ifndefMatch[1];
      includeStack.push(includeStack[includeStack.length - 1] && !Boolean(macros[key]));
      continue;
    }

    if (line === '#else') {
      const old = includeStack.pop();
      const parent = includeStack[includeStack.length - 1];
      includeStack.push(parent && !old);
      continue;
    }

    if (line === '#endif') {
      includeStack.pop();
      continue;
    }

    if (includeStack[includeStack.length - 1]) {
      result.push(rawLine);
    }
  }

  return [
    '#version 300 es',
    'precision highp float;',
    'precision highp int;',
    ...result,
  ].join('\n');
}

function compileShader(glCtx, type, source) {
  const shader = glCtx.createShader(type);
  glCtx.shaderSource(shader, source);
  glCtx.compileShader(shader);
  if (!glCtx.getShaderParameter(shader, glCtx.COMPILE_STATUS)) {
    const log = glCtx.getShaderInfoLog(shader);
    glCtx.deleteShader(shader);
    throw new Error(`Shader compile error:\n${log}\n\nSource:\n${source}`);
  }
  return shader;
}

function createProgram(glCtx, vertexSource, fragmentSource) {
  const program = glCtx.createProgram();
  const vs = compileShader(glCtx, glCtx.VERTEX_SHADER, vertexSource);
  const fs = compileShader(glCtx, glCtx.FRAGMENT_SHADER, fragmentSource);

  glCtx.attachShader(program, vs);
  glCtx.attachShader(program, fs);
  glCtx.linkProgram(program);

  if (!glCtx.getProgramParameter(program, glCtx.LINK_STATUS)) {
    throw new Error(`Program link error: ${glCtx.getProgramInfoLog(program)}`);
  }

  glCtx.deleteShader(vs);
  glCtx.deleteShader(fs);
  return program;
}

function createCubeData() {
  const corners = [
    [-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1],
    [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1],
  ];

  const faces = [
    [0, 1, 2, 3],
    [4, 5, 6, 7],
    [0, 4, 7, 3],
    [1, 5, 6, 2],
    [3, 2, 6, 7],
    [0, 1, 5, 4],
  ];

  const indices = [];
  const vertices = [];

  for (const face of faces) {
    const [a, b, c, d] = face;
    const faceVerts = [corners[a], corners[b], corners[c], corners[d]];

    for (const [x, y, z] of faceVerts) {
      vertices.push(
        x, y, z, 1,
        0, 0, 0, 0,
        0, 1, 0, 0,
      );
    }

    const base = (vertices.length / 12) - 4;
    indices.push(base, base + 1, base + 2, base, base + 2, base + 3);
  }

  return {
    vertices: new Float32Array(vertices),
    indices: new Uint16Array(indices),
  };
}

function resizeCanvasToDisplaySize() {
  const dpr = window.devicePixelRatio || 1;
  const width = Math.floor(canvas.clientWidth * dpr);
  const height = Math.floor(canvas.clientHeight * dpr);
  if (canvas.width !== width || canvas.height !== height) {
    canvas.width = width;
    canvas.height = height;
    gl.viewport(0, 0, width, height);
  }
}

async function main() {
  const shaderSource = await fetch(SHADER_PATH).then((r) => r.text());
  const vertexSource = convertCombinedShaderToWebGL(shaderSource, true);
  const fragmentSource = convertCombinedShaderToWebGL(shaderSource, false);

  const program = createProgram(gl, vertexSource, fragmentSource);
  const mvpLocation = gl.getUniformLocation(program, 'Mvp');
  const colorLocation = gl.getUniformLocation(program, 'Color');

  const { vertices, indices } = createCubeData();
  const vao = gl.createVertexArray();
  const vbo = gl.createBuffer();
  const ibo = gl.createBuffer();

  gl.bindVertexArray(vao);

  gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
  gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);

  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
  gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices, gl.STATIC_DRAW);

  const stride = 12 * 4;
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 4, gl.FLOAT, false, stride, 0);
  gl.enableVertexAttribArray(1);
  gl.vertexAttribPointer(1, 4, gl.FLOAT, false, stride, 4 * 4);
  gl.enableVertexAttribArray(2);
  gl.vertexAttribPointer(2, 4, gl.FLOAT, false, stride, 8 * 4);

  gl.enable(gl.DEPTH_TEST);

  function render(timeMs) {
    resizeCanvasToDisplaySize();

    const t = timeMs * 0.001;
    const projection = mat4.perspective(Math.PI / 3, canvas.width / canvas.height, 0.1, 100);
    const view = mat4.translation(0, 0, -4);
    const model = mat4.rotationY(t);
    const mvp = mat4.multiply(mat4.multiply(model, view), projection);

    gl.clearColor(0.03, 0.04, 0.08, 1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    gl.useProgram(program);
    gl.uniformMatrix4fv(mvpLocation, false, new Float32Array(mvp));
    gl.uniform4f(colorLocation, 0.35 + 0.35 * Math.sin(t), 0.7, 1.0, 1.0);

    gl.bindVertexArray(vao);
    gl.drawElements(gl.TRIANGLES, indices.length, gl.UNSIGNED_SHORT, 0);

    requestAnimationFrame(render);
  }

  requestAnimationFrame(render);
}

main().catch((err) => {
  const hud = document.getElementById('hud');
  hud.textContent = err.message;
  console.error(err);
});
