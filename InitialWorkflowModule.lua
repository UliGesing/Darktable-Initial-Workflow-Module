--[[
  Darktable Initial Workflow Module

  Version 2023-02-26

  This script can be used together with darktable. See
  https://www.darktable.org/ for more information.

  This script offers a new "inital workflow" module both in
  lighttable and darkroom view. It can be used to do some
  configuration for an initial image workflow. It calls some
  automatisms of different modules in the darkroom view. If
  this suits your workflow, the script saves some clicks and time.

  copyright (c) 2022 Ulrich Gesing

  USAGE: See Darktable documentation for your first steps:
  https://docs.darktable.org/usermanual/4.2/en/lua/

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
local dt = require "darktable"
local du = require "lib/dtutils"
local log = require "lib/dtutils.log"
local debug = require "darktable.debug"

local MOD = "InitialWorkflowModule"

---------------------------------------------------------------

-- some helper methods...

log.log_level(log.info) -- log.info or log.warn or log.debug

local LogMinorNr = 0
local LogMajorNr = 0
local LogMajorMax = 0

local function LogInfo(text)
  LogMinorNr = LogMinorNr + 1
  log.msg(log.info, "[" .. LogMajorNr .. "/" .. LogMajorMax .. "] Step " .. LogMinorNr .. ": " .. text)
end

local function LogScreen(text)
  log.msg(log.screen, text)
end

-- get Darktable workflow setting
-- read preference "auto-apply chromatic adaptation defaults"
local function GetDarktableWorkflowSetting()
  return dt.preferences.read("darktable", "plugins/darkroom/chromatic-adaptation", "string")
end

-- debug helper function to dump preference keys
-- helps you to find out strings like "plugins/darkroom/chromatic-adaptation"
-- darktable -d lua > ~/keys.txt
local function DumpPreferenceKeys()
  LogInfo("get preference keys...")
  local keys = dt.preferences.get_keys()
  LogInfo(#keys .. " retrieved, listing follows")
  for _, key in ipairs(keys) do
    LogInfo(key)
  end
end

-- declare some variables to install the module
local env = {
  InstallModuleEventRegistered = false,
  InstallModuleDone = false,
  WaitForEventReceivedFlag = nil,
}

-- check Darktable API version
-- new API of DT 4.2 is needed to use "pixelpipe-processing-complete" event
local apiCheck, err = pcall(function() du.check_min_api_version("9.0.0", "InitialWorkflowModule") end)
if (apiCheck) then
  LogInfo("Darktable 4.2 API detected.")
else
  LogInfo("This script needs Darktable 4.2 API to run.")
  return
end

-- check, if given array contains a certain value
local function contains(table, value)
  for i, element in ipairs(table) do
    if element == value then
      return true
    end
  end
  return false
end

---------------------------------------------------------------

-- Event handling helper functions
-- wait for pixel pipe processing to complete

local function WaitForEventReceived(event, image)
  -- event handling
  env.WaitForEventReceivedFlag = 1
end

local function WaitForEventEmbeddedFunction(embeddedFunction, eventType, min, max)
  -- execute embedded function and wait for given event
  dt.control.sleep(200)

  -- register event
  env.WaitForEventReceivedFlag = nil
  dt.destroy_event("WorkflowModule", eventType)
  if (eventType) then
    dt.register_event("WorkflowModule", eventType, WaitForEventReceived)
  end

  -- execute given function
  embeddedFunction()

  -- wait for registered event
  local duration = 0
  local period = math.min(min, 250)

  while (not (eventType and env.WaitForEventReceivedFlag)) or (duration < min) do
    dt.control.sleep(period)
    duration = duration + period

    if (duration >= max) then
      LogInfo("timeout waiting for event " .. eventType)
      break
    end
  end

  -- unregister event
  env.WaitForEventReceivedFlag = nil
  if (eventType) then
    dt.destroy_event("WorkflowModule", eventType)
  end

  dt.control.sleep(200)
end

local function WaitForPixelPipe(embeddedFunction)
  -- execute embedded function and wait for processing to complete
  -- wait for new pixelpipe-processing-complete event
  -- this event is new in DT 4.2
  WaitForEventEmbeddedFunction(embeddedFunction, "pixelpipe-processing-complete", 100, 2000)
end

---------------------------------------------------------------
-- helper functions to access Darktable feature via user interface
-- use event handling helper functions to wait for pixel pipe
-- processing to complete


local function GuiActionWaitForPixelPipe(path, instance, element, effect, speed)
  -- perform the specified effect on the path and element of an action
  -- see https://docs.darktable.org/lua/stable/lua.api.manual/darktable/gui/action/

  local result
  WaitForPixelPipe(function()
    result = dt.gui.action(path, instance, element, effect, speed)
  end)
  return result
end

local function GuiActionDo(path, element)
  -- perform the specified action
  -- wait a bit...
  dt.gui.action(path, 0, element, "", 1.0)
  dt.control.sleep(200)
end

local function GuiActionGetValue(path, element)
  -- get current value
  return dt.gui.action(path, 0, element)
end

---------------------------------------------------------------
-- base class of workflow steps

-- collect all workflow steps in a table
-- used to execute or configure all steps at once
local WorkflowSteps = {}

-- workflow buttons: collect button widgets in a table
-- used during callback functions
local WorkflowButtons = {}

-- base class of all workflow steps
local WorkflowStep =
{
  Widget,
  Tooltip,
}

function WorkflowStep:new(obj)
  -- create object if user does not provide one
  obj = obj or {}
  -- define inheritance
  setmetatable(obj, self)
  self.__index = self
  -- return new object
  return obj
end

function WorkflowStep:LogStepMessage()
  LogInfo(self.Widget.label .. ": " .. self.Widget.value)
end

function WorkflowStep:ShowDarkroomModule(moduleName)
  -- show given darkroom module
  -- check if the module is already displayed
  local visible = GuiActionGetValue(moduleName, "show")
  if (visible == 0) then
    LogInfo("show module " .. moduleName)
    GuiActionDo(moduleName, "show")
  end
end

function WorkflowStep:EnableDarkroomModule(moduleName)
  -- enable given darkroom module
  -- check if the module is already activated
  local status = GuiActionGetValue(moduleName, "enable")
  if (status == 0) then
    LogInfo("enable module " .. moduleName)
    GuiActionWaitForPixelPipe(moduleName, 0, "enable", "", 1.0)
  end

  self:ShowDarkroomModule(moduleName)
end

function WorkflowStep:DisableDarkroomModule(moduleName)
  -- disable given darkroom module
  -- check if the module is already activated
  local status = GuiActionGetValue(moduleName, "enable")

  if (status ~= 0) then
    LogInfo("disable module " .. moduleName)
    GuiActionWaitForPixelPipe(moduleName, 0, "enable", "", 1.0)
  end
end

---------------------------------------------------------------
-- base class of workflow steps with Button widget

WorkflowStepButton = WorkflowStep:new():new
    {
    }

---------------------------------------------------------------
-- base class of workflow steps with Combobox widget

WorkflowStepCombobox = WorkflowStep:new():new
    {
      OperationNameInternal,
      DisableValue,
      DefaultValue
    }

function WorkflowStepCombobox:Disable()
  self.Widget.value = self.DisableValue
end

function WorkflowStepCombobox:Default()
  self.Widget.value = self.DefaultValue
end

function WorkflowStepCombobox:OperationName()
  return self.OperationNameInternal
end

function WorkflowStepCombobox:OperationPath()
  return "iop/" .. self:OperationName()
end

function WorkflowStepCombobox:ResetModule()
  GuiActionWaitForPixelPipe(self:OperationPath(), 0, "reset", "", 1.0)
end

function WorkflowStepCombobox:SavePreferenceValue()
  local preferenceValue = dt.preferences.read(MOD, self.Widget.label, 'string')
  local comboBoxValue = self.Widget.value

  -- save any changes
  if (preferenceValue ~= comboBoxValue) then
    -- LogInfo("preference write "..self.Widget.label.." = '"..comboBoxValue.."'")
    dt.preferences.write(MOD, self.Widget.label, 'string', comboBoxValue)
  end
end

function WorkflowStepCombobox:ReadPreferenceValue()
  local preferenceValue = dt.preferences.read(MOD, self.Widget.label, 'string')

  -- get combo box index of saved preference value
  for i, comboBoxValue in ipairs(self.ComboBoxValues) do
    if (preferenceValue == comboBoxValue) then
      if (self.Widget.value ~= i) then
        -- LogInfo("preference read "..self.Widget.label.." = '" .. preferenceValue .. "'")
        self.Widget.value = i
      end
      return
    end
  end

  self:Default()
end

-- called from callback function within a "foreign context"
-- we have to determine the button object or workflow step first
function GetWorkflowItem(widget, table)
  for i, item in ipairs(table) do
    if (item.Widget == widget) then
      return item
    end
  end
  return nil
end

function GetWorkflowButton(widget)
  return GetWorkflowItem(widget, WorkflowButtons)
end

function GetWorkflowStep(widget)
  return GetWorkflowItem(widget, WorkflowSteps)
end

function ComboBoxChangedCallback(widget)
  GetWorkflowStep(widget):SavePreferenceValue()
end

---------------------------------------------------------------

--[[

  IMPLEMENTATION OF WORKFLOW STEPS

  For more details see Readme.md in
  https://github.com/UliGesing/Darktable-Initial-Workflow-Module
 ]]
StepCompressHistoryStack = WorkflowStepCombobox:new():new
    {
      -- operation = nil: ignore this module during module reset
      OperationNameInternal = nil,
      DisableValue = 1, -- item in ComboBoxValues
      DefaultValue = 2, -- item in ComboBoxValues
      Tooltip = "Generate the shortest history stack that reproduces the current image. This removes your current history snapshots."
    }

table.insert(WorkflowSteps, StepCompressHistoryStack)

function StepCompressHistoryStack:Init()
  self.ComboBoxValues = { "no", "yes" }

  self.Widget = dt.new_widget("combobox")
      {
        changed_callback = ComboBoxChangedCallback,
        label = "compress history stack",
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepCompressHistoryStack:Run()
  local selection = self.Widget.value

  if (selection == "yes") then
    self:LogStepMessage()
    GuiActionWaitForPixelPipe("lib/history/compress history stack", 0, "", "", 1.0)
  end
end

---------------------------------------------------------------

StepDynamicRangeSceneToDisplay = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      -- distinguish between different modules...
      OperationNameInternal = "Filmic or Sigmoid",
      DisableValue = 1,
      DefaultValue = 4,
      Tooltip = "Use Filmic or Sigmoid to expand or contract the dynamic range of the \z
      scene to fit the dynamic range of the display. Auto tune filmic levels of black + \z
      white relative exposure and / or reset module settings. Or use Sigmoid with one of \z
      its presets. Use only one of Filmic, Sigmoid or Basecurve, this module disables the others."
    }

table.insert(WorkflowSteps, StepDynamicRangeSceneToDisplay)

function StepDynamicRangeSceneToDisplay:Init()
  self.ComboBoxValues =
  {
    "unchanged",
    "Filmic reset defaults",
    "Filmic auto tune levels",
    "Filmic reset + auto tune",
    "Sigmoid reset defaults, color per channel",
    "Sigmoid reset defaults, color rgb ratio",
    "Sigmoid ACES 100 preset"
  }

  self.Widget = dt.new_widget("combobox")
      {
        changed_callback = ComboBoxChangedCallback,
        label = "dynamic range: scene to display",
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepDynamicRangeSceneToDisplay:FilmicSelected()
  return contains(
    { "Filmic reset defaults",
      "Filmic auto tune levels",
      "Filmic reset + auto tune"
    }, self.Widget.value)
end

function StepDynamicRangeSceneToDisplay:SigmoidSelected()
  return contains(
    { "Sigmoid reset defaults, color per channel",
      "Sigmoid reset defaults, color rgb ratio",
      "Sigmoid ACES 100 preset"
    }, self.Widget.value)
end

function StepDynamicRangeSceneToDisplay:OperationName()
  -- override base class function
  -- distinguish between filmic and sigmoid module

  if (self:FilmicSelected()) then
    return "filmicrgb"
  end

  if (self:SigmoidSelected()) then
    return "sigmoid"
  end

  return nil
end

function StepDynamicRangeSceneToDisplay:Run()
  local selection = self.Widget.value

  if (selection == "unchanged") then
    return
  end

  local filmic = self:FilmicSelected()

  local filmicReset = contains(
    { "Filmic reset defaults",
      "Filmic reset + auto tune"
    }, selection)

  local filmicAuto = contains(
    { "Filmic auto tune b+w relative exposure",
      "Filmic reset + auto tune"
    }, selection)

  local sigmoid = self:SigmoidSelected()

  local sigmoidDefaultPerChannel = contains(
    { "Sigmoid reset defaults, color per channel"
    }, selection)

  local sigmoidDefaultRgbRatio = contains(
    { "Sigmoid reset defaults, color rgb ratio"
    }, selection)

  local sigmoidACES100 = contains(
    { "Sigmoid ACES 100 preset"
    }, selection)


  self:LogStepMessage()

  if (filmic) then
    self:DisableDarkroomModule("iop/sigmoid")
    self:DisableDarkroomModule("iop/basecurve")
    self:EnableDarkroomModule("iop/filmicrgb")

    if (filmicReset) then
      GuiActionWaitForPixelPipe("iop/filmicrgb", 0, "reset", "", 1.0)
    end

    if (filmicAuto) then
      GuiActionWaitForPixelPipe("iop/filmicrgb/auto tune levels", 0, "button", "on", 1.0)
    end
  end

  if (sigmoid) then
    self:DisableDarkroomModule("iop/filmicrgb")
    self:DisableDarkroomModule("iop/basecurve")
    self:EnableDarkroomModule("iop/sigmoid")

    GuiActionWaitForPixelPipe("iop/sigmoid", 0, "reset", "", 1.0)

    if (sigmoidDefaultPerChannel) then
      -- keep defaults
    end

    if (sigmoidDefaultRgbRatio) then
      GuiActionWaitForPixelPipe("iop/sigmoid/color processing", 0, "selection", "item:" .. "rgb ratio", 1.0)
    end

    if (sigmoidACES100) then
      GuiActionWaitForPixelPipe("iop/sigmoid/preset/ACES 100-nit like", 0, "button", "on", 1.0)
    end
  end
end

---------------------------------------------------------------

StepColorBalanceGlobalSaturation = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = "colorbalancergb",
      DisableValue = 1,
      DefaultValue = 7,
      Tooltip = "Adjust global saturation in color balance rgb module."
    }

table.insert(WorkflowSteps, StepColorBalanceGlobalSaturation)

function StepColorBalanceGlobalSaturation:Init()
  self.ComboBoxValues =
  {
    "unchanged", 0, 5, 10, 15, 20, 25, 30, 35
  }

  self.Widget = dt.new_widget("combobox")
      {
        changed_callback = ComboBoxChangedCallback,
        label = "color balance rgb global saturation",
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepColorBalanceGlobalSaturation:Run()
  local selection = self.Widget.value

  if (selection ~= "unchanged") then
    self:LogStepMessage()
    self:EnableDarkroomModule("iop/colorbalancergb")
    GuiActionWaitForPixelPipe("iop/colorbalancergb/global saturation", 0, "value", "set", selection / 100)
  end
end

---------------------------------------------------------------

StepColorBalanceGlobalChroma = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = "colorbalancergb",
      DisableValue = 1,
      DefaultValue = 5,
      Tooltip = "Adjust global chroma in color balance rgb module."
    }

table.insert(WorkflowSteps, StepColorBalanceGlobalChroma)

function StepColorBalanceGlobalChroma:Init()
  self.ComboBoxValues =
  {
    "unchanged", 0, 5, 10, 15, 20, 25, 30, 35
  }

  self.Widget = dt.new_widget("combobox")
      {
        changed_callback = ComboBoxChangedCallback,
        label = "color balance rgb global chroma",
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepColorBalanceGlobalChroma:Run()
  local selection = self.Widget.value

  if (selection ~= "unchanged") then
    self:LogStepMessage()
    self:EnableDarkroomModule("iop/colorbalancergb")
    GuiActionWaitForPixelPipe("iop/colorbalancergb/global chroma", 0, "value", "set", selection / 100)
  end
end

---------------------------------------------------------------

StepColorBalanceRGB = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = "colorbalancergb",
      DisableValue = 1,
      DefaultValue = 2,
      Tooltip = "Choose a predefined preset for your color-grading. Or set \z
      auto pickers of the module mask and peak white and gray luminance value \z
      to normalize the power setting in the 4 ways tab."
    }

table.insert(WorkflowSteps, StepColorBalanceRGB)

function StepColorBalanceRGB:Init()
  self.ComboBoxValues =
  {
    "unchanged",
    "reset and peak white & grey fulcrum",
    "add basic colorfulness (legacy)",
    "basic colorfulness: natural skin",
    "basic colorfulness: standard",
    "basic colorfulness: vibrant colors"
  }

  self.Widget = dt.new_widget("combobox")
      {
        changed_callback = ComboBoxChangedCallback,
        label = "color balance rgb",
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepColorBalanceRGB:Run()
  local selection = self.Widget.value

  if (selection == "unchanged") then
    return
  end

  self:LogStepMessage()
  self:EnableDarkroomModule("iop/colorbalancergb")

  if (selection == "reset and peak white & grey fulcrum") then
    GuiActionWaitForPixelPipe("iop/colorbalancergb", 0, "reset", "", 1.0)
    GuiActionWaitForPixelPipe("iop/colorbalancergb/white fulcrum", 0, "button", "on", 1.0)
    GuiActionWaitForPixelPipe("iop/colorbalancergb/contrast gray fulcrum", 0, "button", "on", 1.0)
  else
    GuiActionWaitForPixelPipe("iop/colorbalancergb/preset/" .. selection, 0, "button", "on", 1.0)
  end
end

---------------------------------------------------------------

StepContrastEqualizer = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = "atrous",
      DisableValue = 1,
      DefaultValue = 3,
      Tooltip = "Adjust luminance and chroma contrast. Apply choosen \z
      preset (clarity or denoise & sharpen). Choose different values \z
      to adjust the strength of the effect."
    }

table.insert(WorkflowSteps, StepContrastEqualizer)

function StepContrastEqualizer:Init()
  self.ComboBoxValues =
  {
    "unchanged",
    "reset to default",
    "clarity, strength 0,25",
    "clarity, strength 0,50",
    "denoise & sharpen, strength 0,25",
    "denoise & sharpen, strength 0,50"
  }

  self.Widget = dt.new_widget("combobox")
      {
        changed_callback = ComboBoxChangedCallback,
        label = "contrast equalizer",
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepContrastEqualizer:Run()
  local selection = self.Widget.value

  if (selection == "unchanged") then
    return
  end

  self:LogStepMessage()
  self:EnableDarkroomModule("iop/atrous")
  GuiActionWaitForPixelPipe("iop/atrous", 0, "reset", "", 1.0)

  if (selection == "clarity, strength 0,25") then
    GuiActionWaitForPixelPipe("iop/atrous/preset/clarity", 0, "button", "on", 1.0)
    GuiActionWaitForPixelPipe("iop/atrous/mix", 0, "value", "set", 0.25)
  end

  if (selection == "clarity, strength 0,50") then
    GuiActionWaitForPixelPipe("iop/atrous/preset/clarity", 0, "button", "on", 1.0)
    GuiActionWaitForPixelPipe("iop/atrous/mix", 0, "value", "set", 0.5)
  end

  if (selection == "denoise & sharpen, strength 0,25") then
    GuiActionWaitForPixelPipe("iop/atrous/preset/denoise & sharpen", 0, "button", "on", 1.0)
    GuiActionWaitForPixelPipe("iop/atrous/mix", 0, "value", "set", 0.25)
  end

  if (selection == "denoise & sharpen, strength 0,50") then
    GuiActionWaitForPixelPipe("iop/atrous/preset/denoise & sharpen", 0, "button", "on", 1.0)
    GuiActionWaitForPixelPipe("iop/atrous/mix", 0, "value", "set", 0.5)
  end
end

---------------------------------------------------------------

StepToneEqualizerMask = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = "toneequal",
      DisableValue = 1,
      DefaultValue = 3,
      Tooltip = "Use default preset mask blending for all purposes \z
      plus automatic mask contrast and exposure compensation. Or use \z
      preset to compress shadows and highlights with exposure-independent \z
      guided filter (eigf) (soft, medium or strong)."
    }

table.insert(WorkflowSteps, StepToneEqualizerMask)

function StepToneEqualizerMask:Init()
  self.ComboBoxValues =
  {
    "unchanged",
    "default mask blending",
    "default plus mask compensation",
    "compress high-low (eigf): medium",
    "compress high-low (eigf): soft",
    "compress high-low (eigf): strong"
  }

  self.Widget = dt.new_widget("combobox")
      {
        changed_callback = ComboBoxChangedCallback,
        label = "tone equalizer",
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepToneEqualizerMask:Run()
  local selection = self.Widget.value

  if (selection == "unchanged") then
    return
  end

  self:LogStepMessage()
  self:EnableDarkroomModule("iop/toneequal")

  GuiActionWaitForPixelPipe("iop/toneequal", 0, "reset", "", 1.0)

  if (selection == "default mask blending") then
    -- nothing else to do...
  end

  if (selection == "default plus mask compensation") then
    GuiActionDo("iop/toneequal/page", "masking")
    GuiActionWaitForPixelPipe("iop/toneequal/mask contrast compensation", 0, "button", "on", 1.0)
    GuiActionWaitForPixelPipe("iop/toneequal/mask exposure compensation", 0, "button", "on", 1.0)
  end

  if (selection == "compress high-low (eigf): medium") then
    GuiActionWaitForPixelPipe("iop/toneequal/preset/compress shadows-highlights (eigf): medium", 0, "button", "on", 1.0)
  end

  if (selection == "compress high-low (eigf): soft") then
    GuiActionWaitForPixelPipe("iop/toneequal/preset/compress shadows-highlights (eigf): soft", 0, "button", "on", 1.0)
  end

  if (selection == "compress high-low (eigf): strong") then
    GuiActionWaitForPixelPipe("iop/toneequal/preset/compress shadows-highlights (eigf): strong", 0, "button", "on", 1.0)
  end
end

---------------------------------------------------------------

StepExposureCorrection = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = "exposure",
      DisableValue = 1,
      DefaultValue = 3,
      Tooltip = "Automatically adjust the exposure correction. Remove \z
      the camera exposure bias, useful if you exposed the image to the right."
    }

table.insert(WorkflowSteps, StepExposureCorrection)

function StepExposureCorrection:Init()
  self.ComboBoxValues =
  {
    "unchanged",
    "adjust exposure correction",
    "adjust exp. & compensate camera bias"
  }

  self.Widget = dt.new_widget("combobox")
      {
        changed_callback = ComboBoxChangedCallback,
        label = "exposure",
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepExposureCorrection:Run()
  local selection = self.Widget.value

  if (selection == "unchanged") then
    return
  end

  self:LogStepMessage()
  self:EnableDarkroomModule("iop/exposure")
  GuiActionWaitForPixelPipe("iop/exposure", 0, "reset", "", 1.0)

  if (selection == "adjust exposure correction") then
    GuiActionWaitForPixelPipe("iop/exposure/exposure", 0, "button", "on", 1.0)
  end

  if (selection == "adjust exp. & compensate camera bias") then
    GuiActionWaitForPixelPipe("iop/exposure/exposure", 0, "button", "on", 1.0)
    GuiActionWaitForPixelPipe("iop/exposure/compensate exposure bias", 0, "", "on", 1.0)
  end
end

---------------------------------------------------------------

StepLensCorrection = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = "lens",
      DisableValue = 1,
      DefaultValue = 3,
      Tooltip = "Enable and reset lens correction module.",
    }

table.insert(WorkflowSteps, StepLensCorrection)

function StepLensCorrection:Init()
  self.ComboBoxValues =
  {
    "unchanged",
    "enable and reset",
    "enable lensfun method"
  }

  self.Widget = dt.new_widget("combobox")
      {
        changed_callback = ComboBoxChangedCallback,
        label = "lens correction",
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepLensCorrection:Run()
  local selection = self.Widget.value

  if (selection == "unchanged") then
    return
  end

  self:LogStepMessage()
  self:EnableDarkroomModule("iop/lens")

  if (selection == "enable and reset") then
    GuiActionWaitForPixelPipe("iop/lens", 0, "reset", "", 1.0)
  end

  if (selection == "enable lensfun method") then
    GuiActionWaitForPixelPipe("iop/lens", 0, "reset", "", 1.0)
    GuiActionWaitForPixelPipe("iop/lens/correction method", 0, "selection", "item:lensfun database", 1.0)
  end
end

---------------------------------------------------------------

StepDenoiseProfiled = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = "denoiseprofile",
      DisableValue = 1,
      DefaultValue = 2,
      Tooltip = "Enable and reset denoise (profiled) module."
    }

table.insert(WorkflowSteps, StepDenoiseProfiled)

function StepDenoiseProfiled:Init()
  self.ComboBoxValues = { "unchanged", "enable and reset" }

  self.Widget = dt.new_widget("combobox")
      {
        changed_callback = ComboBoxChangedCallback,
        label = "denoise (profiled)",
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepDenoiseProfiled:Run()
  local selection = self.Widget.value

  if (selection == "unchanged") then
    return
  end

  if (selection == "enable and reset") then
    self:LogStepMessage()
    self:EnableDarkroomModule("iop/denoiseprofile")
    GuiActionWaitForPixelPipe("iop/denoiseprofile", 0, "reset", "", 1.0)
  end
end

---------------------------------------------------------------

StepChromaticAberrations = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = "cacorrect",
      DisableValue = 1,
      DefaultValue = 2,
      Tooltip = "Correct chromatic aberrations."
    }

table.insert(WorkflowSteps, StepChromaticAberrations)

function StepChromaticAberrations:Init()
  self.ComboBoxValues =
  {
    "unchanged",
    "enable (Bayer sensor)",
    "enable (other)"
  }

  self.Widget = dt.new_widget("combobox")
      {
        changed_callback = ComboBoxChangedCallback,
        label = "(raw) chromatic aberrations",
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepChromaticAberrations:Run()
  local selection = self.Widget.value

  if (selection == "unchanged") then
    return
  end

  self:LogStepMessage()

  if (selection == "enable (Bayer sensor)") then
    self:EnableDarkroomModule("iop/cacorrect")
  end

  if (selection == "enable (other)") then
    self:EnableDarkroomModule("iop/cacorrectrgb")
  end
end

---------------------------------------------------------------

StepColorCalibrationIlluminant = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = "channelmixerrgb",
      DisableValue = 1,

      -- distinguish between modern and legacy workflow
      -- keep white balance unchanged, if using legacy workflow
      -- see Darktable preferences - processing - auto-apply chromatic adaptation defaults
      DefaultValue = (GetDarktableWorkflowSetting() == "modern") and 2 or 1,
      Tooltip = "Perform color space corrections in color calibration \z
      module. By default unchanged for the legacy workflow."
    }

table.insert(WorkflowSteps, StepColorCalibrationIlluminant)

function StepColorCalibrationIlluminant:Init()
  self.ComboBoxValues =
  {
    "unchanged",
    "same as pipeline (D50)",
    "D (daylight)",
    "(AI) detect from image edges...",
    "as shot in camera"
  }

  self.Widget = dt.new_widget("combobox")
      {
        changed_callback = ComboBoxChangedCallback,
        label = "color calibration illuminant",
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepColorCalibrationIlluminant:Run()
  local selection = self.Widget.value

  if (selection == "unchanged") then
    return
  end

  self:LogStepMessage()
  self:EnableDarkroomModule("iop/channelmixerrgb")
  GuiActionWaitForPixelPipe("iop/channelmixerrgb/illuminant", 0, "selection", "item:" .. selection, 1.0)
end

---------------------------------------------------------------

-- this step was DISABLED
-- we have to wait for a Darktable bugfix (dt4.4)

StepHighlightReconstruction = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = "highlights",
      DisableValue = 1,
      DefaultValue = 1,
      Tooltip = "Reconstruct color information for clipped pixels. \z
      Select an appropriate reconstruction methods to reconstruct the \z
      missing data from unclipped channels and/or neighboring pixels."
    }

-- disabled step
-- do not add this step to the widget
-- table.insert(WorkflowSteps, StepHighlightReconstruction)

function StepHighlightReconstruction:Init()
  self.ComboBoxValues =
  {
    "unchanged",
    -- "inpaint opposed",
    -- "reconstruct in LCh",
    -- "clip highlights",
    -- "segmentation based",
    -- "guided laplacians"
  }

  self.Widget = dt.new_widget("combobox")
      {
        changed_callback = ComboBoxChangedCallback,
        label = "highlight reconstruction",
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepHighlightReconstruction:Run()
  local selection = self.Widget.value

  if (selection == "unchanged") then
    return
  end

  self:LogStepMessage()
  self:EnableDarkroomModule("iop/highlights")

  if (selection == "inpaint opposed") then
    GuiActionWaitForPixelPipe("iop/highlights/method", 0, "selection", "item:inpaint opposed", 1.0)
  end

  if (selection == "reconstruct in LCh") then
    GuiActionWaitForPixelPipe("iop/highlights/method", 0, "selection", "item:reconstruct in LCh", 1.0)
  end

  if (selection == "clip highlights") then
    GuiActionWaitForPixelPipe("iop/highlights/method", 0, "selection", "item:clip highlights", 1.0)
  end

  if (selection == "segmentation based") then
    GuiActionWaitForPixelPipe("iop/highlights/method", 0, "selection", "item:segmentation based", 1.0)
  end

  if (selection == "guided laplacians") then
    GuiActionWaitForPixelPipe("iop/highlights/method", 0, "selection", "item:guided laplacians", 1.0)
  end
end

---------------------------------------------------------------

StepWhiteBalance = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = "temperature",
      DisableValue = 1,

      -- distinguish between modern and legacy workflow
      -- keep white balance unchanged, if using legacy workflow
      -- see Darktable preferences - processing - auto-apply chromatic adaptation defaults
      DefaultValue = (GetDarktableWorkflowSetting() == "modern") and 2 or 1,

      Tooltip = "Adjust the white balance of the image by altering the \z
      temperature. By default unchanged for the legacy workflow."
    }

table.insert(WorkflowSteps, StepWhiteBalance)

function StepWhiteBalance:Init()
  self.ComboBoxValues =
  {
    "unchanged",
    "as shot",
    "from image area"
  }

  self.Widget = dt.new_widget("combobox")
      {
        changed_callback = ComboBoxChangedCallback,
        label = "white balance",
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepWhiteBalance:Run()
  local selection = self.Widget.value

  if (selection == "unchanged") then
    return
  end

  self:LogStepMessage()
  self:EnableDarkroomModule("iop/temperature")

  if (selection == "as shot") then
    GuiActionWaitForPixelPipe("iop/temperature/settings/as shot", 0, "", "", 1.0)
  elseif (selection == "from image area") then
    GuiActionWaitForPixelPipe("iop/temperature/settings/from image area", 0, "", "", 1.0)
  end
end

---------------------------------------------------------------

StepResetModuleHistory = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      -- operation = nil: ignore this module during module reset
      OperationNameInternal = nil,
      DisableValue = 1, -- item in ComboBoxValues
      DefaultValue = 2, -- item in ComboBoxValues
      Tooltip = "Reset modules that are part of this initial workflow. \z
      Keep other module settings like crop, rotate and perspective. Or \z
      reset all modules of the pixelpipe and discard complete history stack."
    }

table.insert(WorkflowSteps, StepResetModuleHistory)

function StepResetModuleHistory:Init()
  self.ComboBoxValues =
  {
    "no",
    "reset active initial workflow modules",
    "reset all initial workflow modules",
    "discard complete history stack"
  }

  self.Widget = dt.new_widget("combobox")
      {
        changed_callback = ComboBoxChangedCallback,
        label = "reset modules",
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepResetModuleHistory:Run()
  local selection = self.Widget.value

  if (selection == "no") then
    return
  end

  self:LogStepMessage()

  if (selection == "discard complete history stack") then
    GuiActionWaitForPixelPipe("lib/history", 0, "reset", "", 1.0)
  else
    -- collect modules to reset
    local modules = {}

    for i, step in ipairs(WorkflowSteps) do
      if (step ~= self) then
        if (step:OperationName()) then
          if (not contains(modules, step:OperationPath())) then
            -- reset active
            if (selection == "reset active initial workflow modules") then
              if (not contains({ "no", "unchanged" }, step.Widget.value)) then
                table.insert(modules, step:OperationPath())
              end
            end
            -- reset all
            if (selection == "reset all initial workflow modules") then
              table.insert(modules, step:OperationPath())
            end
          end
        end
      end
    end

    -- reset relevant modules
    for i, module in ipairs(modules) do
      LogInfo("- reset " .. module)
      GuiActionWaitForPixelPipe(module, 0, "reset", "", 1.0)
    end
  end
end

---------------------------------------------------------------

--[[

  IMPLEMENTATION OF BUTTON CONTROLS

  These are buttons to start the execution of the steps or e.g. to set default values.

]]
---------------------------------------------------------------

local function ProcessWorkflowSteps()
  -- process current image
  LogInfo("==============================")
  LogInfo("process workflow steps")

  dt.control.sleep(1000)

  -- execute all workflow steps
  -- the order is from bottom to top, along the pixel pipeline.
  for i = 1, #WorkflowSteps do
    step = WorkflowSteps[#WorkflowSteps + 1 - i]
    step:Run()
  end

  dt.control.sleep(1000)

  LogScreen("initial workflow - done")
  LogInfo("initial workflow - done")
  LogInfo("==============================")
end

local function ProcessImageInDarkroomView()
  LogMajorMax = 1
  LogMajorNr = 1
  LogMinorNr = 0

  ProcessWorkflowSteps()
end

local function ProcessSelectedImagesInLighttableView()
  -- function to process selected image(s)

  LogMajorMax = 0
  LogMajorNr = 0
  LogMinorNr = 0

  LogInfo("==============================")
  LogInfo("process selected images")

  -- check that there is an image selected to activate darkroom view

  local images = dt.gui.selection() -- dt.gui.action_images
  if not images or #images == 0 then
    LogScreen("no image selected")
    return
  end

  -- switch to darkroom view
  LogInfo("switch to darkroom view")
  WaitForPixelPipe(function()
    dt.gui.current_view(dt.gui.views.darkroom)
  end)

  dt.control.sleep(1000)

  -- process selected images
  LogMajorMax = #images
  for index, image in ipairs(images) do
    LogMajorNr = index
    LogMinorNr = 0

    --debug.max_depth = 3
    --log.msg(log.always, 4, dt.debug.dump(image))
    --local d = dt.gui.libs.modulegroups
    --log.msg(log.always, 4, dt.debug.dump(d))

    -- load selected image and show it in darkroom view
    LogInfo("load image " .. index .. " of " .. #images)
    LogInfo("file = " .. image.filename)

    if (dt.gui.views.darkroom.display_image() ~= image) then
      WaitForEventEmbeddedFunction(function()
        dt.gui.views.darkroom.display_image(image)
      end, "darkroom-image-loaded", 100, 2000)

      WaitForPixelPipe(function()
        return -- do nothing, just wait
      end)

      dt.control.sleep(1000)
    end

    ProcessWorkflowSteps()
  end

  LogScreen("Processing of all images has been completed.")
  LogInfo("all images are ready")
  LogInfo("==============================")
end

ButtonRunSelectedSteps = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget("button")
      {
        label = "run",
        tooltip = "Perform all configured steps in darkroom for \z
        an initial workflow. Perform the steps from bottom to top \z
        along the pixel pipeline.",

        clicked_callback = function()
          local currentView = dt.gui.current_view()
          if (currentView == dt.gui.views.darkroom) then
            ProcessImageInDarkroomView()
          elseif (currentView == dt.gui.views.lighttable) then
            ProcessSelectedImagesInLighttableView()
          else
            return
          end
        end
      }
    }

table.insert(WorkflowButtons, ButtonRunSelectedSteps)

---------------------------------------------------------------

ButtonDisableAllSteps = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget("button")
      {
        label = "select none",
        tooltip = "Disable all steps of this inital workflow module.",

        clicked_callback = function()
          for i, step in ipairs(WorkflowSteps) do
            step:Disable()
          end
        end
      }
    }

table.insert(WorkflowButtons, ButtonDisableAllSteps)

---------------------------------------------------------------

local function EnableDefaultSteps()
  -- called via default button
  -- called via module reset control
  for i, step in ipairs(WorkflowSteps) do
    step:Default()
  end
end

ButtonEnableDefaultSteps = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget("button")
      {
        label = "select defaults",
        tooltip = "Enable default steps and settings.",

        clicked_callback = EnableDefaultSteps
      }
    }

table.insert(WorkflowButtons, ButtonEnableDefaultSteps)

---------------------------------------------------------------

ButtonEnableRotateAndPerspective = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget("button")
      {
        label = "rotate + perspective",
        tooltip = "Activate the module to rotate the image and adjust the perspective.",

        clicked_callback = function(widget)
          local button = GetWorkflowButton(widget)
          button:EnableDarkroomModule("iop/ashift")
        end
      }
    }

table.insert(WorkflowButtons, ButtonEnableRotateAndPerspective)

---------------------------------------------------------------

ButtonEnableCrop = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget("button")
      {
        label = "crop image",
        tooltip = "Activate the module to crop the image.",

        clicked_callback = function(widget)
          local button = GetWorkflowButton(widget)
          button:EnableDarkroomModule("iop/crop")
        end
      }
    }

table.insert(WorkflowButtons, ButtonEnableCrop)

---------------------------------------------------------------

ButtonMidToneExposure = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget("button")
      {
        label = "exposure (midtones)",
        tooltip = "Show exposure module to adjust the exposure \z
      until the mid-tones are clear enough.",

        clicked_callback = function(widget)
          local button = GetWorkflowButton(widget)
          button:EnableDarkroomModule("iop/exposure")
        end
      }
    }

