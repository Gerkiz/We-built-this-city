local Public = require 'utils.gui.main'

local Inputs = require 'utils.gui.templates.inputs'
Public.inputs = Inputs
Public.classes.Inputs = Inputs

local Toolbar = require 'utils.gui.templates.toolbar'
Public.toolbar = Toolbar
Public.classes.Toolbar = Toolbar

local Center = require 'utils.gui.templates.center'
Public.center = Center
Public.classes.Center = Center

return Public
