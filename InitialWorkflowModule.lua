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

---------------------------------------------------------------
-- add references to required modules

local dt = require 'darktable'
local du = require 'lib/dtutils'
local log = require 'lib/dtutils.log'
local ModuleName = 'InitialWorkflowModule'

---------------------------------------------------------------
-- Translations with gettext, see documentation for details:
-- https://docs.darktable.org/lua/stable/lua.api.manual/darktable/darktable.gettext/

-- use bash script GetTextExtractMessages.sh to update the .mo file

local gettext = dt.gettext

-- used to save translated words or sentences
local TranslationIndex = {}

-- used to get back the original text from translated text
-- used to address internal darktable API values
local ReverseTranslationIndex = {}

-- get path, where this script was started from
local function ScriptFilePath()
  local str = debug.getinfo(1, 'S').source:sub(2)
  return str:match('(.*[/\\])')
end

-- add quote marks
local function quote(text)
  return '"' .. text .. '"'
end

-- set locales directory
local pathSeparator = dt.configuration.running_os == 'windows' and '\\' or '/'
local localePath = ScriptFilePath() .. 'locale' .. pathSeparator
gettext.bindtextdomain(ModuleName, localePath)

-- return translation from given context
local function GetTranslation(context, msgid)
  if (msgid == nil or msgid == '') then
    return ''
  end

  -- get already known translation
  local translation = TranslationIndex[msgid]
  if (translation ~= nil) then
    return translation
  end

  -- call gettext to get previously unknown translation
  translation = gettext.dgettext(context, msgid)

  -- save translated words or sentences
  -- save the other way round
  TranslationIndex[msgid] = translation
  ReverseTranslationIndex[translation] = msgid

  return translation
end

-- return translation from local .po / .mo file
local function _(msgid)
  return GetTranslation(ModuleName, msgid)
end

-- return translation from darktable
local function _dt(msgid)
  return GetTranslation('darktable', msgid)
end

-- return concatenated translated words from darktable
-- darktable provides many translated text elements
-- combine these elements to new ones
local function _dtConcat(msgids)
  -- concat given message parts
  local message = ''
  for i, msgid in ipairs(msgids) do
    message = message .. msgid
  end

  -- get already known translation
  local translation = TranslationIndex[message]
  if (translation ~= nil) then
    return translation
  end

  -- concat previously unknown translation
  translation = ''
  for i, msgid in ipairs(msgids) do
    translation = translation .. _dt(msgid)
  end

  -- save translated words or sentences
  -- save the other way round
  TranslationIndex[message] = translation
  ReverseTranslationIndex[translation] = message

  return translation
end

-- return reverse translation, the other way round
local function GetReverseTranslation(text)
  local reverse = ReverseTranslationIndex[text]

  if (reverse ~= nil) then
    return reverse
  end

  return text
end

---------------------------------------------------------------
-- declare some variables to install the module

local Env =
{
  InstallModuleEventRegistered = false,
  InstallModuleDone = false,
}

local WidgetStack =
{
  Modules = 1,
  Settings = 2,
  Stack = dt.new_widget("stack") {},
}

---------------------------------------------------------------
-- some helper methods to log information messages

