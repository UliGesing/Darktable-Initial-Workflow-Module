---------------------------------------------------------------
-- Event handling helper functions used during EventHelper.dt.gui.action

local indent = '. '

local EventHelper = {}

function EventHelper.Init(_dt, _LogHelper, _Helper, _TranslationHelper, _ModuleName)
    EventHelper.dt = _dt
    EventHelper.LogHelper = _LogHelper
    EventHelper.Helper = _Helper
    EventHelper.TranslationHelper = _TranslationHelper
    EventHelper.ModuleName = _ModuleName
end

-- return translation from local .po / .mo file
local function _(msgid)
    return EventHelper.TranslationHelper.t(msgid)
end

-- base class to handle events
EventHelper.WaitForEventBase =
{
    EventType = nil,
    EventReceivedFlag = nil
}

-- base class constructor
function EventHelper.WaitForEventBase:new(obj)
    -- create object if user does not provide one
    obj = obj or {}
    -- define inheritance
    setmetatable(obj, self)
    self.__index = self
    -- return new object
    return obj
end

function EventHelper.WaitForEventBase:EventReceivedFlagReset()
    self.EventReceivedFlag = nil
end

function EventHelper.WaitForEventBase:EventReceivedFlagSet()
    self.EventReceivedFlag = 1
    -- EventHelper.LogHelper.Info(indent .. string.format(_("received event %s"), self.EventType))
end

-- execute embedded function and wait for given EventType
function EventHelper.WaitForEventBase:Do(embeddedFunction)
    -- register event
    self:EventReceivedFlagReset()

    EventHelper.dt.destroy_event(EventHelper.ModuleName, self.EventType)
    EventHelper.dt.register_event(EventHelper.ModuleName, self.EventType, self.EventReceivedFunction)

    -- EventHelper.LogHelper.Info(indent .. string.format(_("wait for event %s"), self.EventType))

    -- execute given function
    embeddedFunction()

    -- wait for registered event
    local duration = 0
    local durationMax = StepTimeout:Value() * 5
    local period = StepTimeout:Value() / 10
    local output = '..'

    while (not self.EventReceivedFlag) or (duration < period) do
        if ((duration > 0) and (duration % 500 == 0)) then
            EventHelper.LogHelper.Info(output)
            output = output .. '.'
        end

        EventHelper.dt.control.sleep(period)
        duration = duration + period

        if (duration >= durationMax) then
            local timeoutMessage = string.format(
                _("timeout after %d ms waiting for event %s - increase timeout setting and try again"), durationMax, self
                .EventType)
            EventHelper.LogHelper.Info(timeoutMessage)
            EventHelper.LogHelper.SummaryMessage(timeoutMessage)
            break
        end
    end

    -- unregister event
    EventHelper.dt.destroy_event(EventHelper.ModuleName, self.EventType)
    self:EventReceivedFlagReset()
end

-- wait for new pixelpipe-processing-complete event
EventHelper.WaitForPixelPipe = EventHelper.WaitForEventBase:new():new
    {
        EventType = 'pixelpipe-processing-complete'
    }

-- called as callback function
function EventHelper.WaitForPixelPipe:EventReceivedFunction(event)
    EventHelper.WaitForPixelPipe:EventReceivedFlagSet()
end

-- wait for image loaded event
EventHelper.WaitForImageLoaded = EventHelper.WaitForEventBase:new():new
    {
        EventType = 'darkroom-image-loaded'
    }

-- wait for image loaded event and reload it, if necessary.
-- 'clean' flag indicates, if the load was clean (got pixel pipe locks) or not.
function EventHelper.WaitForImageLoaded:EventReceivedFunction(event, clean, image)
    if not clean then
        local message = _("loading image failed, reload is performed (this could indicate a timing problem)")
        EventHelper.LogHelper.Info(message)
        EventHelper.LogHelper.SummaryMessage(message)

        EventHelper.Helper.ThreadSleep(StepTimeout:Value() * 2)
        EventHelper.dt.gui.views.darkroom.display_image(image)
    else
        EventHelper.WaitForImageLoaded:EventReceivedFlagSet()
    end