table.insert(WorkflowButtons, ButtonMidToneExposure)

---------------------------------------------------------------

ButtonFilmicAutoTune = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget("button")
      {
        label = "filmic auto tune",
        tooltip = "Show filmic module and auto tune level again, after \z
        manual adjustment of the midtone exposure. You should perform \z
        final manual changes: highlights, shadows, contrast, reconstruction...",

        clicked_callback = function(widget)
          local button = GetWorkflowButton(widget)
          button:EnableDarkroomModule("iop/filmicrgb")
          GuiActionWaitForPixelPipe("iop/filmicrgb/auto tune levels", 0, "button", "on", 1.0)
        end
      }
    }

table.insert(WorkflowButtons, ButtonFilmicAutoTune)

---------------------------------------------------------------

-- TEST button: Special button, used to perform module tests
-- This button should be disabled for general use of the script.
-- To enable it, create a file named "TEST.txt" in the same
-- directory as this script file.

function FileExists(filename)
  local f = io.open(filename, "r")
  if f ~= nil then
    io.close(f)
    return true
  end
  return false
end

if (FileExists("TEST.txt")) then
  if (FileExists("InitialWorkflowModuleTest.lua")) then
    dofile "InitialWorkflowModuleTest.lua"
    table.insert(WorkflowButtons, ButtonModuleTest)
  end
