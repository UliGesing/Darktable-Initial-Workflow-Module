---------------------------------------------------------------
-- base class of workflow steps

local Workflow = {}

local indent = '. '

function Workflow.Init(_dt, _LogHelper, _Helper, _EventHelper, _TranslationHelper, _GuiAction)
    dt = _dt
    LogHelper = _LogHelper
    Helper = _Helper
    EventHelper = _EventHelper
    GuiTranslation = _TranslationHelper
    GuiAction = _GuiAction
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
  

-- collect all workflow steps in a table
-- used to execute or configure all steps at once
Workflow.ModuleSteps = {}

-- workflow buttons: collect button widgets in a table
-- used during callback functions
Workflow.Buttons = {}

-- base class of all workflow steps
Workflow.ModuleStep =
{
    Widget = nil,
    WidgetBasic = nil,
    Tooltip = nil,
}

-- workflow step base class constructor
function Workflow.ModuleStep:new(obj)
    -- create object if user does not provide one
    obj = obj or {}
    -- define inheritance
    setmetatable(obj, self)
    self.__index = self
    -- return new object
    return obj
end

-- message at the beginning of a step
function Workflow.ModuleStep:LogStepMessage()
    LogHelper.Info('==============================')
    LogHelper.Info(string.format(_("selection = %s - %s"), self.WidgetBasic.value, self.Widget.value))
end

-- show given darkroom module
function Workflow.ModuleStep:ShowDarkroomModule(moduleName)
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

-- hide given darkroom module
function Workflow.ModuleStep:HideDarkroomModule(moduleName)
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
function Workflow.ModuleStep:EnableDarkroomModule(moduleName)
    -- check if the module is already activated
    LogHelper.Info(string.format(_("enable module if disabled: %s"), moduleName))
    local status = GuiAction.GetValue(moduleName, 'enable')
    if (not GuiAction.ConvertValueToBoolean(status)) then
        GuiAction.Do(moduleName, 0, 'enable', '', 1.0)
    else
        LogHelper.Info(indent .. _("module is already enabled, nothing to do"))
    end

    if (StepShowModulesDuringExecution.Widget.value == _dt("yes")) then
        self:ShowDarkroomModule(moduleName)
    end
end

-- disable given darkroom module
function Workflow.ModuleStep:DisableDarkroomModule(moduleName)
    -- check if the module is already activated
    LogHelper.Info(string.format(_("disable module if enabled: %s"), moduleName))
    local status = GuiAction.GetValue(moduleName, 'enable')
    if (GuiAction.ConvertValueToBoolean(status)) then
        GuiAction.Do(moduleName, 0, 'enable', '', 1.0)
    else
        LogHelper.Info(indent .. _("module is already disabled, nothing to do"))
    end
end

-- reset given darkroom module
function Workflow.ModuleStep:ResetDarkroomModule(moduleName)
    LogHelper.Info(_dt("reset parameters") .. ' (' .. moduleName .. ')')
    GuiAction.Do(moduleName, 0, 'reset', '', 1.0)
end

-- handle view changed event (lighttable / darkroom view)
-- some comboboxes or buttons need a special handling
function Workflow.ModuleStep:InitDependingOnCurrentView()
    -- do nothing by default
end

---------------------------------------------------------------
-- base class of workflow steps with ComboBox widget
Workflow.StepConfiguration = Workflow.ModuleStep:new():new
    {
        OperationNameInternal = nil,
        WidgetStackValue = nil,
        ConfigurationValues = nil,
        WidgetUnchangedStepConfigurationValue = nil,
        WidgetDefaultStepConfiguationValue = nil,
    }

-- create default basic widget of most workflow steps
function Workflow.StepConfiguration:CreateDefaultBasicWidget()
    self.WidgetBasicDefaultValue = 4

    self.BasicValues = { _("default"), _("ignore"), _("enable"), _("reset"), _("disable") }

    self.WidgetBasic = dt.new_widget('combobox')
        {
            changed_callback = function(widget)
                local changedStep = Workflow.GetStep(widget)
                if (changedStep ~= nil) then
                    if (changedStep.WidgetBasic.value == _("default")) then
                        changedStep:EnableDefaultBasicConfiguation()
                    end
                end
                Workflow.ComboBoxChangedCallback(widget)
            end,

            label = ' ',
            tooltip = Helper.Wordwrap(self.Label .. ' ' .. _(
                "basic setting: a) Select default value. b) Ignore this step / module and do nothing at all. c) Enable corresponding module and set selected module configuration. d) Reset the module and set selected module configuration. e) Disable module and keep it unchanged.")),
            table.unpack(self.BasicValues)
        }
end

-- create label widget
function Workflow.StepConfiguration:CreateLabelWidget()
    self.WidgetLabel = dt.new_widget('combobox')
        {
            label = self.Label,
            tooltip = self:GetLabelAndTooltip()
        }
end

