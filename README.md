# Darktable-Initial-Workflow-Module
This script offers a new "inital workflow" module both in lighttable and darkroom view. It can be used to do some configuration for an initial image workflow. It calls some automatisms of different modules in the darkroom view. If this suits your workflow, the script saves some clicks and time.

# Usage
See Darktable documentation for your first steps: https://docs.darktable.org/usermanual/4.2/en/lua/

Require this script from your luarc file, add the path of this file to .config/darktable/luarc: require "examples/InitialWorkflowModule"

Execute "darktable -d lua" to get some loggings.

# Workflow Steps
This script executes some automatic functions that can also be accessed via the GUI (magic wand). It provides several workflow steps like "lens correction" or "adapt exposure". If you use it from lighttable view, you can select one or more images and configure offered settings. Clicking the run button, selected image(s) are opened in darkroom and all steps are performed as configured.

If you use it from darkroom view, the currently opened image is processed.

Several steps are offered. See the tooltip within the module for more information.

Your settings are saved in Darktable preferences and restored after the next start of the application.

You can easily customize steps or add new ones. See "IMPLEMENTATION OF WORKFLOW STEPS".
 
There is one step to adjust the white balance by altering the temperature. This step is "unchanged" by default for the legacy workflow. The white balance is only adjusted by default for the modern workflow of Darktable. See Darktable preferences chapter "processing", setting auto-apply chromatic adaptation defaults.
