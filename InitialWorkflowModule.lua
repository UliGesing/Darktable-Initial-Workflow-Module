--[[
  Darktable Initial Workflow Module

  This script can be used together with darktable. See
  https://www.darktable.org/ for more information.

  This script offers a new 'inital workflow module' both in
  lighttable and darkroom view. It can be used to do some
  configuration for an initial image workflow. It calls some
  automatisms of different modules in the darkroom view. If
  this suits your workflow, the script saves some clicks and time.

  copyright (c) 2022 Ulrich Gesing

  USAGE: See Darktable documentation for your first steps:
  https://docs.darktable.org/usermanual/4.8/en/lua/

  For more details see Readme.md in
  https://github.com/UliGesing/Darktable-Initial-Workflow-Module

  This script is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This script is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  See the GNU General Public License for more details
  at <http://www.gnu.org/licenses/>.
]]


--[[
  This lua file contains the main entry point to install the
  Initial Workflow Module as a new module in darktable.

  This file is executed during startup of darktable, loads other
  modules from subfolder "Modules" and initializes them.

  It registers the module and creates a new widget box in lighttable
  and darkroom view.
]]

---------------------------------------------------------------

local ModuleName = 'InitialWorkflowModule'

local dt = require 'darktable'

-- log startup messages
local startupLog = require 'lib/dtutils.log'
startupLog.log_level(startupLog.info)

local function StartupMessage(message)
  startupLog.msg(startupLog.info, message)
end

-- simple startup message
StartupMessage("Initial Workflow Module")

-- get path, where the main script was started from
-- get locales directory, used for translations
local pathSeparator = dt.configuration.running_os == 'windows' and '\\' or '/'
local scriptFilePath = debug.getinfo(1, 'S').source:sub(2):match('(.*[/\\])')
local scriptLocalePath = scriptFilePath .. 'locale' .. pathSeparator

-- prevent exception, if require fails
local function prequire(module)
  StartupMessage("Load submodule " .. module)
  local success, result

  -- first try
  success, result = pcall(require, module)

  if not success then
    -- sub module was not found
    -- try to extend lua package path
    StartupMessage("extend lua package path: " .. scriptFilePath .. "?.lua")
    package.path = package.path .. ";" .. scriptFilePath .. "?.lua"

    -- second try
    success, result = pcall(require, module)

    if not success then
      StartupMessage("Failed to require module " .. module)
      StartupMessage("Script executed from path " .. scriptFilePath)
      StartupMessage("Lua package path = " .. package.path)
      StartupMessage(result)
      return false, result
    end
  end

  return true, result
end

local success

-- load module IWF_GuiTranslation.lua
local GuiTranslation
success, GuiTranslation = prequire('lib.IWF_GuiTranslation')
if not success then return end
GuiTranslation.Init(dt.gettext, ModuleName, scriptLocalePath)

-- load module IWF_LogHelper.lua
local LogHelper
success, LogHelper = prequire('lib.IWF_Log')
if not success then return end
LogHelper.Init()

-- load module IWF_Helper.lua
local Helper
success, Helper = prequire('lib.IWF_Helper')
if not success then return end
Helper.Init(dt, LogHelper, GuiTranslation, ModuleName)

-- return translation from local .po / .mo file
local function _(msgid)
  return GuiTranslation.t(msgid)
end

-- startup messages
StartupMessage(string.format(_("script executed from path %s"), scriptFilePath))
StartupMessage(string.format(_("script translation files in %s"), scriptLocalePath))
StartupMessage(_("script outputs are in English"))

-- check darktable API version: darktable version 5.0 is needed
local du = require 'lib/dtutils'
local function CheckApiVersion()
  local apiCheck, err = pcall(function() du.check_min_api_version('9.4.0', ModuleName) end)
  if (apiCheck) then
    StartupMessage(string.format(_("darktable version with appropriate lua API detected: %s"),
      'dt' .. dt.configuration.version))
  else
    StartupMessage(_("this script needs at least darktable 5.0 API to run"))
    return false
  end

  return true
end

if not CheckApiVersion() then
  return
end

---------------------------------------------------------------

-- load module IWF_EventHelper.lua
local EventHelper
success, EventHelper = prequire('lib.IWF_EventHelper')
if not success then return end
EventHelper.Init(dt, LogHelper, Helper, GuiTranslation, ModuleName)

-- load module IWF_GuiAction.lua
local GuiAction
success, GuiAction = prequire('lib.IWF_GuiAction')
if not success then return end
GuiAction.Init(dt, LogHelper, Helper, EventHelper, GuiTranslation)

-- load module IWF_Workflow.lua
local Workflow
success, Workflow = prequire('lib.IWF_Workflow')
if not success then return end
Workflow.Init(dt, LogHelper, Helper, EventHelper, GuiTranslation, GuiAction)

