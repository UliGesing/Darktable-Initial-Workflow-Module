# darktable Initial Workflow Module

## Releases

- You can download the newest release archive from https://github.com/UliGesing/Darktable-Initial-Workflow-Module/releases

## Introduction

- This script can be used together with darktable. See https://www.darktable.org/ for more information.

- Do you use darktable to develop your raw images? Do you often follow the same initial steps for new images? Do you often use the same modules in darkroom view and configure them in the same way before going into the details? Then this script can save you work.

>><img src="ReadmeImages/ScreenshotModuleIntroduction.png" width=450>

- It offers a new "inital workflow" module both in lighttable and darkroom view. It executes some automatic functions that can also be accessed via the graphical user interface (e.g. magic wand controls). It can be used to do some configuration for an initial image workflow. To do this, the new module provides several workflow steps like "lens correction" or "adapt exposure". It calls some automatisms of different modules in darkroom view, enables your preferred modules and configures some default settings. If this suits your workflow, the script saves some clicks and time.

- This script performs tasks that are comparable to those of the module presets. Depending on your current use case, one or the other is more suitable. Presets are faster, but more static. The script uses some algorithms in darktable, so it takes more time. It mimics manual editing by the user and therefore "reacts" more to the specific image.

## Usage

### New darktable module

- This chapter describes how to use the script. Detailed installation instructions follow below.

- The new module offers some buttons, a list of configurable darktable modules and some common options, both in lighttable and darkroom view. Feel free to use these configurations and options in any order or combination.

- In preparation for running the script, use the following buttons in darkroom view to rotate the image, adjust the perspective, crop the image and to adjust the exposure until the mid-tones are clear enough. These buttons activate and display the associated module. <br>
>><img src="ReadmeImages/ScreenshotModulePreparingSteps.png" width=350>

### Configuration

#### Subpages "Modules" and "Settings"

- The new module offers two subpages: First of all a list of supported modules and secondly a list of some common settings. You can switch between these subpages by selecting one of the buttons "show modules" or "show settings".

>><img src="ReadmeImages/ScreenshotModuleSettingsSubpages.png" width=450>

#### Subpage "Modules"

- Choose "show modules" and adapt your personal configuration for each step of the entire workflow. Several steps and configurations are offered, see the tooltips within the module for more information. Each step of the workflow addresses a module of the pipeline in the darktable darkroom view. Your settings are saved in darktable preferences and restored after the next start of the application

>><img src="ReadmeImages/ScreenshotModuleDefaults.png" width=450>

- Every step provides two configurations: The first one is a basic configuration that is applied before actually performing the main configuration. You can decide, if you want to ignore, enable, reset or disable the module. There are various possibilities:

>><img src="ReadmeImages/ScreenshotModuleStepConfigurationBasic.png" width=100>
>- The predefined <code>default</code> value (one of the following) can be set.
>- The workflow step can be <code>ignored</code> at all, the corresponding module remains unchanged, regardless of the second setting.
>- The module can first be <code>enabled</code> in order to apply the selected configuration afterwards, based on current module settings.
>- A module <code>reset</code> can be carried out, the selected configuration is then applied based on default module settings.
>- The module can be <code>disabled</code> without making any further changes and regardless of the second setting.

- The second configuration depends on your first and basic configuration. If the basic configuration is set to <code>reset</code> or <code>enable</code>, the second configuration is applied. If you choose <code>unchanged</code>, the corresponding module keeps unchanged (apart from the basic configuration above). Each step offers several choices, for example:
<br>
>><img src="ReadmeImages/ScreenshotModuleStepConfigurationFilmic.png" width=250>

<br>
- Via <code>all module basics</code> and <code>all module settings</code> you can select standard configurations for all steps.

#### Subpage "Settings"

- Choose "show settings" and adapt the common settings. Several common settings are offered, see the tooltips for more information. Your settings are saved in darktable preferences and restored after the next start of the application.

>><img src="ReadmeImages/ScreenshotCommonSettingsSubpage.png" width=450>

- Do you want to know more about what the individual steps of the workflow change? You can activate <code>show modules</code>. During script execution in darkroom view, modules are displayed as changes are made. This way you will see the changes made. Best practices: Select <code>ignore</code> for all steps. Then activate <code>enable</code> or <code>reset</code> for the step that interests you and configure it. With <code>run</code> only this one configuration is executed and the affected module is displayed.

- Via <code>all common settings</code> you can select standard configurations for these settings. You can activate or deactive all common settings. 

### Execution

- Once the configuration is complete, execute the script using the <code>run</code> button. If you use it from lighttable view, you can select one or more images. Clicking the run button, selected image(s) are opened in darkroom and all steps are performed as configured. If you use it from darkroom view, the currently opened image is processed. The order during execution is from bottom to top, along the darktable pixel pipeline.<br>
>><img src="ReadmeImages/ScreenshotModuleRunDefaultNoneButtons.png" width=450>

