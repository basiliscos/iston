#version 120

attribute vec3 coord3d;
attribute vec3 N;
attribute vec2 texcoord;

varying vec2 f_texcoord;
varying float intensity;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

uniform vec3 light_position = vec3(20, 5, 20);

void main(void) {
  mat4 mvp = projection * view * model;
  vec3 my_coord = vec3(coord3d);
  //my_coord.z = my_coord.z * 0.5;
  //my_coord.x = sin(5.0* my_coord.x )*0.25;
  //my_coord.z = abs(sin(my_coord.z)) * my_coord.x;
  //my_coord.z = my_coord.z + sin(my_coord.x);
  //my_coord.z = my_coord.z + N.z;

  vec4 lp4 = vec4(light_position, 0);
  // light direction is model independent
  vec4 light_dir4 = normalize( lp4 * model);
  vec4 N4 = vec4(N, 0);
  intensity = dot( N4, light_dir4);

  gl_Position = mvp * vec4(my_coord, 1.0);
  f_texcoord = texcoord;
}
