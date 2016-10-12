local mt = {}
mt.__index = mt

function mt:add(format, ...)
    self.hexs[#self.hexs+1] = (format):pack(...)
end

function mt:add_head()
    self:add('c4', 'HM3W')
    self:add('c4', '\0\0\0\0')
end

function mt:add_name()
    self:add('z', self.w3i.map_name)
end

function mt:add_flag()
    self:add('l', self.w3i.map_flag)
end

function mt:add_playercount()
    self:add('l', 23333)
end

local function get_head(w3i)
    local tbl = setmetatable({}, mt)

    tbl.hexs = {}
    tbl.w3i  = w3i

    tbl:add_head()
    tbl:add_name()
    tbl:add_flag()
    tbl:add_playercount()
    
    local head = table.concat(tbl.hexs)
    return head .. string.rep('\0', 512 - #head)
end

return function (self, map_path, file_count, w3i)
    if not w3i then
        w3i = {
            map_name = '只是另一张魔兽争霸III地图',
            map_flag = 0,
        }
    end
    io.save(map_path, get_head(w3i))
    return mpq_create(map_path, file_count)
end
