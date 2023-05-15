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
local dt = require 'darktable'
local du = require 'lib/dtutils'
local log = require 'lib/dtutils.log'

local ModuleName = 'InitialWorkflowModule'
local indent = '. '

local function ScriptFilePath()
  local str = debug.getinfo(1, 'S').source:sub(2)
  return str:match('(.*[/\\])')
end

local function quote(text)
  return '"' .. text --'"'
end

---------------------------------------------------------------
-- Translations: https://docs.darktable.org/lua/stable/lua.api.manual/darktable/darktable.gettext/

-- use gettext utilities to update translation file (.po, .mo)
-- execute the following commands from the directory that contains the script

-- create InitialWorkflowModule.po from source code:
-- xgettext InitialWorkflowModule.lua -d InitialWorkflowModuleExtracted --from-code=UTF-8 --language=Lua

-- merge new messages into existing translation files:
-- msgmerge -U locale/de/LC_MESSAGES/InitialWorkflowModule.po InitialWorkflowModuleExtracted.po

-- to create a .mo file run:
-- msgfmt -v locale/de/LC_MESSAGES/InitialWorkflowModule.po -o locale/de/LC_MESSAGES/InitialWorkflowModule.mo


local gettext = dt.gettext

local pathSeparator = dt.configuration.running_os == 'windows' and '\\' or '/'
local localePath = ScriptFilePath() .. 'locale' .. pathSeparator
gettext.bindtextdomain(ModuleName, localePath)

local function _(msgid)
  return gettext.dgettext(ModuleName, msgid)
end

---------------------------------------------------------------
-- declare some variables to install the module

local Env =
{
  InstallModuleEventRegistered = false,
  InstallModuleDone = false,
}

---------------------------------------------------------------
-- some helper methods to log information messages

log.log_level(log.info) -- log.info or log.warn or log.debug

local LogCurrentStep = ''
local LogMajorNr = 0
local LogMajorMax = 0
local LogSummaryMessages = {}

local function GetLogInfoText(text)
  return '[' .. LogMajorNr .. '/' .. LogMajorMax .. '] ' .. LogCurrentStep .. ': ' .. text
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

---------------------------------------------------------------
-- some helper functions

function ThreadSleep(milliseconds)
  local timeout = StepTimeout:Value()
  local factor = milliseconds / timeout
  LogInfo(indent .. string.format(_("wait for %d ms. (config = %s ms * %s)"), milliseconds, timeout, factor))
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

-- word wrapping, e.g. used for tooltips
-- based on http://lua-users.org/wiki/StringRecipes
local function wordwrap(str, limit)
  limit = limit or 50
  local here = 1
  local function check(sp, st, word, fi)
    if fi - here > limit then
      here = st
      return '\n' .. word
    end
  end
  return str:gsub('(%s+)()(%S+)()', check)
end

