return function(center, surface) --main buses
    local ce = surface.create_entity --save typing
    local fN = game.forces.neutral
    local direct = defines.direction

    ce{name = "transport-belt", position = {center.x + (-13.0), center.y + (-8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-12.0), center.y + (-8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-13.0), center.y + (-9.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-10.0), center.y + (-8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-10.0), center.y + (-9.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-11.0), center.y + (-9.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-9.0), center.y + (-8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-8.0), center.y + (-8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-9.0), center.y + (-9.0)}, direction = direct.east, force = fN}
    ce{name = "splitter", position = {center.x + (-6.0), center.y + (-7.5)}, direction = direct.east, force = fN}
    ce{name = "splitter", position = {center.x + (-7.0), center.y + (-8.5)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-6.0), center.y + (-9.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-4.0), center.y + (-9.0)}, direction = direct.south, force = fN}
    ce{name = "transport-belt", position = {center.x + (-4.0), center.y + (-8.0)}, direction = direct.east, force = fN}
    ce{name = "underground-belt", position = {center.x + (-5.0), center.y + (-8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-5.0), center.y + (-9.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-2.0), center.y + (-8.0)}, force = fN}
    ce{name = "splitter", position = {center.x + (-3.0), center.y + (-7.5)}, direction = direct.east, force = fN}
    ce{name = "splitter", position = {center.x + (0.0), center.y + (-8.5)}, direction = direct.east, force = fN}
    ce{name = "underground-belt", position = {center.x + (-1.0), center.y + (-8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-1.0), center.y + (-9.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (2.0), center.y + (-8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (2.0), center.y + (-9.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (1.0), center.y + (-9.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (3.0), center.y + (-8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (6.0), center.y + (-9.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (5.0), center.y + (-9.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (7.0), center.y + (-8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (8.0), center.y + (-9.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (9.0), center.y + (-8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (10.0), center.y + (-8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (11.0), center.y + (-8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (11.0), center.y + (-9.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-12.0), center.y + (-6.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-12.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-13.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-10.0), center.y + (-6.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-11.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-11.0), center.y + (-6.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-9.0), center.y + (-6.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-8.0), center.y + (-6.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-8.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-9.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "splitter", position = {center.x + (-7.0), center.y + (-6.5)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-5.0), center.y + (-6.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-4.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "underground-belt", position = {center.x + (-5.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-4.0), center.y + (-6.0)}, force = fN}
    ce{name = "transport-belt", position = {center.x + (-2.0), center.y + (-7.0)}, direction = direct.south, force = fN}
    ce{name = "underground-belt", position = {center.x + (-1.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-1.0), center.y + (-6.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (1.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (1.0), center.y + (-6.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (2.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (4.0), center.y + (-6.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (3.0), center.y + (-6.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (3.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (4.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (5.0), center.y + (-6.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (6.0), center.y + (-6.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (6.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (8.0), center.y + (-6.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (8.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (7.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (10.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (10.0), center.y + (-6.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (9.0), center.y + (-6.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (9.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (11.0), center.y + (-7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-13.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-12.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-12.0), center.y + (-3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-13.0), center.y + (-3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-11.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-10.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-9.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-8.0), center.y + (-3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-6.0), center.y + (-3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-7.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-6.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-7.0), center.y + (-3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-4.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "splitter", position = {center.x + (-5.0), center.y + (-2.5)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-3.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-2.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-2.0), center.y + (-3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-1.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (0.0), center.y + (-3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (1.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (2.0), center.y + (-3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (3.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (4.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (4.0), center.y + (-3.0)}, direction = direct.east, force = fN}
    ce{name = "splitter", position = {center.x + (5.0), center.y + (-2.5)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (6.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (6.0), center.y + (-3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (7.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (8.0), center.y + (-3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (7.0), center.y + (-3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (9.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (10.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (10.0), center.y + (-3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (9.0), center.y + (-3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (11.0), center.y + (-2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (11.0), center.y + (-3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-13.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-13.0), center.y + (2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-12.0), center.y + (2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-11.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-10.0), center.y + (2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-9.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-8.0), center.y + (2.0)}, direction = direct.east, force = fN}
    ce{name = "splitter", position = {center.x + (-7.0), center.y + (1.5)}, direction = direct.east, force = fN}
    ce{name = "splitter", position = {center.x + (-6.0), center.y + (2.5)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-6.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "underground-belt", position = {center.x + (-5.0), center.y + (2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-4.0), center.y + (2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-4.0), center.y + (1.0)}, direction = direct.south, force = fN}
    ce{name = "transport-belt", position = {center.x + (-5.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-2.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-2.0), center.y + (2.0)}, force = fN}
    ce{name = "underground-belt", position = {center.x + (-1.0), center.y + (2.0)}, direction = direct.east, force = fN}
    ce{name = "splitter", position = {center.x + (0.0), center.y + (1.5)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-1.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (2.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (2.0), center.y + (2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (1.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (3.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (4.0), center.y + (2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (6.0), center.y + (2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (5.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (5.0), center.y + (2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (6.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (8.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (7.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (7.0), center.y + (2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (9.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (10.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (11.0), center.y + (2.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (11.0), center.y + (1.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-13.0), center.y + (4.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-13.0), center.y + (3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-12.0), center.y + (3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-10.0), center.y + (4.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-11.0), center.y + (4.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-11.0), center.y + (3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-8.0), center.y + (4.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-8.0), center.y + (3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-9.0), center.y + (4.0)}, direction = direct.east, force = fN}
    ce{name = "splitter", position = {center.x + (-7.0), center.y + (3.5)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-5.0), center.y + (4.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-4.0), center.y + (3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-4.0), center.y + (4.0)}, force = fN}
    ce{name = "transport-belt", position = {center.x + (-2.0), center.y + (3.0)}, direction = direct.south, force = fN}
    ce{name = "splitter", position = {center.x + (0.0), center.y + (3.5)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-1.0), center.y + (4.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (1.0), center.y + (3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (1.0), center.y + (4.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (2.0), center.y + (3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (3.0), center.y + (4.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (3.0), center.y + (3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (4.0), center.y + (4.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (4.0), center.y + (3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (5.0), center.y + (4.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (6.0), center.y + (3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (6.0), center.y + (4.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (8.0), center.y + (4.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (8.0), center.y + (3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (10.0), center.y + (4.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (11.0), center.y + (3.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-12.0), center.y + (8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-13.0), center.y + (8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-13.0), center.y + (7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-10.0), center.y + (7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-10.0), center.y + (8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-9.0), center.y + (8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-8.0), center.y + (7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-9.0), center.y + (7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-6.0), center.y + (7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-6.0), center.y + (8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-7.0), center.y + (7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-7.0), center.y + (8.0)}, direction = direct.east, force = fN}
    ce{name = "splitter", position = {center.x + (-5.0), center.y + (7.5)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-4.0), center.y + (7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-4.0), center.y + (8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-3.0), center.y + (7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-2.0), center.y + (8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (0.0), center.y + (7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-1.0), center.y + (8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (-1.0), center.y + (7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (2.0), center.y + (8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (1.0), center.y + (8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (4.0), center.y + (7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (4.0), center.y + (8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (6.0), center.y + (8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (5.0), center.y + (7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (5.0), center.y + (8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (8.0), center.y + (7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (7.0), center.y + (7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (7.0), center.y + (8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (9.0), center.y + (7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (9.0), center.y + (8.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (11.0), center.y + (7.0)}, direction = direct.east, force = fN}
    ce{name = "transport-belt", position = {center.x + (11.0), center.y + (8.0)}, direction = direct.east, force = fN}
end