# Delphi Performance Tool

## Introduction
Delphi Performance Tool is derived from the Delphi Code Coverage (https://github.com/DelphiCodeCoverage/DelphiCodeCoverage).
Its intention is to collect simple timing/performance data for an application created in Delphi with the use of detailed MAP files.

## License
This Source Code Form is subject to the terms of the Mozilla Public License, 
v. 2.0. If a copy of the MPL was not distributed with this file, 
You can obtain one at http://mozilla.org/MPL/2.0/.

## Preconditions
The application you want to run a must be built in a configuration that generates a detailed MAP file.

## What kind of measurements does it do
The tool collects the hitcount, minimal-, maximal-, average- and total time of a method call.
From its legacy of the Code Coverage it also collects simple line coverage statistics.

## Coverage of DLLs and BPLs
For applications who uses Borland Package Libraries (which are essentially DLLs) or external DLLs, DCC will attempt to 
load a .map file for each DLL and if it exists and units in those libraries are part of the covered units, 
code coverage will span the DLL/BPL loaded as part of the application. The .map file need to exist in the same 
directory as the dll that was loaded.

## Usage
Please see the commandline information on usage.

### Delphi compatibility
The current tool is compatible with Delphi 10.3, 10.4 and 11.0. 
If you find that it works for other Delphi versions thats great. 
I do not intend to make it compile with older versions of Delphi.

### Sponsors
Delphi Code Coverage: 1.0 release was made possible through the generous support of DevFactory and the developers of this product.

### Switches
Please consult the command line for a full list of supported switches.
<table>
    <tr><td><code>-e Executable.exe</code></td><td>The executable to run (alternatively the dproj switch can be used)</td></tr>
	<tr><td><code>-a Param Param2</code></td><td>Parameters to pass on to the application that shall be checked for code coverage. ^ is an escape character</td></tr>
	<tr><td><code>-sym directory</code></td><td>Directory that contains the map files. Default will be the directory of the executable</td></tr>
	<tr><td><code>-u TestUnit TestUnit2</code></td><td>The units that shall be monitored</td></tr>
    <tr><td><code>-uf filename</code></td><td>Cover units listed in the file pointed to by filename. One unit per line in the file</td></tr>
	<tr><td><code>-proc FullyQualifiedMethodName1 FullyQualifiedMethodNameN</code></td><td>Name of the method to track.</td></tr>
	<tr><td><code>-procf filename</code></td><td>Methods listed in the file will be monitored. One method per line.</td></tr>
    <tr><td><code>-groupproj MyProjects.group</code></td><td>Delphi projects group file. The units of the projects contained in the groups will be added to the units list</td></tr>
	<tr><td><code>-dproj MyProject.dproj</code></td><td>Delphi project file. All the units in this project will be added to the units list.</td></tr>
	<tr><td><code>-sp directory directory2</code></td><td>The directories where the source can be found. A wildcard at the end of a directory will add all directories containing .pas files.</td></tr>
    <tr><td><code>-spf filename</code></td><td>Use source directories listed in the file pointed to by filename. One directory per line in the file</td></tr>    
	<tr><td><code>-lt [filename]</code></td><td>Log events to a text log file. Default file name is: Delphi-Code-Coverage-Debug.log</td></tr>
    <tr><td><code>-lcon</code></td><td>Log events to the Windows console</td></tr>
    <tr><td><code>-od directory</code></td><td>The directory where the output files will be put - note - the directory must exist</td></tr>  
    <tr><td><code>-xml</code></td><td>Generate xml output - Generate xml output as 'Results.xml' in the output directory.</td></tr>
    <tr><td><code>-html</code></td><td>Generate html output - Generate html output as 'index.html' in the output directory.</td></tr>
	<tr><td><code>-summary</code></td><td>Generate Console summary output - Generates a console output for the timings. If no other output format is given this will also be done.</td></tr>
	<tr><td><code>-dump</code></td><td>Outputs all available procedures for tracking to the console.</td></tr>
</table>
