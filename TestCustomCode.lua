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

value = dt.gui.action("iop/exposure/exposure",0,"button","on",1.0000)
log.msg(log.info,value)