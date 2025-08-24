shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 grey_color : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform bool show_grey_above = true;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    if (tex_color.a > 0.0) {
        float fill_line = 1.0 - UV.y;

        if (show_grey_above) {
            if (fill_line > progress) {
                vec3 grey = vec3(dot(tex_color.rgb, vec3(0.299, 0.587, 0.114)));
                COLOR = vec4(grey * grey_color.rgb, tex_color.a);
            } else {
                COLOR = tex_color;
            }
        } else {
            if (fill_line > progress) {
                COLOR = tex_color;
            } else {
                vec4 tint = vec4(0.0, 0.8, 0.0, 0.5);
                COLOR = mix(tex_color, tint, 0.5);
            }
        }
    } else {
        COLOR = tex_color;
    }
}