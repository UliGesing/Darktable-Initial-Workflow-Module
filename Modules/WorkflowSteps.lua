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
  
  StepCompressHistoryStack = WorkflowStepCombobox:new():new {[...]}
  to create the new instance.
  
  function StepCompressHistoryStack:Init()
  to define combobox values and create the widget.
  
  function StepCompressHistoryStack:Run()
  to execute the step
  
  table.insert(WorkflowSteps, StepCompressHistoryStack)
  to collect all steps and execute them later on.

  
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

function WorkflowSteps.CreateWorkflowSteps()
    StepCompressHistoryStack = Workflow.StepConfiguration:new():new
        {
            -- operation = nil: ignore this module during module reset
            OperationNameInternal = nil,
            WidgetStackValue = WidgetStack.Settings,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 2,
            Label = _dt("compress history stack"),
            Tooltip = _(
                "Generate the shortest history stack that reproduces the current image. This removes your current history snapshots.")
        }

    table.insert(Workflow.ModuleSteps, StepCompressHistoryStack)

    function StepCompressHistoryStack:Init()
        self:CreateLabelWidget()
        self:CreateEmptyBasicWidget()

        self.ConfigurationValues = { _dt("no"), _dt("yes") }
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

    StepDynamicRangeSceneToDisplay = Workflow.StepConfiguration:new():new
        {
            -- this step refers to different modules
            OperationNameInternal = 'Filmic or Sigmoid',
            WidgetStackValue = WidgetStack.Modules,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 3,
            Label = GuiTranslation.dtConcat({ "filmic rgb", ' / ', "sigmoid" }),
            Tooltip = _(
                "Use Filmic or Sigmoid to expand or contract the dynamic range of the scene to fit the dynamic range of the display. Auto tune filmic levels of black + white relative exposure. Or use Sigmoid with one of its presets. Use only one of Filmic, Sigmoid or Basecurve, this module disables the others.")
        }

    table.insert(Workflow.ModuleSteps, StepDynamicRangeSceneToDisplay)

    function StepDynamicRangeSceneToDisplay:Init()
        self:CreateLabelWidget()
        self:CreateDefaultBasicWidget()

        self.filmicAutoTuneLevels = GuiTranslation.dtConcat({ "filmic", ' ', "auto tune levels" })
        self.filmicHighlightReconstruction = GuiTranslation.dtConcat({ "filmic", ' + ', "highlight reconstruction" })
        self.sigmoidColorPerChannel = GuiTranslation.dtConcat({ "sigmoid", ' ', "per channel" })
        self.sigmoidColorRgbRatio = GuiTranslation.dtConcat({ "sigmoid", ' ', "RGB ratio" })
        self.sigmoidAces100Preset = GuiTranslation.dtConcat({ "sigmoid", ' ', "ACES 100-nit like" })

        self.ConfigurationValues =
        {
            _("unchanged"),
            self.filmicAutoTuneLevels,
            self.filmicHighlightReconstruction,
            self.sigmoidColorPerChannel,
            self.sigmoidColorRgbRatio,
            self.sigmoidAces100Preset
        }

        self.Widget = dt.new_widget('combobox')
            {
                changed_callback = Workflow.ComboBoxChangedCallback,
                label = ' ', -- use separate label widget
                tooltip = self:GetLabelAndTooltip(),
                table.unpack(self.ConfigurationValues)
            }
    end

    function StepDynamicRangeSceneToDisplay:FilmicSelected()
        return Helper.Contains(
            { self.filmicAutoTuneLevels,
                self.filmicHighlightReconstruction
            }, self.Widget.value)
    end

    function StepDynamicRangeSceneToDisplay:SigmoidSelected()
        return Helper.Contains(
            { self.sigmoidColorPerChannel,
                self.sigmoidColorRgbRatio,
                self.sigmoidAces100Preset
            }, self.Widget.value)
    end

    -- override base class function
    -- distinguish between filmic and sigmoid module
    function StepDynamicRangeSceneToDisplay:OperationName()
        if (self:FilmicSelected()) then
            return 'filmicrgb'
        end

        if (self:SigmoidSelected()) then
            return 'sigmoid'
        end

        return 'filmicrgb'
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

        if (self:FilmicSelected()) then
            GuiAction.DisableDarkroomModule('iop/sigmoid')
            GuiAction.DisableDarkroomModule('iop/basecurve')
        end

        if (self:SigmoidSelected()) then
            GuiAction.DisableDarkroomModule('iop/filmicrgb')
            GuiAction.DisableDarkroomModule('iop/basecurve')
        end

        -- evaluate basic widget
        if (not self:RunBasicWidget()) then
            return
        end

        local selection = self.Widget.value

        if (selection == _("unchanged")) then
            return
        end

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

        if (self:SigmoidSelected()) then
            local colorProcessingValues =
            {
                _dt("per channel"),
                _dt("RGB ratio")
            }

            local currentSelectionIndex = GuiAction.GetValue('iop/sigmoid/color processing', 'selection')
            local currentSelection = colorProcessingValues[-currentSelectionIndex]

            if (selection == self.sigmoidColorPerChannel) then
                if (_dt("per channel") ~= currentSelection) then
                    LogHelper.Info(indent ..
                        string.format(_("current color processing = %s"), Helper.Quote(currentSelection)))
                    GuiAction.Do('iop/sigmoid/color processing', 0, 'selection', 'item:per channel', 1.0)
                else
                    LogHelper.Info(indent ..
                        string.format(_("nothing to do, color processing already = %s"), Helper.Quote(currentSelection)))
                end
            end

            if (selection == self.sigmoidColorRgbRatio) then
                if (_dt("RGB ratio") ~= currentSelection) then
                    LogHelper.Info(indent ..
                        string.format(_("current color processing = %s"), Helper.Quote(currentSelection)))
                    GuiAction.Do('iop/sigmoid/color processing', 0, 'selection', 'item:RGB ratio', 1.0)
                else
                    LogHelper.Info(indent ..
                        string.format(_("nothing to do, color processing already = %s"), Helper.Quote(currentSelection)))
                end
            end

            if (selection == self.sigmoidAces100Preset) then
                GuiAction.ButtonOffOn('iop/sigmoid/preset/' .. _dt("ACES 100-nit like"))
            end
        end
    end

    ---------------------------------------------------------------

    StepColorBalanceGlobalSaturation = Workflow.StepConfiguration:new():new
        {
            OperationNameInternal = 'colorbalancergb',
            WidgetStackValue = WidgetStack.Modules,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 7,
            Label = GuiTranslation.dtConcat({ "color balance rgb", ' ', "saturation" }),
            Tooltip = _("Adjust global saturation in color balance rgb module.")
        }

    table.insert(Workflow.ModuleSteps, StepColorBalanceGlobalSaturation)

    function StepColorBalanceGlobalSaturation:Init()
        self:CreateLabelWidget()
        self:CreateSimpleBasicWidget()

        self.ConfigurationValues =
        {
            _("unchanged"), 0, 5, 10, 15, 20, 25, 30, 35
        }

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

    StepColorBalanceGlobalChroma = Workflow.StepConfiguration:new():new
        {
            OperationNameInternal = 'colorbalancergb',
            WidgetStackValue = WidgetStack.Modules,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 5,
            Label = GuiTranslation.dtConcat({ "color balance rgb", ' ', "chroma" }),
            Tooltip = _("Adjust global chroma in color balance rgb module.")
        }

    table.insert(Workflow.ModuleSteps, StepColorBalanceGlobalChroma)

    function StepColorBalanceGlobalChroma:Init()
        self:CreateLabelWidget()
        self:CreateSimpleBasicWidget()

        self.ConfigurationValues =
        {
            _("unchanged"), 0, 5, 10, 15, 20, 25, 30, 35
        }

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

    StepColorBalanceRGBMasks = Workflow.StepConfiguration:new():new
        {
            OperationNameInternal = 'colorbalancergb',
            WidgetStackValue = WidgetStack.Modules,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 2,
            Label = GuiTranslation.dtConcat({ "color balance rgb", ' ', "masks" }),
            Tooltip = _(
                "Set auto pickers of the module mask and peak white and gray luminance value to normalize the power setting in the 4 ways tab.")
        }

    table.insert(Workflow.ModuleSteps, StepColorBalanceRGBMasks)

    function StepColorBalanceRGBMasks:Init()
        self:CreateLabelWidget()
        self:CreateDefaultBasicWidget()

        self.WidgetBasicDefaultValue = 3 -- enable instead of reset

        self.ConfigurationValues =
        {
            _("unchanged"),
            _("peak white & grey fulcrum")
        }

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

    StepColorBalanceRGB = Workflow.StepConfiguration:new():new
        {
            OperationNameInternal = 'colorbalancergb',
            WidgetStackValue = WidgetStack.Modules,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 5,
            Label = _dt("color balance rgb"),
            Tooltip = _("Choose a predefined preset for your color-grading.")
        }

    table.insert(Workflow.ModuleSteps, StepColorBalanceRGB)

    function StepColorBalanceRGB:Init()
        self:CreateLabelWidget()
        self:CreateDefaultBasicWidget()

        self.ConfigurationValues =
        {
            _("unchanged"),
            _dt("add basic colorfulness (legacy)"),
            _dt("basic colorfulness: natural skin"),
            _dt("basic colorfulness: standard"),
            _dt("basic colorfulness: vibrant colors")
        }

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

        GuiAction.ButtonOffOn('iop/colorbalancergb/preset/' .. selection)
    end

    ---------------------------------------------------------------

    StepContrastEqualizer = Workflow.StepConfiguration:new():new
        {
            OperationNameInternal = 'atrous',
            WidgetStackValue = WidgetStack.Modules,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 2,
            Label = _dt("contrast equalizer"),
            Tooltip = _(
                "Adjust luminance and chroma contrast. Apply choosen preset (clarity or denoise & sharpen). Choose different values to adjust the strength of the effect.")
        }

    table.insert(Workflow.ModuleSteps, StepContrastEqualizer)

    function StepContrastEqualizer:Init()
        self:CreateLabelWidget()
        self:CreateDefaultBasicWidget()

        self.clarity010 = GuiTranslation.dtConcat({ "clarity", ', ', "mix", ' ', "0.10" })
        self.clarity025 = GuiTranslation.dtConcat({ "clarity", ', ', "mix", ' ', "0.25" })
        self.clarity050 = GuiTranslation.dtConcat({ "clarity", ', ', "mix", ' ', "0.50" })

        self.denoise010 = GuiTranslation.dtConcat({ "denoise & sharpen", ', ', "mix", ' ', "0.10" })
        self.denoise025 = GuiTranslation.dtConcat({ "denoise & sharpen", ', ', "mix", ' ', "0.25" })
        self.denoise050 = GuiTranslation.dtConcat({ "denoise & sharpen", ', ', "mix", ' ', "0.50" })

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
            GuiAction.ButtonOffOn('iop/atrous/preset/' .. _dt("clarity"))
            GuiAction.SetValue('iop/atrous/mix', 0, 'value', 'set', 0.10)
            --
        elseif (selection == self.clarity025) then
            GuiAction.ButtonOffOn('iop/atrous/preset/' .. _dt("clarity"))
            GuiAction.SetValue('iop/atrous/mix', 0, 'value', 'set', 0.25)
            --
        elseif (selection == self.clarity050) then
            GuiAction.ButtonOffOn('iop/atrous/preset/' .. _dt("clarity"))
            GuiAction.SetValue('iop/atrous/mix', 0, 'value', 'set', 0.5)
            --
        elseif (selection == self.denoise010) then
            GuiAction.ButtonOffOn('iop/atrous/preset/' .. _dt("denoise & sharpen"))
            GuiAction.SetValue('iop/atrous/mix', 0, 'value', 'set', 0.10)
            --
        elseif (selection == self.denoise025) then
            GuiAction.ButtonOffOn('iop/atrous/preset/' .. _dt("denoise & sharpen"))
            GuiAction.SetValue('iop/atrous/mix', 0, 'value', 'set', 0.25)
            --
        elseif (selection == self.denoise050) then
            GuiAction.ButtonOffOn('iop/atrous/preset/' .. _dt("denoise & sharpen"))
            GuiAction.SetValue('iop/atrous/mix', 0, 'value', 'set', 0.5)
        end
    end

    ---------------------------------------------------------------

    StepDiffuseOrSharpen = Workflow.StepConfiguration:new():new
        {
            OperationNameInternal = 'diffuse',
            WidgetStackValue = WidgetStack.Modules,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 8,
            Label = _dt("diffuse or sharpen"),
            Tooltip = _(
                "Adjust luminance and chroma contrast. Apply choosen preset (clarity or denoise & sharpen). Choose different values to adjust the strength of the effect.")
        }

    table.insert(Workflow.ModuleSteps, StepDiffuseOrSharpen)

    function StepDiffuseOrSharpen:Init()
        self:CreateLabelWidget()
        self:CreateDefaultBasicWidget()


        self.ConfigurationValues =
        {
            _("unchanged"),
            _dt("dehaze"),
            _dt("denoise: coarse"),
            _dt("denoise: fine"),
            _dt("denoise: medium"),
            _dt("lens deblur: medium"),
            _dt("local contrast"),
            _dt("sharpen demosaicing: AA filter"),
            _dt("sharpness")
        }

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

        GuiAction.Do('iop/diffuse/preset/' .. _dt(selection), 0, '', '', 1.0)
    end

    ---------------------------------------------------------------

    StepToneEqualizerMask = Workflow.StepConfiguration:new():new
        {
            OperationNameInternal = 'toneequal',
            WidgetStackValue = WidgetStack.Modules,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 4,
            Label = GuiTranslation.dtConcat({ "tone equalizer", ' ', "masking" }),
            Tooltip = _(
                "Apply automatic mask contrast and exposure compensation. Auto adjust the contrast and average exposure.")
        }

    table.insert(Workflow.ModuleSteps, StepToneEqualizerMask)

    function StepToneEqualizerMask:Init()
        self:CreateLabelWidget()
        self:CreateSimpleBasicWidget()

        self.ConfigurationValues =
        {
            _("unchanged"),
            _("mask exposure compensation"),
            _("mask contrast compensation"),
            _("exposure & contrast comp."),
        }

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
        GuiAction.DoWithoutEvent('iop/toneequal/page', 0, 'masking', '', 1.0)

        if (selection == _("mask exposure compensation")) then
            GuiAction.Do('iop/toneequal/mask exposure compensation', 0, 'button', 'toggle', 1.0)
            Helper.ThreadSleep(StepTimeout:Value())
            --
        elseif (selection == _("mask contrast compensation")) then
            GuiAction.Do('iop/toneequal/mask contrast compensation', 0, 'button', 'toggle', 1.0)
            Helper.ThreadSleep(StepTimeout:Value())
            --
        elseif (selection == _("exposure & contrast comp.")) then
            GuiAction.Do('iop/toneequal/mask exposure compensation', 0, 'button', 'toggle', 1.0)
            Helper.ThreadSleep(StepTimeout:Value())
            GuiAction.Do('iop/toneequal/mask contrast compensation', 0, 'button', 'toggle', 1.0)
            Helper.ThreadSleep(StepTimeout:Value())
        end

        -- workaround: show this module, otherwise the buttons will not be pressed
        GuiAction.HideDarkroomModule('iop/toneequal')
        --
    end

    ---------------------------------------------------------------

    StepToneEqualizer = Workflow.StepConfiguration:new():new
        {
            OperationNameInternal = 'toneequal',
            WidgetStackValue = WidgetStack.Modules,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 1,
            Label = _dt("tone equalizer"),
            Tooltip = _(
                "Use preset to compress shadows and highlights with exposure-independent guided filter (eigf) (soft, medium or strong).")
        }

    table.insert(Workflow.ModuleSteps, StepToneEqualizer)

    function StepToneEqualizer:Init()
        self:CreateLabelWidget()
        self:CreateDefaultBasicWidget()

        self.ConfigurationValues =
        {
            _("unchanged"),
            _("compress shadows-highlights (eigf): medium"),
            _("compress shadows-highlights (eigf): soft"),
            _("compress shadows-highlights (eigf): strong")
        }

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


        GuiAction.ButtonOffOn('iop/toneequal/preset/' .. selection)
    end

    ---------------------------------------------------------------

    StepExposureCorrection = Workflow.StepConfiguration:new():new
        {
            OperationNameInternal = 'exposure',
            WidgetStackValue = WidgetStack.Modules,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 1,
            Label = _dt("exposure"),
            Tooltip = _(
                "Automatically adjust the exposure correction. Remove the camera exposure bias, useful if you exposed the image to the right.")
        }

    table.insert(Workflow.ModuleSteps, StepExposureCorrection)

    function StepExposureCorrection:Init()
        self:CreateLabelWidget()
        self:CreateDefaultBasicWidget()

        self.ConfigurationValues =
        {
            _("unchanged"),
            _("adjust exposure correction"),
            _("adjust & compensate bias"),
        }

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

        GuiAction.ButtonOffOn('iop/exposure/exposure')

        if (selection == _("adjust & compensate bias")) then
            local checkbox = GuiAction.GetValue('iop/exposure/compensate exposure bias', '')
            if (checkbox == 0) then
                GuiAction.Do('iop/exposure/compensate exposure bias', 0, '', 'on', 1.0)
            else
                LogHelper.Info(indent .. _("checkbox already selected, nothing to do"))
            end
        end
    end

    ---------------------------------------------------------------

    StepLensCorrection = Workflow.StepConfiguration:new():new
        {
            OperationNameInternal = 'lens',
            WidgetStackValue = WidgetStack.Modules,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 2,
            Label = _dt("lens correction"),
            Tooltip = _("Enable and reset lens correction module."),
        }

    table.insert(Workflow.ModuleSteps, StepLensCorrection)

    function StepLensCorrection:Init()
        self:CreateLabelWidget()
        self:CreateDefaultBasicWidget()

        self.lensfunSelection = _dt("Lensfun database")

        self.ConfigurationValues =
        {
            _("unchanged"),
            self.lensfunSelection,
        }

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

    StepDenoiseProfiled = Workflow.StepConfiguration:new():new
        {
            OperationNameInternal = 'denoiseprofile',
            WidgetStackValue = WidgetStack.Modules,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 1,
            Label = _dt("denoise (profiled)"),
            Tooltip = _(
                "Enable denoise (profiled) module. There is nothing to configure, just enable or reset this module.")
        }

    table.insert(Workflow.ModuleSteps, StepDenoiseProfiled)

    function StepDenoiseProfiled:Init()
        self:CreateLabelWidget()
        self:CreateDefaultBasicWidget()

        self.ConfigurationValues = { _("unchanged") }

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

    StepChromaticAberrations = Workflow.StepConfiguration:new():new
        {
            OperationNameInternal = 'cacorrect',
            WidgetStackValue = WidgetStack.Modules,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 2,
            Label = _dt("chromatic aberrations"),
            Tooltip = _(
                "Correct chromatic aberrations. Distinguish between Bayer sensor and other camera sensors. This operation uses the corresponding correction module and disables the other.")
        }

    table.insert(Workflow.ModuleSteps, StepChromaticAberrations)

    function StepChromaticAberrations:Init()
        self:CreateLabelWidget()
        self:CreateDefaultBasicWidget()

        self.ConfigurationValues =
        {
            _("unchanged"),
            _("Bayer sensor"),
            _("other sensors")
        }

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

    StepColorCalibrationIlluminant = Workflow.StepConfiguration:new():new
        {
            OperationNameInternal = 'channelmixerrgb',
            WidgetStackValue = WidgetStack.Modules,
            WidgetUnchangedStepConfigurationValue = 1,

            -- see EnableDefaultStepConfiguation() override
            WidgetDefaultStepConfiguationValue = nil,
            Label = GuiTranslation.dtConcat({ "color calibration", ' ', "illuminant" }),
            Tooltip = _(
                "Perform color space corrections in color calibration module. Select the illuminant. The type of illuminant assumed to have lit the scene. By default unchanged for the legacy workflow.")
        }

    -- distinguish between modern and legacy workflow
    -- keep value unchanged (1), if using legacy workflow
    -- depends on darktable preference settings
    function StepColorCalibrationIlluminant:EnableDefaultStepConfiguation()
        -- "unchanged: scene referred default"
        self.Widget.value = Helper.CheckDarktableModernWorkflowPreference() and 1 or 1

        -- "same as pipeline"
        -- self.Widget.value = Helper.CheckDarktableModernWorkflowPreference() and 3 or 1
    end

    table.insert(Workflow.ModuleSteps, StepColorCalibrationIlluminant)

    -- combobox values see darktable typedef enum dt_illuminant_t
    -- github/darktable/src/common/illuminants.h
    -- github/darktable/po/darktable.pot
    -- github/darktable/build/lib/darktable/plugins/introspection_channelmixerrgb.c

    function StepColorCalibrationIlluminant:Init()
        self:CreateLabelWidget()
        self:CreateDefaultBasicWidget()

        self.ConfigurationValues =
        {
            _("unchanged"), -- additional value
            _dt("set white balance to detected from area"),
            _dt("same as pipeline (D50)"),
            _dt("A (incandescent)"),
            _dt("D (daylight)"),
            _dt("E (equi-energy)"),
            _dt("F (fluorescent)"),
            _dt("LED (LED light)"),
            _dt("Planckian (black body)"),
            _dt("custom"),
            _dt("(AI) detect from image surfaces..."),
            _dt("(AI) detect from image edges..."),
            _dt("as shot in camera")
        }

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
        if(selection == _dt("set white balance to detected from area")) then
            
            -- dt.gui.action("iop/channelmixerrgb/picker", "", "toggle", 1,000, 0)
            GuiAction.Do('iop/channelmixerrgb/picker', 0, '', 'toggle', 1.0)
            return
        end

        -- set predefined values
        local currentSelectionIndex = GuiAction.GetValue('iop/channelmixerrgb/illuminant', 'selection')
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

    StepColorCalibrationAdaptation = Workflow.StepConfiguration:new():new
        {
            OperationNameInternal = 'channelmixerrgb',
            WidgetStackValue = WidgetStack.Modules,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 3,
            Label = GuiTranslation.dtConcat({ "color calibration", ' ', "adaptation" }),
            Tooltip = _(
                "Perform color space corrections in color calibration module. Select the adaptation. The working color space in which the module will perform its chromatic adaptation transform and channel mixing.")
        }

    table.insert(Workflow.ModuleSteps, StepColorCalibrationAdaptation)

    -- combobox values see darktable typedef enum dt_adaptation_t

    function StepColorCalibrationAdaptation:Init()
        self:CreateLabelWidget()
        self:CreateDefaultBasicWidget()

        self.ConfigurationValues =
        {
            _("unchanged"), -- additional value
            _dt(""),
            _dt("linear Bradford (ICC v4)"),
            _dt("CAT16 (CIECAM16)"),
            _dt("non-linear Bradford"),
            _dt("XYZ"),
            _dt("none (bypass)")
        }

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

    StepHighlightReconstruction = Workflow.StepConfiguration:new():new
        {
            OperationNameInternal = 'highlights',
            WidgetStackValue = WidgetStack.Modules,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 2,
            Label = _dt("highlight reconstruction"),
            Tooltip = _(
                "Reconstruct color information for clipped pixels. Select an appropriate reconstruction methods to reconstruct the missing data from unclipped channels and/or neighboring pixels.")
        }

    table.insert(Workflow.ModuleSteps, StepHighlightReconstruction)

    function StepHighlightReconstruction:Init()
        self:CreateLabelWidget()
        self:CreateDefaultBasicWidget()

        self.ConfigurationValues =
        {
            _("unchanged"),
            _dt("inpaint opposed"),
            _dt("reconstruct in LCh"),
            _dt("clip highlights"),
            _dt("segmentation based"),
            _dt("guided laplacians")
        }

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

    StepWhiteBalance = Workflow.StepConfiguration:new():new
        {
            OperationNameInternal = 'temperature',
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetStackValue = WidgetStack.Modules,

            -- see EnableDefaultStepConfiguation() override
            WidgetDefaultStepConfiguationValue = nil,
            Label = _("white balance"),
            Tooltip = _(
                "Adjust the white balance of the image by altering the temperature. By default unchanged for the legacy workflow.")
        }


    -- distinguish between modern and legacy workflow
    -- keep value unchanged, if using legacy workflow
    -- depends on darktable preference settings
    function StepWhiteBalance:EnableDefaultStepConfiguation()
        self.Widget.value = Helper.CheckDarktableModernWorkflowPreference() and 6 or 1
    end

    table.insert(Workflow.ModuleSteps, StepWhiteBalance)

    function StepWhiteBalance:Init()
        self:CreateLabelWidget()
        self:CreateDefaultBasicWidget()

        self.ConfigurationValues =
        {
            _("unchanged"),
            _dt("as shot"),
            _dt("from image area"),
            _dt("user modified"),
            _dt("camera reference"),
            _dt("as shot to reference")
        }

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

    StepResetModuleHistory = Workflow.StepConfiguration:new():new
        {
            -- operation = nil: ignore this module during module reset
            OperationNameInternal = nil,
            WidgetStackValue = WidgetStack.Settings,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 1,
            Label = _("discard complete history"),
            Tooltip = _("Reset all modules of the whole pixelpipe and discard complete history.")
        }

    table.insert(Workflow.ModuleSteps, StepResetModuleHistory)

    function StepResetModuleHistory:Init()
        self:CreateLabelWidget()
        self:CreateEmptyBasicWidget()

        self.ConfigurationValues =
        {
            _dt("no"), _dt("yes")
        }

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

    StepShowModulesDuringExecution = Workflow.StepConfiguration:new():new
        {
            -- operation = nil: ignore this module during module reset
            OperationNameInternal = nil,
            WidgetStackValue = WidgetStack.Settings,
            WidgetUnchangedStepConfigurationValue = 1,
            WidgetDefaultStepConfiguationValue = 1,
            Label = _("show modules"),
            Tooltip = _(
                "Show darkroom modules for enabled workflow steps during execution of this initial workflow. This makes the changes easier to understand.")
        }

    table.insert(Workflow.ModuleSteps, StepShowModulesDuringExecution)

    function StepShowModulesDuringExecution:Init()
        self:CreateLabelWidget()
        self:CreateEmptyBasicWidget()

        self.ConfigurationValues = { _dt("no"), _dt("yes") }

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

    ---------------------------------------------------------------

    StepTimeout = Workflow.StepConfiguration:new():new
        {
            -- operation = nil: ignore this module during module reset
            OperationNameInternal = nil,
            WidgetStackValue = WidgetStack.Settings,
            WidgetUnchangedStepConfigurationValue = 2,
            WidgetDefaultStepConfiguationValue = 3,
            Label = _("timeout value"),
            Tooltip = _(
                "Some calculations take a certain amount of time. Depending on the hardware equipment also longer.This script waits and attempts to detect timeouts. If steps take much longer than expected, those steps will be aborted. You can configure the default timeout (ms). Before and after each step of the workflow, the script waits this time. In other places also a multiple (loading an image) or a fraction (querying a status).")
        }

    table.insert(Workflow.ModuleSteps, StepTimeout)

    function StepTimeout:Init()
        self:CreateLabelWidget()
        self:CreateEmptyBasicWidget()

        self.ConfigurationValues =
        {
            '500',
            '1000',
            '2000',
            '3000',
            '4000',
            '5000'
        }

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
