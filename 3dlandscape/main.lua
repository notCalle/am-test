local win = am.window{
    title = "3D landscape",
    clear_color = vec4(0.3, 0.5, 0.7, 1.0),
    width = 1920,
    height = 1080,
    depth_buffer = true,
    msaa_samples = 2
}
local near_clip = 0.1
local far_clip = 101
local map_size = 500

local shader = am.program([[
precision mediump float;
attribute vec3 vert;
attribute vec3 normal;
attribute vec3 color;
uniform mat4 MV;
uniform mat4 P;
uniform float water_y;
uniform vec3 camera;
varying vec3 v_color;

void main() {
    float dist = distance(vert, camera);
    vec3 light = normalize((MV * vec4(0.1, 0.1, 1.0, 0.0)).xyz);
    vec3 nm = normalize((MV * vec4(normal, 0.0)).xyz);
    vec3 c = mix(vec3(0.1, 0.1, 0.2), color, 0.5 + 0.5 * dot(light, nm));
    vec3 c2 = mix(c, vec3(0.0, 0.25, 0.5), clamp(water_y - vert.y, 0.0, 0.9));
    v_color = mix(c2, vec3(0.3, 0.5, 0.7), clamp(dist/100.0, 0.0, 1.0));
    gl_Position = P * MV * vec4(vert, 1.0);
}
]],[[
precision mediump float;
varying vec3 v_color;
void main() {
    gl_FragColor = vec4(v_color, 1.0);
}
]])

local
function corner3(pos2)
    local soil = math.simplex(pos2/100)*3
    local rock = (math.simplex(-pos2/20)^3)*10+(math.simplex(pos2)^5)*2
    local color =
        rock > 6 and vec3(1.0)
        or rock >= soil-0.5 and vec3(0.5, 0.5, 0.5)
        or soil < 0.1 and vec3(1.0, 1.0, 0.5)
        or vec3(0.3, 1.0, 0.5)

    return {
        vert = vec3(pos2.x, math.max(rock, soil), pos2.y),
        color = color
    }
end

local map = {}

function map:init(size)
    self.size = size
    self.offset = vec2(size/2)
    for x = 1, size do
        for y = 1, size do
            self[x * size + y] = corner3(vec2(x, y)-self.offset)
        end
    end
end

function map:get(pos2)
    local p = pos2 + self.offset
    return self[p.x * self.size + p.y]
end

local
function normal(v1, v2, v3)
    return math.cross(v2-v1, v3-v2)
end

local
function tile(pos2)
    local c = {}
    c[1] = map:get(pos2)
    c[2] = map:get(pos2 + vec2(0, 1))
    c[3] = map:get(pos2 + vec2(1, 1))
    c[4] = map:get(pos2 + vec2(1, 0))
    c[5] = c[1]
    local c0vert = (c[1].vert + c[2].vert + c[3].vert + c[4].vert) / 4
    local c0color = (c[1].color + c[2].color + c[3].color + c[4].color) / 4

    local vts = {}
    local nms = {}
    local cols = {}
    for v = 1, 4 do
        table.append(vts, { c0vert, c[v].vert, c[v+1].vert })
        table.append(nms, { normal(c0vert, c[v].vert, c[v+1].vert),
                            normal(c[v].vert, c[v+1].vert, c0vert),
                            normal(c[v+1].vert, c0vert, c[v].vert) })
        table.append(cols, { c0color, c[v].color, c[v+1].color })
    end

    return vts, nms, cols
end

local verts, normals, colors

local
function update(node)
    verts = {}
    normals = {}
    colors = {}
    for x = -200, 200, 1 do
        for y = -200, 200, 1 do
            local vts, nms, cols = tile(vec2(x, y))
            table.append(verts, vts)
            table.append(normals, nms)
            table.append(colors, cols)
        end
    end
    if node then
        node.vert = am.vec3_array(verts)
        node.normal = am.vec3_array(normals)
        node.color = am.vec3_array(colors)
    end
end

map:init(map_size)
update()

local camera = am.lookat(vec3(-100, 10, -100), vec3(0, 0, 0), vec3(0, 1, 0))
    ^am.bind{
        P = math.perspective(math.rad(60), win.width/win.height, near_clip, far_clip)
    }

local water = am.bind{
    water_y = 0.0
}

local ground = am.bind{
    vert = am.vec3_array(verts),
    normal = am.vec3_array(normals),
    color = am.vec3_array(colors),
    camera = camera.eye
}^water^am.use_program(shader)^am.draw"triangles"

local fps = am.text("fps",vec4(0.0, 1.0, 0.0, 1.0), "left", "top")

win.scene = am.group{
    camera^ground,
    am.camera2d(win.width, win.height, vec2(win.width/2-10, 10-win.height/2))^fps
}

water:action(function(node)
    node.water_y = math.sin(am.frame_time)*0.1
end)

camera:action(function(node)
    local r = 50 + 25 * math.sin(am.frame_time/31)
    node.eye = (math.rotate4(am.frame_time/11, vec3(0, 1, 0)) * vec4(r, 10, 0, 0)).xyz
    node.center = math.cross(vec3(0, 1, 0), node.eye)
    ground.camera = node.eye
end)

fps:action(function(node)
    node.text = table.tostring(am.perf_stats())
    --string.format("%.1f fps", 1/delta+0.05)
end)
-- objects:action(update)