- During script execution a progress bar is displayed. You can find it at the buttom of your darktable window. You can also cancel the script run using the progress bar <code>X</code> control.

>><img src="ReadmeImages/ScreenshotModuleRunProgress.png" width=450>

### Timeouts

- Some calculations take a certain amount of time. Depending on the hardware equipment also longer. This script waits and attempts to detect timeouts.If steps take much longer than expected, those steps will be aborted. You can configure the default timeout (ms). Before and after each step of the workflow, the script waits this time. In other places also a multiple (loading an image) or a fraction (querying a status).<br>

>><img src="ReadmeImages/ScreenshotModuleStepConfigurationTimeout.png" width=250>

## Installation

### Prerequisites

- This script requires darktable 5.0. The script was developed and tested on Linux (Arch-based EndeavourOs), but it should also work on Windows. You need darktable and Lua installed on your machine. See darktable documentation for your first steps: https://docs.darktable.org/usermanual and choose chapter "Scripting with Lua" in the left panel.

### Lua examples folder

Some examples and contributed scripts come with your darktable lua installation. The initial module script can be installed at the same place.

- lua script folders on Linux: <br><code>/home/[user_name]/.config/darktable/lua/examples</code>

- lua script folders on Windows: <br><code>%LocalAppData%/darktable/lua/examples</code>

### Download Initial-Workflow-Script

- Download the newest release archive <code>InitialWorkflowModule.zip</code> from https://github.com/UliGesing/Darktable-Initial-Workflow-Module/releases. Extract this archive and all contained folders to your darktable lua script examples folder. 

- After installation, your folder structure at <code>[...]/darktable/lua/examples/InitialWorkflowModule/</code> should look like this. The main script <code>InitialWorkflowModule.lua</code> uses some modules in the lib folder.

>><img src="ReadmeImages/ScreenshotInstallationFolder.png" width=250>

### Integration in darktable luarc file

After extracting the archive, you have to integrate it into darktable (more precisely in the named luarc file), using one of the following methods. At startup, darktable will automatically run luarc. All lua scripts are integrated and started from this file. You can find it here:<br>

- luarc directory on Linux: <br> <code>/home/[user_name]/.config/darktable</code>

- luarc directory on Windows: <br> <code>%LocalAppData%/darktable</code>

#### Installation method 1: Using darktable script manager

- edit your luarc file to activate the script manager. The luarc file should contain the following line of code. Restart darktable and use darktable script manager to start the script, see https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/tools/script_manager/ for details

- in luarc:<br><code>require "tools/script_manager"</code>
- there should be no second entry in luarc to require the InitialWorkflowModule from here
- start it from darktable script manager examples:

>><img src="ReadmeImages/ScreenshotInstallationScriptManager.png" width=250>

#### Installation method 2: Require from luarc directly

- edit your luarc file to integrate the initial workflow script directly, without using darktable script manager. Add a new line to your luarc file starting with <code>require</code> and the path of the script file. Restart darktable, the initial workflow script is executed and displayed as a new module.

- in luarc:<br><code>require "examples.InitialWorkflowModule.InitialWorkflowModule"</code>

#### Installation method 3: Use any other script folder

- you can extract the script archive to any other folder, e.g. your git repository directory. Edit your luarc file to extend the package path and to require the script. Add the following two lines of code and adjust the path name. Restart darktable, the initial workflow script is executed and displayed as a new module.

- in luarc: <br><code>package.path = package.path .. ";[any path]/InitialWorkflowModule/?.lua"<br>
require "InitialWorkflowModule"</code>

### Logging

- You can execute darktable with additional parameters <code>darktable -d lua</code> or <code>darktable.exe -d lua</code> to get some loggings. This is very helpful to see what is going on during script execution and to identify errors. On Windows, logging messages are written to a logfile, see https://www.darktable.org/about/faq/#faq-windows-logs. On Linux, logging messages are written to your command line.

## Request for Change

### Transmit your requirements

- Do you have any suggestions for further steps or options? Which darkroom modules do you use most often? With which settings does your own workflow start? Just let me know or see the description below how to do it yourself.

### Localisation

- This script should work with different user interface languages, as configured in darktable preferences. Do you want to translate script outputs into your language? Please let me know. Together we can do that. After a short training, it's fairly easy to deal with gettext tools, .po files, .mo files and to upload your translation to the Github repository. You don't have to be a programmer for this, the translation is done in separate text files.

### Add new or modify workflow steps

- To modify the script, clone the whole repository or download Source.zip archive. You can easily customize steps or add new ones. These steps are implemented in a separate lua file "WorkflowSteps.lua" in subfolder "Modules". You can find more details within this file.

### Module Tests

- The git repository provides some additional files to execute module tests. This is used during module development and deployment. Within the script code there is an additional and optional module test implementation. This should be disabled and not visible for general use of the script. You can find it in file "ModuleTests.lua" in subfolder "Modules". You can find more details within this file.