local indent = '. '

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
-- The script may dump a lot of log messages.
-- The summary collects some important (error) messages.
-- This function is executed at the end of each script run.
local function LogSummary()
  LogInfo('==============================')

  if (#LogSummaryMessages == 0) then
    LogInfo(_("OK - script run without errors"))
    LogScreen(_("initial workflow done"))
  else
    for index, message in ipairs(LogSummaryMessages) do
      LogInfo(message)
      LogScreen(_(message))
    end
  end

  LogInfo(_("initial workflow done"))
  LogInfo('==============================')
end

---------------------------------------------------------------
-- some helper functions

function ThreadSleep(milliseconds)
  -- LogInfo(indent .. string.format(_("wait for %d ms. (config = %s ms * %s)"), milliseconds, StepTimeout:Value(), milliseconds / StepTimeout:Value()))
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

-- check Darktable API version
-- new API of DT 4.2 is needed to use pixelpipe-processing-complete event
local apiCheck, err = pcall(function() du.check_min_api_version('9.0.0', ModuleName) end)
if (apiCheck) then
  LogInfo(string.format(_("darktable version with appropriate lua API detected: %s"), 'dt' .. dt.configuration.version))
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
  LogInfo(string.format(_("number of %d preference keys retrieved"), #keys))
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
    _dt("scene-referred (filmic)"),
    _dt("scene-referred (sigmoid)"),
    _dt("modern")
  }

  local workflow

  if CheckDarktable42() then
    -- use old dt 4.2 preference setting
    workflow = dt.preferences.read('darktable', 'plugins/darkroom/chromatic-adaptation', 'string')
  else
    -- use new dt 4.4 preference setting
    workflow = dt.preferences.read('darktable', 'plugins/darkroom/workflow', 'string')
  end

  return contains(modernWorkflows, _(workflow))
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
  -- LogInfo(indent .. string.format(_("received event %s"), self.EventType))
end

-- execute embedded function and wait for given EventType
function WaitForEventBase:Do(embeddedFunction)
  -- register event
  self:EventReceivedFlagReset()

  dt.destroy_event(self.ModuleName, self.EventType)
  dt.register_event(self.ModuleName, self.EventType, self.EventReceivedFunction)

  -- LogInfo(indent .. string.format(_("wait for event %s"), self.EventType))

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
      local timeoutMessage = string.format(
        _("timeout after %d ms waiting for event %s - increase timeout setting and try again"), durationMax, self
        .EventType)
      LogInfo(timeoutMessage)
      LogSummaryMessage(timeoutMessage)
      break
    end
  end

  -- unregister event
  dt.destroy_event(self.ModuleName, self.EventType)
  self:EventReceivedFlagReset()
end

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

-- wait for image loaded event
WaitForImageLoaded = WaitForEventBase:new():new
    {
      EventType = 'darkroom-image-loaded'
    }

-- wait for image loaded event and reload it, if necessary.
-- 'clean' flag indicates, if the load was clean (got pixel pipe locks) or not.
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

-- convert given number to string
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
local function convertGuiActionValueToBoolean(value)
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

---------------------------------------------------------------
-- helper functions to access darktable feature via user interface

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
  if (convertGuiActionValueToBoolean(buttonState)) then
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
  WidgetBasic = nil,
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
  LogInfo(string.format(_("selection = %s - %s"), self.WidgetBasic.value, self.Widget.value))
end

-- show given darkroom module
function WorkflowStep:ShowDarkroomModule(moduleName)
  -- check if the module is already displayed
  LogInfo(string.format(_("show module if not visible: %s"), moduleName))
  local visible = GuiActionGetValue(moduleName, 'show')
  if (not convertGuiActionValueToBoolean(visible)) then
    dt.gui.panel_show('DT_UI_PANEL_RIGHT')
    ThreadSleep(StepTimeout:Value() / 2)
    GuiActionWithoutEvent(moduleName, 0, 'show', '', 1.0)
  else
    LogInfo(indent .. _("module is already visible, nothing to do"))
  end
end

-- hide given darkroom module
function WorkflowStep:HideDarkroomModule(moduleName)
  -- check if the module is already hidden
  LogInfo(string.format(_("hide module if visible: %s"), moduleName))
  local visible = GuiActionGetValue(moduleName, 'show')
  if (convertGuiActionValueToBoolean(visible)) then
    GuiActionWithoutEvent(moduleName, 0, 'show', '', 1.0)
  else
    LogInfo(indent .. _("module is already hidden, nothing to do"))
  end
end

-- enable given darkroom module
function WorkflowStep:EnableDarkroomModule(moduleName)
  -- check if the module is already activated
  LogInfo(string.format(_("enable module if disabled: %s"), moduleName))
  local status = GuiActionGetValue(moduleName, 'enable')
  if (not convertGuiActionValueToBoolean(status)) then
    GuiAction(moduleName, 0, 'enable', '', 1.0)
  else
    LogInfo(indent .. _("module is already enabled, nothing to do"))
  end

  if (StepShowModulesDuringExecution.Widget.value == _dt("yes")) then
    self:ShowDarkroomModule(moduleName)
  end
end

-- disable given darkroom module
function WorkflowStep:DisableDarkroomModule(moduleName)
  -- check if the module is already activated
  LogInfo(string.format(_("disable module if enabled: %s"), moduleName))
  local status = GuiActionGetValue(moduleName, 'enable')
  if (convertGuiActionValueToBoolean(status)) then
    GuiAction(moduleName, 0, 'enable', '', 1.0)
  else
    LogInfo(indent .. _("module is already disabled, nothing to do"))
  end
end

-- reset given darkroom module
function WorkflowStep:ResetDarkroomModule(moduleName)
  LogInfo(_dt("reset parameters") .. ' (' .. moduleName .. ')')
  GuiAction(moduleName, 0, 'reset', '', 1.0)
end

-- handle view changed event (lighttable / darkroom view)
-- some comboboxes or buttons need a special handling
function WorkflowStep:InitDependingOnCurrentView()
  -- do nothing by default
end

---------------------------------------------------------------
-- base class of workflow steps with ComboBox widget
WorkflowStepConfiguration = WorkflowStep:new():new
    {
      OperationNameInternal = nil,
      WidgetStackValue = nil,
      ConfigurationValues = nil,
      WidgetUnchangedStepConfigurationValue = nil,
      WidgetDefaultStepConfiguationValue = nil,
    }

-- create default basic widget of most workflow steps
function WorkflowStepConfiguration:CreateDefaultBasicWidget()
  self.WidgetBasicDefaultValue = 4

  self.BasicValues = { _("default"), _("ignore"), _("enable"), _("reset"), _("disable") }

  self.WidgetBasic = dt.new_widget('combobox')
      {
        changed_callback = function(widget)
          local changedStep = GetWorkflowStep(widget)
          if (changedStep ~= nil) then
            if (changedStep.WidgetBasic.value == _("default")) then
              changedStep:EnableDefaultBasicConfiguation()
            end
          end
          ComboBoxChangedCallback(widget)
        end,

        label = ' ',
        tooltip = wordwrap(self.Label .. ' ' .. _(
          "basic setting: a) Select default value. b) Ignore this step / module and do nothing at all. c) Enable corresponding module and set selected module configuration. d) Reset the module and set selected module configuration. e) Disable module and keep it unchanged.")),
        table.unpack(self.BasicValues)
      }
end

-- create label widget
function WorkflowStepConfiguration:CreateLabelWidget()
  self.WidgetLabel = dt.new_widget('combobox')
      {
        label = self.Label,
        tooltip = self:GetLabelAndTooltip()
      }
end

-- create simple basic widget of some workflow steps
function WorkflowStepConfiguration:CreateSimpleBasicWidget()
  self.WidgetBasicDefaultValue = 2

  self.BasicValues = { _("ignore"), _("enable") }

  self.WidgetBasic = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = ' ',
        tooltip = wordwrap(self.Label .. ' ' .. _("basic setting: Ignore this module or do corresponding configuration.")),
        table.unpack(self.BasicValues)
      }
end

-- create empty invisible basic widget
function WorkflowStepConfiguration:CreateEmptyBasicWidget()
  self.WidgetBasicDefaultValue = 1

  self.BasicValues = { '' }

  self.WidgetBasic = dt.new_widget('combobox')
      {
        label = ' ',
        table.unpack(self.BasicValues)
      }
end

-- evaluate basic widget, common for most workflow steps
function WorkflowStepConfiguration:RunBasicWidget()
  local basic = self.WidgetBasic.value
  if (basic == '') then
    return true
  end

  if (basic == _("ignore")) then
    return false
  end

  self:LogStepMessage()

  if (basic == _("disable")) then
    self:DisableDarkroomModule(self:OperationPath())
    return false
  end

  if (basic == _("enable")) then
    self:EnableDarkroomModule(self:OperationPath())
    return true
  end

  if (basic == _("reset")) then
    self:EnableDarkroomModule(self:OperationPath())
    self:ResetDarkroomModule(self:OperationPath())
    return true
  end

  return true
end

-- evaluate basic widget, common for some workflow steps
function WorkflowStepConfiguration:RunSimpleBasicWidget()
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
      self:EnableDarkroomModule(self:OperationPath())
    end
    return true
  end

  return true
end

-- choose default step setting
function WorkflowStepConfiguration:EnableDefaultStepConfiguation()
  self.Widget.value = self.WidgetDefaultStepConfiguationValue
end

-- choose default basic setting
function WorkflowStepConfiguration:EnableDefaultBasicConfiguation()
  self.WidgetBasic.value = self.WidgetBasicDefaultValue
end

-- returns internal operation name like 'colorbalancergb' or 'atrous'
function WorkflowStepConfiguration:OperationName()
  return self.OperationNameInternal
end

-- returns operation path like 'iop/colorbalancergb'
function WorkflowStepConfiguration:OperationPath()
  return 'iop/' .. self:OperationName()
end

local PreferencePresetName = "Current"
local PreferencePrefixBasic = "Basic"
local PreferencePrefixConfiguration = "Config"

-- save current selections of this workflow step
-- used to restore settings after starting darktable
function WorkflowStepConfiguration:SavePreferenceValue()
  -- check, if there are any changes
  -- preferences are saved with english names and values
  -- user interfase uses translated names and values

  -- save any changes of the configuration combobox value
  local prefix = PreferencePresetName .. ":" .. PreferencePrefixConfiguration .. ":"
  local preferenceName = prefix .. GetReverseTranslation(self.Label)
  local preferenceValue = dt.preferences.read(ModuleName, preferenceName, 'string')
  local configurationValue = GetReverseTranslation(self.Widget.value)

  if (preferenceValue ~= configurationValue) then
    dt.preferences.write(ModuleName, preferenceName, 'string', configurationValue)
  end

  -- save any changes of the basic combobox value
  local prefixBasic = PreferencePresetName .. ":" .. PreferencePrefixBasic .. ":"
  local preferenceBasicName = prefixBasic .. GetReverseTranslation(self.Label)
  local preferenceBasicValue = dt.preferences.read(ModuleName, preferenceBasicName, 'string')
  local basicValue = GetReverseTranslation(self.WidgetBasic.value)

  if (preferenceBasicValue ~= basicValue) then
    dt.preferences.write(ModuleName, preferenceBasicName, 'string', basicValue)
  end
end

-- read saved selection value from darktable preferences
-- used to restore settings after starting darktable
function WorkflowStepConfiguration:ReadPreferenceConfigurationValue()
  -- preferences are saved with english names and values
  -- user intercase uses translated names and values
  local prefix = PreferencePresetName .. ":" .. PreferencePrefixConfiguration .. ":"
  local preferenceName = prefix .. GetReverseTranslation(self.Label)
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
function WorkflowStepConfiguration:SetWidgetBasicValue(value)
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
function WorkflowStepConfiguration:ReadPreferenceBasicValue()
  -- preferences are saved separately for each user interface language
  -- user intercase uses translated names and values
  local prefixBasic = PreferencePresetName .. ":" .. PreferencePrefixBasic .. ":"
  local preferenceBasicName = prefixBasic .. GetReverseTranslation(self.Label)
  local preferenceBasicValue = _(dt.preferences.read(ModuleName, preferenceBasicName, 'string'))
  self:SetWidgetBasicValue(preferenceBasicValue)
end

-- combobox selection is returned as negative index value
-- convert negative index value to combobox string value
-- consider "unchanged" value: + 1
function WorkflowStepConfiguration:GetConfigurationValueFromSelectionIndex(index)
  return self.ConfigurationValues[(-index) + 1]
end

-- concat widget label and tooltip
function WorkflowStepConfiguration:GetLabelAndTooltip()
  return wordwrap(self.Label .. ': ' .. self.Tooltip)
end

-- called from callback function within a 'foreign context'
-- we have to determine the button object or workflow step first
function GetWorkflowItem(widget, table)
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

---------------------------------------------------------------

StepCompressHistoryStack = WorkflowStepConfiguration:new():new
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

table.insert(WorkflowSteps, StepCompressHistoryStack)

function StepCompressHistoryStack:Init()
  self:CreateLabelWidget()
  self:CreateEmptyBasicWidget()

  self.ConfigurationValues = { _dt("no"), _dt("yes") }
  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
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
    GuiAction('lib/history/compress history stack', 0, '', '', 1.0)
  end
end

---------------------------------------------------------------

StepDynamicRangeSceneToDisplay = WorkflowStepConfiguration:new():new
    {
      -- this step refers to different modules
      OperationNameInternal = 'Filmic or Sigmoid',
      WidgetStackValue = WidgetStack.Modules,
      WidgetUnchangedStepConfigurationValue = 1,
      WidgetDefaultStepConfiguationValue = 3,
      Label = _dtConcat({ "filmic rgb", ' / ', "sigmoid" }),
      Tooltip = _(
        "Use Filmic or Sigmoid to expand or contract the dynamic range of the scene to fit the dynamic range of the display. Auto tune filmic levels of black + white relative exposure. Or use Sigmoid with one of its presets. Use only one of Filmic, Sigmoid or Basecurve, this module disables the others.")
    }

table.insert(WorkflowSteps, StepDynamicRangeSceneToDisplay)

function StepDynamicRangeSceneToDisplay:Init()
  self:CreateLabelWidget()
  self:CreateDefaultBasicWidget()

  self.filmicAutoTuneLevels = _dtConcat({ "filmic", ' ', "auto tune levels" })
  self.filmicHighlightReconstruction = _dtConcat({ "filmic", ' + ', "highlight reconstruction" })
  self.sigmoidColorPerChannel = _dtConcat({ "sigmoid", ' ', "per channel" })
  self.sigmoidColorRgbRatio = _dtConcat({ "sigmoid", ' ', "RGB ratio" })
  self.sigmoidAces100Preset = _dtConcat({ "sigmoid", ' ', "ACES 100-nit like" })

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
        changed_callback = ComboBoxChangedCallback,
        label = ' ', -- use separate label widget
        tooltip = self:GetLabelAndTooltip(),
        table.unpack(self.ConfigurationValues)
      }
