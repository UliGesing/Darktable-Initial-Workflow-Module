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

local indent = '. '

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

---------------------------------------------------------------
-- base class of workflow steps with ComboBox widget
Workflow.StepConfiguration = Workflow.ModuleStep:new():new
    {
        OperationNameInternal = nil,
        WidgetStackValue = nil,
        ConfigurationValues = nil,
        WidgetUnchangedStepConfigurationValue = nil,
        WidgetDefaultStepConfiguationValue = nil,
    }

-- create default basic widget of most workflow steps
function Workflow.StepConfiguration:CreateDefaultBasicWidget()
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
function Workflow.StepConfiguration:CreateLabelWidget()
    self.WidgetLabel = dt.new_widget('combobox')
        {
            label = self.Label,
            tooltip = self:GetLabelAndTooltip()
        }
end

-- create simple basic widget of some workflow steps
function Workflow.StepConfiguration:CreateSimpleBasicWidget()
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
function Workflow.StepConfiguration:CreateEmptyBasicWidget()
    self.WidgetBasicDefaultValue = 1

    self.BasicValues = { '' }

    self.WidgetBasic = dt.new_widget('combobox')
        {
            label = ' ',
            table.unpack(self.BasicValues)
        }
end

-- evaluate basic widget, common for most workflow steps
function Workflow.StepConfiguration:RunBasicWidget()
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
function Workflow.StepConfiguration:RunSimpleBasicWidget()
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

-- choose default step setting
function Workflow.StepConfiguration:EnableDefaultStepConfiguation()
    self.Widget.value = self.WidgetDefaultStepConfiguationValue
end

-- choose default basic setting
function Workflow.StepConfiguration:EnableDefaultBasicConfiguation()
    self.WidgetBasic.value = self.WidgetBasicDefaultValue
end

-- returns internal operation name like 'colorbalancergb' or 'atrous'
function Workflow.StepConfiguration:OperationName()
    return self.OperationNameInternal
end

-- returns operation path like 'iop/colorbalancergb'
function Workflow.StepConfiguration:OperationPath()
    return 'iop/' .. self:OperationName()
end

local PreferencePresetName = "Current"
local PreferencePrefixBasic = "Basic"
local PreferencePrefixConfiguration = "Config"

-- save current selections of this workflow step
-- used to restore settings after starting darktable
function Workflow.StepConfiguration:SavePreferenceValue()
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

-- read saved selection value from darktable preferences
-- used to restore settings after starting darktable
function Workflow.StepConfiguration:ReadPreferenceConfigurationValue()
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
function Workflow.StepConfiguration:SetWidgetBasicValue(value)
    for i, basicValue in ipairs(self.BasicValues) do
        if (value == basicValue) then
            if (self.WidgetBasic.value ~= i) then
                self.WidgetBasic.value = i
            end
            return
        end
    end

    self:EnableDefaultBasicConfiguation()
end

-- read saved selection value from darktable preferences
-- used to restore settings after starting darktable
function Workflow.StepConfiguration:ReadPreferenceBasicValue()
    -- preferences are saved separately for each user interface language
    -- user intercase uses translated names and values
    local prefixBasic = PreferencePresetName .. ":" .. PreferencePrefixBasic .. ":"
    local preferenceBasicName = prefixBasic .. _ReverseTranslation(self.Label)
    local preferenceBasicValue = _(dt.preferences.read(ModuleName, preferenceBasicName, 'string'))
    self:SetWidgetBasicValue(preferenceBasicValue)
end

-- combobox selection is returned as negative index value
-- convert negative index value to combobox string value
-- consider "unchanged" value: + 1
function Workflow.StepConfiguration:GetConfigurationValueFromSelectionIndex(index)
    return self.ConfigurationValues[(-index) + 1]
end

-- concat widget label and tooltip
function Workflow.StepConfiguration:GetLabelAndTooltip()
    return Helper.Wordwrap(self.Label .. ': ' .. self.Tooltip)
end

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

-- called after selection was changed
-- current settings are saved as darktable preferences
function Workflow.ComboBoxChangedCallback(widget)
    Workflow.GetStep(widget):SavePreferenceValue()
end

-- base class of workflow steps with Button widget
Workflow.StepButton = Workflow.ModuleStep:new():new
    {
    }

return Workflow
