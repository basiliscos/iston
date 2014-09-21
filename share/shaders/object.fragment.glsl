#version 120

varying vec2 f_texcoord;
varying float intensity;

uniform sampler2D mytexture;
uniform int has_texture;

uniform vec4 default_color = vec4(0.8, 0.8, 0.8, 1);

void main(void) {
     vec4 color;
     if(has_texture > 0) {
             color = texture2D(mytexture, f_texcoord);
     } else {
             color = default_color;
     }
     gl_FragColor = color * intensity;
}