end

function StepDynamicRangeSceneToDisplay:FilmicSelected()
  return contains(
    { self.filmicAutoTuneLevels,
      self.filmicHighlightReconstruction
    }, self.Widget.value)
end

function StepDynamicRangeSceneToDisplay:SigmoidSelected()
  return contains(
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
    self:DisableDarkroomModule(self:OperationPath())
    return false
  end

  if (self:FilmicSelected()) then
    self:DisableDarkroomModule('iop/sigmoid')
    self:DisableDarkroomModule('iop/basecurve')
  end

  if (self:SigmoidSelected()) then
    self:DisableDarkroomModule('iop/filmicrgb')
    self:DisableDarkroomModule('iop/basecurve')
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
    GuiActionButtonOffOn('iop/filmicrgb/auto tune levels')

    if (selection == self.filmicHighlightReconstruction) then
      local checkbox = GuiActionGetValue('iop/filmicrgb/enable highlight reconstruction', '')
      if (checkbox == 0) then
        GuiAction('iop/filmicrgb/enable highlight reconstruction', 0, '', 'on', 1.0)
      else
        LogInfo(indent .. _("checkbox already selected, nothing to do"))
      end
    end
  end

  if (self:SigmoidSelected()) then
    local colorProcessingValues =
    {
      _dt("per channel"),
      _dt("RGB ratio")
    }

    local currentSelectionIndex = GuiActionGetValue('iop/sigmoid/color processing', 'selection')
    local currentSelection = colorProcessingValues[-currentSelectionIndex]

    if (selection == self.sigmoidColorPerChannel) then
      if (_dt("per channel") ~= currentSelection) then
        LogInfo(indent .. string.format(_("current color processing = %s"), quote(currentSelection)))
        GuiAction('iop/sigmoid/color processing', 0, 'selection', 'item:per channel', 1.0)
      else
        LogInfo(indent .. string.format(_("nothing to do, color processing already = %s"), quote(currentSelection)))
      end
    end

    if (selection == self.sigmoidColorRgbRatio) then
      if (_dt("RGB ratio") ~= currentSelection) then
        LogInfo(indent .. string.format(_("current color processing = %s"), quote(currentSelection)))
        if (CheckDarktable42()) then
          GuiAction('iop/sigmoid/color processing', 0, 'selection', 'item:rgb ratio', 1.0)
        else
          GuiAction('iop/sigmoid/color processing', 0, 'selection', 'item:RGB ratio', 1.0)
        end
      else
        LogInfo(indent .. string.format(_("nothing to do, color processing already = %s"), quote(currentSelection)))
      end
    end

    if (selection == self.sigmoidAces100Preset) then
      GuiActionButtonOffOn('iop/sigmoid/preset/' .. _dt("ACES 100-nit like"))
    end
  end
end

---------------------------------------------------------------

StepColorBalanceGlobalSaturation = WorkflowStepConfiguration:new():new
    {
      OperationNameInternal = 'colorbalancergb',
      WidgetStackValue = WidgetStack.Modules,
      WidgetUnchangedStepConfigurationValue = 1,
      WidgetDefaultStepConfiguationValue = 7,
      Label = _dtConcat({ "color balance rgb", ' ', "saturation" }),
      Tooltip = _("Adjust global saturation in color balance rgb module.")
    }

table.insert(WorkflowSteps, StepColorBalanceGlobalSaturation)

function StepColorBalanceGlobalSaturation:Init()
  self:CreateLabelWidget()
  self:CreateSimpleBasicWidget()

  self.ConfigurationValues =
  {
    _("unchanged"), 0, 5, 10, 15, 20, 25, 30, 35
  }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
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

  GuiActionSetValue('iop/colorbalancergb/global saturation', 0, 'value', 'set', selection / 100)
end

---------------------------------------------------------------

StepColorBalanceGlobalChroma = WorkflowStepConfiguration:new():new
    {
      OperationNameInternal = 'colorbalancergb',
      WidgetStackValue = WidgetStack.Modules,
      WidgetUnchangedStepConfigurationValue = 1,
      WidgetDefaultStepConfiguationValue = 5,
      Label = _dtConcat({ "color balance rgb", ' ', "chroma" }),
      Tooltip = _("Adjust global chroma in color balance rgb module.")
    }

table.insert(WorkflowSteps, StepColorBalanceGlobalChroma)

function StepColorBalanceGlobalChroma:Init()
  self:CreateLabelWidget()
  self:CreateSimpleBasicWidget()

  self.ConfigurationValues =
  {
    _("unchanged"), 0, 5, 10, 15, 20, 25, 30, 35
  }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
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

  GuiActionSetValue('iop/colorbalancergb/global chroma', 0, 'value', 'set', selection / 100)
end

---------------------------------------------------------------

StepColorBalanceRGBMasks = WorkflowStepConfiguration:new():new
    {
      OperationNameInternal = 'colorbalancergb',
      WidgetStackValue = WidgetStack.Modules,
      WidgetUnchangedStepConfigurationValue = 1,
      WidgetDefaultStepConfiguationValue = 2,
      Label = _dtConcat({ "color balance rgb", ' ', "masks" }),
      Tooltip = _(
        "Set auto pickers of the module mask and peak white and gray luminance value to normalize the power setting in the 4 ways tab.")
    }

table.insert(WorkflowSteps, StepColorBalanceRGBMasks)

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
        changed_callback = ComboBoxChangedCallback,
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
    GuiActionButtonOffOn('iop/colorbalancergb/white fulcrum')
    GuiActionButtonOffOn('iop/colorbalancergb/contrast gray fulcrum')
  end
end

---------------------------------------------------------------

StepColorBalanceRGB = WorkflowStepConfiguration:new():new
    {
      OperationNameInternal = 'colorbalancergb',
      WidgetStackValue = WidgetStack.Modules,
      WidgetUnchangedStepConfigurationValue = 1,
      WidgetDefaultStepConfiguationValue = 5,
      Label = _dt("color balance rgb"),
      Tooltip = _("Choose a predefined preset for your color-grading.")
    }

table.insert(WorkflowSteps, StepColorBalanceRGB)

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
        changed_callback = ComboBoxChangedCallback,
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

  GuiActionButtonOffOn('iop/colorbalancergb/preset/' .. selection)
end

---------------------------------------------------------------

StepContrastEqualizer = WorkflowStepConfiguration:new():new
    {
      OperationNameInternal = 'atrous',
      WidgetStackValue = WidgetStack.Modules,
      WidgetUnchangedStepConfigurationValue = 1,
      WidgetDefaultStepConfiguationValue = 2,
      Label = _dt("contrast equalizer"),
      Tooltip = _(
        "Adjust luminance and chroma contrast. Apply choosen preset (clarity or denoise & sharpen). Choose different values to adjust the strength of the effect.")
    }

table.insert(WorkflowSteps, StepContrastEqualizer)

function StepContrastEqualizer:Init()
  self:CreateLabelWidget()
  self:CreateDefaultBasicWidget()

  self.clarity010 = _dtConcat({ "clarity", ', ', "mix", ' ', "0.10" })
  self.clarity025 = _dtConcat({ "clarity", ', ', "mix", ' ', "0.25" })
  self.clarity050 = _dtConcat({ "clarity", ', ', "mix", ' ', "0.50" })

  self.denoise010 = _dtConcat({ "denoise & sharpen", ', ', "mix", ' ', "0.10" })
  self.denoise025 = _dtConcat({ "denoise & sharpen", ', ', "mix", ' ', "0.25" })
  self.denoise050 = _dtConcat({ "denoise & sharpen", ', ', "mix", ' ', "0.50" })

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
        changed_callback = ComboBoxChangedCallback,
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
    GuiActionButtonOffOn('iop/atrous/preset/' .. _dt("clarity"))
    GuiActionSetValue('iop/atrous/mix', 0, 'value', 'set', 0.10)
    --
  elseif (selection == self.clarity025) then
    GuiActionButtonOffOn('iop/atrous/preset/' .. _dt("clarity"))
    GuiActionSetValue('iop/atrous/mix', 0, 'value', 'set', 0.25)
    --
  elseif (selection == self.clarity050) then
    GuiActionButtonOffOn('iop/atrous/preset/' .. _dt("clarity"))
    GuiActionSetValue('iop/atrous/mix', 0, 'value', 'set', 0.5)
    --
  elseif (selection == self.denoise010) then
    GuiActionButtonOffOn('iop/atrous/preset/' .. _dt("denoise & sharpen"))
    GuiActionSetValue('iop/atrous/mix', 0, 'value', 'set', 0.10)
    --
  elseif (selection == self.denoise025) then
    GuiActionButtonOffOn('iop/atrous/preset/' .. _dt("denoise & sharpen"))
    GuiActionSetValue('iop/atrous/mix', 0, 'value', 'set', 0.25)
    --
  elseif (selection == self.denoise050) then
    GuiActionButtonOffOn('iop/atrous/preset/' .. _dt("denoise & sharpen"))
    GuiActionSetValue('iop/atrous/mix', 0, 'value', 'set', 0.5)
  end
end

---------------------------------------------------------------

StepDiffuseOrSharpen = WorkflowStepConfiguration:new():new
    {
      OperationNameInternal = 'diffuse',
      WidgetStackValue = WidgetStack.Modules,
      WidgetUnchangedStepConfigurationValue = 1,
      WidgetDefaultStepConfiguationValue = 8,
      Label = _dt("diffuse or sharpen"),
      Tooltip = _(
        "Adjust luminance and chroma contrast. Apply choosen preset (clarity or denoise & sharpen). Choose different values to adjust the strength of the effect.")
    }

table.insert(WorkflowSteps, StepDiffuseOrSharpen)

function StepDiffuseOrSharpen:Init()
  self:CreateLabelWidget()
  self:CreateDefaultBasicWidget()

  -- workaround for dt4.2
  if (CheckDarktable42()) then
    self.ConfigurationValues =
    {
      _("unchanged"),
      _dt("dehaze"),
      _dt("denoise: coarse"),
      _dt("denoise: fine"),
      _dt("denoise: medium"),
      _dt("lens deblur: medium"),
      _dt("add local contrast"),
      _dt("sharpen demosaicing (AA filter)"),
      _dt("fast sharpness")
    }
  else
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
  end

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
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

  GuiAction('iop/diffuse/preset/' .. _dt(selection), 0, '', '', 1.0)
end

---------------------------------------------------------------

StepToneEqualizerMask = WorkflowStepConfiguration:new():new
    {
      OperationNameInternal = 'toneequal',
      WidgetStackValue = WidgetStack.Modules,
      WidgetUnchangedStepConfigurationValue = 1,
      WidgetDefaultStepConfiguationValue = 4,
      Label = _dtConcat({ "tone equalizer", ' ', "masking" }),
      Tooltip = _(
        "Apply automatic mask contrast and exposure compensation. Auto adjust the contrast and average exposure.")
    }

table.insert(WorkflowSteps, StepToneEqualizerMask)

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
        changed_callback = ComboBoxChangedCallback,
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
  self:ShowDarkroomModule('iop/toneequal')
  GuiActionWithoutEvent('iop/toneequal/page', 0, 'masking', '', 1.0)

  if (selection == _("mask exposure compensation")) then
    GuiAction('iop/toneequal/mask exposure compensation', 0, 'button', 'toggle', 1.0)
    ThreadSleep(StepTimeout:Value())
    --
  elseif (selection == _("mask contrast compensation")) then
    GuiAction('iop/toneequal/mask contrast compensation', 0, 'button', 'toggle', 1.0)
    ThreadSleep(StepTimeout:Value())
    --
  elseif (selection == _("exposure & contrast comp.")) then
    GuiAction('iop/toneequal/mask exposure compensation', 0, 'button', 'toggle', 1.0)
    ThreadSleep(StepTimeout:Value())
    GuiAction('iop/toneequal/mask contrast compensation', 0, 'button', 'toggle', 1.0)
    ThreadSleep(StepTimeout:Value())
  end

  -- workaround: show this module, otherwise the buttons will not be pressed
  self:HideDarkroomModule('iop/toneequal')
  --
end

---------------------------------------------------------------

StepToneEqualizer = WorkflowStepConfiguration:new():new
    {
      OperationNameInternal = 'toneequal',
      WidgetStackValue = WidgetStack.Modules,
      WidgetUnchangedStepConfigurationValue = 1,
      WidgetDefaultStepConfiguationValue = 1,
      Label = _dt("tone equalizer"),
      Tooltip = _(
        "Use preset to compress shadows and highlights with exposure-independent guided filter (eigf) (soft, medium or strong).")
    }

table.insert(WorkflowSteps, StepToneEqualizer)

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
        changed_callback = ComboBoxChangedCallback,
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

  if (CheckDarktable42()) then
    -- workaround to deal with bug in dt 4.2.x
    -- dt 4.2 uses special characters
    -- darktable 4.4 uses some capital letters
    -- DT42: prefix is removed during script run
    if (selection == _("compress shadows-highlights (eigf): medium")) then
      GuiActionButtonOffOn('iop/toneequal/preset/' ..
        _("DT42:compress shadows-highlights (eigf): medium"):gsub("DT42:", ""))
    elseif (selection == _("compress shadows-highlights (eigf): soft")) then
      GuiActionButtonOffOn('iop/toneequal/preset/' .. _("DT42:compress shadows-highlights (eigf): soft"):gsub("DT42:",
        ""))
    elseif (selection == _("compress shadows-highlights (eigf): strong")) then
      GuiActionButtonOffOn('iop/toneequal/preset/' ..
        _("DT42:compress shadows-highlights (eigf): strong"):gsub("DT42:", ""))
    end
  else
    -- dt 4.4
    GuiActionButtonOffOn('iop/toneequal/preset/' .. selection)
  end
end

---------------------------------------------------------------

StepExposureCorrection = WorkflowStepConfiguration:new():new
    {
      OperationNameInternal = 'exposure',
      WidgetStackValue = WidgetStack.Modules,
      WidgetUnchangedStepConfigurationValue = 1,
      WidgetDefaultStepConfiguationValue = 3,
      Label = _dt("exposure"),
      Tooltip = _(
        "Automatically adjust the exposure correction. Remove the camera exposure bias, useful if you exposed the image to the right.")
    }

table.insert(WorkflowSteps, StepExposureCorrection)

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
        changed_callback = ComboBoxChangedCallback,
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

  GuiActionButtonOffOn('iop/exposure/exposure')

  if (selection == _("adjust & compensate bias")) then
    local checkbox = GuiActionGetValue('iop/exposure/compensate exposure bias', '')
    if (checkbox == 0) then
      GuiAction('iop/exposure/compensate exposure bias', 0, '', 'on', 1.0)
    else
      LogInfo(indent .. _("checkbox already selected, nothing to do"))
    end
  end
end

---------------------------------------------------------------

StepLensCorrection = WorkflowStepConfiguration:new():new
    {
      OperationNameInternal = 'lens',
      WidgetStackValue = WidgetStack.Modules,
      WidgetUnchangedStepConfigurationValue = 1,
      WidgetDefaultStepConfiguationValue = 2,
      Label = _dt("lens correction"),
      Tooltip = _("Enable and reset lens correction module."),
    }

table.insert(WorkflowSteps, StepLensCorrection)

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
        changed_callback = ComboBoxChangedCallback,
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
    -- 4.2.1 de: lensfun Datenbank
    -- 4.2.1 en: lensfun database
    -- 4.4.0 de: Lensfun database
    -- 4.4.0 en: Lensfun database

    local lensCorrectionValues =
    {
      _dt("embedded metadata"),
      self.lensfunSelection
    }

    local currentSelectionIndex = GuiActionGetValue('iop/lens/correction method', 'selection')
    local currentSelection = lensCorrectionValues[-currentSelectionIndex]

    if (self.lensfunSelection ~= currentSelection) then
      LogInfo(indent .. string.format(_("current correction method = %s"), quote(currentSelection)))
      if (CheckDarktable42()) then
        GuiAction('iop/lens/correction method', 0, 'selection', 'item:lensfun database', 1.0)
      else
        GuiAction('iop/lens/correction method', 0, 'selection', 'item:Lensfun database', 1.0)
      end
    else
      LogInfo(indent .. string.format(_("nothing to do, correction method already = %s"), quote(currentSelection)))
    end
  end
end

---------------------------------------------------------------

StepDenoiseProfiled = WorkflowStepConfiguration:new():new
    {
      OperationNameInternal = 'denoiseprofile',
      WidgetStackValue = WidgetStack.Modules,
      WidgetUnchangedStepConfigurationValue = 1,
      WidgetDefaultStepConfiguationValue = 1,
      Label = _dt("denoise (profiled)"),
      Tooltip = _(
        "Enable denoise (profiled) module. There is nothing to configure, just enable or reset this module.")
    }

table.insert(WorkflowSteps, StepDenoiseProfiled)

function StepDenoiseProfiled:Init()
  self:CreateLabelWidget()
  self:CreateDefaultBasicWidget()

  self.ConfigurationValues = { _("unchanged") }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
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

StepChromaticAberrations = WorkflowStepConfiguration:new():new
    {
      OperationNameInternal = 'cacorrect',
      WidgetStackValue = WidgetStack.Modules,
      WidgetUnchangedStepConfigurationValue = 1,
      WidgetDefaultStepConfiguationValue = 2,
      Label = _dt("chromatic aberrations"),
      Tooltip = _(
        "Correct chromatic aberrations. Distinguish between Bayer sensor and other camera sensors. This operation uses the corresponding correction module and disables the other.")
    }

table.insert(WorkflowSteps, StepChromaticAberrations)

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
        changed_callback = ComboBoxChangedCallback,
        label = ' ', -- use separate label widget
        tooltip = self:GetLabelAndTooltip(),
        table.unpack(self.ConfigurationValues)
      }
