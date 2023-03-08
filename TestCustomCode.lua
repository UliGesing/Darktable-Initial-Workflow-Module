--[[
  Darktable Initial Workflow Module

  This file contains some custom debug code.
  This code is executed by clicking the "Custom Code" button.
  This code can be changed without restarting darktable.
  You can use it to try some commands "on the fly".

  For more details see Readme.md in
  https://github.com/UliGesing/Darktable-Initial-Workflow-Module
 ]]
local dt = require "darktable"
local log = require "lib/dtutils.log"
local value

-- value = dt.gui.action("iop/colorbalancergb/global chroma",0,"value","",0/0)
--[[ value = dt.gui.action("iop/atrous/mix",0,"value","",0/0)
local converted = value - 2.5
converted = converted * 4
converted = math.floor(converted * 10000 + 0.5) / 10000
log.msg(log.info,value .. " => " .. converted)
 ]]

-- dt.gui.action("iop/channelmixerrgb/illuminant", "selection", "item:(AI) detect from image edges...", 1,000, 0)

value = dt.gui.action("iop/temperature/settings/settings",0,"selection","",0/0)
log.msg(log.info,value)

dt.gui.action("iop/colorbalancergb/global saturation",0,"value","set",0.3000)
