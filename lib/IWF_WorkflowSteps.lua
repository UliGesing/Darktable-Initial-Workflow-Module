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

--[[
  This file contains the implementation of workflow steps. Every step configures
  a darktable module. You can easily customize steps or add new ones.

  All steps are derived from a base class to offer common methods. You can easily
  customize steps or add new ones: Just copy an existing class and adapt the label,
  tooltip and function accordingly. Copy and adapt Constructor, Init and Run functions.
  Don't forget to customize the name of the class as well. Use the new class name for
  Constructor, Init and Run functions.

  By adding it to the "WorkflowSteps" table, the step is automatically displayed and
  executed. The order in the GUI is the same as the order of declaration here in the
  code. The order during execution is from bottom to top, along the pixel pipeline.

  You can get the lua command to perform a specific task as described here:
  https://darktable-org.github.io/dtdocs/en/preferences-settings/shortcuts/

  Click on the small icon in the top panel as described in “assigning shortcuts
  to actions”. You enter visual shortcut mapping mode. Point to a module or GUI control.
  Within the popup you can read the lua command. The most flexible way is to use the
  shortcut mapping screen, create and edit a shortcut (action, element and effect),
  read the lua command from popup windows or copy it to your clipboard (ctrl+v).

  Every workflow step contains of constructor, init and run functions. Example:

  StepCompressHistoryStack = WorkflowStepCombobox:new():new {}
  to create the new instance.

  table.insert(WorkflowSteps, StepCompressHistoryStack)
  to collect all steps and execute them later on.

  function StepCompressHistoryStack:PostConstructor()
  to define common variables for each module step.

  function StepCompressHistoryStack:Init()
  to define combobox values and create the widget.

  function StepCompressHistoryStack:Run()
  to execute the step

  It is not possible to debug your script code directly. If you change your script code,
  you have to restart darktable to apply your changes. But you can run dt.gui.action
  commands on the fly:

  Create a file named "TestFlag.txt" in the same directory as the script file and restart
  darktable. From now there are new buttons, used to perform the module tests.

  The git repository contains one additional file named TestCustomCode.lua. You can use
  it to try some commands or tests "on the fly". This file contains some custom debug code.
  The code is executed by clicking the "Custom Code" button. It can be changed without
  restarting darktable. This is helpful, if you want to run some special tests or execute
  some dt.gui.action commands.
]]

local WorkflowSteps = {}

local indent = '. '

function WorkflowSteps.Init(_dt, _LogHelper, _Helper, _EventHelper, _TranslationHelper, _Workflow, _GuiAction,
                            _WidgetStack, _ScriptFilePath)
    dt = _dt
    LogHelper = _LogHelper
    Helper = _Helper
    EventHelper = _EventHelper
    GuiTranslation = _TranslationHelper
    Workflow = _Workflow
    GuiAction = _GuiAction
    WidgetStack = _WidgetStack
    ScriptFilePath = _ScriptFilePath
end

-- called from darktable exit event
function WorkflowSteps.OnDarktableExit()
    StepCreator:SavePreferenceValue()
end

-- return translation from local .po / .mo file
local function _(msgid)
    return GuiTranslation.t(msgid)
end

-- return translation from darktable
local function _dt(msgid)
    return GuiTranslation.tdt(msgid)
end

local function _dtConcat(msgid)
    return GuiTranslation.dtConcat(msgid)
end

-- return reverse translation
local function _ReverseTranslation(msgid)
    return GuiTranslation.GetReverseTranslation(msgid)
end

