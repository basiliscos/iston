#version 120

// input

varying vec2 f_texcoord;
varying vec3 normal;

uniform sampler2D mytexture;
uniform int has_texture;
uniform int has_lighting;

// structures

struct lightSource
{
  vec4 position;
  vec4 diffuse;
};

struct material
{
  vec4 diffuse;
};

// defaults

lightSource light1 = lightSource(
  vec4(20, 5, 20, 0),
  vec4(0.8, 0.8, 0.8, 0)
);

material frontMaterial = material(
  vec4(0.8, 0.8, 0.8, 0)
);

uniform vec4 default_color = vec4(0.8, 0.8, 0.8, 1);

// functions

vec4 compute_color(vec4 initial_color) {
  if(has_lighting == 0) return initial_color;
  vec4 light_dir = normalize(light1.position);
  vec3 light_dir3 = vec3(light_dir.x, light_dir.y, light_dir.z);
  float intensity = max(dot(normal, light_dir3), 0);
  vec4 diffuse = frontMaterial.diffuse * light1.diffuse;
  vec4 result = intensity * diffuse * initial_color;
  return result;
}

//main

void main(void) {
  vec4 color;
  if(has_texture > 0) {
    color = texture2D(mytexture, f_texcoord);
  } else {
    color = default_color;
  }
  gl_FragColor = compute_color(color);
}
