--[[
  This lua file is part of Darktable Initial Workflow Module

  copyright (c) 2022 Ulrich Gesing

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

-- This file provides the base class of workflow steps. Collect all
-- workflow steps in a table. This table is used to execute or configure
-- all steps at once. Collect button widgets in a table, used during
-- callback functions.

-- Show, hide, enable, disable or reset darktable modules.

-- Save current workflow configurations, used to restore settings after
-- starting darktable. Read saved selection value from darktable preferences.

local Workflow = {}

function Workflow.Init(_dt, _LogHelper, _Helper, _EventHelper, _TranslationHelper, _GuiAction)
    dt = _dt
    LogHelper = _LogHelper
    Helper = _Helper
    EventHelper = _EventHelper
    GuiTranslation = _TranslationHelper
    GuiAction = _GuiAction
end

-- return translation from local .po / .mo file
local function _(msgid)
    return GuiTranslation.t(msgid)
end

-- return translation from darktable
local function _dt(msgid)
    return GuiTranslation.tdt(msgid)
end

-- return reverse translation
local function _ReverseTranslation(msgid)
    return GuiTranslation.GetReverseTranslation(msgid)
end


-- collect all workflow steps in a table
-- used to execute or configure all steps at once
Workflow.ModuleSteps = {}

-- workflow buttons: collect button widgets in a table
-- used during callback functions
Workflow.Buttons = {}

---------------------------------------------------------------

-- base class of all workflow steps
Workflow.ModuleStep =
{
    Widget = nil,
    WidgetBasic = nil,
    Tooltip = nil,
}

-- workflow step base class constructor
function Workflow.ModuleStep:new(obj)
    -- create object if user does not provide one
    obj = obj or {}
    -- define inheritance
    setmetatable(obj, self)
    self.__index = self
    -- return new object
    return obj
end

-- message at the beginning of a step
function Workflow.ModuleStep:LogStepMessage()
    LogHelper.Info('==============================')
    ---@diagnostic disable-next-line: undefined-field
    LogHelper.Info(string.format(_("selection = %s - %s"), self.WidgetBasic.value, self.Widget.value))
end

-- handle view changed event (lighttable / darkroom view)
-- some comboboxes or buttons need a special handling
function Workflow.ModuleStep:InitDependingOnCurrentView()
    -- do nothing by default
end

-- create default basic widget of most workflow steps
function Workflow.ModuleStep:CreateDefaultBasicWidget()
    self.WidgetBasicDefaultValue = 4

    self.BasicValues = { _("default"), _("ignore"), _("enable"), _("reset"), _("disable") }

    self.WidgetBasic = dt.new_widget('combobox')
        {
            changed_callback = function(widget)
                local changedStep = Workflow.GetStep(widget)
                if (changedStep ~= nil) then
                    if (changedStep.WidgetBasic.value == _("default")) then
                        changedStep:EnableDefaultBasicConfiguation()
                    end
                end
                Workflow.ComboBoxChangedCallback(widget)
            end,

            label = ' ',
            tooltip = Helper.Wordwrap(self.Label .. ' ' .. _(
                "basic setting: a) Select default value. b) Ignore this step / module and do nothing at all. c) Enable corresponding module and set selected module configuration. d) Reset the module and set selected module configuration. e) Disable module and keep it unchanged.")),
            table.unpack(self.BasicValues)
        }
end

-- create label widget
function Workflow.ModuleStep:CreateLabelWidget()
    self.WidgetLabel = dt.new_widget('combobox')
        {
            label = self.Label,
            tooltip = self:GetLabelAndTooltip()
        }
end

-- concat widget label and tooltip
function Workflow.ModuleStep:GetLabelAndTooltip()
    return Helper.Wordwrap(self.Label .. ': ' .. self.Tooltip)
end

-- create simple basic widget of some workflow steps
function Workflow.ModuleStep:CreateSimpleBasicWidget()
    self.WidgetBasicDefaultValue = 2

    self.BasicValues = { _("ignore"), _("enable") }

    self.WidgetBasic = dt.new_widget('combobox')
        {
            changed_callback = Workflow.ComboBoxChangedCallback,
            label = ' ',
            tooltip = Helper.Wordwrap(self.Label .. ' ' .. _("basic setting: Ignore this module or do corresponding configuration.")),
            table.unpack(self.BasicValues)
        }
end

-- create empty invisible basic widget
function Workflow.ModuleStep:CreateEmptyBasicWidget()
    self.WidgetBasicDefaultValue = 1

    self.BasicValues = { '' }

    self.WidgetBasic = dt.new_widget('combobox')
        {
            label = ' ',
            table.unpack(self.BasicValues)
        }
end

-- evaluate basic widget, common for most workflow steps
function Workflow.ModuleStep:RunBasicWidget()
    local basic = self.WidgetBasic.value
    if (basic == '') then
        return true
    end

    if (basic == _("ignore")) then
        return false
    end

    self:LogStepMessage()

    if (basic == _("disable")) then
        GuiAction.DisableDarkroomModule(self:OperationPath())
        return false
    end

    if (basic == _("enable")) then
        GuiAction.EnableDarkroomModule(self:OperationPath())
        return true
    end

    if (basic == _("reset")) then
        GuiAction.EnableDarkroomModule(self:OperationPath())
        GuiAction.ResetDarkroomModule(self:OperationPath())
        return true
    end

    return true
end

-- evaluate basic widget, common for some workflow steps
function Workflow.ModuleStep:RunSimpleBasicWidget()
    local basic = self.WidgetBasic.value
    if (basic == '') then
        return true
    end

    if (basic == _("ignore")) then
        return false
    end

    self:LogStepMessage()

    if (basic == _("enable")) then
        if (self:OperationName() ~= nil) then
            GuiAction.EnableDarkroomModule(self:OperationPath())
        end
        return true
    end

    return true
end

---------------------------------------------------------------

local PreferencePresetName = "Current"
local PreferencePrefixBasic = "Basic"
local PreferencePrefixConfiguration = "Config"

-- save current selections of this workflow step
-- used to restore settings after starting darktable
function Workflow.ModuleStep:SavePreferenceValue()
    -- check, if there are any changes
    -- preferences are saved with english names and values
    -- user interfase uses translated names and values

    -- save any changes of the configuration combobox value
    local prefix = PreferencePresetName .. ":" .. PreferencePrefixConfiguration .. ":"
    local preferenceName = prefix .. _ReverseTranslation(self.Label)
    local preferenceValue = dt.preferences.read(ModuleName, preferenceName, 'string')
    local configurationValue = _ReverseTranslation(self.Widget.value)

    if (preferenceValue ~= configurationValue) then
        dt.preferences.write(ModuleName, preferenceName, 'string', configurationValue)
    end

    -- save any changes of the basic combobox value
    local prefixBasic = PreferencePresetName .. ":" .. PreferencePrefixBasic .. ":"
    local preferenceBasicName = prefixBasic .. _ReverseTranslation(self.Label)
    local preferenceBasicValue = dt.preferences.read(ModuleName, preferenceBasicName, 'string')
    local basicValue = _ReverseTranslation(self.WidgetBasic.value)

    if (preferenceBasicValue ~= basicValue) then
        dt.preferences.write(ModuleName, preferenceBasicName, 'string', basicValue)
    end
end

-- read saved value from darktable preferences
-- used to restore settings after starting darktable
function Workflow.ModuleStep:ReadPreferenceConfigurationValue()
    -- preferences are saved with english names and values
    -- user intercase uses translated names and values
    local prefix = PreferencePresetName .. ":" .. PreferencePrefixConfiguration .. ":"
    local preferenceName = prefix .. _ReverseTranslation(self.Label)
    local preferenceValue = _(dt.preferences.read(ModuleName, preferenceName, 'string'))

    -- get combo box index of saved preference value
    for i, configurationValue in ipairs(self.ConfigurationValues) do
        if (preferenceValue == configurationValue) then
            if (self.Widget.value ~= i) then
                self.Widget.value = i
            end
            return
        end
    end

    self:EnableDefaultStepConfiguation()
end

-- select widget value
-- get combo box index of given value
function Workflow.ModuleStep:SetWidgetBasicValue(value)
    for i, basicValue in ipairs(self.BasicValues) do
        if (value == basicValue) then
            if (self.WidgetBasic.value ~= i) then
                self.WidgetBasic.value = i
            end
            return
        end
    end

    -- basic configuration ("reset" or "disable" not supported by this step?
    -- switch to "ignore" and try again
    if ((value == "reset") or (value == "disable")) then
        value = "ignore"
    end

    for i, basicValue in ipairs(self.BasicValues) do
        if (value == basicValue) then
            if (self.WidgetBasic.value ~= i) then
                self.WidgetBasic.value = i
            end
            return
        end
    end

    -- fallback: set default value
    self:EnableDefaultBasicConfiguation()
end

-- read saved value from darktable preferences
-- used to restore settings after starting darktable
function Workflow.ModuleStep:ReadPreferenceBasicValue()
    -- preferences are saved separately for each user interface language
    -- user intercase uses translated names and values
    local prefixBasic = PreferencePresetName .. ":" .. PreferencePrefixBasic .. ":"
    local preferenceBasicName = prefixBasic .. _ReverseTranslation(self.Label)
    local preferenceBasicValue = _(dt.preferences.read(ModuleName, preferenceBasicName, 'string'))
    self:SetWidgetBasicValue(preferenceBasicValue)
end

---------------------------------------------------------------

-- base class of workflow steps with Button widget
Workflow.StepButton = Workflow.ModuleStep:new():new
    {
    }

---------------------------------------------------------------

-- base class of workflow steps with text entry widget
Workflow.StepTextEntry = Workflow.ModuleStep:new():new
    {
    }


-- save current selections of this workflow step
-- used to restore settings after starting darktable
function Workflow.StepTextEntry:SavePreferenceValue()
    -- check, if there are any changes
    -- preferences are saved with english names and values
    -- user interfase uses translated names and values

    -- save any changes of the configuration combobox value
    local prefix = PreferencePresetName .. ":" .. PreferencePrefixConfiguration .. ":"
    local preferenceName = prefix .. _ReverseTranslation(self.Label)
    local preferenceValue = dt.preferences.read(ModuleName, preferenceName, 'string')

    -- lua_entry: use text property instead of value property
    local configurationValue = _ReverseTranslation(self.Widget.text)

    if (preferenceValue ~= configurationValue) then
        dt.preferences.write(ModuleName, preferenceName, 'string', configurationValue)
    end

    -- save any changes of the basic combobox value
    local prefixBasic = PreferencePresetName .. ":" .. PreferencePrefixBasic .. ":"
    local preferenceBasicName = prefixBasic .. _ReverseTranslation(self.Label)
    local preferenceBasicValue = dt.preferences.read(ModuleName, preferenceBasicName, 'string')
    local basicValue = _ReverseTranslation(self.WidgetBasic.value)

    if (preferenceBasicValue ~= basicValue) then
        dt.preferences.write(ModuleName, preferenceBasicName, 'string', basicValue)
    end
end

-- read saved value from darktable preferences
-- used to restore settings after starting darktable
function Workflow.StepTextEntry:ReadPreferenceConfigurationValue()
    -- preferences are saved with english names and values
    -- user intercase uses translated names and values
    local prefix = PreferencePresetName .. ":" .. PreferencePrefixConfiguration .. ":"
    local preferenceName = prefix .. _ReverseTranslation(self.Label)
    local preferenceValue = _(dt.preferences.read(ModuleName, preferenceName, 'string'))

    if (self.Widget.text ~= preferenceValue) then
        self.Widget.text = preferenceValue
    end

    self:EnableDefaultStepConfiguation()
end

---------------------------------------------------------------

-- base class of workflow steps with ComboBox widget
Workflow.StepComboBox = Workflow.ModuleStep:new():new
    {
        -- some basic settings that are overwritten in derived classes
        OperationNameInternal = nil,
        WidgetStackValue = nil,
        ConfigurationValues = nil,
        WidgetUnchangedStepConfigurationValue = nil,
        WidgetDefaultStepConfiguationValue = nil,
        RunSingleStepOnSettingsChange = true,
    }

-- enable flag
function Workflow.StepComboBox:EnableRunSingleStepOnSettingsChange()
    self.RunSingleStepOnSettingsChange = true
end

-- disable flag
function Workflow.StepComboBox:DisableRunSingleStepOnSettingsChange()
    self.RunSingleStepOnSettingsChange = false
end

-- check flag
function Workflow.StepComboBox:CheckRunSingleStepOnSettingsChange()
    return self.RunSingleStepOnSettingsChange
end

-- choose default step setting
function Workflow.StepComboBox:EnableDefaultStepConfiguation()
    self.Widget.value = self.WidgetDefaultStepConfiguationValue
end

-- choose default basic setting
function Workflow.StepComboBox:EnableDefaultBasicConfiguation()
    self.WidgetBasic.value = self.WidgetBasicDefaultValue
end

-- returns internal operation name like 'colorbalancergb' or 'atrous'
function Workflow.StepComboBox:OperationName()
    return self.OperationNameInternal
end

-- returns operation path like 'iop/colorbalancergb'
function Workflow.StepComboBox:OperationPath()
    return 'iop/' .. self:OperationName()
end

-- show darkroom module during step execution
-- see override for some special steps
function Workflow.StepComboBox:ShowDarkroomModuleDuringStepRun()
    return true
end

---------------------------------------------------------------

-- combobox selection is returned as negative index value
-- convert negative index value to combobox string value
-- consider "unchanged" value: + 1
function Workflow.StepComboBox:GetConfigurationValueFromSelectionIndex(index)
    return self.ConfigurationValues[(-index) + 1]
end

---------------------------------------------------------------

-- called from callback function within a 'foreign context'
-- we have to determine the button object or workflow step first
function Workflow.GetItem(widget, table)
    for i, item in ipairs(table) do
        if (item.Widget == widget) then
            return item
        end
        if (item.WidgetBasic == widget) then
            return item
        end
    end
    return nil
end

-- called from callback function within a 'foreign context'
-- determine the button object
function Workflow.GetButton(widget)
    return Workflow.GetItem(widget, Workflow.Buttons)
end

-- called from callback function within a 'foreign context'
-- determine the step object
function Workflow.GetStep(widget)
    return Workflow.GetItem(widget, Workflow.ModuleSteps)
end

-- run single step, if selection / combobox / setting was changed by user
-- callback function Workflow.ComboBoxChangedCallback calls Workflow.RunSingleStep
-- when a single setting changes, execute individual workflow steps and configure a single module.
-- This allows you to see the changes made by each configuration without having to execute the entire workflow.
-- run single step, if the setting has been configured accordingly
function Workflow.RunSingleStep(step)
    -- run single step from darkroom view only
    local currentView = dt.gui.current_view()
    if (currentView ~= dt.gui.views.darkroom) then
        return
    end

    -- run single step after configuration was changed, if configured accordingly.
    -- user can enable this by activating "run single steps on change"
    if (StepRunSingleStepOnSettingsChange:Value() == false) then
        return
    end

    -- return, if e.g. combobox "all module settings" was selected
    -- do not excecute a single step, if all configurations are changing, prevent chaos
    if (not step:CheckRunSingleStepOnSettingsChange()) then
        return
    end

    -- run single step, but ignore common settings
    if (step.WidgetStackValue == WidgetStack.Settings) then
        return
    end

    if (step:ShowDarkroomModuleDuringStepRun()) then
        -- show active modules in darkroom view
        GuiAction.DoWithoutEvent('lib/modulegroups/active modules', 0, '', 'on', 1.0)

        -- show corresponding darkroom module
        GuiAction.ShowDarkroomModule(step:OperationPath())
    end
    
    -- execute workflow step
    LogHelper.CurrentStep = step.Label
    LogHelper.Screen(step.Label)
    step:Run()
    LogHelper.CurrentStep = ''

    LogHelper.Screen("Done")
end

-- called after selection / combobox / setting was changed by user
-- current settings are saved as darktable preferences
function Workflow.ComboBoxChangedCallback(widget)
    local step = Workflow.GetStep(widget)
    if (step == nil) then
        return
    end

    -- save current setting
    step:SavePreferenceValue()

    -- run single step
    Workflow.RunSingleStep(step)
end

return Workflow