end

---------------------------------------------------------------
-- helper functions to access darktable feature via user interface

-- convert values to boolean, consider not a number and nil
function EventHelper.ConvertGuiActionValueToBoolean(value)
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
function GuiActionInternal(path, instance, element, effect, speed, waitForPipeline)
    EventHelper.LogHelper.Info('EventHelper.dt.gui.action(' ..
        EventHelper.Helper.Quote(path) ..
        ',' ..
        instance ..
        ',' ..
        EventHelper.Helper.Quote(element) ..
        ',' .. EventHelper.Helper.Quote(effect) .. ',' .. EventHelper.Helper.NumberToString(speed) .. ')')

    local result

    if (waitForPipeline) then
        EventHelper.WaitForPixelPipe:Do(function()
            result = EventHelper.dt.gui.action(path, instance, element, effect, speed)
        end)
    else
        result = EventHelper.dt.gui.action(path, instance, element, effect, speed)
        -- wait a bit...
        EventHelper.Helper.ThreadSleep(StepTimeout:Value() / 2)
    end

    return result
end

-- wait for 'pixelpipe-processing-complete'
function GuiAction(path, instance, element, effect, speed)
    return GuiActionInternal(path, instance, element, effect, speed, true)
end

-- 'pixelpipe-processing-complete' is not expected
function GuiActionWithoutEvent(path, instance, element, effect, speed)
    return GuiActionInternal(path, instance, element, effect, speed, false)
end

-- get current value
function GuiActionGetValue(path, element)
    -- use 0/0 == NaN as parameter to indicate this read-action
    local value = GuiActionWithoutEvent(path, 0, element, '', 0 / 0)

    EventHelper.LogHelper.Info(indent ..
        'get ' ..
        EventHelper.Helper.Quote(path) ..
        ' ' .. element .. ' = ' .. EventHelper.Helper.NumberToString(value, 'NaN', 'nil'))

    return value
end

-- Set given value, compare it with the current value to avoid
-- unnecessary set commands. There is no “pixelpipe-processing-complete”,
-- if the new value equals the current value.
function GuiActionSetValue(path, instance, element, effect, speed)
    -- get current value
    -- use 0/0 == NaN as parameter to indicate this read-action
    local value = GuiActionWithoutEvent(path, 0, element, 'set', 0 / 0)

    -- round the value to number of digits
    local digits = 4
    local digitsFactor = 10 ^ (digits or 0)
    value = math.floor(value * digitsFactor + 0.5) / digitsFactor

    EventHelper.LogHelper.Info(indent ..
        'get ' ..
        EventHelper.Helper.Quote(path) ..
        ' ' .. element .. ' = ' .. EventHelper.Helper.NumberToString(value, 'NaN', 'nil'))

    if (value ~= speed) then
        GuiAction(path, instance, element, effect, speed)
    else
        EventHelper.LogHelper.Info(indent ..
            string.format(_("nothing to do, value already equals to %s"),
                EventHelper.Helper.Quote(EventHelper.Helper.NumberToString(value))))
    end
end

-- Push the button  addressed by the path. Turn it off, if necessary.
function GuiActionButtonOffOn(path)
    EventHelper.LogHelper.Info(string.format(_("push button off and on: %s"), EventHelper.Helper.Quote(path)))

    local buttonState = GuiActionGetValue(path, 'button')
    if (EventHelper.ConvertGuiActionValueToBoolean(buttonState)) then
        GuiActionWithoutEvent(path, 0, 'button', 'off', 1.0)
    else
        EventHelper.LogHelper.Info(indent .. _("nothing to do, button is already inactive"))
    end

    GuiAction(path, 0, 'button', 'on', 1.0)
end

return EventHelper
