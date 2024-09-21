-- MODULE TEST IMPLEMENTATION.
-- This helper module contains some functions to perform module tests.
-- The following functions are used during development and deployment.

local ModuleTestHelper = {}

function ModuleTestHelper.Init(_dt, _LogHelper, _Helper, _TranslationHelper, _GuiAction, _WorkflowSteps, _ProcessWorkflowSteps, _SetAllDefaultModuleConfigurations)
    dt = _dt
    LogHelper = _LogHelper
    Helper = _Helper
    TranslationHelper = _TranslationHelper
    GuiAction = _GuiAction
    WorkflowSteps = _WorkflowSteps
    ProcessWorkflowSteps = _ProcessWorkflowSteps
    SetAllDefaultModuleConfigurations = _SetAllDefaultModuleConfigurations
end

-- return translation from local .po / .mo file
local function _(msgid)
    return TranslationHelper.t(msgid)
end

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
  local fileHandle = io.popen('stat -c %Y ' .. Helper.Quote(fileName))
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
    Helper.ThreadSleep(period)
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
  Helper.ThreadSleep(StepTimeout:Value())
  local xmpModifiedNew = WaitForFileModified(xmpFile, xmpModified)

  -- copy xmp file to test result folder
  local xmpFileCopy = filePath .. '/TEST/' .. fileName .. appendix .. '.xmp'
  local xmpCopyCommand = 'cp ' .. Helper.Quote(xmpFile) .. ' ' .. Helper.Quote(xmpFileCopy)
  LogHelper.Info(xmpCopyCommand)
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
      if (not Helper.Contains(moduleTestIgnoreSteps, step)) then
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
    LogHelper.MajorMax = configurationValuesMax
    LogHelper.MajorNr = configurationValue
    LogHelper.CurrentStep = ''

    ProcessWorkflowSteps()

    moduleTestXmpModified = CopyXmpFile(moduleTestXmpFile, moduleTestImage.path, moduleTestImage.filename,
      '_' .. moduleTestBasicSetting .. '_' .. configurationValue, moduleTestXmpModified)
  end
end

-- called to perform module tests
function ModuleTestHelper.ModuleTest()
  -- check darkroom view
  local currentView = dt.gui.current_view()
  if (currentView ~= dt.gui.views.darkroom) then
    LogHelper.Screen(_("module tests must be started from darkroom view"))
    return
  end

  -- prepare test execution
  LogHelper.SummaryClear()
  LogHelper.Info(_("module test started"))

  -- get current image information
  moduleTestImage = dt.gui.views.darkroom.display_image()
  moduleTestXmpFile = moduleTestImage.path .. '/' .. moduleTestImage.filename .. '.xmp'
  moduleTestXmpModified = GetFileModified(moduleTestXmpFile)

  ---------------------------------------------------------------
  -- 1. preparing test case
  -- reset current image history
  -- start with a well-defined state
  -- copy xmp file (with 'empty' history stack)
  GuiAction.Do('lib/history', 0, 'reset', '', 1.0)
  moduleTestXmpModified = CopyXmpFile(moduleTestXmpFile, moduleTestImage.path, moduleTestImage.filename, '_0_Reset',
    moduleTestXmpModified)

  ---------------------------------------------------------------
  -- 2. test case
  -- perform default settings
  LogHelper.MajorMax = 1
  LogHelper.MajorNr = 1
  LogHelper.CurrentStep = ''

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
        if (not Helper.Contains(moduleTestIgnoreSteps, step)) then
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
    LogHelper.MajorMax = basicValuesMax
    LogHelper.MajorNr = basicValue
    LogHelper.CurrentStep = ''

    ProcessWorkflowSteps()

    moduleTestXmpModified = CopyXmpFile(moduleTestXmpFile, moduleTestImage.path, moduleTestImage.filename,
      '_BasicIterate_' .. basicValue, moduleTestXmpModified)
  end

  ---------------------------------------------------------------
  -- done
  -- dump result messages
  LogSummary()
  LogHelper.Info(_("module test finished"))
end

return ModuleTestHelper