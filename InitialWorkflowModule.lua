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

local Env =
{
  InstallModuleEventRegistered = false,
  InstallModuleDone = false,
}

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
WorkflowButtons.Init(dt, LogHelper, Helper, EventHelper, GuiTranslation, Workflow, GuiAction, WidgetStack, ScriptFilePath())

WorkflowSteps.CreateWorkflowSteps()
WorkflowButtons.CreateWorkflowButtons()

---------------------------------------------------------------
--[[

      IMPLEMENTATION OF WIDGET FRAME

      Create main widget. Collect buttons and comboboxes.

    ]]
---------------------------------------------------------------

local ResetAllCommonMainSettingsWidget
ResetAllCommonMainSettingsWidget = dt.new_widget('combobox')
    {
      changed_callback = function()
        local selection = ResetAllCommonMainSettingsWidget.value

        if (selection ~= _dt("all common settings")) then
          for i, step in ipairs(Workflow.ModuleSteps) do
            if step.WidgetStackValue == WidgetStack.Settings then
              if (step ~= StepTimeout) then
                if (selection == _("default")) then
                  LogHelper.Info(step.Label)
                  step:EnableDefaultStepConfiguation()
                end
              end
            end
          end

          -- reset to default selection
          ResetAllCommonMainSettingsWidget.value = 1
        end
      end,
      label = ' ',
      tooltip = Helper.Wordwrap(_(
        "Configure all following common settings: Reset all steps to default configurations. These settings are applied during script run, if corresponding step is enabled.")),
      table.unpack({ _dt("all common settings"), _("default") })
    }

local ResetAllModuleBasicSettingsWidget
ResetAllModuleBasicSettingsWidget = dt.new_widget('combobox')
    {
      changed_callback = function()
        local selection = ResetAllModuleBasicSettingsWidget.value

        if (selection ~= _dt("all module basics")) then
          for i, step in ipairs(Workflow.ModuleSteps) do
            if step.WidgetStackValue == WidgetStack.Modules then
              if (step ~= StepTimeout) then
                if (selection == _("default")) then
                  step:EnableDefaultBasicConfiguation()
                else
                  step:SetWidgetBasicValue(selection)
                end
              end
            end
          end

          -- reset to default selection
          ResetAllModuleBasicSettingsWidget.value = 1
        end
      end,
      label = ' ',
      tooltip = Helper.Wordwrap(_(
        "Configure all module settings: a) Select default value. b) Ignore this step / module and do nothing at all. c) Enable corresponding module and set selected module configuration. d) Reset the module and set selected module configuration. e) Disable module and keep it unchanged.")),
      table.unpack({ _dt("all module basics"), _("default"), _("ignore"), _("enable"), _("reset"), _("disable") })
    }

local ResetAllModuleMainSettingsWidget
ResetAllModuleMainSettingsWidget = dt.new_widget('combobox')
    {
      changed_callback = function()
        local selection = ResetAllModuleMainSettingsWidget.value

        if (selection ~= _dt("all module settings")) then
          for i, step in ipairs(Workflow.ModuleSteps) do
            if step.WidgetStackValue == WidgetStack.Modules then
              if (step ~= StepTimeout) then
                if (selection == _("default")) then
                  step:EnableDefaultStepConfiguation()
                elseif (selection == _("unchanged")) then
                  -- choose 'unchanged' step setting
                  -- configuration keeps unchanged during script execution
                  step.Widget.value = step.WidgetUnchangedStepConfigurationValue
                end
              end
            end
          end

          -- reset to default selection
          ResetAllModuleMainSettingsWidget.value = 1
        end
      end,
      label = ' ',
      tooltip = Helper.Wordwrap(_(
        "Configure all module settings: Keep all modules unchanged or enable all default configurations. These configurations are set, if you choose 'reset' or 'enable' as basic setting.")),
      table.unpack({ _dt("all module settings"), _("default"), _("unchanged") })
    }

----------------------------------------------------------

-- TEST button: Special buttons, used to perform module tests.
local function GetWidgetTestButtons(widgets)
  if (ButtonModuleTest) then
    LogHelper.Info(_("insert test button widget"))
    table.insert(widgets,
      dt.new_widget('box')
      {
        orientation = 'horizontal',
        ButtonModuleTest.Widget,
        ButtonModuleTestCustomCode.Widget
      }
    )
  end
end

