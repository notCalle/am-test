local map = {}

local
function corner3(pos2)
    local soil = math.simplex(pos2/100)*3
    local rock = (math.simplex(-pos2/20)^3)*11+(math.simplex(pos2)^5)*2-1
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

local max_slot = 1024*4
local chunk_size = 8
local slot_size = chunk_size^2 * 12^2

local vertb = am.buffer(max_slot * slot_size)
local normalb = am.buffer(max_slot * slot_size)
local colorb = am.buffer(max_slot * slot_size)


local
function update_chunk(pos2, vertv, normv, colv)
    for x = 0, chunk_size-1, 1 do
        for y = 0, chunk_size-1, 1 do
            local vts, nms, cols = tile(vec2(x+pos2.x, y+pos2.y))
            for v = 1, 12 do
                i = (((x * chunk_size) + y) * 12) + v
                vertv[i] = vts[v]
                normv[i] = nms[v]
                colv[i] = cols[v]
            end
        end
    end
end

local chunk_queue = {}

local
function update_coproc()
    slot = 0
    while true do
        local pos2 = table.remove(chunk_queue, 1)
        if pos2 then
            local offset = slot * slot_size
            update_chunk(pos2,
                vertb:view("vec3", offset, 12, slot_size/12),
                normalb:view("vec3", offset, 12, slot_size/12),
                colorb:view("vec3", offset, 12, slot_size/12)
            )
            slot = math.fmod(slot + 1, max_slot)
        end
        coroutine.yield()
    end
end

function map:init(size, node)
    self.size = size
    self.offset = vec2(size/2)
    for x = 1, size do
        for y = 1, size do
            self[x * size + y] = corner3(vec2(x, y)-self.offset)
        end
    end
    for x = 0, 400, chunk_size do
        for y = 0, 400, chunk_size do
            table.insert(chunk_queue, vec2(x-200, y-200))
        end
    end
    node.vert = vertb:view("vec3",0,12)
    node.normal = normalb:view("vec3",0,12)
    node.color = colorb:view("vec3",0,12)
    self.updater = coroutine.wrap(update_coproc)
end

return map
