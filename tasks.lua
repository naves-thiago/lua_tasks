require "debugger"
--require("mobdebug").start()
--require("mobdebug").coro()

-- Coroutine wrapper
co = {tasks={}}
setmetatable(co.tasks, {__mode="kv"})

function co.create(f)
    local fwrap = function(...)
        f(...)
        local handle = co.running()
        handle.state = "dead"
        if handle.destructor then
            handle.destructor(handle)
        end
    end

    local ret = {handle = coroutine.create(fwrap), state = "suspended", destructor = nil}
    co.tasks[ret.handle] = ret
    ret.setdestructor = function(handle, f) handle.destructor = f end

    return ret
end

function co.yield(...)
    local handle = co.running()
    if handle == nil then
        return false, "Not running"
    end

    handle.state = "suspended"

    return coroutine.yield(...)
end

function co.resume(handle, ...)
    if handle.state == "dead" then
        return false, "Cannot resume a dead coroutine"
    end

    handle.state = "running"

    local current = co.running()
    if current then
        current.state = "suspended"

        if children[current] == nil then
            children[current] = {}
        end

        if handle.parent == nil then
            handle.parent = current

            -- TODO change this to children[current] = true
            table.insert(children[current], handle)
        end
    end

    return coroutine.resume(handle.handle, ...)
end

function co.kill(handle)
    if handle.state == "dead" then
        -- Already dead...do nothing
        return
    end

    if handle.state == "running" then
        -- Kill self: yield back to the parent
        handle.state = "dead"
        if handle.destructor then
            handle.destructor(handle)
        end
        coroutine.yield()
        return
    end

    -- handle.state == "suspended"
    handle.state = "dead"
    if handle.destructor then
        handle.destructor(handle)
    end
end

function co.running()
    return co.tasks[coroutine.running()]
end

function co.wrap(f)
    local c = co.create(f)
    return function(...) co.resume(c, ...) end
end

function co.state(handle)
    return handle.state
end

----------------------------------------

children = {}
setmetatable(children, {__mode="k"})

function node_done_or(handle)
    --pause()
    local c = children[handle]
    if c then
        for i,j in pairs(c) do
            j.parent = nil
            if j.node_done then
                j.node_done(j)
            end
            co.kill(j)
        end
    end

    if handle.parent and handle.parent.node_done then
        handle.parent.node_done(handle.parent)
    end

    handle.destructor = nil
    co.kill(handle)
    -- TODO remove from children lists
end

function par_or(fa, fb, name)
    local sub -- children list

    local coa, cob
    coa = co.create(fa)
    coa.destructor = node_done_or

    cob = co.create(fb)
    cob.destructor = node_done_or

    sub = {coa, cob}

    return function()
        local handle = co.running()
        handle.node_done = node_done_or
        handle.name = name -- debug
        for i,j in ipairs(sub) do
            -- TODO figure out how to detect if a child is dead by now
            co.resume(j)
        end

        -- Only yield if coa and cob are still alive
        for i,j in ipairs(sub) do
            if j.state == "dead" then
                return
            end
        end
        co.yield()
    end
end

function node_done_and(handle)
    local c = children[handle]

    for i,j in pairs(c) do
        if j.state ~= "dead" then
            return -- There is at least one child alive. Do nothing
        end
    end

    for i,j in pairs(c) do
        j.parent = nil
        if j.node_done then
            j.node_done(j)
        end
        co.kill(j)
    end

    if handle.parent and handle.parent.node_done then
        handle.parent.node_done(handle.parent)
    end

    handle.destructor = nil
    co.kill(handle)
    -- TODO remove from children lists
end

function par_and(fa, fb, name)
    local sub -- children list

    local coa, cob
    coa = co.create(fa)
    coa.destructor = node_done_or -- these have only 1 child (or none). simply kill (same as the OR)

    cob = co.create(fb)
    cob.destructor = node_done_or -- these have only 1 child (or none). simply kill (same as the OR)

    sub = {coa, cob}

    return function()
        local handle = co.running()
        handle.node_done = node_done_and
        handle.name = name -- debug
        for i,j in ipairs(sub) do
            co.resume(j)
        end

        -- Only yield if a child is still alive
        for i,j in ipairs(sub) do
            if j.state == "suspended" then
                co.yield()
                break
            end
        end
    end
end

----------------------------------------

function pa()
    ha = co.running()
    print("ini a")
    co.yield()
    print("fim a")
end

function pb()
    hb = co.running()
    print("ini b")
    co.yield()
    print("fim b")
end

function pc()
    hc = co.running()
    print("ini c")
    co.yield()
    print("fim c")
end

function pd()
    hd = co.running()
    print("ini d")
    co.yield()
    print("fim d")
end

function start(f)
    local current = co.running()
    local sub = co.create(function()
        local sub_sub = co.create(f)
        co.running().sub = sub_sub
        co.resume(sub_sub)
        co.yield()
    end)
    sub.node_done = function(handle)
        handle.sub.parent = nil
        handle.sub.node_done(handle.sub)
        co.kill(handle.sub)
        if current then
            -- If the program ended, there will be no 'current' to resume
            co.resume(current)
        end
    end
    co.resume(sub)
end

function pe()
    he = co.running()
    print("ini e")
--[[
    pe_sub = co.create(function()
        pe_sub_sub = co.create(par_or(pf, pg))
        co.running().sub = pe_sub_sub
        co.resume(pe_sub_sub)
        co.yield()
    end)
    pe_sub.node_done = function(handle)
        handle.sub.parent = nil
        handle.sub.node_done(handle.sub)
        co.kill(handle.sub)
        co.resume(he)
    end
    co.resume(pe_sub)
--]]

    start(par_or(pf, pg))
    print("antes yield")
    co.yield()
    print("fim e")
end

function pf()
    hf = co.running()
    print("ini f")
    co.yield()
    print("fim f")
end

function pg()
    hg = co.running()
    print("ini g")
    co.yield()
    print("fim g")
end

function ph()
    hh = co.running()
    print("ini h")
    print("fim h")
end

function pi()
    hi = co.running()
    print("ini i")
    print("fim i")
end

function main()
--    par_or(pa, pb)()
--    par_or(par_or(pa, pb), pc)()
--    par_or(par_or(pa, pb, "A"), par_or(pc, pd, "B"), "fora")()
--    par_or(par_or(pa, pb), par_or(pc, pd))()
    par_or(par_or(pa, pb), pe)()
--    par_and(pa, pb)()
--    par_and(pa, par_and(pb, pc))()
--    par_or(pa, par_and(pb, pc))()
--    par_and(pa, par_or(pb, pc))()
--    par_or(par_and(pa, par_or(pb, pc)), pd)()
--    par_or(par_and(pa, pb), pc)()
end

--co.wrap(main)()
--co.resume(ha)

--start(par_or(par_or(pa, pb), pe))
--start(par_and(pa, par_or(par_or(pb, pc), ph)))
--start(par_or(par_and(pa, pb), ph))
start(par_or(par_or(pb, pi), pa))
