#version 120

varying vec2 f_texcoord;
varying vec3 normal;

uniform sampler2D mytexture;
uniform int has_texture;
uniform int has_lighting;

struct lightSource
{
  vec4 position;
};

lightSource light1 = lightSource(
  vec4(20, 5, 20, 0)
);

uniform vec4 default_color = vec4(0.8, 0.8, 0.8, 1);

float get_intensity(void) {
  if(has_lighting == 0) return 1.0;
  vec4 light_dir = normalize(light1.position);
  vec4 N4 = normalize ( vec4(normal, 0) );
  float intensity = dot(N4, light_dir);
  return intensity;
}

void main(void) {
  vec4 color;
  float intensity = get_intensity();

  if(has_texture > 0) {
    color = texture2D(mytexture, f_texcoord);
  } else {
    color = default_color;
  }
  gl_FragColor = color * intensity;
}
