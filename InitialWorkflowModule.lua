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

---------------------------------------------------------------

local ModuleName = 'InitialWorkflowModule'

local dt = require 'darktable'

-- get path, where the main script was started from
local function ScriptFilePath()
  local str = debug.getinfo(1, 'S').source:sub(2)
  return str:match('(.*[/\\])')
end

-- set locales directory
local pathSeparator = dt.configuration.running_os == 'windows' and '\\' or '/'
local localePath = ScriptFilePath() .. 'locale' .. pathSeparator

-- init ./Modules/GuiTranslation.lua
local GuiTranslation = require 'Modules.GuiTranslation'
GuiTranslation.Init(dt.gettext, ModuleName, localePath)

-- return translation from local .po / .mo file
local function _(msgid)
  return GuiTranslation.t(msgid)
end

-- return translation from darktable
local function _dt(msgid)
  return GuiTranslation.tdt(msgid)
end

-- init ./Modules/LogHelper.lua
local indent = '. '
local LogHelper = require 'Modules.LogHelper'
LogHelper.Init()

-- init ./Modules/Helper.lua
local Helper = require 'Modules.Helper'
Helper.Init(dt, LogHelper, GuiTranslation, ModuleName)

if not Helper.CheckApiVersion() then
  return
end

LogHelper.Info(string.format(_("script executed from path %s"), ScriptFilePath()))
LogHelper.Info(string.format(_("script translation files in %s"), localePath))
LogHelper.Info(_("script outputs are in English"))

---------------------------------------------------------------

-- init ./Modules/EventHelper.lua
local EventHelper = require 'Modules.EventHelper'
EventHelper.Init(dt, LogHelper, Helper, GuiTranslation, ModuleName)

-- init ./Modules/GuiActionHelper
local GuiAction = require 'Modules.GuiAction'
GuiAction.Init(dt, LogHelper, Helper, EventHelper, GuiTranslation)

---------------------------------------------------------------

-- init ./Modules/Workflow.lua
local Workflow = require 'Modules.Workflow'
Workflow.Init(dt, LogHelper, Helper, EventHelper, GuiTranslation, GuiAction)

local WidgetStack =
{
  Modules = 1,
  Settings = 2,
  Stack = dt.new_widget("stack") {},
}

-- init ./Modules/Steps.lua
local WorkflowSteps = require 'Modules.WorkflowSteps'
WorkflowSteps.Init(dt, LogHelper, Helper, EventHelper, GuiTranslation, Workflow, GuiAction, WidgetStack, ScriptFilePath())

-- init ./Modules/Buttons.lua
local WorkflowButtons = require 'Modules.WorkflowButtons'
WorkflowButtons.Init(dt, LogHelper, Helper, EventHelper, GuiTranslation, Workflow, GuiAction, WidgetStack,
ScriptFilePath())

-- init widget controls
WorkflowSteps.CreateWorkflowSteps()
WorkflowButtons.CreateWorkflowButtons()

-- init ./Modules/GuiWidgets
local GuiWidgets = require 'Modules.GuiWidgets'
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

-- main entry function to install the module at startup
local function InstallInitialWorkflowModule()
  LogHelper.Info(_("create widget in lighttable and darkroom panels"))

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

  return true
end

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

---------------------------------------------------------------