function WorkflowSteps.CreateWorkflowSteps()
    ---------------------------------------------------------------
    --- This function contains the implementation of all workflow steps.
    --- Every step configures a darktable module.
    ---------------------------------------------------------------

    StepCompressHistoryStack = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepCompressHistoryStack)

    function StepCompressHistoryStack:PostConstructor()
        -- darktable internal module name abbreviation
        -- operation = nil: ignore this module during module reset
        self.OperationNameInternal = nil
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Settings

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues = { _dt("no"), _dt("yes") }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 2

        self.Label = _dt("compress history stack")

        self.Tooltip = _(
            "Generate the shortest history stack that reproduces the current image. This removes your current history snapshots.")
    end

    function StepCompressHistoryStack:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show empty invisible step initialization combobox in 2nd column (settings subpage)
        self:CreateEmptyBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepCompressHistoryStack:Run()
        -- evaluate basic widget
        if (not self:RunSimpleBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _dt("yes")) then
            GuiAction.Do('lib/history/compress history stack', 0, '', '', 1.0)
        end
    end

    ---------------------------------------------------------------

    StepDynamicRangeSceneToDisplay = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepDynamicRangeSceneToDisplay)

    function StepDynamicRangeSceneToDisplay:PostConstructor()
        -- darktable internal module name abbreviation
        -- this step refers to different modules
        self.OperationNameInternal = 'Filmic - Sigmoid - AgX'

        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        self.filmicAutoTuneLevels = _dtConcat({ "filmic", ' ', "auto tune levels" })
        self.filmicHighlightReconstruction = _dtConcat({ "filmic", ' + ', "highlight reconstruction" })

        self.sigmoidDefault = _dtConcat({ "sigmoid", ' ', "scene-referred default" })
        self.sigmoidAces100Preset = _dtConcat({ "sigmoid", ' ', "ACES 100-nit like" })
        self.sigmoidNeutralGrayPreset = _dtConcat({ "sigmoid", ' ', "neutral gray" })

        self.agxDefault = _dtConcat({ "agx" })
        self.agxDefaultAutoTune = _dtConcat({ "agx", ' + ', "auto tune levels" })
        self.agxBlenderBasePreset = _dtConcat({ "agx", ' ', "blender-like", ' ', "base" })
        self.agxBlenderBasePresetAutoTune = _dtConcat({ "agx", ' ', "blender", ' ', "base", ' + ', 'auto tune' })
        self.agxSmoothBasePreset = _dtConcat({ "agx", ' ', "smooth", ' ', "base" })
        self.agxSmoothBasePresetAutoTune = _dtConcat({ "agx", ' ', "smooth", ' ', "base", ' + ', 'auto tune' })

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"),
            self.filmicAutoTuneLevels,
            self.filmicHighlightReconstruction,
            self.sigmoidDefault,
            self.sigmoidAces100Preset,
            self.sigmoidNeutralGrayPreset,
            self.agxDefault,
            self.agxDefaultAutoTune,
            self.agxBlenderBasePreset,
            self.agxBlenderBasePresetAutoTune,
            self.agxSmoothBasePreset,
            self.agxSmoothBasePresetAutoTune
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 10

        self.Label = _dtConcat({ "filmic", '/', "sigmoid", '/', "agx" })

        self.Tooltip = _(
            "Use Filmic, Sigmoid or AgX to expand or contract the dynamic range of the scene to fit the dynamic range of the display. Auto tune filmic or agx levels of black + white relative exposure. Or use a predefined preset. Use only one of Filmic, Sigmoid, AgX or Basecurve, other modules are disabled.")
    end

    function StepDynamicRangeSceneToDisplay:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show step initialization comb-- show step initialization combobox in 2nd column: ignore, enable, reset or disable module first
        self:CreateDefaultBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    -- true, if one of filmic module configurations was selected
    function StepDynamicRangeSceneToDisplay:FilmicSelected()
        return Helper.Contains(
            { self.filmicAutoTuneLevels,
                self.filmicHighlightReconstruction
            }, self.Widget.value)
    end

    -- true, if one of sigmoid module configurations was selected
    function StepDynamicRangeSceneToDisplay:SigmoidSelected()
        return Helper.Contains(
            { self.sigmoidDefault,
                self.sigmoidNeutralGrayPreset,
                self.sigmoidAces100Preset
            }, self.Widget.value)
    end

    -- true, if one of AgX module configurations was selected
    function StepDynamicRangeSceneToDisplay:AgXSelected()
        return Helper.Contains(
            { self.agxDefault,
                self.agxDefaultAutoTune,
                self.agxBlenderBasePreset,
                self.agxBlenderBasePresetAutoTune,
                self.agxSmoothBasePreset,
                self.agxSmoothBasePresetAutoTune
            }, self.Widget.value)
    end

    -- override base class function
    -- distinguish between filmic, sigmoid and agx module
    function StepDynamicRangeSceneToDisplay:OperationName()
        if (self:FilmicSelected()) then
            return 'filmicrgb'
        end

        if (self:SigmoidSelected()) then
            return 'sigmoid'
        end

        if (self:AgXSelected()) then
            return 'agx'
        end

        return 'agx'
    end

    function StepDynamicRangeSceneToDisplay:Run()
        -- special handling (Filmic/Sigmoid/Basecurve)
        -- do nothing or disable corresponding modules
        local basic = self.WidgetBasic.value
        if (basic == _("ignore")) then
            return
        end

        if (basic == _("disable")) then
            GuiAction.DisableDarkroomModule(self:OperationPath())
            return false
        end

        -- use only one of Filmic, Sigmoid, AgX or Basecurve
        -- other modules are disabled.
        GuiAction.DisableDarkroomModule('iop/basecurve')

        if (not self:FilmicSelected()) then
            GuiAction.DisableDarkroomModule('iop/filmicrgb')
        end

        if (not self:SigmoidSelected()) then
            GuiAction.DisableDarkroomModule('iop/sigmoid')
        end

        if (not self:AgXSelected()) then
            GuiAction.DisableDarkroomModule('iop/agx')
        end

        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        -- configure filmic module
        if (self:FilmicSelected()) then
            GuiAction.ButtonOffOn('iop/filmicrgb/auto tune levels')

            if (selection == self.filmicHighlightReconstruction) then
                local checkbox = GuiAction.GetValue('iop/filmicrgb/enable highlight reconstruction', '')
                if (checkbox == 0) then
                    GuiAction.Do('iop/filmicrgb/enable highlight reconstruction', 0, '', 'on', 1.0)
                else
                    LogHelper.Info(indent .. _("checkbox already selected, nothing to do"))
                end
            end
        end

        -- configure sigmoid module
        if (self:SigmoidSelected()) then
            if (selection == self.sigmoidDefault) then
                GuiAction.SelectModulePreset('iop/sigmoid/preset/', '', 'scene-referred default')
            end

            if (selection == self.sigmoidNeutralGrayPreset) then
                GuiAction.SelectModulePreset('iop/sigmoid/preset/', '', 'neutral gray')
            end

            if (selection == self.sigmoidAces100Preset) then
                GuiAction.SelectModulePreset('iop/sigmoid/preset/', '', 'ACES 100-nit like')
            end
        end

        -- configure agx module
        if (self:AgXSelected()) then
            if (selection == self.agxDefault) then
                -- use default settings, nothing to do
            end

            if (selection == self.agxDefaultAutoTune) then
                GuiAction.Do("iop/agx/exposure range/auto tune levels", 0, '', 'toggle', 1.0)
            end

            if (selection == self.agxBlenderBasePreset) then
                GuiAction.SelectModulePreset('iop/agx/preset/', '', 'blender-like|base')
            end

            if (selection == self.agxBlenderBasePresetAutoTune) then
                GuiAction.SelectModulePreset('iop/agx/preset/', '', 'blender-like|base')
                GuiAction.Do("iop/agx/exposure range/auto tune levels", 0, '', 'toggle', 1.0)
            end

            if (selection == self.agxSmoothBasePreset) then
                GuiAction.SelectModulePreset('iop/agx/preset/', '', 'smooth|base')
            end

            if (selection == self.agxSmoothBasePresetAutoTune) then
                GuiAction.SelectModulePreset('iop/agx/preset/', '', 'smooth|base')
                GuiAction.Do("iop/agx/exposure range/auto tune levels", 0, '', 'toggle', 1.0)
            end
        end
    end

    ---------------------------------------------------------------

    StepColorBalanceGlobalSaturation = Workflow.StepComboBox:new():new {}
    -- workflow steps for global saturation was removed
    -- implementation was kept to reactivate it if needed
    -- remove "--" in the following line if desired.
    -- table.insert(Workflow.ModuleSteps, StepColorBalanceGlobalSaturation)

    function StepColorBalanceGlobalSaturation:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'colorbalancergb'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"), 0, 5, 10, 15, 20, 25, 30, 35
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 1

        self.Label = _dtConcat({ "color balance rgb", ' ', "saturation" })

        self.Tooltip = _("Adjust global saturation in color balance rgb module.")
    end

    function StepColorBalanceGlobalSaturation:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show simple step initialization combobox in 2nd column: ignore or enable module first
        self:CreateSimpleBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepColorBalanceGlobalSaturation:Run()
        -- evaluate basic widget
        if (not self:RunSimpleBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        GuiAction.SetValue('iop/colorbalancergb/global saturation', 0, 'value', 'set', selection / 100)
    end

    ---------------------------------------------------------------

    StepColorBalanceGlobalChroma = Workflow.StepComboBox:new():new {}
    -- workflow steps for global chroma was removed
    -- implementation was kept to reactivate it if needed
    -- remove "--" in the following line if desired.
    -- table.insert(Workflow.ModuleSteps, StepColorBalanceGlobalChroma)

    function StepColorBalanceGlobalChroma:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'colorbalancergb'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"), 0, 5, 10, 15, 20, 25, 30, 35
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 1

        Label = _dtConcat({ "color balance rgb", ' ', "chroma" })

        self.Tooltip = _("Adjust global chroma in color balance rgb module.")
    end

    function StepColorBalanceGlobalChroma:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show simple step initialization combobox in 2nd column: ignore or enable module first
        self:CreateSimpleBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepColorBalanceGlobalChroma:Run()
        -- evaluate basic widget
        if (not self:RunSimpleBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        GuiAction.SetValue('iop/colorbalancergb/global chroma', 0, 'value', 'set', selection / 100)
    end

    ---------------------------------------------------------------

    StepColorBalanceContrast = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepColorBalanceContrast)

    function StepColorBalanceContrast:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'colorbalancergb'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"), 0, 5, 10, 15, 20, 25, 30
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 1

        self.Label = _dtConcat({ "color balance rgb", ' ', "contrast" })

        self.Tooltip = _(
            "Adjust brilliance in color balance rgb module to add contrast (darker shadows and brighter highlights). You can combine this with sigmoid neutral gray preset.")
    end

    function StepColorBalanceContrast:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show simple step initialization combobox in 2nd column: ignore or enable module first
        self:CreateSimpleBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepColorBalanceContrast:Run()
        -- evaluate basic widget
        if (not self:RunSimpleBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        GuiAction.SetValue('iop/colorbalancergb/brilliance/shadows', 0, 'value', 'set', -selection / 100)
        GuiAction.SetValue('iop/colorbalancergb/brilliance/highlights', 0, 'value', 'set', selection / 100)
    end

    ---------------------------------------------------------------

    StepColorBalanceRGBMasks = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepColorBalanceRGBMasks)

    function StepColorBalanceRGBMasks:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'colorbalancergb'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"),
            _("peak white & grey fulcrum")
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 2

        self.Label = _dtConcat({ "color balance rgb", ' ', "masks" })

        self.Tooltip = _(
            "Set auto pickers of the module mask and peak white and gray luminance value to normalize the power setting in the 4 ways tab.")
    end

    function StepColorBalanceRGBMasks:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show step initialization comb-- show step initialization combobox in 2nd column: ignore, enable, reset or disable module first
        self:CreateDefaultBasicWidget()

        -- overwrite default behaviour
        self.WidgetBasicDefaultValue = 3 -- enable instead of reset

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepColorBalanceRGBMasks:Run()
        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        if (selection == _("peak white & grey fulcrum")) then
            GuiAction.ButtonOffOn('iop/colorbalancergb/white fulcrum')
            GuiAction.ButtonOffOn('iop/colorbalancergb/contrast gray fulcrum')
        end
    end

    ---------------------------------------------------------------

    StepColorBalanceRGB = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepColorBalanceRGB)

    function StepColorBalanceRGB:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'colorbalancergb'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"),
            _dt("legacy"),
            _dt("natural skin"),
            _dt("standard"),
            _dt("vibrant colors")
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 5

        self.Label = _dtConcat({ 'color balance rgb', ' ', 'basic colorfulness' })

        self.Tooltip = _("Choose a predefined basic colorfulness preset for your color-grading.")
    end

    function StepColorBalanceRGB:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show step initialization comb-- show step initialization combobox in 2nd column: ignore, enable, reset or disable module first
        self:CreateDefaultBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepColorBalanceRGB:Run()
        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        GuiAction.SelectModulePreset('iop/colorbalancergb/preset/', 'basic colorfulness',
            GuiTranslation.GetReverseTranslation(selection))
    end

    ---------------------------------------------------------------

    StepContrastEqualizer = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepContrastEqualizer)

    function StepContrastEqualizer:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'atrous'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        self.clarity010 = _dtConcat({ "clarity", ', ', "mix", ' ', "0.10" })
        self.clarity025 = _dtConcat({ "clarity", ', ', "mix", ' ', "0.25" })
        self.clarity050 = _dtConcat({ "clarity", ', ', "mix", ' ', "0.50" })
        self.denoise010 = _dtConcat({ "denoise & sharpen", ', ', "mix", ' ', "0.10" })
        self.denoise025 = _dtConcat({ "denoise & sharpen", ', ', "mix", ' ', "0.25" })
        self.denoise050 = _dtConcat({ "denoise & sharpen", ', ', "mix", ' ', "0.50" })

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"),
            self.clarity010,
            self.clarity025,
            self.clarity050,
            self.denoise010,
            self.denoise025,
            self.denoise050
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 1

        self.Label = _dt("contrast equalizer")

        self.Tooltip = _(
            "Adjust luminance and chroma contrast. Apply choosen preset (clarity or denoise & sharpen). Choose different values to adjust the strength of the effect.")
    end

    function StepContrastEqualizer:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show step initialization comb-- show step initialization combobox in 2nd column: ignore, enable, reset or disable module first
        self:CreateDefaultBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepContrastEqualizer:Run()
        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        if (selection == self.clarity010) then
            GuiAction.SelectModulePreset('iop/atrous/preset/', '', _dt("clarity"))
            GuiAction.SetValue('iop/atrous/mix', 0, 'value', 'set', 0.10)
            --
        elseif (selection == self.clarity025) then
            GuiAction.SelectModulePreset('iop/atrous/preset/', '', _dt("clarity"))
            GuiAction.SetValue('iop/atrous/mix', 0, 'value', 'set', 0.25)
            --
        elseif (selection == self.clarity050) then
            GuiAction.SelectModulePreset('iop/atrous/preset/', '', _dt("clarity"))
            GuiAction.SetValue('iop/atrous/mix', 0, 'value', 'set', 0.5)
            --
        elseif (selection == self.denoise010) then
            GuiAction.SelectModulePreset('iop/atrous/preset/', '', _dt("denoise & sharpen"))
            GuiAction.SetValue('iop/atrous/mix', 0, 'value', 'set', 0.10)
            --
        elseif (selection == self.denoise025) then
            GuiAction.SelectModulePreset('iop/atrous/preset/', '', _dt("denoise & sharpen"))
            GuiAction.SetValue('iop/atrous/mix', 0, 'value', 'set', 0.25)
            --
        elseif (selection == self.denoise050) then
            GuiAction.SelectModulePreset('iop/atrous/preset/', '', _dt("denoise & sharpen"))
            GuiAction.SetValue('iop/atrous/mix', 0, 'value', 'set', 0.5)
        end
    end

    ---------------------------------------------------------------

    StepColorLookupTable = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepColorLookupTable)

    function StepColorLookupTable:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'colorchecker'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"),
            _dt("expanded color checker"),
            _dt("Fuji Astia emulation"),
            _dt("Fuji Classic Chrome emulation"),
            _dt("Fuji Monochrome emulation"),
            _dt("Fuji Provia emulation"),
            _dt("Fuji Velvia emulation"),
            _dt("Helmholtz/Kohlrausch monochrome"),
            _dt("it8 skin tones")
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 2

        self.Label = _dtConcat({ "color look up table" })

        self.Tooltip = _(
            "Use LUTs to modify the color mapping, perform color corrections or apply looks. You can choose a given preset.")
    end

    function StepColorLookupTable:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show simple step initialization combobox in 2nd column: ignore or enable module first
        self:CreateSimpleBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepColorLookupTable:Run()
        -- evaluate basic widget
        if (not self:RunSimpleBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        GuiAction.SelectModulePreset('iop/colorchecker/preset/', '', GuiTranslation.GetReverseTranslation(selection))
    end

    ---------------------------------------------------------------

    StepDiffuseOrSharpen = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepDiffuseOrSharpen)

    function StepDiffuseOrSharpen:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'diffuse'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"),
            _dt("dehaze | default"),
            _dt("denoise | coarse"),
            _dt("denoise | fine"),
            _dt("denoise | medium"),
            _dt("lens deblur | medium"),
            _dt("local contrast | normal"),
            _dt("sharpen demosaicing | AA filter"),
            _dt("sharpness | normal")
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 8

        self.Label = _dt("diffuse or sharpen")

        self.Tooltip = _(
            "Adjust luminance and chroma contrast. Apply choosen preset (clarity or denoise & sharpen). Choose different values to adjust the strength of the effect.")
    end

    function StepDiffuseOrSharpen:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show step initialization comb-- show step initialization combobox in 2nd column: ignore, enable, reset or disable module first
        self:CreateDefaultBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepDiffuseOrSharpen:Run()
        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        GuiAction.SelectModulePreset('iop/diffuse/preset/', '', GuiTranslation.GetReverseTranslation(selection))
    end

    ---------------------------------------------------------------

    StepToneEqualizerMask = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepToneEqualizerMask)

    function StepToneEqualizerMask:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'toneequal'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"),
            _("mask exposure compensation"),
            _("mask contrast compensation"),
            _("exposure & contrast comp."),
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 4

        self.Label = _dtConcat({ "tone equalizer", ' ', "masking" })

        self.Tooltip = _(
            "Apply automatic mask contrast and exposure compensation. Auto adjust the contrast and average exposure.")
    end

    function StepToneEqualizerMask:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show simple step initialization combobox in 2nd column: ignore or enable module first
        self:CreateSimpleBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepToneEqualizerMask:Run()
        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        -- workaround: show this module, otherwise the buttons will not be pressed
        GuiAction.ShowDarkroomModule('iop/toneequal')
        GuiAction.DoWithoutEvent('iop/toneequal/page', 0, 'advanced', '', 1.0)

        -- exposure compensation
        if ((selection == _("mask exposure compensation"))
                or (selection == _("exposure & contrast comp."))) then
            --
            local path = 'iop/toneequal/mask exposure compensation'

            -- workaround: move slider to initialize mask post-processing
            -- otherwise this setting will not work reliably
            -- (there are different states after the complete reset of the history stack and after the initialization of this module)
            local oldValue = GuiAction.DoWithoutEvent(path, 0, 'value', 'set', 0 / 0)
            GuiAction.SetValue(path, 0, 'value', 'set', oldValue + 0.1)

            -- toggle button
            GuiAction.Do(path, 0, 'button', 'toggle', 1.0)
            Helper.ThreadSleep(StepTimeout:Value())
            --
        end

        -- contrast compensation
        if ((selection == _("mask contrast compensation"))
                or (selection == _("exposure & contrast comp."))) then
            --
            local path = 'iop/toneequal/mask contrast compensation'

            -- workaround: move slider to initialize mask post-processing
            local oldValue = GuiAction.DoWithoutEvent(path, 0, 'value', 'set', 0 / 0)
            GuiAction.SetValue(path, 0, 'value', 'set', oldValue + 0.1)

            -- toggle button
            GuiAction.Do(path, 0, 'button', 'toggle', 1.0)
            Helper.ThreadSleep(StepTimeout:Value())
            --
        end

        -- workaround: show this module, otherwise the buttons will not be pressed
        GuiAction.HideDarkroomModule('iop/toneequal')
        --
    end

    ---------------------------------------------------------------

    StepToneEqualizer = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepToneEqualizer)

    function StepToneEqualizer:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'toneequal'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        self.labelMedium = _dtConcat({ "EIGF", ' ', "medium" })
        self.labelSoft = _dtConcat({ "EIGF", ' ', "soft" })
        self.labelStrong = _dtConcat({ "EIGF", ' ', "strong" })

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"),
            self.labelMedium,
            self.labelSoft,
            self.labelStrong
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 1

        self.Label = _dtConcat({ 'tone equalizer', ' ', 'compress shadows-highlights' })

        self.Tooltip = _(
            "Use preset to compress shadows and highlights with exposure-independent guided filter (eigf) (soft, medium or strong).")
    end

    function StepToneEqualizer:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show step initialization comb-- show step initialization combobox in 2nd column: ignore, enable, reset or disable module first
        self:CreateDefaultBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepToneEqualizer:Run()
        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        if (selection == self.labelMedium) then
            GuiAction.SelectModulePreset('iop/toneequal/preset/', 'compress shadows@<highlights', 'EIGF | medium')
        elseif (selection == self.labelSoft) then
            GuiAction.SelectModulePreset('iop/toneequal/preset/', 'compress shadows@<highlights', 'EIGF | soft')
        elseif (selection == self.labelStrong) then
            GuiAction.SelectModulePreset('iop/toneequal/preset/', 'compress shadows@<highlights', 'EIGF | strong')
        end
    end

    ---------------------------------------------------------------

    StepExposureCorrection = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepExposureCorrection)

    function StepExposureCorrection:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'exposure'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        self.AutoExposureAdjustment = _("auto exposure adjustment")
        self.AutoExposureAndCompensateCameraExposure = _("auto and camera compensation")

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"),
            self.AutoExposureAdjustment,
            self.AutoExposureAndCompensateCameraExposure
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 1

        self.Label = _dt("exposure")

        self.Tooltip = _(
            "Automatically adjust the exposure correction. Remove the camera exposure bias, useful if you exposed the image to the right.")
    end

    function StepExposureCorrection:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show step initialization comb-- show step initialization combobox in 2nd column: ignore, enable, reset or disable module first
        self:CreateDefaultBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepExposureCorrection:Run()
        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        if (selection == self.AutoExposureAdjustment) then
            GuiAction.ButtonOffOn('iop/exposure/exposure')
        end

        if (selection == self.AutoExposureAndCompensateCameraExposure) then
            GuiAction.ButtonOffOn('iop/exposure/exposure')

            local checkbox = GuiAction.GetValue('iop/exposure/compensate exposure bias', '')
            if (checkbox == 0) then
                GuiAction.Do('iop/exposure/compensate exposure bias', 0, '', 'on', 1.0)
            else
                LogHelper.Info(indent .. _("checkbox already selected, nothing to do"))
            end
        end
    end

    ---------------------------------------------------------------

    StepLensCorrection = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepLensCorrection)

    function StepLensCorrection:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'lens'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        self.lensfunSelection = _dt("Lensfun database")

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"),
            self.lensfunSelection,
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 2

        self.Label = _dt("lens correction")

        self.Tooltip = _("Enable and reset lens correction module.")
    end

    function StepLensCorrection:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show step initialization comb-- show step initialization combobox in 2nd column: ignore, enable, reset or disable module first
        self:CreateDefaultBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepLensCorrection:Run()
        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        if (selection == _dt("Lensfun database")) then
            local lensCorrectionValues =
            {
                _dt("embedded metadata"),
                self.lensfunSelection
            }

            local currentSelectionIndex = GuiAction.GetValue('iop/lens/correction method', 'selection')
            local currentSelection = lensCorrectionValues[-currentSelectionIndex]

            if (self.lensfunSelection ~= currentSelection) then
                LogHelper.Info(indent ..
                    string.format(_("current correction method = %s"), Helper.Quote(currentSelection)))
                GuiAction.Do('iop/lens/correction method', 0, 'selection', 'item:Lensfun database', 1.0)
            else
                LogHelper.Info(indent ..
                    string.format(_("nothing to do, correction method already = %s"), Helper.Quote(currentSelection)))
            end
        end
    end

    ---------------------------------------------------------------

    StepDenoiseProfiled = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepDenoiseProfiled)

    function StepDenoiseProfiled:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'denoiseprofile'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues = { _("unchanged") }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 1

        self.Label = _dt("denoise (profiled)")

        self.Tooltip = _(
            "Enable denoise (profiled) module. There is nothing to configure, just enable or reset this module.")
    end

    function StepDenoiseProfiled:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show step initialization comb-- show step initialization combobox in 2nd column: ignore, enable, reset or disable module first
        self:CreateDefaultBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepDenoiseProfiled:Run()
        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end
    end

    ---------------------------------------------------------------

    StepChromaticAberrations = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepChromaticAberrations)

    function StepChromaticAberrations:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'cacorrect'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"),
            _("Bayer sensor"),
            _("other sensors")
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 2

        self.Label = _dt("chromatic aberrations")

        self.Tooltip = _(
            "Correct chromatic aberrations. Distinguish between Bayer sensor and other camera sensors. This operation uses the corresponding correction module and disables the other.")
    end

    function StepChromaticAberrations:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show step initialization comb-- show step initialization combobox in 2nd column: ignore, enable, reset or disable module first
        self:CreateDefaultBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepChromaticAberrations:BayerSensorSelected()
        return Helper.Contains(
            { _("Bayer sensor")
            }, self.Widget.value)
    end

    function StepChromaticAberrations:OtherSensorSelected()
        return Helper.Contains(
            { _("other sensors")
            }, self.Widget.value)
    end

    -- override base class function
    -- distinguish between bayer sensor and other
    function StepChromaticAberrations:OperationName()
        if (self:BayerSensorSelected()) then
            return 'cacorrect'
        end

        if (self:OtherSensorSelected()) then
            return 'cacorrectrgb'
        end

        return 'cacorrect'
    end

    function StepChromaticAberrations:Run()
        -- special handling (bayer sensor / other)
        -- do nothing or disable corresponding modules
        local basic = self.WidgetBasic.value
        if (basic == _("ignore")) then
            return
        end

        if (basic == _("disable")) then
            GuiAction.DisableDarkroomModule(self:OperationPath())
            return false
        end

        -- disable other module than selected
        if (self:BayerSensorSelected()) then
            GuiAction.DisableDarkroomModule('iop/cacorrectrgb')
        end

        if (self:OtherSensorSelected()) then
            GuiAction.DisableDarkroomModule('iop/cacorrect')
        end

        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end
    end

    ---------------------------------------------------------------

    StepColorCalibrationIlluminant = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepColorCalibrationIlluminant)

    function StepColorCalibrationIlluminant:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'channelmixerrgb'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"),                                 -- additional value
            _dt("set white balance to detected from area"), -- additional value
            _dt("same as pipeline (D50)"),
            _dt("A (incandescent)"),
            _dt("D (daylight)"),
            _dt("E (equi-energy)"),
            _dt("F (fluorescent)"),
            _dt("LED (LED light)"),
            _dt("Planckian (black body)"),
            _dt("custom"),
            -- these presets are ditched...
            -- _dt("(AI) detect from image surfaces..."),
            -- _dt("(AI) detect from image edges..."),
            _dt("as shot in camera")
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        -- see EnableDefaultStepConfiguation() override
        self.ConfigurationValueDefaultIndex = nil

        self.Label = _dtConcat({ "color calibration", ' ', "illuminant" })

        self.Tooltip = _(
            "Perform color space corrections in color calibration module. Select the illuminant. The type of illuminant assumed to have lit the scene. By default unchanged for the legacy workflow.")
    end

    -- distinguish between modern and legacy workflow
    -- keep value unchanged (1), if using legacy workflow
    -- depends on darktable preference settings
    function StepColorCalibrationIlluminant:EnableDefaultStepConfiguation()
        -- "unchanged: scene referred default"
        self.Widget.value = Helper.CheckDarktableModernWorkflowPreference() and 1 or 1
    end

    -- combobox values see darktable typedef enum dt_illuminant_t
    -- github/darktable/src/common/illuminants.h
    -- github/darktable/po/darktable.pot
    -- github/darktable/build/lib/darktable/plugins/introspection_channelmixerrgb.c

    function StepColorCalibrationIlluminant:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show step initialization comb-- show step initialization combobox in 2nd column: ignore, enable, reset or disable module first
        self:CreateDefaultBasicWidget()

        -- overwrite default behaviour
        self.WidgetBasicDefaultValue = 3 -- enable instead of reset

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepColorCalibrationIlluminant:Run()
        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        -- ignore illuminant, if current adaptation is equal to bypass
        local adaptationSelectionIndex = GuiAction.GetValue('iop/channelmixerrgb/adaptation', 'selection')
        local adaptationSelection = StepColorCalibrationAdaptation:GetConfigurationValueFromSelectionIndex(
            adaptationSelectionIndex)

        LogHelper.Info(indent .. string.format(_("color calibration adaption = %s"), adaptationSelection))
        if (adaptationSelection == _dt("none (bypass)")) then
            LogHelper.Info(indent .. _("illuminant cannot be set"))
            return
        else
            LogHelper.Info(indent .. _("illuminant can be set"))
        end

        -- set illuminant

        -- detect custom value from picture
        if (selection == _dt("set white balance to detected from area")) then
            GuiAction.Do('iop/channelmixerrgb/picker', 0, '', 'toggle', 1.0)
            return
        end

        -- set predefined values
        local currentSelectionIndex = GuiAction.GetValue('iop/channelmixerrgb/illuminant', 'selection')

        -- consider additional value
        currentSelectionIndex = currentSelectionIndex - 1

        local currentSelection = self:GetConfigurationValueFromSelectionIndex(currentSelectionIndex)

        if (selection ~= currentSelection) then
            LogHelper.Info(indent .. string.format(_("current illuminant = %s"), Helper.Quote(currentSelection)))
            GuiAction.Do('iop/channelmixerrgb/illuminant', 0, 'selection', 'item:' .. _ReverseTranslation(selection), 1.0)
        else
            LogHelper.Info(indent ..
                string.format(_("nothing to do, illuminant already = %s"), Helper.Quote(currentSelection)))
        end
    end

    ---------------------------------------------------------------

    StepColorCalibrationAdaptation = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepColorCalibrationAdaptation)

    function StepColorCalibrationAdaptation:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'channelmixerrgb'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        -- combobox values see darktable typedef enum dt_adaptation_t

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"), -- additional value
            _dt("linear Bradford (ICC v4)"),
            _dt("CAT16 (CIECAM16)"),
            _dt("non-linear Bradford"),
            _dt("XYZ"),
            _dt("none (bypass)")
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 3

        self.Label = _dtConcat({ "color calibration", ' ', "adaptation" })

        self.Tooltip = _(
            "Perform color space corrections in color calibration module. Select the adaptation. The working color space in which the module will perform its chromatic adaptation transform and channel mixing.")
    end

    function StepColorCalibrationAdaptation:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show step initialization comb-- show step initialization combobox in 2nd column: ignore, enable, reset or disable module first
        self:CreateDefaultBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepColorCalibrationAdaptation:Run()
        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        local currentSelectionIndex = GuiAction.GetValue('iop/channelmixerrgb/adaptation', 'selection')
        local currentSelection = self:GetConfigurationValueFromSelectionIndex(currentSelectionIndex)

        if (selection ~= currentSelection) then
            LogHelper.Info(indent .. string.format(_("current adaptation = %s"), Helper.Quote(currentSelection)))
            GuiAction.Do('iop/channelmixerrgb/adaptation', 0, 'selection', 'item:' .. _ReverseTranslation(selection), 1.0)
        else
            LogHelper.Info(indent ..
                string.format(_("nothing to do, adaptation already = %s"), Helper.Quote(currentSelection)))
        end
    end

    ---------------------------------------------------------------

    StepHighlightReconstruction = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepHighlightReconstruction)

    function StepHighlightReconstruction:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'highlights'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"),
            _dt("inpaint opposed"),
            _dt("reconstruct in LCh"),
            _dt("clip highlights"),
            _dt("segmentation based"),
            _dt("guided laplacians")
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 2

        self.Label = _dt("highlight reconstruction")

        self.Tooltip = _(
            "Reconstruct color information for clipped pixels. Select an appropriate reconstruction methods to reconstruct the missing data from unclipped channels and/or neighboring pixels.")
    end

    function StepHighlightReconstruction:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show step initialization comb-- show step initialization combobox in 2nd column: ignore, enable, reset or disable module first
        self:CreateDefaultBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepHighlightReconstruction:Run()
        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        local currentSelectionIndex = GuiAction.GetValue('iop/highlights/method', 'selection')
        local currentSelection = self:GetConfigurationValueFromSelectionIndex(currentSelectionIndex)

        if (selection ~= currentSelection) then
            LogHelper.Info(indent .. string.format(_("current value = %s"), Helper.Quote(currentSelection)))
            GuiAction.Do('iop/highlights/method', 0, 'selection', 'item:' .. _ReverseTranslation(selection), 1.0)
        else
            LogHelper.Info(indent ..
                string.format(_("nothing to do, value already = %s"), Helper.Quote(currentSelection)))
        end
    end

    ---------------------------------------------------------------

    StepWhiteBalance = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepWhiteBalance)

    function StepWhiteBalance:PostConstructor()
        -- darktable internal module name abbreviation
        self.OperationNameInternal = 'temperature'
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"),
            _dt("as shot"),
            _dt("from image area"),
            _dt("user modified"),
            _dt("camera reference"),
            _dt("as shot to reference")
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        -- see EnableDefaultStepConfiguation() override
        self.ConfigurationValueDefaultIndex = nil

        self.Label = _("white balance")

        self.Tooltip = _(
            "Adjust the white balance of the image by altering the temperature. By default unchanged for the legacy workflow.")
    end

    -- distinguish between modern and legacy workflow
    -- keep value unchanged, if using legacy workflow
    -- depends on darktable preference settings
    function StepWhiteBalance:EnableDefaultStepConfiguation()
        self.Widget.value = Helper.CheckDarktableModernWorkflowPreference() and 6 or 1
    end

    function StepWhiteBalance:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show step initialization comb-- show step initialization combobox in 2nd column: ignore, enable, reset or disable module first
        self:CreateDefaultBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepWhiteBalance:Run()
        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

        local currentSelectionIndex = GuiAction.GetValue('iop/temperature/settings/settings', 'selection')
        local currentSelection = self:GetConfigurationValueFromSelectionIndex(currentSelectionIndex)

        if (selection ~= currentSelection) then
            LogHelper.Info(indent .. string.format(_("current value = %s"), Helper.Quote(currentSelection)))
            GuiAction.Do('iop/temperature/settings/' .. _ReverseTranslation(selection), 0, '', '', 1.0)
        else
            LogHelper.Info(indent ..
                string.format(_("nothing to do, value already = %s"), Helper.Quote(currentSelection)))
        end
    end

    ---------------------------------------------------------------

    StepCreator = Workflow.StepTextEntry:new():new()
    table.insert(Workflow.ModuleSteps, StepCreator)

    function StepCreator:PostConstructor()
        -- darktable internal module name abbreviation
        -- operation = nil: ignore this module during module reset
        self.OperationNameInternal = nil
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues = {}

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 2

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 3

        self.Label = _dtConcat({ 'metadata', ' ', 'creator' })

        self.Tooltip = _(
            "Creator of this image. Enter your name or contact address. Leave this field blank if you don't want to change the current value. After reloading your image you can find this value as full text in metadata editor and image information module. This value is exported to jpg meta data.")
    end

    function StepCreator:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show empty invisible step initialization combobox in 2nd column (settings subpage)
        self:CreateEmptyBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('entry')
            {
                -- changed_callback does not exist for lua_entry
                -- preferences are saved via darktable exit event
                text = "",
                placeholder = _("empty, tag keeps unchanged"),
                is_password = false,
                editable = true,
                tooltip = self:GetLabelAndTooltip(),
            }
    end

    function StepCreator:Run()
        local creatorName = self.Widget.text

        if (creatorName == nil) or (creatorName == "") then
            return
        end

        local currentImage = dt.gui.views.darkroom.display_image()
        LogHelper.Info(_dtConcat({ "creator", " = ", creatorName }))
        currentImage.creator = creatorName
    end

    function StepCreator:Value()
        return self.Widget.text
    end

    function StepCreator:EnableDefaultStepConfiguation()
        -- do nothing
    end

    ---------------------------------------------------------------

    StepCreativeCommonLicense = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepCreativeCommonLicense)

    function StepCreativeCommonLicense:PostConstructor()
        -- darktable internal module name abbreviation
        -- operation = nil: ignore this module during module reset
        self.OperationNameInternal = "creator and license"
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Modules

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _("unchanged"),
            "all rights reserved",
            "CC BY",
            "CC BY-NC",
            "CC BY-NC-ND",
            "CC BY-NC-SA",
            "CC BY-ND",
            "CC BY-SA"
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 1

        self.Label = _dtConcat({ 'metadata', ' ', 'license' })

        self.Tooltip = _(
            "Choose a creative common license. After reloading your image you can find this value as full text in metadata editor and image information module. This value is exported to jpg meta data.")
    end

    function StepCreativeCommonLicense:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show empty invisible step initialization combobox in 2nd column (settings subpage)
        self:CreateEmptyBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    -- show darkroom module during step execution
    -- override base class function
    function StepCreativeCommonLicense:ShowDarkroomModuleDuringStepRun()
        return false
    end

    local licenseFullText = {}

    licenseFullText["all rights reserved"] = "all rights reserved"
    licenseFullText["CC BY"] = "Creative Commons Attribution (CC BY)"
    licenseFullText["CC BY-NC"] = "Creative Commons Attribution-NonCommercial (CC BY-NC)"
    licenseFullText["CC BY-NC-ND"] = "Creative Commons Attribution-NonCommercial-NoDerivs (CC BY-NC-ND)"
    licenseFullText["CC BY-NC-SA"] = "Creative Commons Attribution-NonCommercial-ShareAlike (CC BY-NC-SA)"
    licenseFullText["CC BY-ND"] = "Creative Commons Attribution-NoDerivs (CC BY-ND)"
    licenseFullText["CC BY-SA"] = "Creative Commons Attribution-ShareAlike (CC BY-SA)"

    function StepCreativeCommonLicense:Run()
        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local rights = self.Widget.value

        if (rights == nil) or (rights == "") then
            return
        end

        if (rights == _("unchanged")) then
            return
        end

        local currentImage = dt.gui.views.darkroom.display_image()
        rights = licenseFullText[rights]
        LogHelper.Info(_dtConcat({ "rights", " = ", rights }))
        currentImage.rights = rights
    end

    ---------------------------------------------------------------

    StepResetModuleHistory = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepResetModuleHistory)

    function StepResetModuleHistory:PostConstructor()
        -- darktable internal module name abbreviation
        -- operation = nil: ignore this module during module reset
        self.OperationNameInternal = nil
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Settings

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            _dt("no"), _dt("yes")
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 1

        self.Label = _("discard complete history")

        self.Tooltip = _("Reset all modules of the whole pixelpipe and discard complete history.")
    end

    function StepResetModuleHistory:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show empty invisible step initialization combobox in 2nd column (settings subpage)
        self:CreateEmptyBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepResetModuleHistory:Run()
        -- evaluate basic widget
        if (not self:RunSimpleBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _dt("no")) then
            return
        end

        if (selection == _dt("yes")) then
            GuiAction.Do('lib/history', 0, 'reset', '', 1.0)
        end
    end

    ---------------------------------------------------------------

    StepShowModulesDuringExecution = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepShowModulesDuringExecution)

    function StepShowModulesDuringExecution:PostConstructor()
        -- darktable internal module name abbreviation
        -- operation = nil: ignore this module during module reset
        self.OperationNameInternal = nil
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Settings

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues = { _dt("no"), _dt("yes") }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 1

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 1

        self.Label = _("show modules")

        self.Tooltip = _(
            "Show darkroom modules for enabled workflow steps during execution of this initial workflow. This makes the changes easier to understand.")
    end

    function StepShowModulesDuringExecution:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show empty invisible step initialization combobox in 2nd column (settings subpage)
        self:CreateEmptyBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepShowModulesDuringExecution:Run()
        -- do nothing...
    end

    function StepShowModulesDuringExecution:Value()
        return self.Widget.value == _dt("yes")
    end

    ---------------------------------------------------------------

    StepRunSingleStepOnSettingsChange = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepRunSingleStepOnSettingsChange)

    function StepRunSingleStepOnSettingsChange:PostConstructor()
        -- darktable internal module name abbreviation
        -- operation = nil: ignore this module during module reset
        self.OperationNameInternal = nil
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Settings

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues = { _dt("no"), _dt("yes") }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 2

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 2

        self.Label = _("when making changes, execute individual steps directly.")

        self.Tooltip = _(
            "If a setting in this module is changed, the corresponding workflow step is executed directly. The associated individual module is configured. This allows you to see the changes made by each configuration without having to run the entire workflow.")
    end

    function StepRunSingleStepOnSettingsChange:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show empty invisible step initialization combobox in 2nd column (settings subpage)
        self:CreateEmptyBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepRunSingleStepOnSettingsChange:Run()
        -- do nothing...
    end

    function StepRunSingleStepOnSettingsChange:Value()
        return self.Widget.value == _dt("yes")
    end

    ---------------------------------------------------------------

    StepTimeout = Workflow.StepComboBox:new():new {}
    table.insert(Workflow.ModuleSteps, StepTimeout)

    function StepTimeout:PostConstructor()
        -- darktable internal module name abbreviation
        -- operation = nil: ignore this module during module reset
        self.OperationNameInternal = nil
        -- select subpage containing this step: WidgetStack.Modules or WidgetStack.Settings
        self.WidgetStackValue = WidgetStack.Settings

        -- array of configuration values ​​selectable by the user
        self.ConfigurationValues =
        {
            '500',
            '1000',
            '2000',
            '3000',
            '4000',
            '5000'
        }

        -- step configurationvalue array index, used if module settings are reset to "unchanged"
        self.ConfigurationValueUnchangedIndex = 2

        -- step configurationvalue array index, used if module settings are reset to "default"
        self.ConfigurationValueDefaultIndex = 3

        self.Label = _("timeout value")

        self.Tooltip = _(
            "Some calculations take a certain amount of time. Depending on the hardware equipment also longer.This script waits and attempts to detect timeouts. If steps take much longer than expected, those steps will be aborted. You can configure the default timeout (ms). Before and after each step of the workflow, the script waits this time. In other places also a multiple (loading an image) or a fraction (querying a status).")
    end

    function StepTimeout:Init()
        -- show step label and tooltip in first column of the inital workflow module
        self:CreateLabelWidget()
        -- show empty invisible step initialization combobox in 2nd column (settings subpage)
        self:CreateEmptyBasicWidget()

        -- show main combobox with configuration values in 3rd column
        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepTimeout:Run()
        LogHelper.Info(string.format(_("step timeout = %s ms"), self:Value()))
    end

    function StepTimeout:Value()
        return tonumber(self.Widget.value)
    end
end

return WorkflowSteps
