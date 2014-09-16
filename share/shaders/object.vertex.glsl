// #version 130
attribute vec3 coord3d;
attribute vec2 texcoord;
varying vec2 f_texcoord;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;


void main(void) {
  mat4 mvp = projection * view * model;
  gl_Position = mvp * vec4(coord3d, 1.0);
  f_texcoord = texcoord;
}
