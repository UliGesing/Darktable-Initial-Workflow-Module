# Darktable-Initial-Workflow-Module
This script can be used together with darktable. See https://www.darktable.org/ for more information.

This script offers a new "inital workflow" module both in lighttable and darkroom view. It can be used to do some configuration for an initial image workflow. It calls some automatisms of different modules in the darkroom view. If this suits your workflow, the script saves some clicks and time.

# Usage
See Darktable documentation for your first steps: https://docs.darktable.org/usermanual/4.2/en/lua/

Require this script from your luarc file, add the path of this file to .config/darktable/luarc: 
require "examples/InitialWorkflowModule"

Execute "darktable -d lua" to get some loggings.

# Workflow Steps
This script executes some automatic functions that can also be accessed via the GUI (magic wand). It provides several workflow steps like "lens correction" or "adapt exposure". If you use it from lighttable view, you can select one or more images and configure offered settings. Clicking the run button, selected image(s) are opened in darkroom and all steps are performed as configured.

If you use it from darkroom view, the currently opened image is processed.

Several steps are offered. See the tooltip within the module for more information.

Your settings are saved in Darktable preferences and restored after the next start of the application.

You can easily customize steps or add new ones. See "IMPLEMENTATION OF WORKFLOW STEPS".
 
There is one step to adjust the white balance by altering the temperature. This step is "unchanged" by default for the legacy workflow. The white balance is only adjusted by default for the modern workflow of Darktable. See Darktable preferences chapter "processing", setting auto-apply chromatic adaptation defaults.

# Add new or modify workflow steps

All steps are derived from a base class to offer common methods. You can easily customize steps or add new ones: Just copy an existing class and adapt the label, tooltip and function accordingly. Copy and adapt Constructor, Init and Run functions. Don't forget to customize the name of the class as well. Use the new class name for Constructor, Init and Run functions.

By adding it to the "WorkflowSteps" table, the step is automatically displayed and executed. The order in the GUI is the same as the order of declaration here in the code. The order during execution is from bottom to top, along the pixel pipeline.

Using Darktable 4.2 you can get the lua command in this way: Follow https://darktable-org.github.io/dtdocs/en/preferences-settings/shortcuts/ and click on the small icon in the top panel as described in “assigning shortcuts to actions”. You enter visual shortcut mapping mode. Point to a module or GUI control. Within the popup you can read the lua command.

Every workflow step contains of constructor, init and run functions. Example:
- StepCompressHistoryStack = WorkflowStepCombobox:new():new {[...]} to create the new instance.
- function StepCompressHistoryStack:Init() to define combobox values and create the widget.
- function StepCompressHistoryStack:Run() to execute the step
- table.insert(WorkflowSteps, StepCompressHistoryStack) to collect all steps and execute some common things.

# Module Tests

There is an additional file "InitialWorkflowModuleTest.lua". This implements the "TEST" button. This special button, used to perform module tests, should be disabled for general use of the script. It is used during module development and deployment. To enable this button, toggle comment out and add it to the widget in function GetWidgets.

--dofile "InitialWorkflowModuleTest.lua" in main script file.
--table.insert(WorkflowButtons, ButtonModuleTest)

Up to now, there is a simple module test that iterates over workflow steps and combobox value settings and sets different combinations of module settings. Resulting xmp files are copied to a test result folder. You can compare these files with previously generated reference files.
