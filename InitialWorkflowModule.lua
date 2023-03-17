--[[
  Darktable Initial Workflow Module

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
  
  local ModuleName = "InitialWorkflowModule"
  
  -- declare some variables to install the module
  
  local Env =
  {
    InstallModuleEventRegistered = false,
    InstallModuleDone = false,
  }
  
  ---------------------------------------------------------------
  
  -- some helper methods to log information messages
  
  log.log_level(log.info) -- log.info or log.warn or log.debug
  
  local LogCurrentStep = ""
  local LogMajorNr = 0
  local LogMajorMax = 0
  local LogSummaryMessages = {}
  
  local function GetLogInfoText(text)
    return "[" .. LogMajorNr .. "/" .. LogMajorMax .. "] " .. LogCurrentStep .. ": " .. text
  end
  
  local function LogInfo(text)
    log.msg(log.info, GetLogInfoText(text))
  end
  
  local function LogScreen(text)
    log.msg(log.screen, text)
  end
  
  local function LogSummaryClear()
    for k, v in pairs(LogSummaryMessages) do
      LogSummaryMessages[k] = nil
    end
  end
  
  local function LogSummaryMessage(text)
    table.insert(LogSummaryMessages, GetLogInfoText(text))
  end
  
  -- The script may dump a lot of log messages.
  -- The summary collects some important (error) messages.
  -- This function is executed at the end of each script run.
  local function LogSummary()
    LogInfo("==============================")
  
    if (#LogSummaryMessages == 0) then
      LogInfo("Summary: OK. There are no important messages and no timeouts.")
    else
      LogInfo("THERE ARE IMPORTANT MESSAGES:")
  
      for index, message in ipairs(LogSummaryMessages) do
        LogInfo(message)
      end

      LogInfo("If you detect timeouts, you can increase the timeout value and try again.")
    end
  
    if (#LogSummaryMessages == 0) then
      LogScreen("initial workflow - image processing has been completed")
    else
      LogScreen("THERE ARE IMPORTANT MESSAGES - see log for details / increase timeout value")
    end
  
    LogInfo("initial workflow - image processing has been completed")
    LogInfo("==============================")
  end
  
  function ScriptFilePath()
    local str = debug.getinfo(1, "S").source:sub(2)
    return str:match("(.*[/\\])")
  end
  
  function ThreadSleep(milliseconds)
    local timeout = StepTimeout:Value()
    local factor = milliseconds / timeout
    LogInfo(". wait for " .. milliseconds .. "ms... (config=" .. timeout .. "ms * " .. factor .. ")")
    dt.control.sleep(milliseconds)
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
  
  -- check Darktable API version
  -- new API of DT 4.2 is needed to use "pixelpipe-processing-complete" event
  local apiCheck, err = pcall(function() du.check_min_api_version("9.0.0", ModuleName) end)
  if (apiCheck) then
    LogInfo("Darktable " .. dt.configuration.version .. " with appropriate lua API detected.")
  else
    LogInfo("This script needs at least Darktable 4.2 API to run.")
    return
  end
  
  LogInfo("Script executed from " .. ScriptFilePath())
  
  -- debug helper function to dump preference keys
  -- helps you to find out strings like "plugins/darkroom/chromatic-adaptation"
  -- darktable -d lua > ~/keys.txt
  local function DumpPreferenceKeys()
    LogInfo("get preference keys...")
    local keys = dt.preferences.get_keys()
    LogInfo(#keys .. " retrieved, listing follows")
    for _, key in ipairs(keys) do
      LogInfo(key .. " = " .. dt.preferences.read("darktable", key, "string"))
    end
  end
  
  -- check current darktable version
  -- used to handle different behavior of dt 4.2 and following versions
  local function CheckDarktable42()
    return contains({ "4.2", "4.2.0", "4.2.1" }, dt.configuration.version)
  end
  
  -- get Darktable workflow setting
  -- read preference "auto-apply chromatic adaptation defaults"
  local function CheckDarktableModernWorkflowPreference()
    local modernWorkflows =
    {
      "scene-referred (filmic)",
      "scene-referred (sigmoid)",
      "modern"
    }
  
    local workflow
  
    if CheckDarktable42() then
      -- use old dt 4.2 preference setting
      workflow = dt.preferences.read("darktable", "plugins/darkroom/chromatic-adaptation", "string")
    else
      -- use new dt 4.4 preference setting
      workflow = dt.preferences.read("darktable", "plugins/darkroom/workflow", "string")
    end
  
    return contains(modernWorkflows, workflow)
  end
  
  ---------------------------------------------------------------
  
  -- Event handling helper functions used during dt.gui.action
  
  -- base class to handle events
  local WaitForEventBase =
  {
    ModuleName = ModuleName,
    EventType = nil,
    EventReceivedFlag = nil
  }
  
  -- base class constructor
  function WaitForEventBase:new(obj)
    -- create object if user does not provide one
    obj = obj or {}
    -- define inheritance
    setmetatable(obj, self)
    self.__index = self
    -- return new object
    return obj
  end
  
  function WaitForEventBase:EventReceivedFlagReset()
    self.EventReceivedFlag = nil
  end
  
  function WaitForEventBase:EventReceivedFlagSet()
    self.EventReceivedFlag = 1
    LogInfo(". received event " .. self.EventType)
  end
  
  -- execute embedded function and wait for given EventType
  function WaitForEventBase:Do(embeddedFunction)
    -- register event
    self:EventReceivedFlagReset()
  
    dt.destroy_event(self.ModuleName, self.EventType)
    dt.register_event(self.ModuleName, self.EventType, self.EventReceivedFunction)
  
    LogInfo(". wait for event " .. self.EventType)
  
    -- execute given function
    embeddedFunction()
  
    -- wait for registered event
    local duration = 0
    local durationMax = StepTimeout:Value() * 5
    local period = StepTimeout:Value() / 10
    local output = ".."
  
  
    while (not self.EventReceivedFlag) or (duration < period) do
      if ((duration > 0) and (duration % 500 == 0)) then
        LogInfo(output)
        output = output .. "."
      end
  
      dt.control.sleep(period)
      duration = duration + period
  
      if (duration >= durationMax) then
        local timeoutMessage = "timeout after " .. durationMax .. "ms waiting for event " .. self.EventType
        LogInfo(timeoutMessage)
        LogSummaryMessage(timeoutMessage)
        break
      end
    end
  
    -- unregister event
    dt.destroy_event(self.ModuleName, self.EventType)
    self:EventReceivedFlagReset()
  end
  
  ---------------------------------------------------------------
  
  -- wait for new pixelpipe-processing-complete event
  -- this event is new in DT 4.2
  WaitForPixelPipe = WaitForEventBase:new():new
      {
        EventType = "pixelpipe-processing-complete"
      }
  
  -- called as callback function
  function WaitForPixelPipe:EventReceivedFunction(event)
    WaitForPixelPipe:EventReceivedFlagSet()
  end
  
  ---------------------------------------------------------------
  
  -- wait for image loaded event and reload it, if necessary.
  -- "clean" flag indicates, if the load was clean (got pixel pipe locks) or not.
  WaitForImageLoaded = WaitForEventBase:new():new
      {
        EventType = "darkroom-image-loaded"
      }
  
  function WaitForImageLoaded:EventReceivedFunction(event, clean, image)
    if not clean then
      local message = "Loading image failed, reload it. This could indicate a timing problem."
      LogInfo(message)
      LogSummaryMessage(message)
  
      ThreadSleep(StepTimeout:Value() * 2)
      dt.gui.views.darkroom.display_image(image)
    else
      WaitForImageLoaded:EventReceivedFlagSet()
    end
  end
  
  ---------------------------------------------------------------
  -- helper functions to access darktable feature via user interface
  -- use event handling helper functions to wait for pixel pipe
  -- processing to complete
  
  local function numberToString(number, nilReplacement, nanReplacement)
    -- convert given number to string
    -- return "not a number" and "nil" as "0/0"
    -- log output equals to dt.gui.action command and parameters
    if (number ~= number) then
      return nanReplacement or "0/0"
    end
  
    if (number == nil) then
      return nilReplacement or "0/0"
    end
  
    -- some digits with dot
    local result = string.format("%.4f", number)
    result = string.gsub(result, ",", ".")
  
    return result
  end
  
  -- convert values to boolean, consider not a number and nil
  local function GuiActionValueToBoolean(value)
    -- NaN
    if (value ~= value) then
      return false
    end
  
    -- nil
    if (value == nil) then
      return false
    end
  
    return value ~= 0
  end
  
  -- perform the specified effect on the path and element of an action
  -- see https://docs.darktable.org/lua/stable/lua.api.manual/darktable/gui/action/
  local function GuiActionInternal(path, instance, element, effect, speed, waitForPipeline)
    LogInfo('dt.gui.action("' ..
      path .. '",' .. instance .. ',"' .. element .. '","' .. effect .. '",' .. numberToString(speed) .. ')')
  
    local result
  
    if (waitForPipeline) then
      WaitForPixelPipe:Do(function()
        result = dt.gui.action(path, instance, element, effect, speed)
      end)
    else
      result = dt.gui.action(path, instance, element, effect, speed)
      -- wait a bit...
      ThreadSleep(StepTimeout:Value() / 2)
    end
  
    return result
  end
  
  -- wait for "pixelpipe-processing-complete"
  local function GuiAction(path, instance, element, effect, speed)
    return GuiActionInternal(path, instance, element, effect, speed, true)
  end
  
  -- "pixelpipe-processing-complete" is not expected
  local function GuiActionWithoutEvent(path, instance, element, effect, speed)
    return GuiActionInternal(path, instance, element, effect, speed, false)
  end
  
  -- get current value
  local function GuiActionGetValue(path, element)
    -- use 0/0 == NaN as parameter to indicate this read-action
    local value = GuiActionWithoutEvent(path, 0, element, "", 0 / 0)
  
    LogInfo('. get "' .. path .. '" ' .. element .. ' = ' .. numberToString(value, "NaN", "nil"))
  
    return value
  end
  
  -- Set given value, compare it with the current value to avoid
  -- unnecessary set commands. There is no “pixelpipe-processing-complete”,
  -- if the new value equals the current value.
  local function GuiActionSetValue(path, instance, element, effect, speed)
    -- get current value
    -- use 0/0 == NaN as parameter to indicate this read-action
    local value = GuiActionWithoutEvent(path, 0, element, "set", 0 / 0)
  
    -- round the value to number of digits
    local digits = 4
    local digitsFactor = 10 ^ (digits or 0)
    value = math.floor(value * digitsFactor + 0.5) / digitsFactor
  
    LogInfo('. get "' .. path .. '" ' .. element .. ' = ' .. numberToString(value, "NaN", "nil"))
  
    if (value ~= speed) then
      GuiAction(path, instance, element, effect, speed)
    else
      LogInfo('. value already equals to "' .. numberToString(value) .. '", nothing to do')
    end
  end
  
  -- Push the button  addressed by the path. Turn it off, if necessary.
  local function GuiActionButtonOffOn(path)
    LogInfo('push button off and on: "' .. path .. '"')
  
    local buttonState = GuiActionGetValue(path, "button")
    if (GuiActionValueToBoolean(buttonState)) then
      GuiActionWithoutEvent(path, 0, "button", "off", 1.0)
    else
      LogInfo('. button already "off", nothing to do')
    end
  
    GuiAction(path, 0, "button", "on", 1.0)
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
    Widget = nil,
    Tooltip = nil,
  }
  
  -- workflow step base class constructor
  function WorkflowStep:new(obj)
    -- create object if user does not provide one
    obj = obj or {}
    -- define inheritance
    setmetatable(obj, self)
    self.__index = self
    -- return new object
    return obj
  end
  
  -- message at the beginning of a step
  function WorkflowStep:LogStepMessage()
    LogInfo("==============================")
    LogInfo("selection = " .. self.Widget.value)
  end
  
  -- show given darkroom module
  function WorkflowStep:ShowDarkroomModule(moduleName)
    -- check if the module is already displayed
    LogInfo("show module " .. moduleName .. " (if not visible)")
    local visible = GuiActionGetValue(moduleName, "show")
    if (not GuiActionValueToBoolean(visible)) then
      GuiActionWithoutEvent(moduleName, 0, "show", "", 1.0)
    else
      LogInfo(". already visible, nothing to do")
    end
  end
  
  -- hide given darkroom module
  function WorkflowStep:HideDarkroomModule(moduleName)
    -- check if the module is already hidden
    LogInfo("hide module " .. moduleName .. " (if visible)")
    local visible = GuiActionGetValue(moduleName, "show")
    if (GuiActionValueToBoolean(visible)) then
      GuiActionWithoutEvent(moduleName, 0, "show", "", 1.0)
    else
      LogInfo(". already hidden, nothing to do")
    end
  end
  
  -- enable given darkroom module
  function WorkflowStep:EnableDarkroomModule(moduleName)
    -- check if the module is already activated
    LogInfo("enable module " .. moduleName .. " (if disabled)")
    local status = GuiActionGetValue(moduleName, "enable")
    if (not GuiActionValueToBoolean(status)) then
      GuiAction(moduleName, 0, "enable", "", 1.0)
    else
      LogInfo(". already enabled, nothing to do")
    end
  
    if (StepShowModulesDuringExecution.Widget.value == "yes") then
      self:ShowDarkroomModule(moduleName)
    end
  end
  
  -- disable given darkroom module
  function WorkflowStep:DisableDarkroomModule(moduleName)
    -- check if the module is already activated
    LogInfo("disable module " .. moduleName .. " (if enabled)")
    local status = GuiActionGetValue(moduleName, "enable")
    if (GuiActionValueToBoolean(status)) then
      GuiAction(moduleName, 0, "enable", "", 1.0)
    else
      LogInfo(". already disabled, nothing to do")
    end
  end
  
  -- reset given darkroom module
  function WorkflowStep:ResetDarkroomModule(moduleName)
    LogInfo("reset module " .. moduleName)
    GuiAction(moduleName, 0, "reset", "", 1.0)
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
        OperationNameInternal = nil,
        DisableValue = nil,
        DefaultValue = nil
      }
  
  -- disable step, setting keeps unchanged during script execution
  function WorkflowStepCombobox:Disable()
    self.Widget.value = self.DisableValue
  end
  
  -- choose default step setting
  function WorkflowStepCombobox:Default()
    self.Widget.value = self.DefaultValue
  end
  
  -- returns internal operation name like "colorbalancergb" or "atrous"
  function WorkflowStepCombobox:OperationName()
    return self.OperationNameInternal
  end
  
  -- returns operation path like "iop/colorbalancergb"
  function WorkflowStepCombobox:OperationPath()
    return "iop/" .. self:OperationName()
  end
  
  -- save current selection of this workflow step
  -- used to restore settings after starting darktable
  function WorkflowStepCombobox:SavePreferenceValue()
    -- check, if there are any changes
    local preferenceValue = dt.preferences.read(ModuleName, self.Widget.label, 'string')
    local comboBoxValue = self.Widget.value
  
    -- save any changes
    if (preferenceValue ~= comboBoxValue) then
      -- LogInfo("preference write "..self.Widget.label.." = '"..comboBoxValue.."'")
      dt.preferences.write(ModuleName, self.Widget.label, 'string', comboBoxValue)
    end
  end
  
  -- read saved selection value from darktable preferences
  -- used to restore settings after starting darktable
  function WorkflowStepCombobox:ReadPreferenceValue()
    local preferenceValue = dt.preferences.read(ModuleName, self.Widget.label, 'string')
  
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
  
  -- combobox selection is returned as negative index value
  -- use index to compare current value with newly selected value
  -- used to avoid unnecessary set commands
  function WorkflowStepCombobox:CreateComboBoxSelectionIndex()
    -- dt.gui.action returns but c types (instead of string / combobox entry)
    self.ComboBoxValuesIndex = {}
    for k, v in pairs(self.ComboBoxValues) do
      -- ignore first additional combobox entry
      if (v ~= "unchanged") then
        -- negative index values are used by dt.gui.action
        -- in order to distinguish the first index from 100%
        self.ComboBoxValuesIndex[v] = -(k - 1)
      end
    end
  end
  
  -- combobox selection is returned as negative index value
  -- convert negative index value to combobox string value
  function WorkflowStepCombobox:GetComboBoxValueFromSelectionIndex(index)
    return self.ComboBoxValues[(-index) + 1]
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
  
  -- called from callback function within a "foreign context"
  -- determine the button object
  function GetWorkflowButton(widget)
    return GetWorkflowItem(widget, WorkflowButtons)
  end
  
  -- called from callback function within a "foreign context"
  -- determine the step object
  function GetWorkflowStep(widget)
    return GetWorkflowItem(widget, WorkflowSteps)
  end
  
  -- called after selection was changed
  -- current settings are saved as darktable preferences
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
        Tooltip =
        "Generate the shortest history stack that reproduces the current \n\z
        image. This removes your current history snapshots."
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
      GuiAction("lib/history/compress history stack", 0, "", "", 1.0)
    end
  end
  
  ---------------------------------------------------------------
  
  StepDynamicRangeSceneToDisplay = WorkflowStepCombobox:new():new
      {
        -- internal operation name should be copied from gui action command (iop/OperationName)
        -- this step refers to different modules
        OperationNameInternal = "Filmic or Sigmoid",
        DisableValue = 1,
        DefaultValue = 4,
        Tooltip = "Use Filmic or Sigmoid to expand or contract the dynamic range of the \n\z
        scene to fit the dynamic range of the display. Auto tune filmic levels of black + \n\z
        white relative exposure and / or reset module settings. Or use Sigmoid with one of \n\z
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
        "Filmic auto tune levels",
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
        self:ResetDarkroomModule("iop/filmicrgb")
      end
  
      if (filmicAuto) then
        GuiActionButtonOffOn("iop/filmicrgb/auto tune levels")
      end
    end
  
    if (sigmoid) then
      self:DisableDarkroomModule("iop/filmicrgb")
      self:DisableDarkroomModule("iop/basecurve")
      self:EnableDarkroomModule("iop/sigmoid")
  
      self:ResetDarkroomModule("iop/sigmoid")
  
      if (sigmoidDefaultPerChannel) then
        -- keep defaults
      end
  
      if (sigmoidDefaultRgbRatio) then
        GuiAction("iop/sigmoid/color processing", 0, "selection", "item:" .. "rgb ratio", 1.0)
      end
  
      if (sigmoidACES100) then
        GuiActionButtonOffOn("iop/sigmoid/preset/ACES 100-nit like")
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
      GuiActionSetValue("iop/colorbalancergb/global saturation", 0, "value", "set", selection / 100)
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
      GuiActionSetValue("iop/colorbalancergb/global chroma", 0, "value", "set", selection / 100)
    end
  end
  
  ---------------------------------------------------------------
  
  StepColorBalanceRGB = WorkflowStepCombobox:new():new
      {
        -- internal operation name should be copied from gui action command (iop/OperationName)
        OperationNameInternal = "colorbalancergb",
        DisableValue = 1,
        DefaultValue = 2,
        Tooltip = "Choose a predefined preset for your color-grading. Or set \n\z
        auto pickers of the module mask and peak white and gray luminance value \n\z
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
      self:ResetDarkroomModule("iop/colorbalancergb")
      GuiActionButtonOffOn("iop/colorbalancergb/white fulcrum")
      GuiActionButtonOffOn("iop/colorbalancergb/contrast gray fulcrum")
    else
      GuiActionButtonOffOn("iop/colorbalancergb/preset/" .. selection)
    end
  end
  
  ---------------------------------------------------------------
  
  StepContrastEqualizer = WorkflowStepCombobox:new():new
      {
        -- internal operation name should be copied from gui action command (iop/OperationName)
        OperationNameInternal = "atrous",
        DisableValue = 1,
        DefaultValue = 3,
        Tooltip = "Adjust luminance and chroma contrast. Apply choosen \n\z
        preset (clarity or denoise & sharpen). Choose different values \n\z
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
  
    if (selection == "reset to default") then
      self:ResetDarkroomModule("iop/atrous")
      --
    elseif (selection == "clarity, strength 0,25") then
      GuiActionButtonOffOn("iop/atrous/preset/clarity")
      GuiActionSetValue("iop/atrous/mix", 0, "value", "set", 0.25)
      --
    elseif (selection == "clarity, strength 0,50") then
      GuiActionButtonOffOn("iop/atrous/preset/clarity")
      GuiActionSetValue("iop/atrous/mix", 0, "value", "set", 0.5)
      --
    elseif (selection == "denoise & sharpen, strength 0,25") then
      GuiActionButtonOffOn("iop/atrous/preset/denoise & sharpen")
      GuiActionSetValue("iop/atrous/mix", 0, "value", "set", 0.25)
      --
    elseif (selection == "denoise & sharpen, strength 0,50") then
      GuiActionButtonOffOn("iop/atrous/preset/denoise & sharpen")
      GuiActionSetValue("iop/atrous/mix", 0, "value", "set", 0.5)
    end
  end
  
  ---------------------------------------------------------------
  
  StepToneEqualizerMask = WorkflowStepCombobox:new():new
      {
        -- internal operation name should be copied from gui action command (iop/OperationName)
        OperationNameInternal = "toneequal",
        DisableValue = 1,
        DefaultValue = 3,
        Tooltip = "Use default preset mask blending for all purposes \n\z
        plus automatic mask contrast and exposure compensation. Or use \n\z
        preset to compress shadows and highlights with exposure-independent \n\z
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
    self:ResetDarkroomModule("iop/toneequal")
  
    if (selection == "default mask blending") then
      -- nothing else to do...
      --
    elseif (selection == "default plus mask compensation") then
      -- workaround: show this module, otherwise the buttons will not be pressed
      self:ShowDarkroomModule("iop/toneequal")
  
      GuiActionWithoutEvent("iop/toneequal/page", 0, "masking", "", 1.0)
      GuiActionButtonOffOn("iop/toneequal/mask exposure compensation")
      GuiActionButtonOffOn("iop/toneequal/mask contrast compensation")
  
      -- workaround: show this module, otherwise the buttons will not be pressed
      self:HideDarkroomModule("iop/toneequal")
      --
    elseif (selection == "compress high-low (eigf): medium") then
      GuiActionButtonOffOn("iop/toneequal/preset/compress shadows-highlights (eigf): medium")
      --
    elseif (selection == "compress high-low (eigf): soft") then
      -- workaround to deal with bug in dt 4.2.x
      -- dt 4.2 uses special characters
      if (CheckDarktable42()) then
        GuiActionButtonOffOn("iop/toneequal/preset/compress shadows-highlights (eigf): soft")
      else
        GuiActionButtonOffOn("iop/toneequal/preset/compress shadows-highlights (eigf): soft")
      end
      --
    elseif (selection == "compress high-low (eigf): strong") then
      -- workaround to deal with bug in dt 4.2.x
      -- dt 4.2 uses special characters
      if (CheckDarktable42()) then
        GuiActionButtonOffOn("iop/toneequal/preset/compress shadows-highlights (eigf): strong")
      else
        GuiActionButtonOffOn("iop/toneequal/preset/compress shadows-highlights (eigf): strong")
      end
      --
    end
  end
  
  ---------------------------------------------------------------
  
  StepExposureCorrection = WorkflowStepCombobox:new():new
      {
        -- internal operation name should be copied from gui action command (iop/OperationName)
        OperationNameInternal = "exposure",
        DisableValue = 1,
        DefaultValue = 4,
        Tooltip = "Automatically adjust the exposure correction. Remove \n\z
        the camera exposure bias, useful if you exposed the image to the right."
      }
  
  table.insert(WorkflowSteps, StepExposureCorrection)
  
  function StepExposureCorrection:Init()
    self.ComboBoxValues =
    {
      "unchanged",
      "adjust exposure correction",
      "reset & adjust exposure correction",
      "adjust exp. & compensate camera bias",
      "reset & adjust exp. & comp. camera bias"
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
  
    local adjustExposureCorrection = contains(
      { "adjust exposure correction",
        "adjust exp. & compensate camera bias"
      }, selection)
  
    local resetModule              = contains(
      { "reset & adjust exposure correction",
        "reset & adjust exp. & comp. camera bias"
      }, selection)
  
    local compensateBias           = contains(
      {
        "adjust exp. & compensate camera bias",
        "reset & adjust exp. & comp. camera bias"
      }, selection)
  
    self:LogStepMessage()
    self:EnableDarkroomModule("iop/exposure")
  
    if (resetModule) then
      self:ResetDarkroomModule("iop/exposure")
    end
  
    if (adjustExposureCorrection) then
      GuiActionButtonOffOn("iop/exposure/exposure")
    end
  
    if (compensateBias) then
      local checkbox = GuiActionGetValue("iop/exposure/compensate exposure bias", "")
      if (checkbox == 0) then
        GuiAction("iop/exposure/compensate exposure bias", 0, "", "on", 1.0)
      else
        LogInfo('. checkbox already selected, nothing to do')
      end
      --
    end
  end
  
  ---------------------------------------------------------------
  
  StepLensCorrection = WorkflowStepCombobox:new():new
      {
        -- internal operation name should be copied from gui action command (iop/OperationName)
        OperationNameInternal = "lens",
        DisableValue = 1,
        DefaultValue = 4,
        Tooltip = "Enable and reset lens correction module.",
      }
  
  table.insert(WorkflowSteps, StepLensCorrection)
  
  function StepLensCorrection:Init()
    self.ComboBoxValues =
    {
      "unchanged",
      "reset module",
      "enable lensfun method",
      "reset & lensfun method"
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
  
    local resetModule = contains(
      {
        "reset module",
        "reset & lensfun method"
      }, selection)
  
    local lensfun = contains(
      {
        "enable lensfun method",
        "reset & lensfun method"
      }, selection)
  
    self:LogStepMessage()
    self:EnableDarkroomModule("iop/lens")
  
    if (resetModule) then
      self:ResetDarkroomModule("iop/lens")
    end
  
    if (lensfun) then
      GuiAction("iop/lens/correction method", 0, "selection", "item:lensfun database", 1.0)
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
      self:ResetDarkroomModule("iop/denoiseprofile")
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
  
        -- see Default() override
        DefaultValue = nil,
        Tooltip = "Perform color space corrections in color calibration \n\z
        module. Select the illuminant. The type of illuminant assumed to \n\z
        have lit the scene. By default unchanged for the legacy workflow."
      }
  
  -- distinguish between modern and legacy workflow
  -- keep value unchanged, if using legacy workflow
  -- depends on darktable preference settings
  function StepColorCalibrationIlluminant:Default()
    self.Widget.value = CheckDarktableModernWorkflowPreference() and 2 or 1
  end
  
  table.insert(WorkflowSteps, StepColorCalibrationIlluminant)
  
  -- combobox values see darktable typedef enum dt_illuminant_t
  -- github/darktable/src/common/illuminants.h
  -- github/darktable/po/darktable.pot
  -- github/darktable/build/lib/darktable/plugins/introspection_channelmixerrgb.c
  
  function StepColorCalibrationIlluminant:Init()
    self.ComboBoxValues =
    {
      "unchanged", -- additional value
      "same as pipeline (D50)",
      "A (incandescent)",
      "D (daylight)",
      "E (equi-energy)",
      "F (fluorescent)",
      "LED (LED light)",
      "Planckian (black body)",
      "custom",
      "(AI) detect from image surfaces...",
      "(AI) detect from image edges...",
      "as shot in camera"
    }
  
    self:CreateComboBoxSelectionIndex()
  
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
  
    -- ignore illuminant, if current adaptation is equal to bypass
    local adaptationSelectionIndex = GuiActionGetValue("iop/channelmixerrgb/adaptation", "selection")
    local adaptationSelection = StepColorCalibrationAdaptation:GetComboBoxValueFromSelectionIndex(adaptationSelectionIndex)
    if (adaptationSelection == "none (bypass)") then
      LogInfo(". adaptation = none (bypass): Illuminant cannot be set.")
      return
    else
      LogInfo(". adaptation = " .. adaptationSelection .. " <> none (bypass): Illuminant can be set.")
    end
  
    -- set illuminant
  
    self:EnableDarkroomModule("iop/channelmixerrgb")
  
    local currentSelectionIndex = GuiActionGetValue("iop/channelmixerrgb/illuminant", "selection")
    local currentSelection = StepColorCalibrationIlluminant:GetComboBoxValueFromSelectionIndex(currentSelectionIndex)
  
    if (selection ~= currentSelection) then
      LogInfo('. current illuminant = "' .. currentSelection .. '"')
      GuiAction("iop/channelmixerrgb/illuminant", 0, "selection", "item:" .. selection, 1.0)
    else
      LogInfo('. illuminant already "' .. currentSelection .. '", nothing to do')
    end
  end
  
  ---------------------------------------------------------------
  
  StepColorCalibrationAdaptation = WorkflowStepCombobox:new():new
      {
        -- internal operation name should be copied from gui action command (iop/OperationName)
        OperationNameInternal = "channelmixerrgb",
        DisableValue = 1,
        DefaultValue = 3,
        Tooltip = "Perform color space corrections in color calibration \n\z
        module. Select the adaptation. The working color space in which \n\z
        the module will perform its chromatic adaptation transform and \n\z
        channel mixing."
      }
  
  table.insert(WorkflowSteps, StepColorCalibrationAdaptation)
  
  -- combobox values see darktable typedef enum dt_adaptation_t
  
  function StepColorCalibrationAdaptation:Init()
    self.ComboBoxValues =
    {
      "unchanged", -- additional value
      "linear Bradford (ICC v4)",
      "CAT16 (CIECAM16)",
      "non-linear Bradford",
      "XYZ",
      "none (bypass)"
    }
  
    self:CreateComboBoxSelectionIndex()
  
    self.Widget = dt.new_widget("combobox")
        {
          changed_callback = ComboBoxChangedCallback,
          label = "color calibration adaptation",
          tooltip = self.Tooltip,
          table.unpack(self.ComboBoxValues)
        }
  end
  
  function StepColorCalibrationAdaptation:Run()
    local selection = self.Widget.value
  
    if (selection == "unchanged") then
      return
    end
  
    self:LogStepMessage()
    self:EnableDarkroomModule("iop/channelmixerrgb")
  
    local currentSelectionIndex = GuiActionGetValue("iop/channelmixerrgb/adaptation", "selection")
    local currentSelection = StepColorCalibrationAdaptation:GetComboBoxValueFromSelectionIndex(currentSelectionIndex)
  
    if (selection ~= currentSelection) then
      LogInfo('. current adaptation = "' .. currentSelection .. '"')
      GuiAction("iop/channelmixerrgb/adaptation", 0, "selection", "item:" .. selection, 1.0)
    else
      LogInfo('. adaptation already "' .. currentSelection .. '", nothing to do')
    end
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
        Tooltip = "Reconstruct color information for clipped pixels. \n\z
        Select an appropriate reconstruction methods to reconstruct the \n\z
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
      GuiAction("iop/highlights/method", 0, "selection", "item:inpaint opposed", 1.0)
    end
  
    if (selection == "reconstruct in LCh") then
      GuiAction("iop/highlights/method", 0, "selection", "item:reconstruct in LCh", 1.0)
    end
  
    if (selection == "clip highlights") then
      GuiAction("iop/highlights/method", 0, "selection", "item:clip highlights", 1.0)
    end
  
    if (selection == "segmentation based") then
      GuiAction("iop/highlights/method", 0, "selection", "item:segmentation based", 1.0)
    end
  
    if (selection == "guided laplacians") then
      GuiAction("iop/highlights/method", 0, "selection", "item:guided laplacians", 1.0)
    end
  end
  
  ---------------------------------------------------------------
  
  StepWhiteBalance = WorkflowStepCombobox:new():new
      {
        -- internal operation name should be copied from gui action command (iop/OperationName)
        OperationNameInternal = "temperature",
        DisableValue = 1,
  
        -- see Default() override
        DefaultValue = nil,
        Tooltip = "Adjust the white balance of the image by altering the \n\z
        temperature. By default unchanged for the legacy workflow."
      }
  
  
  -- distinguish between modern and legacy workflow
  -- keep value unchanged, if using legacy workflow
  -- depends on darktable preference settings
  function StepWhiteBalance:Default()
    self.Widget.value = CheckDarktableModernWorkflowPreference() and 2 or 1
  end
  
  table.insert(WorkflowSteps, StepWhiteBalance)
  
  function StepWhiteBalance:Init()
    self.ComboBoxValues =
    {
      "unchanged",
      "as shot",
      "from image area",
      "user modified",
      "camera reference"
    }
  
    self:CreateComboBoxSelectionIndex()
  
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
  
    local currentSelectionIndex = GuiActionGetValue("iop/temperature/settings/settings", "selection")
    local currentSelection = StepWhiteBalance:GetComboBoxValueFromSelectionIndex(currentSelectionIndex)
  
    if (selection ~= currentSelection) then
      LogInfo('. current value = "' .. currentSelection .. '"')
      GuiAction("iop/temperature/settings/" .. selection, 0, "", "", 1.0)
    else
      LogInfo('. value already "' .. currentSelection .. '", nothing to do')
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
        Tooltip = "Reset modules that are part of this initial workflow. \n\z
        Keep other module settings like crop, rotate and perspective. Or \n\z
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
      GuiAction("lib/history", 0, "reset", "", 1.0)
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
        self:ResetDarkroomModule(module)
      end
    end
  end
  
  ---------------------------------------------------------------
  
  StepShowModulesDuringExecution = WorkflowStepCombobox:new():new
      {
        -- operation = nil: ignore this module during module reset
        OperationNameInternal = nil,
        DisableValue = 1, -- item in ComboBoxValues
        DefaultValue = 1, -- item in ComboBoxValues
        Tooltip =
        "Show darkroom modules for enabled workflow steps during \n\z
        execution of this initial workflow. This makes the changes \n\z
        easier to understand."
      }
  
  table.insert(WorkflowSteps, StepShowModulesDuringExecution)
  
  function StepShowModulesDuringExecution:Init()
    self.ComboBoxValues = { "no", "yes" }
  
    self.Widget = dt.new_widget("combobox")
        {
          changed_callback = ComboBoxChangedCallback,
          label = "show modules",
          tooltip = self.Tooltip,
          table.unpack(self.ComboBoxValues)
        }
  end
  
  function StepShowModulesDuringExecution:Run()
    -- do nothing...
  end
  
  ---------------------------------------------------------------
  
  StepTimeout = WorkflowStepCombobox:new():new
      {
        -- operation = nil: ignore this module during module reset
        OperationNameInternal = nil,
        DisableValue = 2, -- item in ComboBoxValues
        DefaultValue = 2, -- item in ComboBoxValues
        Tooltip =
        "Some calculations take a certain amount of time. Depending on \n\z
        the hardware equipment also longer.This script waits and attempts to \n\z
        detect timeouts. If steps take much longer than expected, those \n\z
        steps will be aborted. You can configure the default timeout (ms). \n\z
        Before and after each step of the workflow, the script waits this time. \n\z
        In other places also a multiple (loading an image) or a fraction \n\z
        (querying a status)."
      }
  
  table.insert(WorkflowSteps, StepTimeout)
  
  function StepTimeout:Init()
    self.ComboBoxValues =
    {
      "500",
      "1000",
      "2000",
      "3000",
      "4000",
      "5000"
    }
  
    self.Widget = dt.new_widget("combobox")
        {
          changed_callback = ComboBoxChangedCallback,
          label = "timeout value",
          tooltip = self.Tooltip,
          table.unpack(self.ComboBoxValues)
        }
  end
  
  function StepTimeout:Run()
    LogInfo("Step timeout = " .. self:Value() .. "ms")
  end
  
  function StepTimeout:Value()
    return tonumber(self.Widget.value)
  end
  
  ---------------------------------------------------------------
  
  --[[
  
    IMPLEMENTATION OF BUTTON CONTROLS
  
    These are buttons to start the execution of the steps or e.g. to set default values.
  
  ]]
  ---------------------------------------------------------------
  
  -- process all configured workflow steps
  local function ProcessWorkflowSteps()
    LogInfo("==============================")
    LogInfo("process workflow steps")
  
    ThreadSleep(StepTimeout:Value())
  
    -- execute all workflow steps
    -- the order is from bottom to top, along the pixel pipeline.
    for i = 1, #WorkflowSteps do
      local step = WorkflowSteps[#WorkflowSteps + 1 - i]
      LogCurrentStep = step.Widget.label
      step:Run()
    end
  
    LogCurrentStep = ""
    ThreadSleep(StepTimeout:Value())
  end
  
  -- process current image in darkroom view
  local function ProcessImageInDarkroomView()
    LogMajorMax = 1
    LogMajorNr = 1
    LogCurrentStep = ""
  
    LogSummaryClear()
  
    ProcessWorkflowSteps()
  
    LogSummary()
  end
  
  -- process selected image(s)
  local function ProcessSelectedImagesInLighttableView()
    LogMajorMax = 0
    LogMajorNr = 0
    LogCurrentStep = ""
  
    LogSummaryClear()
  
    LogInfo("==============================")
    LogInfo("process selected images")
  
    -- check that there is an image selected to activate darkroom view
    local images = dt.gui.action_images
    if not images or #images == 0 then
      LogScreen("no image selected")
      return
    end
  
    -- remember currently selected images
    images = {}
    for _, newImage in ipairs(dt.gui.action_images) do
      table.insert(images, newImage)
    end
  
    -- switch to darkroom view
    LogInfo("switch to darkroom view")
    WaitForPixelPipe:Do(function()
      dt.gui.current_view(dt.gui.views.darkroom)
    end)
  
    -- process selected images
    LogMajorMax = #images
    for index, newImage in ipairs(images) do
      LogMajorNr = index
      LogCurrentStep = ""
  
      local oldImage = dt.gui.views.darkroom.display_image()
  
      -- load selected image and show it in darkroom view
      LogInfo("load image " .. index .. " of " .. #images)
      LogInfo("image file = " .. newImage.filename)
  
      if (oldImage ~= newImage) then
        WaitForPixelPipe:Do(function()
          LogInfo("load new image into darkroom view")
          WaitForImageLoaded:Do(function()
            dt.gui.views.darkroom.display_image(newImage)
          end)
        end)
      end
  
      ProcessWorkflowSteps()
    end
  
    -- switch to lighttable view
    LogInfo("switch to lighttable view")
    dt.gui.current_view(dt.gui.views.lighttable)
    dt.gui.selection(images)

    LogSummary()
  
  end
  
  ButtonRunSelectedSteps = WorkflowStepButton:new():new
      {
        Widget = dt.new_widget("button")
            {
              label = "run",
              tooltip = "Perform all configured steps in darkroom for an initial workflow.\n\z
                        Perform the steps from bottom to top along the pixel pipeline.",
  
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
  
  -- select default configuration for each step
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
                if button ~= nil then
                  button:EnableDarkroomModule("iop/ashift")
                  button:ShowDarkroomModule("iop/ashift")
                end
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
                if (button ~= nil) then
                  button:EnableDarkroomModule("iop/crop")
                  button:ShowDarkroomModule("iop/crop")
                end
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
              tooltip = "Show exposure module to adjust the exposure \n\z
                        until the mid-tones are clear enough.",
  
              clicked_callback = function(widget)
                local button = GetWorkflowButton(widget)
                if (button ~= nil) then
                  button:EnableDarkroomModule("iop/exposure")
                  button:ShowDarkroomModule("iop/exposure")
                end
              end
            }
      }
  
  table.insert(WorkflowButtons, ButtonMidToneExposure)
  
  ---------------------------------------------------------------
  
  -- MODULE TEST IMPLEMENTATION.
  
  -- This section contains some functions to perform module tests.
  -- The following functions are used during development and deployment.
  
  function FileExists(filename)
    local f = io.open(filename, "r")
    if f ~= nil then
      io.close(f)
      return true
    end
    return false
  end
  
  local function GetFileModified(fileName)
    local fileHandle = io.popen("stat -c %Y '" .. fileName .. "'")
    if (fileHandle ~= nil) then
      return fileHandle:read()
    end
    return nil
  end
  
  local function WaitForFileModified(xmpFile, xmpModified)
    local duration = 0
    local durationMax = StepTimeout:Value() * 5
    local period = StepTimeout:Value()
  
    while (duration < period) do
      ThreadSleep(period)
      duration = duration + period
      if (duration >= durationMax) then
        break
      end
  
      local xmpModifiedNew = GetFileModified(xmpFile)
      if (xmpModifiedNew ~= xmpModified) then
        xmpModified = xmpModifiedNew
        break;
      end
    end
  
    return xmpModified
  end
  
  local function CopyXmpFile(xmpFile, filePath, fileName, appendix, xmpModified)
    -- wait until xmp file was written
    ThreadSleep(StepTimeout:Value())
    local xmpModifiedNew = WaitForFileModified(xmpFile, xmpModified)
  
    -- copy xmp file to test result folder
    local xmpFileCopyReset = filePath .. "/TEST/" .. fileName .. appendix .. ".xmp"
    local xmpCopyCommand = 'cp "' .. xmpFile .. '" "' .. xmpFileCopyReset .. '"'
    LogInfo(xmpCopyCommand)
    local ok = os.execute(xmpCopyCommand)
  
    return xmpModifiedNew
  end
  
  -- called to perform module tests
  local function ModuleTest()
    local currentView = dt.gui.current_view()
    if (currentView ~= dt.gui.views.darkroom) then
      LogScreen("Module test: Tests must be started from darkroom view")
      return
    end
  
    LogSummaryClear()
    LogInfo("Module test: Started.")
  
    LogMajorMax = 1
    LogMajorNr = 1
    LogCurrentStep = ""
  
  
    -- get current image information
    local image = dt.gui.views.darkroom.display_image()
    local xmpFile = image.path .. "/" .. image.filename .. ".xmp"
    local xmpModified = GetFileModified(xmpFile)
  
    -- ====================================
    -- reset current image history
    -- start with a well-defined state
    -- copy xmp file (with 'empty' history stack)
    GuiAction("lib/history", 0, "reset", "", 1.0)
    xmpModified = CopyXmpFile(xmpFile, image.path, image.filename, "_0_Reset", xmpModified)
  
    -- ====================================
    -- perform default settings
    -- copy xmp file (with 'default' history stack)
    LogMajorMax = 1
    LogMajorNr = 1
    LogCurrentStep = ""
    EnableDefaultSteps()
    ProcessWorkflowSteps()
    xmpModified = CopyXmpFile(xmpFile, image.path, image.filename, "_0_Default", xmpModified)
  
    -- get maximum number of combobox entries
    local comboBoxValuesMax = 1
    for i, step in ipairs(WorkflowSteps) do
      local count = #step.ComboBoxValues
      if (count > comboBoxValuesMax) then
        comboBoxValuesMax = count
      end
    end
  
    -- ====================================
    -- iterate over all workflow steps and combobox value settings
  
    -- configure first step to reset all inital workflow modules
    StepResetModuleHistory.Widget.value = 3
  
    local ignoreSteps =
    {
      StepResetModuleHistory,
      StepTimeout
    }
  
    -- set different combinations of module settings
    for comboBoxValue = 1, comboBoxValuesMax do
      for i, step in ipairs(WorkflowSteps) do
        if (not contains(ignoreSteps, step)) then
          if (comboBoxValue <= #step.ComboBoxValues) then
            step.Widget.value = comboBoxValue
          elseif (comboBoxValue == #step.ComboBoxValues + 1) then
            step:Default()
          else
            step.Widget.value = (comboBoxValue % #step.ComboBoxValues) + 1
          end
        end
      end
  
      -- perform configured settings
      -- copy xmp file with current settings to test result folder
      LogMajorMax = comboBoxValuesMax
      LogMajorNr = comboBoxValue
      LogCurrentStep = ""
      ProcessWorkflowSteps()
      xmpModified = CopyXmpFile(xmpFile, image.path, image.filename, "_" .. comboBoxValue, xmpModified)
    end
    LogSummary()
  
    LogInfo("Module test: Finished.")
  end
  
  -- TEST button: Special button, used to perform module tests.
  -- This button should be disabled for general use of the script.
  -- To enable it, create a file named "TestFlag.txt" in the same
  -- directory as this script file.
  
  if (FileExists(ScriptFilePath() .. "TestFlag.txt")) then
    ButtonModuleTest = WorkflowStepButton:new():new
        {
          Widget = dt.new_widget("button")
              {
                label = "TEST",
                tooltip = "Execute module tests. Used during development and deployment.",
  
                clicked_callback = ModuleTest
              }
        }
  
    ButtonModuleTestCustomCode = WorkflowStepButton:new():new
        {
          Widget = dt.new_widget("button")
              {
                label = "Custom Code",
                tooltip = "Execute code from TestCustomCode.lua: \n\z
                          This file contains some custom debug code. It can be changed without \n\z
                          restarting darktable. Just edit, save and execute it. You can use it \n\z
                          to try some lua commands on the fly, e.g. dt.gui.action commands.",
  
                clicked_callback = function()
                  local currentView = dt.gui.current_view()
                  if (currentView ~= dt.gui.views.darkroom) then
                    LogScreen("Module test: Tests must be started from darkroom view")
                    return
                  end
  
                  local fileName = ScriptFilePath() .. "TestCustomCode.lua"
  
                  if (not FileExists(fileName)) then
                    LogScreen("Module test: File not found: " .. fileName)
                    return
                  end
  
                  LogInfo('Execute script "' .. fileName .. '"')
                  dofile(fileName)
                end
              }
        }
  
    table.insert(WorkflowButtons, ButtonModuleTest)
    table.insert(WorkflowButtons, ButtonModuleTestCustomCode)
  end
  
  -- END OF MODULE TEST IMPLEMENTATION.
  
  ---------------------------------------------------------------
  
  --[[
  
    IMPLEMENTATION OF WIDGET FRAME
  
    Create main widget. Collect buttons and comboboxes.
  
  ]]
  -- collect all widgets to be displayed within the module
  local function GetWidgets()
    local widgets =
    {
      dt.new_widget("label") { label = "preparing manual steps", selectable = false, ellipsize = "start", halign = "start" },
      dt.new_widget("box") {
        orientation = "horizontal",
  
        -- buttons to simplify some manual steps
        ButtonEnableRotateAndPerspective.Widget,
        ButtonEnableCrop.Widget,
        ButtonMidToneExposure.Widget,
      },
  
      dt.new_widget("label") { label = "" },
      dt.new_widget("label") { label = "select and perform automatic steps", selectable = false, ellipsize = "start", halign =
      "start" },
      dt.new_widget("box") {
        orientation = "horizontal",
  
        -- buttons to start image processing and to set default values
        ButtonRunSelectedSteps.Widget,
        ButtonEnableDefaultSteps.Widget,
        ButtonDisableAllSteps.Widget
      },
  
      dt.new_widget("label") { label = "" },
    }
  
    -- TEST button: Special buttons, used to perform module tests.
    if (ButtonModuleTest) then
      LogInfo("INSERT TEST BUTTON WIDGET")
      table.insert(widgets,
        dt.new_widget("box")
        {
          orientation = "horizontal",
          ButtonModuleTest.Widget,
          ButtonModuleTestCustomCode.Widget
        }
      )
    end
  
    -- Comboboxes to configure single workflow steps.
    -- The order in the GUI is the same as the order of declaration in the code.
    for i, step in ipairs(WorkflowSteps) do
      table.insert(widgets, step.Widget)
    end
  
    return widgets
  end
  
  ---------------------------------------------------------------
  
  -- register the module and create widget box in lighttable and darkroom
  local function InstallModuleRegisterLib()
    if not Env.InstallModuleDone then
      dt.register_lib(
        ModuleName,         -- Module name
        "initial workflow", -- name
        true,               -- expandable
        true,               -- resetable
  
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
        nil  -- view_leave
      )
  
      Env.InstallModuleDone = true
    end
  end
  
  -- register an event to signal changes from darkroom to lighttable
  local function viewChangedEvent(event, old_view, new_view)
    LogInfo("view changed event")
    if new_view.name == "lighttable" and old_view.name == "darkroom" then
      InstallModuleRegisterLib()
    end
  end
  
  -- install module
  local function InstallModuleRegisterEvent()
    LogInfo("install module - register event")
  
    if not Env.InstallModuleEventRegistered then
      dt.register_event(ModuleName, "view-changed", viewChangedEvent)
      Env.InstallModuleEventRegistered = true
    end
  end
  
  -- main entry function to install the module at startup
  local function InstallInitialWorkflowModule()
    LogInfo("create widget in lighttable and darkroom panels")
  
    -- initialize workflow steps
    for i, step in ipairs(WorkflowSteps) do
      step:Init()
    end
  
    -- get current settings as saved in darktable preferences
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
  