-- create simple basic widget of some workflow steps
function Workflow.StepConfiguration:CreateSimpleBasicWidget()
    self.WidgetBasicDefaultValue = 2

    self.BasicValues = { _("ignore"), _("enable") }

    self.WidgetBasic = dt.new_widget('combobox')
        {
            changed_callback = Workflow.ComboBoxChangedCallback,
            label = ' ',
            tooltip = Helper.Wordwrap(self.Label .. ' ' .. _("basic setting: Ignore this module or do corresponding configuration.")),
            table.unpack(self.BasicValues)
        }
end

-- create empty invisible basic widget
function Workflow.StepConfiguration:CreateEmptyBasicWidget()
    self.WidgetBasicDefaultValue = 1

    self.BasicValues = { '' }

    self.WidgetBasic = dt.new_widget('combobox')
        {
            label = ' ',
            table.unpack(self.BasicValues)
        }
end

-- evaluate basic widget, common for most workflow steps
function Workflow.StepConfiguration:RunBasicWidget()
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
function Workflow.StepConfiguration:RunSimpleBasicWidget()
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
function Workflow.StepConfiguration:EnableDefaultStepConfiguation()
    self.Widget.value = self.WidgetDefaultStepConfiguationValue
end

-- choose default basic setting
function Workflow.StepConfiguration:EnableDefaultBasicConfiguation()
    self.WidgetBasic.value = self.WidgetBasicDefaultValue
end

-- returns internal operation name like 'colorbalancergb' or 'atrous'
function Workflow.StepConfiguration:OperationName()
    return self.OperationNameInternal
end

-- returns operation path like 'iop/colorbalancergb'
function Workflow.StepConfiguration:OperationPath()
    return 'iop/' .. self:OperationName()
end

local PreferencePresetName = "Current"
local PreferencePrefixBasic = "Basic"
local PreferencePrefixConfiguration = "Config"

-- save current selections of this workflow step
-- used to restore settings after starting darktable
function Workflow.StepConfiguration:SavePreferenceValue()
    -- check, if there are any changes
    -- preferences are saved with english names and values
    -- user interfase uses translated names and values

    -- save any changes of the configuration combobox value
    local prefix = PreferencePresetName .. ":" .. PreferencePrefixConfiguration .. ":"
    local preferenceName = prefix .. _ReverseTranslation(self.Label)
    local preferenceValue = dt.preferences.read(ModuleName, preferenceName, 'string')
    local configurationValue = _ReverseTranslation(self.Widget.value)

    if (preferenceValue ~= configurationValue) then
        dt.preferences.write(ModuleName, preferenceName, 'string', configurationValue)
    end

    -- save any changes of the basic combobox value
    local prefixBasic = PreferencePresetName .. ":" .. PreferencePrefixBasic .. ":"
    local preferenceBasicName = prefixBasic .. _ReverseTranslation(self.Label)
    local preferenceBasicValue = dt.preferences.read(ModuleName, preferenceBasicName, 'string')
    local basicValue = _ReverseTranslation(self.WidgetBasic.value)

    if (preferenceBasicValue ~= basicValue) then
        dt.preferences.write(ModuleName, preferenceBasicName, 'string', basicValue)
    end
end

-- read saved selection value from darktable preferences
-- used to restore settings after starting darktable
function Workflow.StepConfiguration:ReadPreferenceConfigurationValue()
    -- preferences are saved with english names and values
    -- user intercase uses translated names and values
    local prefix = PreferencePresetName .. ":" .. PreferencePrefixConfiguration .. ":"
    local preferenceName = prefix .. _ReverseTranslation(self.Label)
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
function Workflow.StepConfiguration:SetWidgetBasicValue(value)
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
function Workflow.StepConfiguration:ReadPreferenceBasicValue()
    -- preferences are saved separately for each user interface language
    -- user intercase uses translated names and values
    local prefixBasic = PreferencePresetName .. ":" .. PreferencePrefixBasic .. ":"
    local preferenceBasicName = prefixBasic .. _ReverseTranslation(self.Label)
    local preferenceBasicValue = _(dt.preferences.read(ModuleName, preferenceBasicName, 'string'))
    self:SetWidgetBasicValue(preferenceBasicValue)
end

-- combobox selection is returned as negative index value
-- convert negative index value to combobox string value
-- consider "unchanged" value: + 1
function Workflow.StepConfiguration:GetConfigurationValueFromSelectionIndex(index)
    return self.ConfigurationValues[(-index) + 1]
end

-- concat widget label and tooltip
function Workflow.StepConfiguration:GetLabelAndTooltip()
    return Helper.Wordwrap(self.Label .. ': ' .. self.Tooltip)
end

-- called from callback function within a 'foreign context'
-- we have to determine the button object or workflow step first
function Workflow.GetItem(widget, table)
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
function Workflow.GetButton(widget)
    return Workflow.GetItem(widget, Workflow.Buttons)
end

-- called from callback function within a 'foreign context'
-- determine the step object
function Workflow.GetStep(widget)
    return Workflow.GetItem(widget, Workflow.ModuleSteps)
end

-- called after selection was changed
-- current settings are saved as darktable preferences
function Workflow.ComboBoxChangedCallback(widget)
    Workflow.GetStep(widget):SavePreferenceValue()
end

-- base class of workflow steps with Button widget
Workflow.StepButton = Workflow.ModuleStep:new():new
    {
    }


return Workflow
