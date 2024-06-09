shader_type canvas_item;

void fragment() {
	vec4 tex = texture(TEXTURE,UV);
	
	if (tex.a > 0.5){
		COLOR.a = 1.0;
	}else{
		COLOR.a = 0.0;
		}
	
	
}