end

function StepChromaticAberrations:BayerSensorSelected()
  return contains(
    { _("Bayer sensor")
    }, self.Widget.value)
end

function StepChromaticAberrations:OtherSensorSelected()
  return contains(
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
    self:DisableDarkroomModule(self:OperationPath())
    return false
  end

  -- disable other module than selected
  if (self:BayerSensorSelected()) then
    self:DisableDarkroomModule('iop/cacorrectrgb')
  end

  if (self:OtherSensorSelected()) then
    self:DisableDarkroomModule('iop/cacorrect')
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

StepColorCalibrationIlluminant = WorkflowStepConfiguration:new():new
    {
      OperationNameInternal = 'channelmixerrgb',
      WidgetStackValue = WidgetStack.Modules,
      WidgetUnchangedStepConfigurationValue = 1,

      -- see EnableDefaultStepConfiguation() override
      WidgetDefaultStepConfiguationValue = nil,
      Label = _dtConcat({ "color calibration", ' ', "illuminant" }),
      Tooltip = _(
        "Perform color space corrections in color calibration module. Select the illuminant. The type of illuminant assumed to have lit the scene. By default unchanged for the legacy workflow.")
    }

-- distinguish between modern and legacy workflow
-- keep value unchanged, if using legacy workflow
-- depends on darktable preference settings
function StepColorCalibrationIlluminant:EnableDefaultStepConfiguation()
  self.Widget.value = CheckDarktableModernWorkflowPreference() and 2 or 1
end

table.insert(WorkflowSteps, StepColorCalibrationIlluminant)

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
        changed_callback = ComboBoxChangedCallback,
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
  local adaptationSelectionIndex = GuiActionGetValue('iop/channelmixerrgb/adaptation', 'selection')
  local adaptationSelection = StepColorCalibrationAdaptation:GetConfigurationValueFromSelectionIndex(
    adaptationSelectionIndex)

  LogInfo(indent .. string.format(_("color calibration adaption = %s"), adaptationSelection))
  if (adaptationSelection == _dt("none (bypass)")) then
    LogInfo(indent .. _("illuminant cannot be set"))
    return
  else
    LogInfo(indent .. _("illuminant can be set"))
  end

  -- set illuminant

  local currentSelectionIndex = GuiActionGetValue('iop/channelmixerrgb/illuminant', 'selection')
  local currentSelection = self:GetConfigurationValueFromSelectionIndex(currentSelectionIndex)

  if (selection ~= currentSelection) then
    LogInfo(indent .. string.format(_("current illuminant = %s"), quote(currentSelection)))
    GuiAction('iop/channelmixerrgb/illuminant', 0, 'selection', 'item:' .. GetReverseTranslation(selection), 1.0)
  else
    LogInfo(indent .. string.format(_("nothing to do, illuminant already = %s"), quote(currentSelection)))
  end
end

---------------------------------------------------------------

StepColorCalibrationAdaptation = WorkflowStepConfiguration:new():new
    {
      OperationNameInternal = 'channelmixerrgb',
      WidgetStackValue = WidgetStack.Modules,
      WidgetUnchangedStepConfigurationValue = 1,
      WidgetDefaultStepConfiguationValue = 3,
      Label = _dtConcat({ "color calibration", ' ', "adaptation" }),
      Tooltip = _(
        "Perform color space corrections in color calibration module. Select the adaptation. The working color space in which the module will perform its chromatic adaptation transform and channel mixing.")
    }

table.insert(WorkflowSteps, StepColorCalibrationAdaptation)

-- combobox values see darktable typedef enum dt_adaptation_t

function StepColorCalibrationAdaptation:Init()
  self:CreateLabelWidget()
  self:CreateDefaultBasicWidget()

  self.ConfigurationValues =
  {
    _("unchanged"), -- additional value
    _dt("linear Bradford (ICC v4)"),
    _dt("CAT16 (CIECAM16)"),
    _dt("non-linear Bradford"),
    _dt("XYZ"),
    _dt("none (bypass)")
  }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
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

  local currentSelectionIndex = GuiActionGetValue('iop/channelmixerrgb/adaptation', 'selection')
  local currentSelection = self:GetConfigurationValueFromSelectionIndex(currentSelectionIndex)

  if (selection ~= currentSelection) then
    LogInfo(indent .. string.format(_("current adaptation = %s"), quote(currentSelection)))
    GuiAction('iop/channelmixerrgb/adaptation', 0, 'selection', 'item:' .. GetReverseTranslation(selection), 1.0)
  else
    LogInfo(indent .. string.format(_("nothing to do, adaptation already = %s"), quote(currentSelection)))
  end
end

---------------------------------------------------------------

StepHighlightReconstruction = WorkflowStepConfiguration:new():new
    {
      OperationNameInternal = 'highlights',
      WidgetStackValue = WidgetStack.Modules,
      WidgetUnchangedStepConfigurationValue = 1,
      WidgetDefaultStepConfiguationValue = 2,
      Label = _dt("highlight reconstruction"),
      Tooltip = _(
        "Reconstruct color information for clipped pixels. Select an appropriate reconstruction methods to reconstruct the missing data from unclipped channels and/or neighboring pixels.")
    }

-- we have to wait for a darktable bugfix (dt4.4)
-- do not add this step to the widget if you are using darktable 4.2
if (not CheckDarktable42()) then
  table.insert(WorkflowSteps, StepHighlightReconstruction)
end

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
        changed_callback = ComboBoxChangedCallback,
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

  local currentSelectionIndex = GuiActionGetValue('iop/highlights/method', 'selection')
  local currentSelection = self:GetConfigurationValueFromSelectionIndex(currentSelectionIndex)

  if (selection ~= currentSelection) then
    LogInfo(indent .. string.format(_("current value = %s"), quote(currentSelection)))
    GuiAction('iop/highlights/method', 0, 'selection', 'item:' .. GetReverseTranslation(selection), 1.0)
  else
    LogInfo(indent .. string.format(_("nothing to do, value already = %s"), quote(currentSelection)))
  end
end

---------------------------------------------------------------

StepWhiteBalance = WorkflowStepConfiguration:new():new
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
  self.Widget.value = CheckDarktableModernWorkflowPreference() and 6 or 1
end

table.insert(WorkflowSteps, StepWhiteBalance)

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
        changed_callback = ComboBoxChangedCallback,
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

  local currentSelectionIndex = GuiActionGetValue('iop/temperature/settings/settings', 'selection')
  local currentSelection = self:GetConfigurationValueFromSelectionIndex(currentSelectionIndex)

  if (selection ~= currentSelection) then
    LogInfo(indent .. string.format(_("current value = %s"), quote(currentSelection)))
    GuiAction('iop/temperature/settings/' .. GetReverseTranslation(selection), 0, '', '', 1.0)
  else
    LogInfo(indent .. string.format(_("nothing to do, value already = %s"), quote(currentSelection)))
  end
end

---------------------------------------------------------------

StepResetModuleHistory = WorkflowStepConfiguration:new():new
    {
      -- operation = nil: ignore this module during module reset
      OperationNameInternal = nil,
      WidgetStackValue = WidgetStack.Settings,
      WidgetUnchangedStepConfigurationValue = 1,
      WidgetDefaultStepConfiguationValue = 1,
      Label = _("discard complete history"),
      Tooltip = _("Reset all modules of the whole pixelpipe and discard complete history.")
    }

table.insert(WorkflowSteps, StepResetModuleHistory)

function StepResetModuleHistory:Init()
  self:CreateLabelWidget()
  self:CreateEmptyBasicWidget()

  self.ConfigurationValues =
  {
    _dt("no"), _dt("yes")
  }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
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
    GuiAction('lib/history', 0, 'reset', '', 1.0)
  end
end

---------------------------------------------------------------

StepShowModulesDuringExecution = WorkflowStepConfiguration:new():new
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

table.insert(WorkflowSteps, StepShowModulesDuringExecution)

function StepShowModulesDuringExecution:Init()
  self:CreateLabelWidget()
  self:CreateEmptyBasicWidget()

  self.ConfigurationValues = { _dt("no"), _dt("yes") }

  self.Widget = dt.new_widget('combobox')
      {
        changed_callback = ComboBoxChangedCallback,
        label = ' ', -- use separate label widget
        tooltip = self:GetLabelAndTooltip(),
        table.unpack(self.ConfigurationValues)
      }
end

function StepShowModulesDuringExecution:Run()
  -- do nothing...
end

---------------------------------------------------------------

StepTimeout = WorkflowStepConfiguration:new():new
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

table.insert(WorkflowSteps, StepTimeout)

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
        changed_callback = ComboBoxChangedCallback,
        label = ' ', -- use separate label widget
        tooltip = self:GetLabelAndTooltip(),
        table.unpack(self.ConfigurationValues)
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


-- stop running thumbnail creation
local function stop_job(job)
  job.valid = false
end

-- process all configured workflow steps
local function ProcessWorkflowSteps()
  LogInfo('==============================')
  LogInfo(_("process workflow steps"))

  -- create a progress bar
  local job = dt.gui.create_job("process workflow steps", true, stop_job)
  local workflowCanceled = false

  ThreadSleep(StepTimeout:Value())

  -- execute all workflow steps
  -- the order is from bottom to top, along the pixel pipeline.
  for i = 1, #WorkflowSteps do
    local step = WorkflowSteps[#WorkflowSteps + 1 - i]
    LogCurrentStep = step.Label

    LogScreen(step.Label) -- instead of dt.print()

    -- execute workflow step
    step:Run()

    -- sleep for a short moment to give stop_job callback function a chance to run
    dt.control.sleep(10)

    -- stop workflow if the cancel button of the progress bar is pressed
    workflowCanceled = not job.valid
    if workflowCanceled then
      LogSummaryMessage(_("workflow canceled"))
      break
    end

    -- stop workflow if darktable is shutting down
    if dt.control.ending then
      job.valid = false
      workflowCanceled = true
      LogSummaryMessage(_("workflow canceled - darktable shutting down"))
      break
    end

    -- update progress_bar
    job.percent = i / #WorkflowSteps
  end

  LogCurrentStep = ''
  ThreadSleep(StepTimeout:Value())

  if not workflowCanceled then
    job.valid = false
  end

  return workflowCanceled
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

    local workflowCanceled = ProcessWorkflowSteps()

    if workflowCanceled then
      break
    end
  end

  -- switch to lighttable view
  LogInfo(_("switch to lighttable view"))
  dt.gui.current_view(dt.gui.views.lighttable)
  dt.gui.selection(images)

  LogSummary()
end

---------------------------------------------------------------

-- base class of workflow steps with Button widget
WorkflowStepButton = WorkflowStep:new():new
    {
    }

---------------------------------------------------------------

ButtonRunSelectedSteps = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget('button')
          {
            label = _("run"),
            tooltip = wordwrap(_(
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

ButtonShowWidgetStackModules = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget('button')
          {
            label = _("show modules"),
            tooltip = wordwrap(_(
              "Show the subpage with the configuration of the modules.")),

            clicked_callback = function()
              WidgetStack.Stack.active = WidgetStack.Modules
              return
            end
          }
    }

table.insert(WorkflowButtons, ButtonShowWidgetStackModules)

---------------------------------------------------------------

ButtonShowWidgetStackSettings = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget('button')
          {
            label = _("show settings"),
            tooltip = wordwrap(_(
              "Show the subpage with common settings.")),

            clicked_callback = function()
              WidgetStack.Stack.active = WidgetStack.Settings
              return
            end
          }
    }

table.insert(WorkflowButtons, ButtonShowWidgetStackSettings)

---------------------------------------------------------------

ButtonEnableRotateAndPerspective = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget('button')
          {
            label = _dt("rotate and perspective"),
            tooltip = wordwrap(_(
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
            label = _dt("crop"),
            tooltip = wordwrap(_("Activate the module to crop the image. Enabled in darkroom view.")),

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
            label = _dt("exposure"),
            tooltip = wordwrap(_(
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

-- select default basic configuration for each step
-- called via module reset control
local function SetAllDefaultModuleConfigurations()
  for i, step in ipairs(WorkflowSteps) do
    if (step ~= StepTimeout) then
      step:EnableDefaultBasicConfiguation()
      step:EnableDefaultStepConfiguation()
    end
  end
end

---------------------------------------------------------------

-- MODULE TEST IMPLEMENTATION.

-- This section contains some functions to perform module tests.
-- The following functions are used during development and deployment.

local moduleTestImage
local moduleTestXmpFile
local moduleTestXmpModified
local moduleTestBasicSetting

-- ignore some basic configurations
local moduleTestIgnoreSteps =
{
  StepResetModuleHistory,
  StepTimeout
}

-- check, if file exists
function FileExists(filename)
  local f = io.open(filename, 'r')
  if f ~= nil then
    io.close(f)
    return true
  end
  return false
end

-- check, if file was modified
local function GetFileModified(fileName)
  local fileHandle = io.popen('stat -c %Y ' .. quote(fileName))
  if (fileHandle ~= nil) then
    return fileHandle:read()
  end
  return nil
end

-- wait until xmp file was written
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

-- copy xmp file to test result folder
local function CopyXmpFile(xmpFile, filePath, fileName, appendix, xmpModified)
  -- wait until xmp file was written
  ThreadSleep(StepTimeout:Value())
  local xmpModifiedNew = WaitForFileModified(xmpFile, xmpModified)

  -- copy xmp file to test result folder
  local xmpFileCopy = filePath .. '/TEST/' .. fileName .. appendix .. '.xmp'
  local xmpCopyCommand = 'cp ' .. quote(xmpFile) .. ' ' .. quote(xmpFileCopy)
  LogInfo(xmpCopyCommand)
  local ok = os.execute(xmpCopyCommand)

  return xmpModifiedNew
end

-- iterate over all workflow steps and combobox value settings
-- set different combinations of module settings
local function ModuleTestIterateConfigurationValues()
  -- get maximum number of combobox entries
  local configurationValuesMax = 1
  for i, step in ipairs(WorkflowSteps) do
    local count = #step.ConfigurationValues
    if (count > configurationValuesMax) then
      configurationValuesMax = count
    end
  end

  -- iterate over all selectable values
  for configurationValue = 1, configurationValuesMax do
    -- iterate over all configurations
    for i, step in ipairs(WorkflowSteps) do
      -- ignore some basic configurations
      if (not contains(moduleTestIgnoreSteps, step)) then
        -- iterate over configuration values
        if (configurationValue <= #step.ConfigurationValues) then
          step.Widget.value = configurationValue
        elseif (configurationValue == #step.ConfigurationValues + 1) then
          step:EnableDefaultStepConfiguation()
        else
          step.Widget.value = (configurationValue % #step.ConfigurationValues) + 1
        end
      end
    end

    -- perform configured settings
    -- copy xmp file with current settings to test result folder
    LogMajorMax = configurationValuesMax
    LogMajorNr = configurationValue
    LogCurrentStep = ''

    ProcessWorkflowSteps()

    moduleTestXmpModified = CopyXmpFile(moduleTestXmpFile, moduleTestImage.path, moduleTestImage.filename,
      '_' .. moduleTestBasicSetting .. '_' .. configurationValue, moduleTestXmpModified)
  end
end

-- called to perform module tests
local function ModuleTest()
  -- check darkroom view
  local currentView = dt.gui.current_view()
  if (currentView ~= dt.gui.views.darkroom) then
    LogScreen(_("module tests must be started from darkroom view"))
    return
  end

  -- prepare test execution
  LogSummaryClear()
  LogInfo(_("module test started"))

  LogMajorMax = 1
  LogMajorNr = 1
  LogCurrentStep = ''

  -- get current image information
  moduleTestImage = dt.gui.views.darkroom.display_image()
  moduleTestXmpFile = moduleTestImage.path .. '/' .. moduleTestImage.filename .. '.xmp'
  moduleTestXmpModified = GetFileModified(moduleTestXmpFile)

  ---------------------------------------------------------------
  -- 1. preparing test case
  -- reset current image history
  -- start with a well-defined state
  -- copy xmp file (with 'empty' history stack)
  GuiAction('lib/history', 0, 'reset', '', 1.0)
  moduleTestXmpModified = CopyXmpFile(moduleTestXmpFile, moduleTestImage.path, moduleTestImage.filename, '_0_Reset',
    moduleTestXmpModified)

  ---------------------------------------------------------------
  -- 2. test case
  -- perform default settings
  LogMajorMax = 1
  LogMajorNr = 1
  LogCurrentStep = ''

  -- reset module configurations
  -- basic widgets are configured to 'reset' modules first
  moduleTestBasicSetting = 'Default'
  SetAllDefaultModuleConfigurations()

  ProcessWorkflowSteps()

  -- copy xmp file (with 'default' history stack)
  moduleTestXmpModified = CopyXmpFile(moduleTestXmpFile, moduleTestImage.path, moduleTestImage.filename, '_0_Default',
    moduleTestXmpModified)

  ---------------------------------------------------------------
  -- 3. test case, basic "reset"
  -- iterate over all workflow steps and combobox value settings
  -- set different combinations of module settings

  -- reset module configurations
  -- basic widgets are configured to 'reset' modules first
  moduleTestBasicSetting = 'BasicDefault'
  SetAllDefaultModuleConfigurations()
  ModuleTestIterateConfigurationValues()

  ---------------------------------------------------------------
  -- 4. test case, basic "enable"
  -- iterate over all workflow steps and combobox value settings
  -- set different combinations of module settings

  -- prepare test case, reset module configurations
  -- basic widgets are configured to 'reset' modules first
  SetAllDefaultModuleConfigurations()
  ProcessWorkflowSteps()

  -- basic widgets are configured to 'enable' modules first, without reset
  for i, step in ipairs(WorkflowSteps) do
    if (step ~= StepTimeout) then
      step:SetWidgetBasicValue(_("enable"))
    end
  end

  moduleTestBasicSetting = 'BasicEnable'
  ModuleTestIterateConfigurationValues()

  ---------------------------------------------------------------
  -- 5. test case
  -- iterate over basic settings (reset, enable, ignore, ...)

  -- reset module configurations
  -- basic widgets are configured to 'reset' modules first
  moduleTestBasicSetting = 'BasicIterate'
  SetAllDefaultModuleConfigurations()

  -- get maximum number of combobox entries
  local basicValuesMax = 1
  for i, step in ipairs(WorkflowSteps) do
    local count = #step.BasicValues
    if (count > basicValuesMax) then
      basicValuesMax = count
    end
  end

  -- iterate over all selectable values
  for basicValue = 1, basicValuesMax do
    -- iterate over all configurations
    for i, step in ipairs(WorkflowSteps) do
      -- ignore empty comboboxes
      if (#step.BasicValues > 1) then
        -- ignore some basic configurations
        if (not contains(moduleTestIgnoreSteps, step)) then
          -- iterate over configuration values
          if (basicValue <= #step.BasicValues) then
            step.WidgetBasic.value = basicValue
          elseif (basicValue == #step.BasicValues + 1) then
            step:EnableDefaultBasicConfiguation()
          else
            step.Widget.value = (basicValue % #step.BasicValues) + 1
          end
        end
      end
    end

    -- perform configured settings
    -- copy xmp file with current settings to test result folder
    LogMajorMax = basicValuesMax
    LogMajorNr = basicValue
    LogCurrentStep = ''

    ProcessWorkflowSteps()

    moduleTestXmpModified = CopyXmpFile(moduleTestXmpFile, moduleTestImage.path, moduleTestImage.filename,
      '_BasicIterate_' .. basicValue, moduleTestXmpModified)
  end

  ---------------------------------------------------------------
  -- done
  -- dump result messages
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
              tooltip = wordwrap(_(
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
              tooltip = wordwrap(_(
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
---------------------------------------------------------------

local ResetAllCommonMainSettingsWidget
ResetAllCommonMainSettingsWidget = dt.new_widget('combobox')
    {
      changed_callback = function()
        local selection = ResetAllCommonMainSettingsWidget.value

        if (selection ~= _dt("all common settings")) then
          for i, step in ipairs(WorkflowSteps) do
            if step.WidgetStackValue == WidgetStack.Settings then
              if (step ~= StepTimeout) then
                if (selection == _("default")) then
                  LogInfo(step.Label)
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
      tooltip = wordwrap(_(
        "Configure all following common settings: Reset all steps to default configurations. These settings are applied during script run, if corresponding step is enabled.")),
      table.unpack({ _dt("all common settings"), _("default") })
    }

local ResetAllModuleBasicSettingsWidget
ResetAllModuleBasicSettingsWidget = dt.new_widget('combobox')
    {
      changed_callback = function()
        local selection = ResetAllModuleBasicSettingsWidget.value

        if (selection ~= _dt("all module basics")) then
          for i, step in ipairs(WorkflowSteps) do
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
      tooltip = wordwrap(_(
        "Configure all module settings: a) Select default value. b) Ignore this step / module and do nothing at all. c) Enable corresponding module and set selected module configuration. d) Reset the module and set selected module configuration. e) Disable module and keep it unchanged.")),
      table.unpack({ _dt("all module basics"), _("default"), _("ignore"), _("enable"), _("reset"), _("disable") })
    }

local ResetAllModuleMainSettingsWidget
ResetAllModuleMainSettingsWidget = dt.new_widget('combobox')
    {
      changed_callback = function()
        local selection = ResetAllModuleMainSettingsWidget.value

        if (selection ~= _dt("all module settings")) then
          for i, step in ipairs(WorkflowSteps) do
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
      tooltip = wordwrap(_(
        "Configure all module settings: Keep all modules unchanged or enable all default configurations. These configurations are set, if you choose 'reset' or 'enable' as basic setting.")),
      table.unpack({ _dt("all module settings"), _("default"), _("unchanged") })
    }

----------------------------------------------------------

-- TEST button: Special buttons, used to perform module tests.
local function GetWidgetTestButtons(widgets)
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

  for i, step in ipairs(WorkflowSteps) do
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

  for i, step in ipairs(WorkflowSteps) do
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
