local map = require("map")

local win = am.window{
    title = "3D landscape",
    clear_color = vec4(0.3, 0.5, 0.7, 1.0),
    width = 1920,
    height = 1080,
    depth_buffer = true,
    msaa_samples = 8
}
win.scene = am.camera2d(win.width, win.height, vec2(0))
    ^am.text("Preparing landscape mesh")

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
    vec3 c = mix(vec3(0.1, 0.1, 0.2), color, 0.33 + 0.67 * dot(light, nm));
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



win.scene:action(function()
    local ground0 = {}
    map:init(map_size, ground0)

    local camera = am.lookat(vec3(0, 10, 0), vec3(0, 20, 0), vec3(0, 1, 0))
        ^am.bind{
            P = math.perspective(math.rad(60), win.width/win.height, near_clip, far_clip)
        }

    local water = am.bind{
        water_y = 0.0
    }

    local ground = am.bind{
        camera = camera.eye,
        vert = ground0.vert,
        normal = ground0.normal,
        color = ground0.color
    }^water^am.use_program(shader)^am.draw"triangles"

    ground:action(map.updater)

    local fps = am.text("fps",vec4(0.0, 1.0, 0.0, 1.0), "left", "top")

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

    win.scene = am.group{
        camera^ground,
        am.camera2d(win.width, win.height, vec2(win.width/2-10, 10-win.height/2))^fps
    }
    return true
end)

