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

-- Event handling helper functions used during dt.gui.action, execute darktable
-- function and wait for given event type (pixelpipe-processing-complete event),
-- wait for image loaded event and reload it, if necessary.

local EventHelper = {}

function EventHelper.Init(_dt, _LogHelper, _Helper, _TranslationHelper, _ModuleName)
    dt = _dt
    LogHelper = _LogHelper
    Helper = _Helper
    GuiTranslation = _TranslationHelper
    ModuleName = _ModuleName
end

-- return translation from local .po / .mo file
local function _(msgid)
    return GuiTranslation.t(msgid)
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
    -- LogHelper.Info(indent .. string.format(_("received event %s"), self.EventType))
end

-- execute embedded function and wait for given EventType
function EventHelper.WaitForEventBase:Do(embeddedFunction)
    -- register event
    self:EventReceivedFlagReset()

    dt.destroy_event(ModuleName, self.EventType)
    dt.register_event(ModuleName, self.EventType, self.EventReceivedFunction)

    -- LogHelper.Info(indent .. string.format(_("wait for event %s"), self.EventType))

    -- execute given function
    embeddedFunction()

    -- wait for registered event
    local duration = 0
    local durationMax = StepTimeout:Value() * 5
    local period = StepTimeout:Value() / 10
    local output = '..'

    while (not self.EventReceivedFlag) or (duration < period) do
        if ((duration > 0) and (duration % 500 == 0)) then
            LogHelper.Info(output)
            output = output .. '.'
        end

        dt.control.sleep(period)
        duration = duration + period

        if (duration >= durationMax) then
            local timeoutMessage = string.format(
                _("timeout after %d ms waiting for event %s - increase timeout setting and try again"), durationMax, self
                .EventType)
            LogHelper.Info(timeoutMessage)
            LogHelper.SummaryMessage(timeoutMessage)
            break
        end
    end

    -- unregister event
    dt.destroy_event(ModuleName, self.EventType)
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
        LogHelper.Info(message)
        LogHelper.SummaryMessage(message)

        Helper.ThreadSleep(StepTimeout:Value() * 2)
        dt.gui.views.darkroom.display_image(image)
    else
        EventHelper.WaitForImageLoaded:EventReceivedFlagSet()
    end
end

return EventHelper
