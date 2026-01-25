# Release Notes

## v2.0.0 darktable 5.4 with AgX
January 31, 2026

- support for darktable 5.4

- add new AgX module configuration as an alternative for filmic and sigmoid 
- add new demosaic capture sharpen option to reconstruct pixels from sensor data and recover details lost due to in-camera blurring
- add color look up table module with preferences
- add creator and copyright meta data as offered by metadata editor and image information module. These values are exported to jpg meta data.
- remove workflow steps for global chroma and saturation 
- add new common setting to run single step directly when single setting changes
- support new module preset names (with dt5.2 and 5.4)

- after updating to a new major version of this script, your settings will be reset to their default values.
- some minor refactoring
- use enable as new default basic setting instead of reset

## v1.5.1 Pre-Release bugfix: Prevent exception, if requiring a submodule fails
December 1, 2024

- prevent exception, if requiring a submodule fails
- extend lua package.path if neccessary
- submodules are now named more "unique"
- rename Modules folder to "lib"
- submodules are no longer displayed in the script manager

## v1.5.0 Pre-Release for darktable 4.9
November 25, 2024

- supports darktable 4.9 / 5.0
- new option for color calibration module: set white balance to detected from area
- refactoring, split source files
- user interface: separate module configuration and other settings
- show progress bar during script run
- option to cancel current script run
- some minor bugfixes
- tested with dt4.9.0+1170 (2024-11-25)

## v1.4.0 Support darktable 4.8
June 30, 2024

- some minor changes to support darktable 4.8 (new option in whitebalance module).

## v1.3.0 Create release archive
June 22, 2023

- create release archive to simplify script manager integration

## v1.2.0 Extended configuration and language support
June 17, 2023

- reorganized and more flexible user interface.
- new options, more supported modules in darkroom view.
- support for additional languages for the main controls, depending on the configuration in the darktable settings.

## v1.1.0 German translation
May 21, 2023

- depending on the configuration, the script outputs are now in English or German.
- the basis for further translations has been prepared.

## v1.0.1 Bugfix release.
April 3, 2023

- Bugfix: Enable buttons depending on darktable view. Avoid darktable crash.

## v1.0.0 First release.
March 30, 2023

- this is the first release of the Initial Workflow Module for darktable.

- darktable 4.2.1 and 4.3.0 (in preparation for 4.4) are supported.