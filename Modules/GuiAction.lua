---------------------------------------------------------------
-- helper functions to access darktable feature via user interface

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

return GuiAction
