extends MultiMeshInstance2D

const SHADER_CODE="""shader_type canvas_item;
render_mode unshaded;
uniform bool unit_outline = false;
varying vec4 atlas_region;
varying vec4 instance_tint;
void vertex() {
    atlas_region = INSTANCE_CUSTOM;
    instance_tint = COLOR;
}
void fragment() {
    vec2 uv = atlas_region.xy + vec2(UV.x, 1.0 - UV.y) * atlas_region.zw;
    vec4 texel = texture(TEXTURE, uv);
    if (unit_outline) {
        vec2 step_uv = TEXTURE_PIXEL_SIZE * 2.0;
        vec2 lo = atlas_region.xy + TEXTURE_PIXEL_SIZE;
        vec2 hi = atlas_region.xy + atlas_region.zw - TEXTURE_PIXEL_SIZE;
        float edge = texture(TEXTURE, clamp(uv + vec2(step_uv.x, 0.0), lo, hi)).a;
        edge = max(edge, texture(TEXTURE, clamp(uv - vec2(step_uv.x, 0.0), lo, hi)).a);
        edge = max(edge, texture(TEXTURE, clamp(uv + vec2(0.0, step_uv.y), lo, hi)).a);
        edge = max(edge, texture(TEXTURE, clamp(uv - vec2(0.0, step_uv.y), lo, hi)).a);
        vec3 body = texel.rgb * 1.15 + instance_tint.rgb * 0.06;
        COLOR = vec4(mix(instance_tint.rgb, body, smoothstep(0.1, 0.85, texel.a)), max(texel.a, edge * 0.85));
    } else {
        COLOR = vec4(texel.rgb * instance_tint.rgb, texel.a * instance_tint.a);
    }
}
"""
var used=0

func configure(atlas: Texture2D,capacity: int,outline: bool=false):
	texture=atlas
	var quad=QuadMesh.new(); quad.size=Vector2.ONE
	multimesh=MultiMesh.new(); multimesh.transform_format=MultiMesh.TRANSFORM_2D
	multimesh.use_colors=true; multimesh.use_custom_data=true; multimesh.mesh=quad
	multimesh.instance_count=capacity; multimesh.visible_instance_count=0
	var shader=Shader.new(); shader.code=SHADER_CODE
	var mat=ShaderMaterial.new(); mat.shader=shader; material=mat
	mat.set_shader_parameter("unit_outline",outline)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR

func begin(): used=0

func put(p: Vector2,size: Vector2,uv: Rect2,tint: Color=Color.WHITE):
	if used>=multimesh.instance_count: return
	multimesh.set_instance_transform_2d(used,Transform2D(0,size,0,p))
	multimesh.set_instance_custom_data(used,Color(uv.position.x,uv.position.y,uv.size.x,uv.size.y))
	multimesh.set_instance_color(used,tint)
	used+=1

func finish(): multimesh.visible_instance_count=used