end

---------------------------------------------------------------

--[[

  IMPLEMENTATION OF WIDGET FRAME

  Create main widget. Collect buttons and comboboxes.

]]
local function GetWidgets()
  -- collect all widgets to be displayed within the module

  -- buttons to simplify some manual steps
  -- buttons to start image processing and to set default values
  widgets =
  {
    dt.new_widget("label") { label = "preparing manual steps", selectable = false, ellipsize = "start", halign = "start" },
    dt.new_widget("box")
    {
      orientation = "horizontal",

      ButtonEnableRotateAndPerspective.Widget,
      ButtonEnableCrop.Widget,
      ButtonMidToneExposure.Widget,
    },

    dt.new_widget("label") { label = "" },
    dt.new_widget("label") { label = "select and perform automatic steps", selectable = false, ellipsize = "start", halign = "start" },
    dt.new_widget("box")
    {
      orientation = "horizontal",

      ButtonRunSelectedSteps.Widget,
      ButtonEnableDefaultSteps.Widget,
      ButtonDisableAllSteps.Widget
    },

    dt.new_widget("label") { label = "" },
  }

  -- widget group: all single workflow steps
  -- the order in the GUI is the same as the order of declaration in the code.
  for i, step in ipairs(WorkflowSteps) do
    table.insert(widgets, step.Widget)
  end

  -- TEST button: Special button, used to perform module tests
  if (ButtonModuleTest) then
    LogInfo("INSERT TEST BUTTON WIDGET")
    table.insert(widgets, ButtonModuleTest.Widget)
  end

  return widgets
