local Event = require 'utils.event'
local Global = require 'utils.global'

local Public = {}

local this = {
    chunk_size = 32,
    max_forces = 64,
    ticks_per_second = 60,
    ticks_per_minute = 3600,
    ticks_per_hour = 216000
}

Global.register(
    this,
    function(t)
        this = t
    end
)

function Public.reset_table()
    this.chunk_size = 32
    this.max_forces = 64
    this.ticks_per_second = 60
    this.ticks_per_minute = 3600
    this.ticks_per_hour = 216000
end

function Public.get(key)
    if key then
        return this[key]
    else
        return this
    end
end

local on_init = function()
    Public.reset_table()
end

Event.on_init(on_init)
return Public
