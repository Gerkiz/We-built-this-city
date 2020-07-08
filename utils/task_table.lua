-- one table to rule them all!
local Global = require 'utils.global'

local this = {
    ticker = {}
}
local Public = {}

Global.register(
    this,
    function(tbl)
        this = tbl
    end
)

function Public.get(key)
    if key then
        return this[key]
    else
        return this
    end
end

return Public
