M = {}
function M.lerp(a, b, t)
    return a + (b - a) * t
end

function M.close(tag, i, time, callback)
    local sector = world:get_sectors(tag)[i]
    local ttime=0
    local from=sector:get_height()
    local to=0
    world:add_task(function(dt)
        ttime=ttime+dt
        if ttime > time then
            ttime = time
        end
        local nh = M.lerp(from, to, ttime/time)
        sector:set_height(nh)
        if nh == 0 then
            if callback then
                callback(function(_time, _callback)
                    M.open(tag, i, _time, from, _callback)
                end)
            end
            return true
        end
    end)
end

function M.close_all(tag, time, callback)
    for i in ipairs(world:get_sectors(tag)) do
        M.close(tag, i, time, function(fn)
            if callback then
                callback(fn)
            end
            callback = nil
        end)
    end
end

function M.open(tag, i, time, to, callback)
    local sector = world:get_sectors(tag)[i]
    local ttime=0
    local from=sector:get_height()
    world:add_task(function(dt)
        ttime=ttime+dt
        if ttime > time then
            ttime = time
        end
        local nh = M.lerp(from, to, ttime/time)
        sector:set_height(nh)
        if nh == to then
            if callback then
                callback()
            end
            return true
        end
    end)
end

function M.open_all(tag, time, to, callback)
    for i in ipairs(world:get_sectors(tag)) do
        M.open(tag, i, time, to, function()
            if callback then
                callback()
            end
            callback = nil
        end)
    end
end

function M.wait(time, callback)
    local ttime=0
    world:add_task(function(dt)
        ttime=ttime+dt
        if ttime>=time then
            if callback then
                callback()
            end
            return true
        end
    end)
end

function M.interaction()
    local functions = {}

    local S = {}
    function S.fn()
        for _, fn in ipairs(functions) do
            fn()
        end
    end
    function S.listen(fn)
        table.insert(functions, fn)
    end
    return S
end

return M
