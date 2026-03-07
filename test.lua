function lerp(a, b, t)
    return a + (b - a) * t
end

function close(tag, i, time, callback)
    local sector = world:get_sectors(tag)[i]
    local ttime=0
    local from=sector:get_height()
    local to=0
    world:add_task(function(dt)
        ttime=ttime+dt
        if ttime > time then
            ttime = time
        end
        local nh = lerp(from, to, ttime/time)
        sector:set_height(nh)
        if nh == 0 then
            if callback then
                callback(function(_time, _callback)
                    open(tag, i, _time, from, _callback)
                end)
            end
            return true
        end
    end)
end

function close_all(tag, time, callback)
    for i in ipairs(world:get_sectors(tag)) do
        close(tag, i, time, function(fn)
            if callback then
                callback(fn)
            end
            callback = nil
        end)
    end
end

function open(tag, i, time, to, callback)
    local sector = world:get_sectors(tag)[i]
    local ttime=0
    local from=sector:get_height()
    world:add_task(function(dt)
        ttime=ttime+dt
        if ttime > time then
            ttime = time
        end
        local nh = lerp(from, to, ttime/time)
        sector:set_height(nh)
        if nh == to then
            if callback then
                callback()
            end
            return true
        end
    end)
end

function open_all(tag, time, to, callback)
    for i in ipairs(world:get_sectors(tag)) do
        open(tag, i, time, to, function()
            if callback then
                callback()
            end
            callback = nil
        end)
    end
end

function wait(time, callback)
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




local function c()
    close(1, 1, 1, function(open)
        wait(1, function()
            open(1, function()
                wait(1, c)
            end)
        end)
    end)
end
c()