-- create stack widget, used to display subpages
local WidgetStack =
{
  Modules = 1,
  Settings = 2,
  Stack = dt.new_widget("stack") {},
}

-- load module IWF_WorkflowSteps.lua
local WorkflowSteps
success, WorkflowSteps = prequire('lib.IWF_WorkflowSteps')
if not success then return end
WorkflowSteps.Init(dt, LogHelper, Helper, EventHelper, GuiTranslation, Workflow, GuiAction, WidgetStack, scriptFilePath)

-- load module IWF_WorkflowButtons.lua
local WorkflowButtons
success, WorkflowButtons = prequire('lib.IWF_WorkflowButtons')
if not success then return end
WorkflowButtons.Init(dt, LogHelper, Helper, EventHelper, GuiTranslation, Workflow, GuiAction, WidgetStack, scriptFilePath)

-- init widget controls
WorkflowSteps.CreateWorkflowSteps()
WorkflowButtons.CreateWorkflowButtons()

-- load module IWF_GuiWidgets
local GuiWidgets
success, GuiWidgets = prequire('lib.IWF_GuiWidgets')
if not success then return end
GuiWidgets.Init(dt, LogHelper, Helper, Workflow, WidgetStack)

---------------------------------------------------------------

local Env =
{
  InstallModuleEventRegistered = false,
  InstallModuleDone = false,
}

-- register the module and create widget box in lighttable and darkroom
local function InstallModuleRegisterLib()
  if not Env.InstallModuleDone then
    dt.register_lib(
      ModuleName,         -- Module name
      'initial workflow', -- name
      true,               -- expandable
      true,               -- resetable

      {
        [dt.gui.views.lighttable] = { 'DT_UI_CONTAINER_PANEL_RIGHT_CENTER', 100 },
        [dt.gui.views.darkroom] = { 'DT_UI_CONTAINER_PANEL_LEFT_CENTER', 100 }
      },

      dt.new_widget('box')
      {
        orientation = 'vertical',
        reset_callback = SetAllDefaultModuleConfigurations,
        table.unpack(GuiWidgets.GetWidgets()),
      },

      nil, -- view_enter
      nil  -- view_leave
    )

    Env.InstallModuleDone = true
  end
end

local function InitAllControlsDependingOnCurrentView()
  for i, step in ipairs(Workflow.ModuleSteps) do
    step:InitDependingOnCurrentView()
  end

  for i, button in ipairs(Workflow.Buttons) do
    button:InitDependingOnCurrentView()
  end
end

-- event to handle changes from darkroom to lighttable view
-- some comboboxes or buttons need a special handling
-- see base class overrides for details
local function ViewChangedEvent(event, old_view, new_view)
  LogHelper.Info(string.format(_("view changed to %s"), new_view.name))

  if ((new_view == dt.gui.views.lighttable) and (old_view == dt.gui.views.darkroom)) then
    InstallModuleRegisterLib()
  end

  InitAllControlsDependingOnCurrentView()
end

local function EventOnDarktableExit()
  LogHelper.Info(_("exit darktable."))
  WorkflowSteps.OnDarktableExit()
end

-- main entry function to install the module at startup
local function InstallInitialWorkflowModule()
  LogHelper.Info(_("create widget in lighttable and darkroom panels"))

    -- call post constructor first
  for i, step in ipairs(Workflow.ModuleSteps) do
    step:PostConstructor()
  end

  -- initialize workflow steps
  for i, step in ipairs(Workflow.ModuleSteps) do
    step:Init()
  end

  -- get current settings as saved in darktable preferences
  for i, step in ipairs(Workflow.ModuleSteps) do
    step:ReadPreferenceBasicValue()
    step:ReadPreferenceConfigurationValue()
  end

  -- create the module depending on which view darktable starts in
  if dt.gui.current_view() == dt.gui.views.lighttable then
    InstallModuleRegisterLib()
  end

  if not Env.InstallModuleEventRegistered then
    dt.register_event(ModuleName, 'view-changed', ViewChangedEvent)
    Env.InstallModuleEventRegistered = true
  end

  InitAllControlsDependingOnCurrentView()

  -- register event: This event is triggered when darktable exits.
  dt.register_event(ModuleName, "exit", EventOnDarktableExit)

  return true
end

---------------------------------------------------------------

-- start it!
InstallInitialWorkflowModule()

---------------------------------------------------------------
-- darktable script manager integration

-- function to destory the script
local function destroy()
  dt.gui.libs[ModuleName].visible = false
end

-- make the script visible again after it's been hidden
local function restart()
  dt.gui.libs[ModuleName].visible = true
end

local script_data = {}
script_data.destroy = destroy
script_data.restart = restart
-- set to hide since we can't destroy them commpletely yet
script_data.destroy_method = 'hide'
script_data.show = restart

return script_data