---------------------------------------------------------------
-- The script may dump a lot of log messages.
-- The summary collects some important (error) messages.
-- This function is executed at the end of each script run.
local function LogSummary()
  LogInfo('==============================')

  if (#LogSummaryMessages == 0) then
    LogInfo(_("script summary OK - there are no important messages and no timeouts"))
  else
    LogInfo(_("THERE ARE IMPORTANT MESSAGES:"))

    for index, message in ipairs(LogSummaryMessages) do
      LogInfo(message)
    end

    LogInfo(_("if you detect timeouts, you can increase the timeout value and try again"))
  end

  if (#LogSummaryMessages == 0) then
    LogScreen(_("initial workflow - image processing has been completed"))
  else
    LogScreen(_("THERE ARE IMPORTANT MESSAGES - see log for details / increase timeout value"))
  end

  LogInfo(_("initial workflow - image processing has been completed"))
  LogInfo('==============================')
end

---------------------------------------------------------------
-- dump some messages during script start up

-- check Darktable API version
-- new API of DT 4.2 is needed to use pixelpipe-processing-complete event
local apiCheck, err = pcall(function() du.check_min_api_version('9.0.0', ModuleName) end)
if (apiCheck) then
  LogInfo(string.format(_("darktable with appropriate lua API detected: %s"), 'dt' .. dt.configuration.version))
else
  LogInfo(_("this script needs at least darktable 4.2 API to run"))
  return
end

LogInfo(string.format(_("script executed from path %s"), ScriptFilePath()))
LogInfo(string.format(_("script translation files in %s"), localePath))
LogInfo(_("script outputs are in English"))

---------------------------------------------------------------
-- debug helper function to dump preference keys
-- helps you to find out strings like plugins/darkroom/chromatic-adaptation
-- darktable -d lua > ~/keys.txt
local function DumpPreferenceKeys()
  local keys = dt.preferences.get_keys()
  LogInfo(string.format(_("number of %d preference keys retrieved, listing follows"), #keys))
  for _, key in ipairs(keys) do
    LogInfo(key .. ' = ' .. dt.preferences.read('darktable', key, 'string'))
  end
end

-- check current darktable version
-- used to handle different behavior of dt 4.2 and following versions
local function CheckDarktable42()
  return contains({ '4.2', '4.2.0', '4.2.1' }, dt.configuration.version)
end

-- get Darktable workflow setting
-- read preference 'auto-apply chromatic adaptation defaults'
local function CheckDarktableModernWorkflowPreference()
  local modernWorkflows =
  {
    _("scene-referred (filmic)"),
    _("scene-referred (sigmoid)"),
    _("modern")
  }

  local workflow

  if CheckDarktable42() then
    -- use old dt 4.2 preference setting
    workflow = dt.preferences.read('darktable', 'plugins/darkroom/chromatic-adaptation', 'string')
  else
    -- use new dt 4.4 preference setting
    workflow = dt.preferences.read('darktable', 'plugins/darkroom/workflow', 'string')
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
  LogInfo(indent .. string.format(_("received event %s"), self.EventType))
end

-- execute embedded function and wait for given EventType
function WaitForEventBase:Do(embeddedFunction)
  -- register event
  self:EventReceivedFlagReset()

  dt.destroy_event(self.ModuleName, self.EventType)
  dt.register_event(self.ModuleName, self.EventType, self.EventReceivedFunction)

  LogInfo(indent .. string.format(_("wait for event %s"), self.EventType))

  -- execute given function
  embeddedFunction()

  -- wait for registered event
  local duration = 0
  local durationMax = StepTimeout:Value() * 5
  local period = StepTimeout:Value() / 10
  local output = '..'


  while (not self.EventReceivedFlag) or (duration < period) do
    if ((duration > 0) and (duration % 500 == 0)) then
      LogInfo(output)
      output = output .. '.'
    end

    dt.control.sleep(period)
    duration = duration + period

    if (duration >= durationMax) then
      local timeoutMessage = string.format(_("timeout after %d ms waiting for event %s"), durationMax, self.EventType)
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
      EventType = 'pixelpipe-processing-complete'
    }

-- called as callback function
function WaitForPixelPipe:EventReceivedFunction(event)
  WaitForPixelPipe:EventReceivedFlagSet()
end

---------------------------------------------------------------

-- wait for image loaded event and reload it, if necessary.
-- 'clean' flag indicates, if the load was clean (got pixel pipe locks) or not.
WaitForImageLoaded = WaitForEventBase:new():new
    {
      EventType = 'darkroom-image-loaded'
    }

function WaitForImageLoaded:EventReceivedFunction(event, clean, image)
  if not clean then
    local message = _("loading image failed, reload is performed (this could indicate a timing problem)")
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
  -- return 'not a number' and 'nil' as '0/0'
  -- log output equals to dt.gui.action command and parameters
  if (number ~= number) then
    return nanReplacement or '0/0'
  end

  if (number == nil) then
    return nilReplacement or '0/0'
  end

  -- some digits with dot
  local result = string.format('%.4f', number)
  result = string.gsub(result, ',', '.')

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
  LogInfo('dt.gui.action(' ..
    quote(path) ..
    ',' .. instance .. ',' .. quote(element) .. ',' .. quote(effect) .. ',' .. numberToString(speed) .. ')')

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

-- wait for 'pixelpipe-processing-complete'
local function GuiAction(path, instance, element, effect, speed)
  return GuiActionInternal(path, instance, element, effect, speed, true)
end

-- 'pixelpipe-processing-complete' is not expected
local function GuiActionWithoutEvent(path, instance, element, effect, speed)
  return GuiActionInternal(path, instance, element, effect, speed, false)
end

-- get current value
local function GuiActionGetValue(path, element)
  -- use 0/0 == NaN as parameter to indicate this read-action
  local value = GuiActionWithoutEvent(path, 0, element, '', 0 / 0)

  LogInfo(indent .. 'get ' .. quote(path) .. ' ' .. element .. ' = ' .. numberToString(value, 'NaN', 'nil'))

  return value
end

-- Set given value, compare it with the current value to avoid
-- unnecessary set commands. There is no “pixelpipe-processing-complete”,
-- if the new value equals the current value.
local function GuiActionSetValue(path, instance, element, effect, speed)
  -- get current value
  -- use 0/0 == NaN as parameter to indicate this read-action
  local value = GuiActionWithoutEvent(path, 0, element, 'set', 0 / 0)

  -- round the value to number of digits
  local digits = 4
  local digitsFactor = 10 ^ (digits or 0)
  value = math.floor(value * digitsFactor + 0.5) / digitsFactor

  LogInfo(indent .. 'get ' .. quote(path) .. ' ' .. element .. ' = ' .. numberToString(value, 'NaN', 'nil'))

  if (value ~= speed) then
    GuiAction(path, instance, element, effect, speed)
  else
    LogInfo(indent .. string.format(_("nothing to do, value already equals to %s"), quote(numberToString(value))))
  end
end

-- Push the button  addressed by the path. Turn it off, if necessary.
local function GuiActionButtonOffOn(path)
  LogInfo(string.format(_("push button off and on: %s"), quote(path)))

  local buttonState = GuiActionGetValue(path, 'button')
  if (GuiActionValueToBoolean(buttonState)) then
    GuiActionWithoutEvent(path, 0, 'button', 'off', 1.0)
  else
    LogInfo(indent .. _("nothing to do, button is already inactive"))
  end

  GuiAction(path, 0, 'button', 'on', 1.0)
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
  LogInfo('==============================')
  LogInfo(string.format(_("selection = %s"), self.Widget.value))
end

-- show given darkroom module
function WorkflowStep:ShowDarkroomModule(moduleName)
  -- check if the module is already displayed
  LogInfo(string.format(_("show module if not visible: %s"), moduleName))
  local visible = GuiActionGetValue(moduleName, 'show')
  if (not GuiActionValueToBoolean(visible)) then
    dt.gui.panel_show('DT_UI_PANEL_RIGHT')
    GuiActionWithoutEvent(moduleName, 0, 'show', '', 1.0)
  else
    LogInfo(indent .. _("already visible, nothing to do"))
  end
end

-- hide given darkroom module
function WorkflowStep:HideDarkroomModule(moduleName)
  -- check if the module is already hidden
  LogInfo(string.format(_("hide module if visible: %s"), moduleName))
  local visible = GuiActionGetValue(moduleName, 'show')
  if (GuiActionValueToBoolean(visible)) then
    GuiActionWithoutEvent(moduleName, 0, 'show', '', 1.0)
  else
    LogInfo(indent .. _("already hidden, nothing to do"))
  end
end

-- enable given darkroom module
function WorkflowStep:EnableDarkroomModule(moduleName)
  -- check if the module is already activated
  LogInfo(string.format(_("enable module if disabled: %s"), moduleName))
  local status = GuiActionGetValue(moduleName, 'enable')
  if (not GuiActionValueToBoolean(status)) then
    GuiAction(moduleName, 0, 'enable', '', 1.0)
  else
    LogInfo(indent .. _("already enabled, nothing to do"))
  end

  if (StepShowModulesDuringExecution.Widget.value == _("yes")) then
    self:ShowDarkroomModule(moduleName)
  end
end

-- disable given darkroom module
function WorkflowStep:DisableDarkroomModule(moduleName)
  -- check if the module is already activated
  LogInfo(string.format(_("disable module if enabled: %s"), moduleName))
  local status = GuiActionGetValue(moduleName, 'enable')
  if (GuiActionValueToBoolean(status)) then
    GuiAction(moduleName, 0, 'enable', '', 1.0)
  else
    LogInfo(indent .. _("already disabled, nothing to do"))
  end
end

-- reset given darkroom module
function WorkflowStep:ResetDarkroomModule(moduleName)
  LogInfo(string.format(_("reset module %s"), moduleName))
  GuiAction(moduleName, 0, 'reset', '', 1.0)
end

-- handle view changed event (lighttable / darkroom view)
-- some comboboxes or buttons need a special handling
function WorkflowStep:InitDependingOnCurrentView()
  -- do nothing by default
  -- self.Widget.sensitive = true
  -- self.Widget.visible = true
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

-- returns internal operation name like 'colorbalancergb' or 'atrous'
function WorkflowStepCombobox:OperationName()
  return self.OperationNameInternal
end

-- returns operation path like 'iop/colorbalancergb'
function WorkflowStepCombobox:OperationPath()
  return 'iop/' .. self:OperationName()
end

-- save current selection of this workflow step
-- used to restore settings after starting darktable
function WorkflowStepCombobox:SavePreferenceValue()
  -- check, if there are any changes
  local preferenceValue = dt.preferences.read(ModuleName, self.Widget.label, 'string')
  local comboBoxValue = self.Widget.value

  -- save any changes
  if (preferenceValue ~= comboBoxValue) then
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
    if (v ~= _("unchanged")) then
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

-- called from callback function within a 'foreign context'
-- we have to determine the button object or workflow step first
function GetWorkflowItem(widget, table)
  for i, item in ipairs(table) do
    if (item.Widget == widget) then
      return item
    end
  end
  return nil
end

-- called from callback function within a 'foreign context'
-- determine the button object
function GetWorkflowButton(widget)
  return GetWorkflowItem(widget, WorkflowButtons)
end

-- called from callback function within a 'foreign context'
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
      Tooltip = _(wordwrap(
        "Generate the shortest history stack that reproduces the current image. This removes your current history snapshots."))
    }

table.insert(WorkflowSteps, StepCompressHistoryStack)

function StepCompressHistoryStack:Init()
  self.ComboBoxValues = { _("no"), _("yes") }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("compress history stack"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepCompressHistoryStack:Run()
  local selection = self.Widget.value

  if (selection == _("yes")) then
    self:LogStepMessage()
    GuiAction('lib/history/compress history stack', 0, '', '', 1.0)
  end
end

---------------------------------------------------------------

StepDynamicRangeSceneToDisplay = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      -- this step refers to different modules
      OperationNameInternal = 'Filmic or Sigmoid',
      DisableValue = 1,
      DefaultValue = 4,
      Tooltip = _(wordwrap(
        "Use Filmic or Sigmoid to expand or contract the dynamic range of the scene to fit the dynamic range of the display. Auto tune filmic levels of black + white relative exposure and / or reset module settings. Or use Sigmoid with one of its presets. Use only one of Filmic, Sigmoid or Basecurve, this module disables the others."))
    }

table.insert(WorkflowSteps, StepDynamicRangeSceneToDisplay)

function StepDynamicRangeSceneToDisplay:Init()
  self.ComboBoxValues =
  {
    _("unchanged"),
    _("Filmic reset defaults"),
    _("Filmic auto tune levels"),
    _("Filmic reset + auto tune"),
    _("Sigmoid reset defaults, color per channel"),
    _("Sigmoid reset defaults, color rgb ratio"),
    _("Sigmoid ACES 100 preset")
  }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("dynamic range: scene to display"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepDynamicRangeSceneToDisplay:FilmicSelected()
  return contains(
    { _("Filmic reset defaults"),
      _("Filmic auto tune levels"),
      _("Filmic reset + auto tune")
    }, self.Widget.value)
end

function StepDynamicRangeSceneToDisplay:SigmoidSelected()
  return contains(
    { _("Sigmoid reset defaults, color per channel"),
      _("Sigmoid reset defaults, color rgb ratio"),
      _("Sigmoid ACES 100 preset")
    }, self.Widget.value)
end

function StepDynamicRangeSceneToDisplay:OperationName()
  -- override base class function
  -- distinguish between filmic and sigmoid module

  if (self:FilmicSelected()) then
    return 'filmicrgb'
  end

  if (self:SigmoidSelected()) then
    return 'sigmoid'
  end

  return nil
end

function StepDynamicRangeSceneToDisplay:Run()
  local selection = self.Widget.value

  if (selection == _("unchanged")) then
    return
  end

  local filmic = self:FilmicSelected()

  local filmicReset = contains(
    { _("Filmic reset defaults"),
      _("Filmic reset + auto tune")
    }, selection)

  local filmicAuto = contains(
    { _("Filmic auto tune b+w relative exposure"),
      _("Filmic auto tune levels"),
      _("Filmic reset + auto tune")
    }, selection)

  local sigmoid = self:SigmoidSelected()

  local sigmoidDefaultPerChannel = contains(
    { _("Sigmoid reset defaults, color per channel")
    }, selection)

  local sigmoidDefaultRgbRatio = contains(
    { _("Sigmoid reset defaults, color rgb ratio")
    }, selection)

  local sigmoidACES100 = contains(
    { _("Sigmoid ACES 100 preset")
    }, selection)


  self:LogStepMessage()

  if (filmic) then
    self:DisableDarkroomModule('iop/sigmoid')
    self:DisableDarkroomModule('iop/basecurve')
    self:EnableDarkroomModule('iop/filmicrgb')

    if (filmicReset) then
      self:ResetDarkroomModule('iop/filmicrgb')
    end

    if (filmicAuto) then
      GuiActionButtonOffOn('iop/filmicrgb/auto tune levels')
    end
  end

  if (sigmoid) then
    self:DisableDarkroomModule('iop/filmicrgb')
    self:DisableDarkroomModule('iop/basecurve')
    self:EnableDarkroomModule('iop/sigmoid')

    self:ResetDarkroomModule('iop/sigmoid')

    if (sigmoidDefaultPerChannel) then
      -- keep defaults
    end

    if (sigmoidDefaultRgbRatio) then
      GuiAction('iop/sigmoid/color processing', 0, 'selection', 'item:' .. _("rgb ratio"), 1.0)
    end

    if (sigmoidACES100) then
      GuiActionButtonOffOn('iop/sigmoid/preset/' .. _("ACES 100-nit like"))
    end
  end
end

---------------------------------------------------------------

StepColorBalanceGlobalSaturation = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = 'colorbalancergb',
      DisableValue = 1,
      DefaultValue = 7,
      Tooltip = _(wordwrap("Adjust global saturation in color balance rgb module."))
    }

table.insert(WorkflowSteps, StepColorBalanceGlobalSaturation)

function StepColorBalanceGlobalSaturation:Init()
  self.ComboBoxValues =
  {
    _("unchanged"), 0, 5, 10, 15, 20, 25, 30, 35
  }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("color balance rgb global saturation"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepColorBalanceGlobalSaturation:Run()
  local selection = self.Widget.value

  if (selection ~= _("unchanged")) then
    self:LogStepMessage()
    self:EnableDarkroomModule('iop/colorbalancergb')
    GuiActionSetValue('iop/colorbalancergb/global saturation', 0, 'value', 'set', selection / 100)
  end
end

---------------------------------------------------------------

StepColorBalanceGlobalChroma = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = 'colorbalancergb',
      DisableValue = 1,
      DefaultValue = 5,
      Tooltip = _(wordwrap("Adjust global chroma in color balance rgb module."))
    }

table.insert(WorkflowSteps, StepColorBalanceGlobalChroma)

function StepColorBalanceGlobalChroma:Init()
  self.ComboBoxValues =
  {
    _("unchanged"), 0, 5, 10, 15, 20, 25, 30, 35
  }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("color balance rgb global chroma"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepColorBalanceGlobalChroma:Run()
  local selection = self.Widget.value

  if (selection ~= _("unchanged")) then
    self:LogStepMessage()
    self:EnableDarkroomModule('iop/colorbalancergb')
    GuiActionSetValue('iop/colorbalancergb/global chroma', 0, 'value', 'set', selection / 100)
  end
end

---------------------------------------------------------------

StepColorBalanceRGB = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = 'colorbalancergb',
      DisableValue = 1,
      DefaultValue = 2,
      Tooltip = _(wordwrap(
        "Choose a predefined preset for your color-grading. Or set auto pickers of the module mask and peak white and gray luminance value to normalize the power setting in the 4 ways tab."))
    }

table.insert(WorkflowSteps, StepColorBalanceRGB)

function StepColorBalanceRGB:Init()
  self.ComboBoxValues =
  {
    _("unchanged"),
    _("reset and peak white & grey fulcrum"),
    _("add basic colorfulness (legacy)"),
    _("basic colorfulness: natural skin"),
    _("basic colorfulness: standard"),
    _("basic colorfulness: vibrant colors")
  }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("color balance rgb"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepColorBalanceRGB:Run()
  local selection = self.Widget.value

  if (selection == _("unchanged")) then
    return
  end

  self:LogStepMessage()
  self:EnableDarkroomModule('iop/colorbalancergb')

  if (selection == _("reset and peak white & grey fulcrum")) then
    self:ResetDarkroomModule('iop/colorbalancergb')
    GuiActionButtonOffOn('iop/colorbalancergb/white fulcrum')
    GuiActionButtonOffOn('iop/colorbalancergb/contrast gray fulcrum')
  else
    GuiActionButtonOffOn('iop/colorbalancergb/preset/' .. selection)
  end
end

---------------------------------------------------------------

StepContrastEqualizer = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = 'atrous',
      DisableValue = 1,
      DefaultValue = 3,
      Tooltip = _(wordwrap(
        "Adjust luminance and chroma contrast. Apply choosen preset (clarity or denoise & sharpen). Choose different values to adjust the strength of the effect."))
    }

table.insert(WorkflowSteps, StepContrastEqualizer)

function StepContrastEqualizer:Init()
  self.ComboBoxValues =
  {
    _("unchanged"),
    _("reset to default"),
    _("clarity, strength 0,25"),
    _("clarity, strength 0,50"),
    _("denoise & sharpen, strength 0,25"),
    _("denoise & sharpen, strength 0,50")
  }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("contrast equalizer"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepContrastEqualizer:Run()
  local selection = self.Widget.value

  if (selection == _("unchanged")) then
    return
  end

  self:LogStepMessage()
  self:EnableDarkroomModule('iop/atrous')

  if (selection == _("reset to default")) then
    self:ResetDarkroomModule('iop/atrous')
    --
  elseif (selection == _("clarity, strength 0,25")) then
    GuiActionButtonOffOn('iop/atrous/preset/' .. _("clarity"))
    GuiActionSetValue('iop/atrous/mix', 0, 'value', 'set', 0.25)
    --
  elseif (selection == _("clarity, strength 0,50")) then
    GuiActionButtonOffOn('iop/atrous/preset/' .. _("clarity"))
    GuiActionSetValue('iop/atrous/mix', 0, 'value', 'set', 0.5)
    --
  elseif (selection == _("denoise & sharpen, strength 0,25")) then
    GuiActionButtonOffOn('iop/atrous/preset/' .. _("denoise & sharpen"))
    GuiActionSetValue('iop/atrous/mix', 0, 'value', 'set', 0.25)
    --
  elseif (selection == _("denoise & sharpen, strength 0,50")) then
    GuiActionButtonOffOn('iop/atrous/preset/' .. _("denoise & sharpen"))
    GuiActionSetValue('iop/atrous/mix', 0, 'value', 'set', 0.5)
  end
end

---------------------------------------------------------------

StepToneEqualizerMask = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = 'toneequal',
      DisableValue = 1,
      DefaultValue = 3,
      Tooltip = _(wordwrap(
        "Use default preset mask blending for all purposes plus automatic mask contrast and exposure compensation. Or use preset to compress shadows and highlights with exposure-independent guided filter (eigf) (soft, medium or strong)."))
    }

table.insert(WorkflowSteps, StepToneEqualizerMask)

function StepToneEqualizerMask:Init()
  self.ComboBoxValues =
  {
    _("unchanged"),
    _("default mask blending"),
    _("default plus mask compensation"),
    _("compress high-low (eigf): medium"),
    _("compress high-low (eigf): soft"),
    _("compress high-low (eigf): strong")
  }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("tone equalizer"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepToneEqualizerMask:Run()
  local selection = self.Widget.value

  if (selection == _("unchanged")) then
    return
  end

  self:LogStepMessage()
  self:EnableDarkroomModule('iop/toneequal')
  self:ResetDarkroomModule('iop/toneequal')

  if (selection == _("default mask blending")) then
    -- nothing else to do...
    --
  elseif (selection == _("default plus mask compensation")) then
    -- workaround: show this module, otherwise the buttons will not be pressed
    self:ShowDarkroomModule('iop/toneequal')

    GuiActionWithoutEvent('iop/toneequal/page', 0, 'masking', '', 1.0)

    GuiAction('iop/toneequal/mask exposure compensation', 0, 'button', 'toggle', 1.0)
    ThreadSleep(StepTimeout:Value())
    GuiAction('iop/toneequal/mask contrast compensation', 0, 'button', 'toggle', 1.0)
    ThreadSleep(StepTimeout:Value())

    -- workaround: show this module, otherwise the buttons will not be pressed
    self:HideDarkroomModule('iop/toneequal')
    --
  elseif (selection == _("compress high-low (eigf): medium")) then
    GuiActionButtonOffOn('iop/toneequal/preset/' .. _("compress shadows-highlights (eigf): medium"))
    --
  elseif (selection == _("compress high-low (eigf): soft")) then
    -- workaround to deal with bug in dt 4.2.x
    -- dt 4.2 uses special characters
    if (CheckDarktable42()) then
      GuiActionButtonOffOn('iop/toneequal/preset/' .. _("compress shadows-highlights (eigf): soft"))
    else
      GuiActionButtonOffOn('iop/toneequal/preset/' .. _("compress shadows-highlights (eigf): soft"))
    end
    --
  elseif (selection == _("compress high-low (eigf): strong")) then
    -- workaround to deal with bug in dt 4.2.x
    -- dt 4.2 uses special characters
    if (CheckDarktable42()) then
      GuiActionButtonOffOn('iop/toneequal/preset/' .. _("compress shadows-highlights (eigf): strong"))
    else
      GuiActionButtonOffOn('iop/toneequal/preset/' .. _("compress shadows-highlights (eigf): strong"))
    end
    --
  end
end

---------------------------------------------------------------

StepExposureCorrection = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = 'exposure',
      DisableValue = 1,
      DefaultValue = 4,
      Tooltip = _(wordwrap(
        "Automatically adjust the exposure correction. Remove the camera exposure bias, useful if you exposed the image to the right."))
    }

table.insert(WorkflowSteps, StepExposureCorrection)

function StepExposureCorrection:Init()
  self.ComboBoxValues =
  {
    _("unchanged"),
    _("adjust exposure correction"),
    _("reset & adjust exposure correction"),
    _("adjust exp. & compensate camera bias"),
    _("reset & adjust exp. & comp. camera bias")
  }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("exposure"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepExposureCorrection:Run()
  local selection = self.Widget.value

  if (selection == _("unchanged")) then
    return
  end

  local adjustExposureCorrection = contains(
    { _("adjust exposure correction"),
      _("adjust exp. & compensate camera bias")
    }, selection)

  local resetModule              = contains(
    { _("reset & adjust exposure correction"),
      _("reset & adjust exp. & comp. camera bias")
    }, selection)

  local compensateBias           = contains(
    {
      _("adjust exp. & compensate camera bias"),
      _("reset & adjust exp. & comp. camera bias")
    }, selection)

  self:LogStepMessage()
  self:EnableDarkroomModule('iop/exposure')

  if (resetModule) then
    self:ResetDarkroomModule('iop/exposure')
  end

  if (adjustExposureCorrection) then
    GuiActionButtonOffOn('iop/exposure/exposure')
  end

  if (compensateBias) then
    local checkbox = GuiActionGetValue('iop/exposure/compensate exposure bias', '')
    if (checkbox == 0) then
      GuiAction('iop/exposure/compensate exposure bias', 0, '', 'on', 1.0)
    else
      LogInfo(indent .. _("checkbox already selected, nothing to do"))
    end
    --
  end
end

---------------------------------------------------------------

StepLensCorrection = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = 'lens',
      DisableValue = 1,
      DefaultValue = 4,
      Tooltip = _(wordwrap("Enable and reset lens correction module.")),
    }

table.insert(WorkflowSteps, StepLensCorrection)

function StepLensCorrection:Init()
  self.ComboBoxValues =
  {
    _("unchanged"),
    _("reset module"),
    _("enable lensfun method"),
    _("reset & lensfun method")
  }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("lens correction"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepLensCorrection:Run()
  local selection = self.Widget.value

  if (selection == _("unchanged")) then
    return
  end

  local resetModule = contains(
    {
      _("reset module"),
      _("reset & lensfun method")
    }, selection)

  local lensfun = contains(
    {
      _("enable lensfun method"),
      _("reset & lensfun method")
    }, selection)

  self:LogStepMessage()
  self:EnableDarkroomModule('iop/lens')

  if (resetModule) then
    self:ResetDarkroomModule('iop/lens')
  end

  if (lensfun) then
    GuiAction('iop/lens/correction method', 0, 'selection', 'item:' .. _("lensfun database"), 1.0)
  end
end

---------------------------------------------------------------

StepDenoiseProfiled = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = 'denoiseprofile',
      DisableValue = 1,
      DefaultValue = 2,
      Tooltip = _(wordwrap("Enable and reset denoise (profiled) module."))
    }

table.insert(WorkflowSteps, StepDenoiseProfiled)

function StepDenoiseProfiled:Init()
  self.ComboBoxValues = { _("unchanged"), _("enable and reset") }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("denoise (profiled)"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepDenoiseProfiled:Run()
  local selection = self.Widget.value

  if (selection == _("unchanged")) then
    return
  end

  if (selection == _("enable and reset")) then
    self:LogStepMessage()
    self:EnableDarkroomModule('iop/denoiseprofile')
    self:ResetDarkroomModule('iop/denoiseprofile')
  end
end

---------------------------------------------------------------

StepChromaticAberrations = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = 'cacorrect',
      DisableValue = 1,
      DefaultValue = 2,
      Tooltip = _(wordwrap("Correct chromatic aberrations."))
    }

table.insert(WorkflowSteps, StepChromaticAberrations)

function StepChromaticAberrations:Init()
  self.ComboBoxValues =
  {
    _("unchanged"),
    _("enable (Bayer sensor)"),
    _("enable (other)")
  }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("chromatic aberrations"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepChromaticAberrations:Run()
  local selection = self.Widget.value

  if (selection == _("unchanged")) then
    return
  end

  self:LogStepMessage()

  if (selection == _("enable (Bayer sensor)")) then
    self:EnableDarkroomModule('iop/cacorrect')
  end

  if (selection == _("enable (other)")) then
    self:EnableDarkroomModule('iop/cacorrectrgb')
  end
end

---------------------------------------------------------------

StepColorCalibrationIlluminant = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = 'channelmixerrgb',
      DisableValue = 1,

      -- see Default() override
      DefaultValue = nil,
      Tooltip = _(wordwrap(
        "Perform color space corrections in color calibration module. Select the illuminant. The type of illuminant assumed to have lit the scene. By default unchanged for the legacy workflow."))
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
    _("unchanged"), -- additional value
    _("same as pipeline (D50)"),
    _("A (incandescent)"),
    _("D (daylight)"),
    _("E (equi-energy)"),
    _("F (fluorescent)"),
    _("LED (LED light)"),
    _("Planckian (black body)"),
    _("custom"),
    _("(AI) detect from image surfaces..."),
    _("(AI) detect from image edges..."),
    _("as shot in camera")
  }

  self:CreateComboBoxSelectionIndex()

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("color calibration illuminant"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepColorCalibrationIlluminant:Run()
  local selection = self.Widget.value

  if (selection == _("unchanged")) then
    return
  end

  self:LogStepMessage()

  -- ignore illuminant, if current adaptation is equal to bypass
  local adaptationSelectionIndex = GuiActionGetValue('iop/channelmixerrgb/adaptation', 'selection')
  local adaptationSelection = StepColorCalibrationAdaptation:GetComboBoxValueFromSelectionIndex(adaptationSelectionIndex)

  LogInfo(indent .. string.format(_("color calibration adaption = %s"), adaptationSelection))
  if (adaptationSelection == _("none (bypass)")) then
    LogInfo(indent .. _("illuminant cannot be set"))
    return
  else
    LogInfo(indent .. _("illuminant can be set"))
  end

  -- set illuminant

  self:EnableDarkroomModule('iop/channelmixerrgb')

  local currentSelectionIndex = GuiActionGetValue('iop/channelmixerrgb/illuminant', 'selection')
  local currentSelection = StepColorCalibrationIlluminant:GetComboBoxValueFromSelectionIndex(currentSelectionIndex)

  if (selection ~= currentSelection) then
    LogInfo(indent .. string.format(_("current illuminant = %s"), quote(currentSelection)))
    GuiAction('iop/channelmixerrgb/illuminant', 0, 'selection', 'item:' .. selection, 1.0)
  else
    LogInfo(indent .. string.format(_("nothing to do, illuminant already = %s"), quote(currentSelection)))
  end
end

---------------------------------------------------------------

StepColorCalibrationAdaptation = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = 'channelmixerrgb',
      DisableValue = 1,
      DefaultValue = 3,
      Tooltip = _(wordwrap(
        "Perform color space corrections in color calibration module. Select the adaptation. The working color space in which the module will perform its chromatic adaptation transform and channel mixing."))
    }

table.insert(WorkflowSteps, StepColorCalibrationAdaptation)

-- combobox values see darktable typedef enum dt_adaptation_t

function StepColorCalibrationAdaptation:Init()
  self.ComboBoxValues =
  {
    _("unchanged"), -- additional value
    _("linear Bradford (ICC v4)"),
    _("CAT16 (CIECAM16)"),
    _("non-linear Bradford"),
    _("XYZ"),
    _("none (bypass)")
  }

  self:CreateComboBoxSelectionIndex()

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("color calibration adaptation"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepColorCalibrationAdaptation:Run()
  local selection = self.Widget.value

  if (selection == _("unchanged")) then
    return
  end

  self:LogStepMessage()
  self:EnableDarkroomModule('iop/channelmixerrgb')

  local currentSelectionIndex = GuiActionGetValue('iop/channelmixerrgb/adaptation', 'selection')
  local currentSelection = StepColorCalibrationAdaptation:GetComboBoxValueFromSelectionIndex(currentSelectionIndex)

  if (selection ~= currentSelection) then
    LogInfo(indent .. string.format(_("current adaptation = %s"), quote(currentSelection)))
    GuiAction('iop/channelmixerrgb/adaptation', 0, 'selection', 'item:' .. selection, 1.0)
  else
    LogInfo(indent .. string.format(_("nothing to do, adaptation already = %s"), quote(currentSelection)))
  end
end

---------------------------------------------------------------

-- this step was DISABLED
-- we have to wait for a Darktable bugfix (dt4.4)

StepHighlightReconstruction = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = 'highlights',
      DisableValue = 1,
      DefaultValue = 1,
      Tooltip = _(wordwrap(
        "Reconstruct color information for clipped pixels. Select an appropriate reconstruction methods to reconstruct the missing data from unclipped channels and/or neighboring pixels."))
    }

-- disabled step
-- do not add this step to the widget
-- table.insert(WorkflowSteps, StepHighlightReconstruction)

function StepHighlightReconstruction:Init()
  self.ComboBoxValues =
  {
    _("unchanged"),
    -- _("inpaint opposed"),
    -- _("reconstruct in LCh"),
    -- _("clip highlights"),
    -- _("segmentation based"),
    -- _("guided laplacians")
  }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("highlight reconstruction"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepHighlightReconstruction:Run()
  local selection = self.Widget.value

  if (selection == _("unchanged")) then
    return
  end

  self:LogStepMessage()
  self:EnableDarkroomModule('iop/highlights')
  GuiAction('iop/highlights/method', 0, 'selection', 'item:' .. selection, 1.0)
end

---------------------------------------------------------------

StepWhiteBalance = WorkflowStepCombobox:new():new
    {
      -- internal operation name should be copied from gui action command (iop/OperationName)
      OperationNameInternal = 'temperature',
      DisableValue = 1,

      -- see Default() override
      DefaultValue = nil,
      Tooltip = _(wordwrap(
        "Adjust the white balance of the image by altering the temperature. By default unchanged for the legacy workflow."))
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
    _("unchanged"),
    _("as shot"),
    _("from image area"),
    _("user modified"),
    _("camera reference")
  }

  self:CreateComboBoxSelectionIndex()

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("white balance"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepWhiteBalance:Run()
  local selection = self.Widget.value

  if (selection == _("unchanged")) then
    return
  end

  self:LogStepMessage()
  self:EnableDarkroomModule('iop/temperature')

  local currentSelectionIndex = GuiActionGetValue('iop/temperature/settings/settings', 'selection')
  local currentSelection = StepWhiteBalance:GetComboBoxValueFromSelectionIndex(currentSelectionIndex)

  if (selection ~= currentSelection) then
    LogInfo(indent .. string.format(_("current value = %s"), quote(currentSelection)))
    GuiAction('iop/temperature/settings/' .. selection, 0, '', '', 1.0)
  else
    LogInfo(indent .. string.format(_("nothing to do, value already = %s"), quote(currentSelection)))
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
      Tooltip = _(wordwrap(
        "Reset modules that are part of this initial workflow. Keep other module settings like crop, rotate and perspective. Or reset all modules of the pixelpipe and discard complete history stack."))
    }

table.insert(WorkflowSteps, StepResetModuleHistory)

function StepResetModuleHistory:Init()
  self.ComboBoxValues =
  {
    _("no"),
    _("reset active initial workflow modules"),
    _("reset all initial workflow modules"),
    _("discard complete history stack")
  }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("reset modules"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepResetModuleHistory:Run()
  local selection = self.Widget.value

  if (selection == _("no")) then
    return
  end

  self:LogStepMessage()

  if (selection == _("discard complete history stack")) then
    GuiAction('lib/history', 0, 'reset', '', 1.0)
  else
    -- collect modules to reset
    local modules = {}

    for i, step in ipairs(WorkflowSteps) do
      if (step ~= self) then
        if (step:OperationName()) then
          if (not contains(modules, step:OperationPath())) then
            -- reset active
            if (selection == _("reset active initial workflow modules")) then
              if (not contains({ _("no"), _("unchanged") }, step.Widget.value)) then
                table.insert(modules, step:OperationPath())
              end
            end
            -- reset all
            if (selection == _("reset all initial workflow modules")) then
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
      Tooltip = _(wordwrap(
        "Show darkroom modules for enabled workflow steps during execution of this initial workflow. This makes the changes easier to understand."))
    }

table.insert(WorkflowSteps, StepShowModulesDuringExecution)

function StepShowModulesDuringExecution:Init()
  self.ComboBoxValues = { _("no"), _("yes") }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = _("show modules"),
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
      Tooltip = _(wordwrap(
        "Some calculations take a certain amount of time. Depending on the hardware equipment also longer.This script waits and attempts to detect timeouts. If steps take much longer than expected, those steps will be aborted. You can configure the default timeout (ms). Before and after each step of the workflow, the script waits this time. In other places also a multiple (loading an image) or a fraction (querying a status)."))
    }

table.insert(WorkflowSteps, StepTimeout)

function StepTimeout:Init()
  self.ComboBoxValues =
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
        changed_callback = ComboBoxChangedCallback,
        label = _("timeout value"),
        tooltip = self.Tooltip,
        table.unpack(self.ComboBoxValues)
      }
end

function StepTimeout:Run()
  LogInfo(string.format(_("step timeout = %s ms"), self:Value()))
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
  LogInfo('==============================')
  LogInfo(_("process workflow steps"))

  ThreadSleep(StepTimeout:Value())

  -- execute all workflow steps
  -- the order is from bottom to top, along the pixel pipeline.
  for i = 1, #WorkflowSteps do
    local step = WorkflowSteps[#WorkflowSteps + 1 - i]
    LogCurrentStep = step.Widget.label
    step:Run()
  end

  LogCurrentStep = ''
  ThreadSleep(StepTimeout:Value())
end

-- process current image in darkroom view
local function ProcessImageInDarkroomView()
  LogMajorMax = 1
  LogMajorNr = 1
  LogCurrentStep = ''

  LogSummaryClear()

  ProcessWorkflowSteps()

  LogSummary()
end

-- process selected image(s)
local function ProcessSelectedImagesInLighttableView()
  LogMajorMax = 0
  LogMajorNr = 0
  LogCurrentStep = ''

  LogSummaryClear()

  LogInfo('==============================')
  LogInfo(_("process selected images"))

  -- check that there is an image selected to activate darkroom view
  local images = dt.gui.action_images
  if not images or #images == 0 then
    LogScreen(_("no image selected"))
    return
  end

  -- remember currently selected images
  images = {}
  for _, newImage in ipairs(dt.gui.action_images) do
    table.insert(images, newImage)
  end

  -- switch to darkroom view
  LogInfo(_("switch to darkroom view"))
  WaitForPixelPipe:Do(function()
    dt.gui.current_view(dt.gui.views.darkroom)
  end)

  -- process selected images
  LogMajorMax = #images
  for index, newImage in ipairs(images) do
    LogMajorNr = index
    LogCurrentStep = ''

    local oldImage = dt.gui.views.darkroom.display_image()

    -- load selected image and show it in darkroom view
    LogInfo(string.format(_("load image number %s of %s"), index, #images))
    LogInfo(string.format(_("image file = %s"), newImage.filename))

    if (oldImage ~= newImage) then
      WaitForPixelPipe:Do(function()
        LogInfo(_("load new image into darkroom view"))
        WaitForImageLoaded:Do(function()
          dt.gui.views.darkroom.display_image(newImage)
        end)
      end)
    end

    ProcessWorkflowSteps()
  end

  -- switch to lighttable view
  LogInfo(_("switch to lighttable view"))
  dt.gui.current_view(dt.gui.views.lighttable)
  dt.gui.selection(images)

  LogSummary()
end

ButtonRunSelectedSteps = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget('button')
          {
            label = _("run"),
            tooltip = _(wordwrap(
              "Perform all configured steps in darkroom for an initial workflow. Perform the steps from bottom to top along the pixel pipeline.")),

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
      Widget = dt.new_widget('button')
          {
            label = _("select none"),
            tooltip = _(wordwrap("Disable all steps of this inital workflow module.")),

            clicked_callback = function()
              for i, step in ipairs(WorkflowSteps) do
                if (step ~= StepTimeout) then
                  step:Disable()
                end
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
    if (step ~= StepTimeout) then
      step:Default()
    end
  end
end

ButtonEnableDefaultSteps = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget('button')
          {
            label = _("select defaults"),
            tooltip = _(wordwrap("Enable default steps and settings.")),

            clicked_callback = EnableDefaultSteps
          }
    }

table.insert(WorkflowButtons, ButtonEnableDefaultSteps)

---------------------------------------------------------------

ButtonEnableRotateAndPerspective = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget('button')
          {
            label = _("rotate + perspective"),
            tooltip = _(wordwrap(
              "Activate the module to rotate the image and adjust the perspective. Enabled in darkroom view.")),

            clicked_callback = function(widget)
              local button = GetWorkflowButton(widget)
              if button ~= nil then
                button:EnableDarkroomModule('iop/ashift')
                button:ShowDarkroomModule('iop/ashift')
              end
            end
          }
    }

function ButtonEnableRotateAndPerspective:InitDependingOnCurrentView()
  -- override base class function
  self.Widget.sensitive = (dt.gui.current_view() == dt.gui.views.darkroom)
end

table.insert(WorkflowButtons, ButtonEnableRotateAndPerspective)

---------------------------------------------------------------

ButtonEnableCrop = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget('button')
          {
            label = _("crop image"),
            tooltip = _(wordwrap("Activate the module to crop the image. Enabled in darkroom view.")),

            clicked_callback = function(widget)
              local button = GetWorkflowButton(widget)
              if (button ~= nil) then
                button:EnableDarkroomModule('iop/crop')
                button:ShowDarkroomModule('iop/crop')
              end
            end
          }
    }

function ButtonEnableCrop:InitDependingOnCurrentView()
  -- override base class function
  self.Widget.sensitive = (dt.gui.current_view() == dt.gui.views.darkroom)
end

table.insert(WorkflowButtons, ButtonEnableCrop)

---------------------------------------------------------------

ButtonMidToneExposure = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget('button')
          {
            label = _("exposure (midtones)"),
            tooltip = _(wordwrap(
              "Show exposure module to adjust the exposure until the mid-tones are clear enough. Enabled in darkroom view.")),

            clicked_callback = function(widget)
              local button = GetWorkflowButton(widget)
              if (button ~= nil) then
                button:EnableDarkroomModule('iop/exposure')
                button:ShowDarkroomModule('iop/exposure')
              end
            end
          }
    }

function ButtonMidToneExposure:InitDependingOnCurrentView()
  -- override base class function
  self.Widget.sensitive = (dt.gui.current_view() == dt.gui.views.darkroom)
end

table.insert(WorkflowButtons, ButtonMidToneExposure)

---------------------------------------------------------------

-- MODULE TEST IMPLEMENTATION.

-- This section contains some functions to perform module tests.
-- The following functions are used during development and deployment.

function FileExists(filename)
  local f = io.open(filename, 'r')
  if f ~= nil then
    io.close(f)
    return true
  end
  return false
end

local function GetFileModified(fileName)
  local fileHandle = io.popen('stat -c %Y ' .. quote(fileName))
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
  local xmpFileCopyReset = filePath .. '/TEST/' .. fileName .. appendix .. '.xmp'
  local xmpCopyCommand = 'cp ' .. quote(xmpFile) .. ' ' .. quote(xmpFileCopyReset)
  LogInfo(xmpCopyCommand)
  local ok = os.execute(xmpCopyCommand)

  return xmpModifiedNew
end

-- called to perform module tests
local function ModuleTest()
  local currentView = dt.gui.current_view()
  if (currentView ~= dt.gui.views.darkroom) then
    LogScreen(_("module tests must be started from darkroom view"))
    return
  end

  LogSummaryClear()
  LogInfo(_("module test started"))

  LogMajorMax = 1
  LogMajorNr = 1
  LogCurrentStep = ''


  -- get current image information
  local image = dt.gui.views.darkroom.display_image()
  local xmpFile = image.path .. '/' .. image.filename .. '.xmp'
  local xmpModified = GetFileModified(xmpFile)

  -- ====================================
  -- reset current image history
  -- start with a well-defined state
  -- copy xmp file (with 'empty' history stack)
  GuiAction('lib/history', 0, 'reset', '', 1.0)
  xmpModified = CopyXmpFile(xmpFile, image.path, image.filename, '_0_Reset', xmpModified)

  -- ====================================
  -- perform default settings
  -- copy xmp file (with 'default' history stack)
  LogMajorMax = 1
  LogMajorNr = 1
  LogCurrentStep = ''
  EnableDefaultSteps()
  ProcessWorkflowSteps()
  xmpModified = CopyXmpFile(xmpFile, image.path, image.filename, '_0_Default', xmpModified)

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
    LogCurrentStep = ''
    ProcessWorkflowSteps()
    xmpModified = CopyXmpFile(xmpFile, image.path, image.filename, '_' .. comboBoxValue, xmpModified)
  end
  LogSummary()

  LogInfo(_("module test finished"))
end

-- TEST button: Special button, used to perform module tests.
-- This button should be disabled for general use of the script.
-- To enable it, create a file named 'TestFlag.txt' in the same
-- directory as this script file.

if (FileExists(ScriptFilePath() .. 'TestFlag.txt')) then
  ButtonModuleTest = WorkflowStepButton:new():new
      {
        Widget = dt.new_widget('button')
            {
              label = 'TEST',
              tooltip = _(wordwrap(
                "Execute module tests. Used during development and deployment. Enabled in darkroom view.")),

              clicked_callback = ModuleTest
            }
      }

  function ButtonModuleTest:InitDependingOnCurrentView()
    -- override base class function
    self.Widget.visible = (dt.gui.current_view() == dt.gui.views.darkroom)
  end

  ButtonModuleTestCustomCode = WorkflowStepButton:new():new
      {
        Widget = dt.new_widget('button')
            {
              label = _("Custom Code"),
              tooltip = _(wordwrap(
                "Execute code from TestCustomCode.lua: This file contains some custom debug code. It can be changed without restarting darktable. Just edit, save and execute it. You can use it to try some lua commands on the fly, e.g. dt.gui.action commands. Enabled in darkroom view.")),

              clicked_callback = function()
                local currentView = dt.gui.current_view()
                if (currentView ~= dt.gui.views.darkroom) then
                  LogScreen(_("module tests must be started from darkroom view"))
                  return
                end

                local fileName = ScriptFilePath() .. 'TestCustomCode.lua'

                if (not FileExists(fileName)) then
                  LogScreen(string.format(_("module test file not found: %s"), fileName))
                  return
                end

                LogInfo('Execute script ' .. quote(fileName))
                dofile(fileName)
              end
            }
      }

  function ButtonModuleTestCustomCode:InitDependingOnCurrentView()
    -- override base class function
    self.Widget.visible = (dt.gui.current_view() == dt.gui.views.darkroom)
  end

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
    dt.new_widget('label') { label = _("preparing manual steps"), selectable = false, ellipsize = 'start', halign =
    'start' },
    dt.new_widget('box') {
      orientation = 'horizontal',

      -- buttons to simplify some manual steps
      ButtonEnableRotateAndPerspective.Widget,
      ButtonEnableCrop.Widget,
      ButtonMidToneExposure.Widget,
    },

    dt.new_widget('label') { label = '' },
    dt.new_widget('label') { label = _("select and perform automatic steps"), selectable = false, ellipsize = 'start', halign =
    'start' },
    dt.new_widget('box') {
      orientation = 'horizontal',

      -- buttons to start image processing and to set default values
      ButtonRunSelectedSteps.Widget,
      ButtonEnableDefaultSteps.Widget,
      ButtonDisableAllSteps.Widget
    },

    dt.new_widget('label') { label = '' },
  }

  -- TEST button: Special buttons, used to perform module tests.
  if (ButtonModuleTest) then
    LogInfo(_("insert test button widget"))
    table.insert(widgets,
      dt.new_widget('box')
      {
        orientation = 'horizontal',
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
        reset_callback = EnableDefaultSteps,
        table.unpack(GetWidgets()),
      },

      nil, -- view_enter
      nil  -- view_leave
    )

    Env.InstallModuleDone = true
  end
end

local function InitAllControlsDependingOnCurrentView()
  for i, step in ipairs(WorkflowSteps) do
    step:InitDependingOnCurrentView()
  end

  for i, button in ipairs(WorkflowButtons) do
    button:InitDependingOnCurrentView()
  end
end

-- event to handle changes from darkroom to lighttable view
-- some comboboxes or buttons need a special handling
-- see base class overrides for details
local function ViewChangedEvent(event, old_view, new_view)
  LogInfo(string.format(_("view changed to %s"), new_view.name))

  if ((new_view == dt.gui.views.lighttable) and (old_view == dt.gui.views.darkroom)) then
    InstallModuleRegisterLib()
  end

  InitAllControlsDependingOnCurrentView()
end

-- main entry function to install the module at startup
local function InstallInitialWorkflowModule()
  LogInfo(_("create widget in lighttable and darkroom panels"))

  -- initialize workflow steps
  for i, step in ipairs(WorkflowSteps) do
    step:Init()
  end

  -- get current settings as saved in darktable preferences
  for i, step in ipairs(WorkflowSteps) do
    step:ReadPreferenceValue()
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
