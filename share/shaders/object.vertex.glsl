#version 120

attribute vec3 coord3d;
attribute vec3 N;
attribute vec2 texcoord;

varying vec2 f_texcoord;
varying vec3 normal;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main(void) {
  mat4 mvp = projection * view * model;

  gl_Position = mvp * vec4(coord3d, 1.0);
  f_texcoord = texcoord;

  // move normal from object space into world space
  vec4 my_normal = transpose (inverse( view * model)) * vec4(N, 0);
  normal = normalize(vec3(my_normal.x, my_normal.y, my_normal.z));
}
