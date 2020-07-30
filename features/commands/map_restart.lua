local Server = require 'utils.server'
local Global = require 'utils.global'

local this = {}

Global.register(
    this,
    function(t)
        this = t
    end
)

commands.add_command(
    'map_command',
    'Usable only for admins - controls the scenario!',
    function(cmd)
        local p
        local player = game.player

        if not player or not player.valid then
            p = log
        else
            p = player.print
            if not player.admin then
                return
            end
        end

        local param = cmd.parameter
        if not param then
            return
        end

        if string.len(param) < 3 then
            return
        end

        if param == 'wbtc_oarc' then
            if not this.reset_are_you_sure then
                this.reset_are_you_sure = true
                p(
                    '[WARNING] This command will restart this scenario, only run this command again if you really want to do this!'
                )
                return
            end
            this.reset_are_you_sure = nil
            Server.start_scenario('We_Built_This_City_Oarc')
            return
        elseif param == 's1_freeplay' then
            if not this.reset_are_you_sure then
                this.reset_are_you_sure = true
                p(
                    '[WARNING] This command will restart this scenario, only run this command again if you really want to do this!'
                )
                return
            end
            this.reset_are_you_sure = nil
            Server.start_scenario('s1_freeplay')
            return
        end
    end
)
