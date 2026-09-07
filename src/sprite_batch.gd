extends MultiMeshInstance2D

const SHADER_CODE="""shader_type canvas_item;
render_mode unshaded;
varying vec4 atlas_region;
varying vec4 instance_tint;
void vertex() {
    atlas_region = INSTANCE_CUSTOM;
    instance_tint = COLOR;
}
void fragment() {
    vec4 texel = texture(TEXTURE, atlas_region.xy + vec2(UV.x, 1.0 - UV.y) * atlas_region.zw);
    COLOR = vec4(texel.rgb * instance_tint.rgb, texel.a * instance_tint.a);
}
"""
var used=0

func configure(atlas: Texture2D,capacity: int):
	texture=atlas
	var quad=QuadMesh.new(); quad.size=Vector2.ONE
	multimesh=MultiMesh.new(); multimesh.transform_format=MultiMesh.TRANSFORM_2D
	multimesh.use_colors=true; multimesh.use_custom_data=true; multimesh.mesh=quad
	multimesh.instance_count=capacity; multimesh.visible_instance_count=0
	var shader=Shader.new(); shader.code=SHADER_CODE
	var mat=ShaderMaterial.new(); mat.shader=shader; material=mat
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR

func begin(): used=0

func put(p: Vector2,size: Vector2,uv: Rect2,tint: Color=Color.WHITE):
	if used>=multimesh.instance_count: return
	multimesh.set_instance_transform_2d(used,Transform2D(0,size,0,p))
	multimesh.set_instance_custom_data(used,Color(uv.position.x,uv.position.y,uv.size.x,uv.size.y))
	multimesh.set_instance_color(used,tint)
	used+=1

func finish(): multimesh.visible_instance_count=used
