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

-- Helper functions to access darktable feature via user interface,
-- get or set darktable module settings or push buttons.

local GuiAction = {}

local indent = '. '

function GuiAction.Init(_dt, _LogHelper, _Helper, _EventHelper, _TranslationHelper)
    dt = _dt
    LogHelper = _LogHelper
    Helper = _Helper
    EventHelper = _EventHelper
    GuiTranslation = _TranslationHelper
end

-- return translation from local .po / .mo file
local function _(msgid)
    return GuiTranslation.t(msgid)
end

-- return translation from darktable
local function _dt(msgid)
    return GuiTranslation.tdt(msgid)
end

-- convert values to boolean, consider not a number and nil
function GuiAction.ConvertValueToBoolean(value)
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
function GuiAction.DoInternal(path, instance, element, effect, speed, waitForPipeline)
    LogHelper.Info('dt.gui.action(' ..
        Helper.Quote(path) ..
        ',' ..
        instance ..
        ',' ..
        Helper.Quote(element) ..
        ',' .. Helper.Quote(effect) .. ',' .. Helper.NumberToString(speed) .. ')')

    local result

    if (waitForPipeline) then
        EventHelper.WaitForPixelPipe:Do(function()
            result = dt.gui.action(path, instance, element, effect, speed)
        end)
    else
        result = dt.gui.action(path, instance, element, effect, speed)
        -- wait a bit...
        Helper.ThreadSleep(StepTimeout:Value() / 2)
    end

    return result
end

-- wait for 'pixelpipe-processing-complete'
function GuiAction.Do(path, instance, element, effect, speed)
    return GuiAction.DoInternal(path, instance, element, effect, speed, true)
end

-- 'pixelpipe-processing-complete' is not expected
function GuiAction.DoWithoutEvent(path, instance, element, effect, speed)
    return GuiAction.DoInternal(path, instance, element, effect, speed, false)
end

-- get current value
function GuiAction.GetValue(path, element)
    -- use 0/0 == NaN as parameter to indicate this read-action
    local value = GuiAction.DoWithoutEvent(path, 0, element, '', 0 / 0)

    LogHelper.Info(indent ..
        'get ' ..
        Helper.Quote(path) ..
        ' ' .. element .. ' = ' .. Helper.NumberToString(value, 'NaN', 'nil'))

    return value
end

-- Set given value, compare it with the current value to avoid
-- unnecessary set commands. There is no “pixelpipe-processing-complete”,
-- if the new value equals the current value.
function GuiAction.SetValue(path, instance, element, effect, speed)
    -- get current value
    -- use 0/0 == NaN as parameter to indicate this read-action
    local value = GuiAction.DoWithoutEvent(path, 0, element, 'set', 0 / 0)

    -- round the value to number of digits
    local digits = 4
    local digitsFactor = 10 ^ (digits or 0)
    value = math.floor(value * digitsFactor + 0.5) / digitsFactor

    LogHelper.Info(indent ..
        'get ' ..
        Helper.Quote(path) ..
        ' ' .. element .. ' = ' .. Helper.NumberToString(value, 'NaN', 'nil'))

    if (value ~= speed) then
        GuiAction.Do(path, instance, element, effect, speed)
    else
        LogHelper.Info(indent ..
            string.format(_("nothing to do, value already equals to %s"),
                Helper.Quote(Helper.NumberToString(value))))
    end
end

-- Push the button  addressed by the path. Turn it off, if necessary.
function GuiAction.ButtonOffOn(path)
    LogHelper.Info(string.format(_("push button off and on: %s"), Helper.Quote(path)))

    local buttonState = GuiAction.GetValue(path, 'button')
    if (GuiAction.ConvertValueToBoolean(buttonState)) then
        GuiAction.DoWithoutEvent(path, 0, 'button', 'off', 1.0)
    else
        LogHelper.Info(indent .. _("nothing to do, button is already inactive"))
    end

    GuiAction.Do(path, 0, 'button', 'on', 1.0)
end

-- show given darkroom module
function GuiAction.ShowDarkroomModule(moduleName)
    -- check if the module is already displayed
    LogHelper.Info(string.format(_("show module if not visible: %s"), moduleName))
    local visible = GuiAction.GetValue(moduleName, 'show')
    if (not GuiAction.ConvertValueToBoolean(visible)) then
        dt.gui.panel_show('DT_UI_PANEL_RIGHT')
        Helper.ThreadSleep(StepTimeout:Value() / 2)
        GuiAction.DoWithoutEvent(moduleName, 0, 'show', '', 1.0)
    else
        LogHelper.Info(indent .. _("module is already visible, nothing to do"))
    end
end

-- disable given darkroom module
function GuiAction.DisableDarkroomModule(moduleName)
    -- check if the module is already activated
    LogHelper.Info(string.format(_("disable module if enabled: %s"), moduleName))
    local status = GuiAction.GetValue(moduleName, 'enable')
    if (GuiAction.ConvertValueToBoolean(status)) then
        GuiAction.Do(moduleName, 0, 'enable', '', 1.0)
    else
        LogHelper.Info(indent .. _("module is already disabled, nothing to do"))
    end
end

-- hide given darkroom module
function GuiAction.HideDarkroomModule(moduleName)
    -- check if the module is already hidden
    LogHelper.Info(string.format(_("hide module if visible: %s"), moduleName))
    local visible = GuiAction.GetValue(moduleName, 'show')
    if (GuiAction.ConvertValueToBoolean(visible)) then
        GuiAction.DoWithoutEvent(moduleName, 0, 'show', '', 1.0)
    else
        LogHelper.Info(indent .. _("module is already hidden, nothing to do"))
    end
end

-- enable given darkroom module
function GuiAction.EnableDarkroomModule(moduleName)
    -- check if the module is already activated
    LogHelper.Info(string.format(_("enable module if disabled: %s"), moduleName))
    local status = GuiAction.GetValue(moduleName, 'enable')
    if (not GuiAction.ConvertValueToBoolean(status)) then
        GuiAction.Do(moduleName, 0, 'enable', '', 1.0)
    else
        LogHelper.Info(indent .. _("module is already enabled, nothing to do"))
    end

    if (StepShowModulesDuringExecution:Value()) then
        GuiAction.ShowDarkroomModule(moduleName)
    end
end

-- reset given darkroom module
function GuiAction.ResetDarkroomModule(moduleName)
    LogHelper.Info(_dt("reset parameters") .. ' (' .. moduleName .. ')')
    GuiAction.Do(moduleName, 0, 'reset', '', 1.0)
end

return GuiAction
