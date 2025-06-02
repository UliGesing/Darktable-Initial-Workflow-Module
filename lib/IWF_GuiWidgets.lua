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

-- Implementation of visible widget frame. Create main widget, collect buttons
-- and comboboxes, add buttons to simplify some manual steps, add comboboxes
-- to configure workflow steps, collect all widgets to be displayed within the module.


local GuiWidgets = {}

function GuiWidgets.Init(_dt, _LogHelper, _Helper, _Workflow, _WidgetStack, _TranslationHelper)
    dt = _dt
    LogHelper = _LogHelper
    Helper = _Helper
    Workflow = _Workflow
    WidgetStack = _WidgetStack
    _TranslationHelper = _TranslationHelper
end

-- return translation from local .po / .mo file
local function _(msgid)
    return GuiTranslation.t(msgid)
end

-- return translation from darktable
local function _dt(msgid)
    return GuiTranslation.tdt(msgid)
end

local ResetAllCommonMainSettingsWidget
ResetAllCommonMainSettingsWidget = dt.new_widget('combobox')
    {
        changed_callback = function()
            local selection = ResetAllCommonMainSettingsWidget.value

            if (selection ~= _dt("all common settings")) then
                for i, step in ipairs(Workflow.ModuleSteps) do
                    if step.WidgetStackValue == WidgetStack.Settings then
                        if (step ~= StepTimeout) and (step ~= StepCreator) then
                            -- do not excecute a single step, if all configurations are changing, prevent chaos
                            step:DisableRunSingleStepOnSettingsChange()

                            if (selection == _("default")) then
                                LogHelper.Info(step.Label)
                                step:EnableDefaultStepConfiguation()
                            end

                            -- sleep for a short moment to give callback function a chance to run
                            -- callback function Workflow.ComboBoxChangedCallback calls Workflow.RunSingleStep
                            -- function Workflow.RunSingleStep checks the RunSingleStepOnSettingsChange flag
                            dt.control.sleep(100)

                            -- set default
                            step:EnableRunSingleStepOnSettingsChange()
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
                        if (step ~= StepTimeout) and (step ~= StepCreator) then
                            -- do not excecute a single step, if all configurations are changing, prevent chaos
                            step:DisableRunSingleStepOnSettingsChange()

                            if (selection == _("default")) then
                                step:EnableDefaultBasicConfiguation()
                            else
                                step:SetWidgetBasicValue(selection)
                            end

                            -- sleep for a short moment to give callback function a chance to run
                            -- callback function Workflow.ComboBoxChangedCallback calls Workflow.RunSingleStep
                            -- function Workflow.RunSingleStep checks the RunSingleStepOnSettingsChange flag
                            dt.control.sleep(100)

                            -- set default
                            step:EnableRunSingleStepOnSettingsChange()
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
                        if (step ~= StepTimeout) and (step ~= StepCreator) then
                            -- do not excecute a single step, if all configurations are changing, prevent chaos
                            step:DisableRunSingleStepOnSettingsChange()

                            if (selection == _("default")) then
                                step:EnableDefaultStepConfiguation()
                            elseif (selection == _("unchanged")) then
                                -- choose 'unchanged' step setting
                                -- configuration keeps unchanged during script execution
                                step.Widget.value = step.WidgetUnchangedStepConfigurationValue
                            end

                            -- sleep for a short moment to give callback function a chance to run
                            -- callback function Workflow.ComboBoxChangedCallback calls Workflow.RunSingleStep
                            -- function Workflow.RunSingleStep checks the RunSingleStepOnSettingsChange flag
                            dt.control.sleep(100)

                            -- set default
                            step:EnableRunSingleStepOnSettingsChange()
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

----------------------------------------------------------

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
function GuiWidgets.GetWidgets()
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

return GuiWidgets
