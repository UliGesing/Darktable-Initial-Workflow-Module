--[[
  Darktable Initial Workflow Module

  This file implements the "TEST" button.
  Execute module tests. Used during development and deployment.

  For more details see Readme.md in
  https://github.com/UliGesing/Darktable-Initial-Workflow-Module
 ]]
local dt = require "darktable"

local function GetFileModified(fileName)
  local f = io.popen("stat -c %Y '" .. fileName .. "'")
  local xmpModified = f:read()
  return xmpModified
end

local function WaitForFileModified(xmpFile, xmpModified)
  local min = 500
  local max = 5000
  local duration = 0
  local period = 500

  while (duration < min) do
    dt.control.sleep(period)
    duration = duration + period
    if (duration >= max) then
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
  dt.control.sleep(2000)
  local xmpModifiedNew = WaitForFileModified(xmpFile, xmpModified)

  -- copy xmp file to test result folder
  local xmpFileCopyReset = filePath .. "/TEST/" .. fileName .. appendix .. ".xmp"
  local ok = os.execute('cp "' .. xmpFile .. '" "' .. xmpFileCopyReset .. '"')

  return xmpModifiedNew
end

local function ModuleTest()
  -- called to perform module tests

  local currentView = dt.gui.current_view()
  if (currentView ~= dt.gui.views.darkroom) then
    LogScreen("module tests must be started from Darkroom view")
    return
  end

  -- get current image information
  local image = dt.gui.views.darkroom.display_image()
  local xmpFile = image.path .. "/" .. image.filename .. ".xmp"
  local xmpModified = GetFileModified(xmpFile)

  -- reset current image history
  -- start with a well-defined state
  GuiActionWaitForPixelPipe("lib/history", 0, "reset", "", 1.0)

  -- copy xmp file (with 'empty' history stack)
  xmpModified = CopyXmpFile(xmpFile, image.path, image.filename, "_0_Reset", xmpModified)

  -- perform default settings
  EnableDefaultSteps()
  ProcessImageInDarkroomView()
  xmpModified = CopyXmpFile(xmpFile, image.path, image.filename, "_0_Default", xmpModified)


  -- get maximum number of combobox entries
  local comboBoxValuesMax = 1
  for i, step in ipairs(WorkflowSteps) do
    local count = #step.ComboBoxValues
    if (step == StepColorBalanceGlobalChroma or step == StepColorBalanceGlobalSaturation) then
      count = 2 -- limit number to sensible values
    end
    if (count > comboBoxValuesMax) then
      comboBoxValuesMax = count
    end
  end

  -- configure first step to reset all inital workflow modules
  StepResetModuleHistory.Widget.value = 3

  -- iterate over all workflow steps and combobox value settings
  -- set different combinations of module settings
  for comboBoxValue = 1, comboBoxValuesMax do
    for i, step in ipairs(WorkflowSteps) do
      if (step ~= StepResetModuleHistory) then
        if (comboBoxValue <= #step.ComboBoxValues) then
          step.Widget.value = comboBoxValue
          dt.control.sleep(100)
        else
          step:Default()
        end
      end
    end

    -- perform configured settings
    ProcessImageInDarkroomView()

    -- copy xmp file with current settings to test result folder
    xmpModified = CopyXmpFile(xmpFile, image.path, image.filename, "_" .. comboBoxValue, xmpModified)
  end
end

ButtonModuleTest = WorkflowStepButton:new():new
    {
      Widget = dt.new_widget("button")
      {
        label = "TEST",
        tooltip = "Execute module tests. Used during development and deployment.",

        clicked_callback = ModuleTest
      }
    }
