#version 120

varying vec2 f_texcoord;
varying vec3 normal;

uniform sampler2D mytexture;
uniform int has_texture;
uniform int has_lighting;

uniform vec4 default_color = vec4(0.8, 0.8, 0.8, 1);
uniform vec3 light_position = vec3(20, 5, 20);

float get_intensity(void) {
     if(has_lighting == 0) return 1.0;
     vec4 light_dir4 = vec4( normalize(light_position), 0 );
     // light direction is model independent
     vec4 N4 = normalize ( vec4(normal, 0) );
     float intensity = dot(N4, light_dir4);
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
