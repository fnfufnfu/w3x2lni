local w3xparser = require 'w3xparser'

local math_floor = math.floor
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local wtonumber = w3xparser.tonumber
local next = next
local table_concat = table.concat

local w2l
local metadata
local has_level
local keyconvert
local slk_type
local txt_keys
local txt_meta

local function to_type(meta, value)
    local tp = w2l:get_id_type(meta.type)
    if tp == 0 then
        if not value then
            return 0
        end
        value = wtonumber(value)
        if not value then
            return 0
        end
        return math_floor(value)
    elseif tp == 1 or tp == 2 then
        if not value then
            return 0.0
        end
        value = wtonumber(value)
        if not value then
            return 0.0
        end
        return value + 0.0
    elseif tp == 3 then
        if not value then
            return nil
        end
        if value == '' then
            return value
        end
        value = tostring(value)
        if not value:match '[^ %-%_]' then
            return nil
        end
        return value
    end
end

local function slk_read_data(obj, key, meta, data)
    local has_repeat = has_level and meta['repeat'] and meta['repeat'] > 0
    if has_repeat then
        obj[key] = {}
        for i = 1, 4 do
            obj[key][i] = to_type(meta, data[key..i])
        end
        if not next(obj[key]) then
            obj[key] = nil
        end
    else
        obj[key] = to_type(meta, data[key])
    end
end

local function slk_read_obj(obj, name, data, keys, metas)
    obj._user_id = name
    obj._origin_id = data.code or obj._origin_id or name
    if slk_type == 'unit' and not obj._name then
        obj._name = data.name  -- 单位的反slk可以用name作为线索
    end
    
    for i = 1, #keys do
        slk_read_data(obj, keys[i], metas[i], data)
    end

    local private = keyconvert[name] or keyconvert[obj._origin_id]
    if private then
        for key, id in pairs(private) do
            slk_read_data(obj, key, metadata[id], data)
        end
    end
end

local function slk_read(table, slk, keys, metas, update_level)
    for name, data in pairs(slk) do
        if not table[name] then
            table[name] = {}
        end
        local obj = table[name]
        slk_read_obj(obj, name, data, keys, metas)
        if update_level then
            obj._max_level = obj[update_level]
            if obj._max_level == 0 then
                obj._max_level = 1
            end
        end
    end
end

local function txt_add_default_data(obj, key, meta)
    local has_repeat = has_level and meta['repeat'] and meta['repeat'] > 0
    if has_repeat then
        local value = to_type(meta)
        if obj[key] then
            for i = 5, #obj[key] do
                obj[key][i] = nil
            end
        else
            if value then
                obj[key] = {}
            else
                return
            end
        end
        for i = 1, 4 do
            if not obj[key][i] then
                obj[key][i] = value
            end
        end
    else
        if not obj[key] then
            obj[key] = to_type(meta)
        end
    end
end

local function txt_read_data(name, obj, key, meta, txt)
    if meta['index'] == 1 then
        local key = key:sub(1, -3)
        local value = txt and txt[key]
        if value then
            for i = 1, 2 do
                obj[key..':'..i] = to_type(meta, value[i])
            end
        else
            for i = 1, 2 do
                obj[key..':'..i] = to_type(meta)
            end
        end
        return
    end

    if meta['appendIndex'] == 1 then
        local max_level = txt and txt[key..'count'] and txt[key..'count'][1] or 1
        obj[key] = {}
        for i = 1, max_level do
            local new_key
            if i == 1 then
                new_key = key
            else
                new_key = key .. (i-1)
            end
            local value = txt and txt[new_key]
            if value and #value > 0 then
                obj[key][i] = table_concat(value, ',')
            end
        end
        return
    end

    local value = txt and txt[key]
    if not value or #value == 0 then
        --TODO: 防止后来的button:1将button:2解析出来的数据覆盖
        if not obj[key] then
            obj[key] = to_type(meta)
        end
        return
    end
    if meta['index'] == -1 and #value > 1 then
        obj[key] = table_concat(value, ',')
        return
    end
    if not meta['repeat'] or meta['repeat'] == 0 then
        obj[key] = to_type(meta, value[1])
        return
    end
    obj[key] = {}
    for i = 1, #value do
        obj[key][i] = value[i]
    end
end

local function txt_read_obj(obj, name, data)
    for i = 1, #txt_keys do
        txt_read_data(name, obj, txt_keys[i], txt_meta[i], data)
    end
end


local function txt_read(table, txt)
    for name, obj in pairs(table) do
        txt_read_obj(obj, name, txt[name])
    end
end

return function (w2l_, type, loader)
    w2l = w2l_
    metadata = w2l:read_metadata(type)
    has_level = w2l.info.key.max_level[type]
    keyconvert = w2l:keyconvert(type)
    slk_type = type

    txt_keys = {}
    txt_meta = {}
    if keyconvert.profile then
        for key, id in pairs(keyconvert.profile) do
            txt_keys[#txt_keys+1] = key
            txt_meta[#txt_meta+1] = metadata[id]
        end
    end

    local data = {}
    for _, filename in ipairs(w2l.info.template.slk[type]) do
        local update_level
        local slk_keys = {}
        local slk_meta = {}
        for key, id in pairs(keyconvert[filename]) do
            slk_keys[#slk_keys+1] = key
            slk_meta[#slk_meta+1] = metadata[id]
            if key == has_level then
                update_level = has_level
            end
        end
        slk_read(data, w2l:parse_slk(loader(filename)), slk_keys, slk_meta, update_level)
    end
    if #w2l.info.template.txt[type] > 0 then
        local txt = {}
        for _, filename in ipairs(w2l.info.template.txt[type]) do
            w2l:parse_txt(loader(filename), filename, txt)
        end
        txt_read(data, txt)
    end
    return data
end
