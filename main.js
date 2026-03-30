const SHADER_PATH = './Shaders0980/blackhole.glsl';

document.getElementById('shader-name').textContent = SHADER_PATH;

const canvas = document.getElementById('gl');
const gl = canvas.getContext('webgl2');
if (!gl) {
  throw new Error('WebGL2 is required to run this renderer.');
}

const BLACK_HOLE_DEFINES = [
  '#define ACCR_DISK',
];

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
};

function extractShaderStage(source, vertexStage) {
  const lines = source.split(/\r?\n/);
  const begin = lines.findIndex((line) => line.trim() === '#ifdef _VERTEX_');
  if (begin === -1) {
    throw new Error('Combined shader is missing #ifdef _VERTEX_ section.');
  }

  let depth = 0;
  let elseAt = -1;
  let end = -1;

  for (let i = begin; i < lines.length; i += 1) {
    const line = lines[i].trim();
    if (/^#if(n?def)?\b/.test(line)) {
      depth += 1;
      continue;
    }
    if (line === '#else' && depth === 1) {
      elseAt = i;
      continue;
    }
    if (line === '#endif') {
      depth -= 1;
      if (depth === 0) {
        end = i;
        break;
      }
    }
  }

  if (elseAt === -1 || end === -1) {
    throw new Error('Failed to parse _VERTEX_ block boundaries.');
  }

  const section = vertexStage
    ? lines.slice(begin + 1, elseAt)
    : lines.slice(elseAt + 1, end);

  return section.join('\n');
}

