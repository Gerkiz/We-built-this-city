local Public = {}

Public.my_fixed_width_style = {
    minimal_width = 450,
    maximal_width = 450
}
Public.my_label_style = {
    single_line = false,
    font_color = {r = 1, g = 1, b = 1},
    top_padding = 0,
    bottom_padding = 0
}
Public.my_label_header_style = {
    single_line = false,
    font = 'heading-1',
    font_color = {r = 1, g = 1, b = 1},
    top_padding = 0,
    bottom_padding = 0
}
Public.my_label_header_grey_style = {
    single_line = false,
    font = 'heading-1',
    font_color = {r = 0.6, g = 0.6, b = 0.6},
    top_padding = 0,
    bottom_padding = 0
}
Public.my_note_style = {
    single_line = false,
    font = 'default-small-semibold',
    font_color = {r = 1, g = 0.5, b = 0.5},
    top_padding = 0,
    bottom_padding = 0
}
Public.my_warning_style = {
    single_line = false,
    font_color = {r = 1, g = 0.1, b = 0.1},
    top_padding = 0,
    bottom_padding = 0
}
Public.my_spacer_style = {
    minimal_height = 10,
    top_padding = 0,
    bottom_padding = 0
}
Public.my_small_button_style = {
    font = 'default-small-semibold'
}
Public.my_player_list_fixed_width_style = {
    minimal_width = 200,
    maximal_width = 400,
    maximal_height = 200
}
Public.my_player_list_admin_style = {
    font = 'default-semibold',
    font_color = {r = 1, g = 0.5, b = 0.5},
    minimal_width = 200,
    top_padding = 0,
    bottom_padding = 0,
    single_line = false
}
Public.my_player_list_style = {
    font = 'default-semibold',
    minimal_width = 200,
    top_padding = 0,
    bottom_padding = 0,
    single_line = false
}
Public.my_player_list_offline_style = {
    font_color = {r = 0.5, g = 0.5, b = 0.5},
    minimal_width = 200,
    top_padding = 0,
    bottom_padding = 0,
    single_line = false
}
Public.my_player_list_style_spacer = {
    minimal_height = 20
}
Public.my_color_red = {r = 1, g = 0.1, b = 0.1}

Public.my_longer_label_style = {
    maximal_width = 600,
    single_line = false,
    font_color = {r = 1, g = 1, b = 1},
    top_padding = 0,
    bottom_padding = 0
}
Public.my_longer_warning_style = {
    maximal_width = 600,
    single_line = false,
    font_color = {r = 1, g = 0.1, b = 0.1},
    top_padding = 0,
    bottom_padding = 0
}

--------------------------------------------------------------------------------
-- GUI Functions
--------------------------------------------------------------------------------

-- Apply a style option to a GUI
function Public.ApplyStyle(guiIn, styleIn)
    for k, v in pairs(styleIn) do
        guiIn.style[k] = v
    end
end

-- Shorter way to add a label with a style
function Public.AddLabel(guiIn, name, message, style)
    local g =
        guiIn.add {
        name = name,
        type = 'label',
        caption = message
    }
    if (type(style) == 'table') then
        Public.ApplyStyle(g, style)
        g.style.font = 'count-font'
    else
        g.style = style
        g.style.font = 'count-font'
    end
end

-- Shorter way to add a spacer
function Public.AddSpacer(guiIn)
    Public.ApplyStyle(guiIn.add {type = 'label', caption = ' '}, Public.my_spacer_style)
end

function Public.AddSpacerLine(guiIn)
    Public.ApplyStyle(guiIn.add {type = 'line', direction = 'horizontal'}, Public.my_spacer_style)
end

return Public
