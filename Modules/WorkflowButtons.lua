-- IMPLEMENTATION OF BUTTON FUNCTIONALITY
-- These are buttons to start the execution of the steps or e.g. to set default values.

local WorkflowButtons = {}

local indent = '. '

function WorkflowButtons.Init(_dt, _LogHelper, _Helper, _EventHelper, _TranslationHelper, _Workflow, _GuiAction, _WidgetStack,
                      _ScriptFilePath)
    dt = _dt
    LogHelper = _LogHelper
    Helper = _Helper
    EventHelper = _EventHelper
    GuiTranslation = _TranslationHelper
    Workflow = _Workflow
    GuiAction = _GuiAction
    WidgetStack = _WidgetStack
    ScriptFilePath = _ScriptFilePath
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


-- stop running thumbnail creation
local function stop_job(job)
    job.valid = false
end

-- process all configured workflow steps
local function ProcessWorkflowSteps()
    LogHelper.Info('==============================')
    LogHelper.Info(_("process workflow steps"))

    -- create a progress bar
    local job = dt.gui.create_job("process workflow steps", true, stop_job)
    local workflowCanceled = false

    Helper.ThreadSleep(StepTimeout:Value())

    -- execute all workflow steps
    -- the order is from bottom to top, along the pixel pipeline.
    for i = 1, #Workflow.ModuleSteps do
        local step = Workflow.ModuleSteps[#Workflow.ModuleSteps + 1 - i]
        LogHelper.CurrentStep = step.Label

        LogHelper.Screen(step.Label) -- instead of dt.print()

        -- execute workflow step
        step:Run()

        -- sleep for a short moment to give stop_job callback function a chance to run
        dt.control.sleep(10)

        -- stop workflow if the cancel button of the progress bar is pressed
        workflowCanceled = not job.valid
        if workflowCanceled then
            LogHelper.SummaryMessage(_("workflow canceled"))
            break
        end

        -- stop workflow if darktable is shutting down
        if dt.control.ending then
            job.valid = false
            workflowCanceled = true
            LogHelper.SummaryMessage(_("workflow canceled - darktable shutting down"))
            break
        end

        -- update progress_bar
        job.percent = i / #Workflow.ModuleSteps
    end

    LogHelper.CurrentStep = ''
    Helper.ThreadSleep(StepTimeout:Value())

    if not workflowCanceled then
        job.valid = false
    end

    return workflowCanceled
end


-- The summary collects some important (error) messages.
-- This function is executed at the end of each script run.
function LogSummary()
    LogHelper.Info('==============================')

    if (#LogHelper.SummaryMessages == 0) then
        LogHelper.Info(_("OK - script run without errors"))
        LogHelper.Screen(_("initial workflow done"))
    else
        for index, message in ipairs(LogHelper.SummaryMessages) do
            LogHelper.Info(message)
            LogHelper.Screen(_(message))
        end
    end

    LogHelper.Info(_("initial workflow done"))
    LogHelper.Info('==============================')
end

-- process current image in darkroom view
local function ProcessImageInDarkroomView()
    LogHelper.MajorMax = 1
    LogHelper.MajorNr = 1
    LogHelper.CurrentStep = ''

    LogHelper.SummaryClear()

    ProcessWorkflowSteps()

    LogSummary()
end

-- process selected image(s)
local function ProcessSelectedImagesInLighttableView()
    LogHelper.MajorMax = 0
    LogHelper.MajorNr = 0
    LogHelper.CurrentStep = ''

    LogHelper.SummaryClear()

    LogHelper.Info('==============================')
    LogHelper.Info(_("process selected images"))

    -- check that there is an image selected to activate darkroom view
    local images = dt.gui.action_images
    if not images or #images == 0 then
        LogHelper.Screen(_("no image selected"))
        return
    end

    -- remember currently selected images
    images = {}
    for _, newImage in ipairs(dt.gui.action_images) do
        table.insert(images, newImage)
    end

    -- switch to darkroom view
    LogHelper.Info(_("switch to darkroom view"))
    EventHelper.WaitForPixelPipe:Do(function()
        dt.gui.current_view(dt.gui.views.darkroom)
    end)

    -- process selected images
    LogHelper.MajorMax = #images
    for index, newImage in ipairs(images) do
        LogHelper.MajorNr = index
        LogHelper.CurrentStep = ''

        local oldImage = dt.gui.views.darkroom.display_image()

        -- load selected image and show it in darkroom view
        LogHelper.Info(string.format(_("load image number %s of %s"), index, #images))
        LogHelper.Info(string.format(_("image file = %s"), newImage.filename))

        if (oldImage ~= newImage) then
            EventHelper.WaitForPixelPipe:Do(function()
                LogHelper.Info(_("load new image into darkroom view"))
                EventHelper.WaitForImageLoaded:Do(function()
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
    LogHelper.Info(_("switch to lighttable view"))
    dt.gui.current_view(dt.gui.views.lighttable)
    dt.gui.selection(images)

    LogSummary()
end

---------------------------------------------------------------

function WorkflowButtons.CreateWorkflowButtons()
    ButtonRunSelectedSteps = Workflow.StepButton:new():new
        {
            Widget = dt.new_widget('button')
                {
                    label = _("run"),
                    tooltip = Helper.Wordwrap(_(
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

    table.insert(Workflow.Buttons, ButtonRunSelectedSteps)

    ---------------------------------------------------------------

    ButtonShowWidgetStackModules = Workflow.StepButton:new():new
        {
            Widget = dt.new_widget('button')
                {
                    label = _("show modules"),
                    tooltip = Helper.Wordwrap(_(
                        "Show the subpage with the configuration of the modules.")),

                    clicked_callback = function()
                        WidgetStack.Stack.active = WidgetStack.Modules
                        return
                    end
                }
        }

    table.insert(Workflow.Buttons, ButtonShowWidgetStackModules)

    ---------------------------------------------------------------

    ButtonShowWidgetStackSettings = Workflow.StepButton:new():new
        {
            Widget = dt.new_widget('button')
                {
                    label = _("show settings"),
                    tooltip = Helper.Wordwrap(_(
                        "Show the subpage with common settings.")),

                    clicked_callback = function()
                        WidgetStack.Stack.active = WidgetStack.Settings
                        return
                    end
                }
        }

    table.insert(Workflow.Buttons, ButtonShowWidgetStackSettings)

    ---------------------------------------------------------------

    ButtonEnableRotateAndPerspective = Workflow.StepButton:new():new
        {
            Widget = dt.new_widget('button')
                {
                    label = _dt("rotate and perspective"),
                    tooltip = Helper.Wordwrap(_(
                        "Activate the module to rotate the image and adjust the perspective. Enabled in darkroom view.")),

                    clicked_callback = function(widget)
                        local button = Workflow.GetButton(widget)
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

    table.insert(Workflow.Buttons, ButtonEnableRotateAndPerspective)

    ---------------------------------------------------------------

    ButtonEnableCrop = Workflow.StepButton:new():new
        {
            Widget = dt.new_widget('button')
                {
                    label = _dt("crop"),
                    tooltip = Helper.Wordwrap(_("Activate the module to crop the image. Enabled in darkroom view.")),

                    clicked_callback = function(widget)
                        local button = Workflow.GetButton(widget)
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

    table.insert(Workflow.Buttons, ButtonEnableCrop)

    ---------------------------------------------------------------

    ButtonMidToneExposure = Workflow.StepButton:new():new
        {
            Widget = dt.new_widget('button')
                {
                    label = _dt("exposure"),
                    tooltip = Helper.Wordwrap(_(
                        "Show exposure module to adjust the exposure until the mid-tones are clear enough. Enabled in darkroom view.")),

                    clicked_callback = function(widget)
                        local button = Workflow.GetButton(widget)
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

    table.insert(Workflow.Buttons, ButtonMidToneExposure)

    ---------------------------------------------------------------

    -- select default basic configuration for each step
    -- called via module reset control
    local function SetAllDefaultModuleConfigurations()
        for i, step in ipairs(Workflow.ModuleSteps) do
            if (step ~= StepTimeout) then
                step:EnableDefaultBasicConfiguation()
                step:EnableDefaultStepConfiguation()
            end
        end
    end

    ---------------------------------------------------------------

    -- init ./Modules/ModuleTest
    local ModuleTests = require 'Modules.ModuleTests'
    ModuleTests.Init(dt, LogHelper, Helper, GuiTranslation, GuiAction, Workflow.ModuleSteps, ProcessWorkflowSteps,
        SetAllDefaultModuleConfigurations)

    -- TEST button: Special button, used to perform module tests.
    -- This button should be disabled for general use of the script.
    -- To enable it, create a file named 'TestFlag.txt' in the same
    -- directory as this script file.

    if (FileExists(ScriptFilePath .. 'TestFlag.txt')) then
        ButtonModuleTest = Workflow.StepButton:new():new
            {
                Widget = dt.new_widget('button')
                    {
                        label = 'TEST',
                        tooltip = Helper.Wordwrap(_(
                            "Execute module tests. Used during development and deployment. Enabled in darkroom view.")),

                        clicked_callback = ModuleTests.ModuleTest
                    }
            }

        function ButtonModuleTest:InitDependingOnCurrentView()
            -- override base class function
            self.Widget.visible = (dt.gui.current_view() == dt.gui.views.darkroom)
        end

        ButtonModuleTestCustomCode = Workflow.StepButton:new():new
            {
                Widget = dt.new_widget('button')
                    {
                        label = _("Custom Code"),
                        tooltip = Helper.Wordwrap(_(
                            "Execute code from TestCustomCode.lua: This file contains some custom debug code. It can be changed without restarting darktable. Just edit, save and execute it. You can use it to try some lua commands on the fly, e.g. dt.gui.action commands. Enabled in darkroom view.")),

                        clicked_callback = function()
                            local currentView = dt.gui.current_view()
                            if (currentView ~= dt.gui.views.darkroom) then
                                LogHelper.Screen(_("module tests must be started from darkroom view"))
                                return
                            end

                            local fileName = Helper.ScriptFilePath() .. 'TestCustomCode.lua'

                            if (not FileExists(fileName)) then
                                LogHelper.Screen(string.format(_("module test file not found: %s"), fileName))
                                return
                            end

                            LogHelper.Info('Execute script ' .. Helper.Quote(fileName))
                            dofile(fileName)
                        end
                    }
            }

        function ButtonModuleTestCustomCode:InitDependingOnCurrentView()
            -- override base class function
            self.Widget.visible = (dt.gui.current_view() == dt.gui.views.darkroom)
        end

        table.insert(Workflow.Buttons, ButtonModuleTest)
        table.insert(Workflow.Buttons, ButtonModuleTestCustomCode)
    end
end

return WorkflowButtons