end

---------------------------------------------------------------

local function InstallModuleRegisterLib()
  -- register the module and create widget box in lighttable and darkroom

  if not env.InstallModuleDone then
    LogInfo("install module - create widget")

    dt.register_lib(
      "InitialWorkflowModule", -- Module name
      "initial workflow", -- name
      true, -- expandable
      true, -- resetable

      {
        [dt.gui.views.lighttable] = { "DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100 },
        [dt.gui.views.darkroom] = { "DT_UI_CONTAINER_PANEL_LEFT_CENTER", 100 }
      },

      dt.new_widget("box")
      {
        orientation = "vertical",
        reset_callback = EnableDefaultSteps,
        table.unpack(GetWidgets()),
      },

      nil, -- view_enter
      nil -- view_leave
    )

    env.InstallModuleDone = true
  end
end

local function viewChangedEvent(event, old_view, new_view)
  -- register an event to signal changes from darkroom to lighttable
  LogInfo("view changed event")
  if new_view.name == "lighttable" and old_view.name == "darkroom" then
    InstallModuleRegisterLib()
  end
end

local function InstallModuleRegisterEvent()
  LogInfo("install module - register event")

  if not env.InstallModuleEventRegistered then
    dt.register_event("InitialWorkflowModule", "view-changed", viewChangedEvent)
    env.InstallModuleEventRegistered = true
  end
end

local function InstallInitialWorkflowModule()
  -- main entry function to install the module at startup

  LogInfo("install initial workflow module")

  -- initialize workflow steps
  for i, step in ipairs(WorkflowSteps) do
    step:Init()
  end

  -- default settings
  for i, step in ipairs(WorkflowSteps) do
    step:ReadPreferenceValue()
  end

  -- create the module depending on which view darktable starts in
  if dt.gui.current_view().id == "lighttable" then
    InstallModuleRegisterLib()
  else
    InstallModuleRegisterEvent()
  end

  return true
end

---------------------------------------------------------------

return InstallInitialWorkflowModule()

---------------------------------------------------------------
