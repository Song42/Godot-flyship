shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

void vertex() {
	// Preserve particle scale while facing the active camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz),0,0,0), vec4(0,length(MODEL_MATRIX[1].xyz),0,0), vec4(0,0,length(MODEL_MATRIX[2].xyz),0), vec4(0,0,0,1));
}
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float soft = pow(max(0.0, 1.0 - r*r), 2.0);
	ALBEDO = COLOR.rgb;
	ALPHA = soft * COLOR.a;
}