function convertCombinedShaderToWebGL(source, vertexStage) {
  const shader = extractShaderStage(source, vertexStage)
    .replace('uniform sampler1D   PlanckFunction;', 'uniform sampler2D   PlanckFunction;')
    .replace(
      'vec3 emissColor = texture(PlanckFunction, log(temp * 0.001 + tempShift) * 0.188 + 0.1316).rgb * fadeEmiss * diskBright;',
      'vec3 emissColor = texture(PlanckFunction, vec2(log(temp * 0.001 + tempShift) * 0.188 + 0.1316, 0.5)).rgb * fadeEmiss * diskBright;',
    )
    .replace(
      'vec3 emissColor = texture(PlanckFunction, log(temp * 0.001 + tempShift) * 0.188 + 0.1316).rgb * starBright;',
      'vec3 emissColor = texture(PlanckFunction, vec2(log(temp * 0.001 + tempShift) * 0.188 + 0.1316, 0.5)).rgb * starBright;',
    );

  return [
    '#version 300 es',
    'precision highp float;',
    'precision highp int;',
    ...BLACK_HOLE_DEFINES,
    shader,
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

function createQuadData() {
  return {
    vertices: new Float32Array([
      -1, -1, 0, 0, 0, 1, 0, 0,
      1, -1, 0, 1, 0, 1, 0, 0,
      1, 1, 0, 1, 1, 1, 0, 0,
      -1, 1, 0, 0, 1, 1, 0, 0,
    ]),
    indices: new Uint16Array([0, 1, 2, 0, 2, 3]),
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

function createNoiseTexture(glCtx) {
  const size = 16;
  const data = new Uint8Array(size * size * 2);
  for (let i = 0; i < data.length; i += 1) {
    data[i] = Math.floor(Math.random() * 256);
  }

  const tex = glCtx.createTexture();
  glCtx.bindTexture(glCtx.TEXTURE_2D, tex);
  glCtx.texImage2D(glCtx.TEXTURE_2D, 0, glCtx.RG8, size, size, 0, glCtx.RG, glCtx.UNSIGNED_BYTE, data);
  glCtx.texParameteri(glCtx.TEXTURE_2D, glCtx.TEXTURE_MIN_FILTER, glCtx.LINEAR);
  glCtx.texParameteri(glCtx.TEXTURE_2D, glCtx.TEXTURE_MAG_FILTER, glCtx.LINEAR);
  glCtx.texParameteri(glCtx.TEXTURE_2D, glCtx.TEXTURE_WRAP_S, glCtx.REPEAT);
  glCtx.texParameteri(glCtx.TEXTURE_2D, glCtx.TEXTURE_WRAP_T, glCtx.REPEAT);
  return tex;
}

function createPlanckTexture(glCtx) {
  const width = 256;
  const data = new Uint8Array(width * 4);
  for (let x = 0; x < width; x += 1) {
    const t = x / (width - 1);
    const r = Math.pow(t, 0.6);
    const g = Math.pow(t, 1.1);
    const b = Math.pow(t, 2.2);
    data[x * 4 + 0] = Math.min(255, Math.floor(255 * (0.6 + 0.4 * r)));
    data[x * 4 + 1] = Math.min(255, Math.floor(255 * g));
    data[x * 4 + 2] = Math.min(255, Math.floor(255 * b));
    data[x * 4 + 3] = 255;
  }

  const tex = glCtx.createTexture();
  glCtx.bindTexture(glCtx.TEXTURE_2D, tex);
  glCtx.texImage2D(glCtx.TEXTURE_2D, 0, glCtx.RGBA8, width, 1, 0, glCtx.RGBA, glCtx.UNSIGNED_BYTE, data);
  glCtx.texParameteri(glCtx.TEXTURE_2D, glCtx.TEXTURE_MIN_FILTER, glCtx.LINEAR);
  glCtx.texParameteri(glCtx.TEXTURE_2D, glCtx.TEXTURE_MAG_FILTER, glCtx.LINEAR);
  glCtx.texParameteri(glCtx.TEXTURE_2D, glCtx.TEXTURE_WRAP_S, glCtx.CLAMP_TO_EDGE);
  glCtx.texParameteri(glCtx.TEXTURE_2D, glCtx.TEXTURE_WRAP_T, glCtx.CLAMP_TO_EDGE);
  return tex;
}

function createFrameTexture(glCtx) {
  const width = 512;
  const height = 256;
  const data = new Uint8Array(width * height * 4);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const i = (y * width + x) * 4;
      const sx = (x / width) * 2 - 1;
      const sy = (y / height) * 2 - 1;
      const radial = Math.max(0, 1 - Math.sqrt(sx * sx + sy * sy));
      const starChance = Math.random();
      const star = starChance > 0.9975 ? 1 : 0;
      data[i + 0] = Math.floor(8 + 30 * radial + 220 * star);
      data[i + 1] = Math.floor(12 + 45 * radial + 210 * star);
      data[i + 2] = Math.floor(24 + 80 * radial + 255 * star);
      data[i + 3] = 255;
    }
  }

  const tex = glCtx.createTexture();
  glCtx.bindTexture(glCtx.TEXTURE_2D, tex);
  glCtx.texImage2D(glCtx.TEXTURE_2D, 0, glCtx.RGBA8, width, height, 0, glCtx.RGBA, glCtx.UNSIGNED_BYTE, data);
  glCtx.texParameteri(glCtx.TEXTURE_2D, glCtx.TEXTURE_MIN_FILTER, glCtx.LINEAR);
  glCtx.texParameteri(glCtx.TEXTURE_2D, glCtx.TEXTURE_MAG_FILTER, glCtx.LINEAR);
  glCtx.texParameteri(glCtx.TEXTURE_2D, glCtx.TEXTURE_WRAP_S, glCtx.REPEAT);
  glCtx.texParameteri(glCtx.TEXTURE_2D, glCtx.TEXTURE_WRAP_T, glCtx.CLAMP_TO_EDGE);
  return tex;
}

async function main() {
  const shaderSource = await fetch(SHADER_PATH).then((r) => r.text());
  const vertexSource = convertCombinedShaderToWebGL(shaderSource, true);
  const fragmentSource = convertCombinedShaderToWebGL(shaderSource, false);

  const program = createProgram(gl, vertexSource, fragmentSource);

  const mvpLocation = gl.getUniformLocation(program, 'MVP');
  const eyePosLocation = gl.getUniformLocation(program, 'EyePos');
  const paramsLocation = gl.getUniformLocation(program, 'Params');
  const radiusesLocation = gl.getUniformLocation(program, 'Radiuses');
  const diskParams1Location = gl.getUniformLocation(program, 'DiskParams1');
  const diskParams2Location = gl.getUniformLocation(program, 'DiskParams2');
  const starParamsLocation = gl.getUniformLocation(program, 'StarParams');
  const frameLocation = gl.getUniformLocation(program, 'Frame');
  const noiseTexLocation = gl.getUniformLocation(program, 'NoiseTex');
  const planckFunctionLocation = gl.getUniformLocation(program, 'PlanckFunction');

  const { vertices, indices } = createQuadData();
  const vao = gl.createVertexArray();
  const vbo = gl.createBuffer();
  const ibo = gl.createBuffer();

  gl.bindVertexArray(vao);
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
  gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);
  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
  gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices, gl.STATIC_DRAW);

  const stride = 8 * 4;
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 3, gl.FLOAT, false, stride, 0);
  gl.enableVertexAttribArray(1);
  gl.vertexAttribPointer(1, 2, gl.FLOAT, false, stride, 3 * 4);
  gl.enableVertexAttribArray(2);
  gl.vertexAttribPointer(2, 3, gl.FLOAT, false, stride, 5 * 4);

  const frameTex = createFrameTexture(gl);
  const noiseTex = createNoiseTexture(gl);
  const planckTex = createPlanckTexture(gl);

  gl.disable(gl.DEPTH_TEST);

  function render(timeMs) {
    resizeCanvasToDisplaySize();

    const t = timeMs * 0.001;
    const projection = mat4.perspective(Math.PI / 2.8, canvas.width / canvas.height, 0.05, 30);

    gl.clearColor(0.01, 0.01, 0.02, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);

    gl.useProgram(program);
    gl.uniformMatrix4fv(mvpLocation, false, new Float32Array(projection));

    const eyeDistance = 6.5;
    gl.uniform4f(eyePosLocation, 0.0, 0.0, eyeDistance, eyeDistance);
    gl.uniform4f(paramsLocation, canvas.width, canvas.height, 1.0, 0.0);
    gl.uniform4f(radiusesLocation, 1.8, 4.0, 1.0, 1.0);
    gl.uniform4f(diskParams1Location, 6800.0, 4.5, t * 0.1, t * 0.2);
    gl.uniform4f(diskParams2Location, 0.08, 1.5, 1.2, t * 0.03);
    gl.uniform4f(starParamsLocation, 6500.0, 1.6, 0.08, 0.9);

    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, frameTex);
    gl.uniform1i(frameLocation, 0);

    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, noiseTex);
    gl.uniform1i(noiseTexLocation, 1);

    gl.activeTexture(gl.TEXTURE2);
    gl.bindTexture(gl.TEXTURE_2D, planckTex);
    gl.uniform1i(planckFunctionLocation, 2);

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
