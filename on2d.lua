local on2 = require("on2")
local component = require("component")
local event = require("event")
local thread = require("thread")
local stopping = false
local t = nil
function start()
    t = thread.create(
    function()
        local args = args or {}
        local port = args[1] or 1
        if component.modem == nil then
            error("on2d: No modem found!")
        end
        local on2con = on2.create(component.modem,port)
        while not stopping do
            event.push("on2_message",on2con:listen())
        end
    end)
end

function stop()
    stopping = true
end