-- add buttons to simplify some manual steps
local function GetWidgetOverallButtons(widgets)
  local buttonColumn1 = {}
  local buttonColumn2 = {}
  local buttonColumn3 = {}

  -- add overall function buttons, first column
  table.insert(buttonColumn1, ButtonEnableRotateAndPerspective.Widget)
  table.insert(buttonColumn1, ButtonRunSelectedSteps.Widget)

  -- ... second column
  table.insert(buttonColumn2, ButtonEnableCrop.Widget)
  table.insert(buttonColumn2, ButtonShowWidgetStackModules.Widget)

  -- ... third column
  table.insert(buttonColumn3, ButtonMidToneExposure.Widget)
  table.insert(buttonColumn3, ButtonShowWidgetStackSettings.Widget)

  table.insert(widgets,
    dt.new_widget('box')
    {
      orientation = 'horizontal',

      dt.new_widget('box') {
        orientation = 'vertical',
        table.unpack(buttonColumn1),
      },

      dt.new_widget('box') {
        orientation = 'vertical',
        table.unpack(buttonColumn2),
      },

      dt.new_widget('box') {
        orientation = 'vertical',
        table.unpack(buttonColumn3),
      },
    }
  )
end

-- add comboboxes to configure workflow steps
local function GetWidgetModulesBox()
  -- add workflow step controls
  -- first column: label widgets
  -- second column: basic widgets (reset, enable, ignore...)
  -- third column: step configuration combobox widgets

  local labelWidgetsModules = {}
  local basicWidgetsModules = {}
  local comboBoxWidgetsModules = {}

  -- add comboboxes to configure or reset all configurations

  table.insert(labelWidgetsModules, dt.new_widget('label') { label = ' ' })
  table.insert(basicWidgetsModules, ResetAllModuleBasicSettingsWidget)
  table.insert(comboBoxWidgetsModules, ResetAllModuleMainSettingsWidget)

  table.insert(labelWidgetsModules, dt.new_widget('label') { label = ' ' })
  table.insert(basicWidgetsModules, dt.new_widget('label') { label = ' ' })
  table.insert(comboBoxWidgetsModules, dt.new_widget('label') { label = ' ' })

  for i, step in ipairs(Workflow.ModuleSteps) do
    if step.WidgetStackValue == WidgetStack.Modules then
      table.insert(labelWidgetsModules, step.WidgetLabel)
      table.insert(basicWidgetsModules, step.WidgetBasic)
      table.insert(comboBoxWidgetsModules, step.Widget)
    end
  end

  local box = dt.new_widget('box')
      {
        orientation = 'horizontal',

        dt.new_widget('box') {
          orientation = 'vertical',
          table.unpack(labelWidgetsModules),
        },

        dt.new_widget('box') {
          orientation = 'vertical',
          table.unpack(basicWidgetsModules),
        },

        dt.new_widget('box') {
          orientation = 'vertical',
          table.unpack(comboBoxWidgetsModules),
        },
      }

  return box
end

-- add comboboxes to configure workflow steps
local function GetWidgetSettingsBox()
  -- add setting controls

  local labelWidgetsSettings = {}
  local basicWidgetsSettings = {}
  local comboBoxWidgetsSettings = {}

  -- add comboboxes to configure or reset all configurations

  table.insert(labelWidgetsSettings, dt.new_widget('label') { label = ' ' })
  table.insert(basicWidgetsSettings, dt.new_widget('label') { label = ' ' })
  table.insert(comboBoxWidgetsSettings, ResetAllCommonMainSettingsWidget)

  table.insert(labelWidgetsSettings, dt.new_widget('label') { label = ' ' })
  table.insert(basicWidgetsSettings, dt.new_widget('label') { label = ' ' })
  table.insert(comboBoxWidgetsSettings, dt.new_widget('label') { label = ' ' })

  -- add setting controls

  for i, step in ipairs(Workflow.ModuleSteps) do
    if step.WidgetStackValue == WidgetStack.Settings then
      table.insert(labelWidgetsSettings, step.WidgetLabel)
      table.insert(basicWidgetsSettings, step.WidgetBasic)
      table.insert(comboBoxWidgetsSettings, step.Widget)
    end
  end

  local box = dt.new_widget('box')
      {
        orientation = 'horizontal',

        dt.new_widget('box') {
          orientation = 'vertical',
          table.unpack(labelWidgetsSettings),
        },

        dt.new_widget('box') {
          orientation = 'vertical',
          table.unpack(basicWidgetsSettings),
        },

        dt.new_widget('box') {
          orientation = 'vertical',
          table.unpack(comboBoxWidgetsSettings),
        },
      }

  return box
end

-- collect all widgets to be displayed within the module
-- collect buttons and comboboxes (basic and configuration)
-- the order in the GUI is the same as the order of declaration in this function.
local function GetWidgets()
  local widgets = {}

  GetWidgetTestButtons(widgets)
  GetWidgetOverallButtons(widgets)
  local boxModules = GetWidgetModulesBox()
  local boxSettings = GetWidgetSettingsBox()

  -- create widget stack
  WidgetStack.Stack[WidgetStack.Modules] = boxModules
  WidgetStack.Stack[WidgetStack.Settings] = boxSettings
  WidgetStack.Stack.active = WidgetStack.Modules

  table.insert(widgets, WidgetStack.Stack)

  return widgets
end

---------------------------------------------------------------

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
        table.unpack(GetWidgets()),
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
