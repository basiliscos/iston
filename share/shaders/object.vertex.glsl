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
  vec3 my_coord = vec3(coord3d);
  //my_coord.z = my_coord.z * 0.5;
  //my_coord.x = sin(5.0* my_coord.x )*0.25;
  //my_coord.z = abs(sin(my_coord.z)) * my_coord.x;
  //my_coord.z = my_coord.z + sin(my_coord.x);
  //my_coord.z = my_coord.z + N.z;

  gl_Position = mvp * vec4(my_coord, 1.0);
  f_texcoord = texcoord;
  normal = N;
}
