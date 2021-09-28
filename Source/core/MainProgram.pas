(***********************************************************************)
(* Delphi Simple Performance Measurement Tool                          *)
(*                                                                     *)
(* This code is based on the code for Delphi Code Coverage             *)
(* A quick hack of a Code Coverage Tool for Delphi                     *)
(* by Christer Fahlgren and Nick Ring                                  *)
(* Adapted to be a profiler by Tobias Rörig                            *)
(*                                                                     *)
(* This Source Code Form is subject to the terms of the Mozilla Public *)
(* License, v. 2.0. If a copy of the MPL was not distributed with this *)
(* file, You can obtain one at http://mozilla.org/MPL/2.0/.            *)
unit MainProgram;

interface

procedure ExecuteProgram;
procedure PrintUsage;

implementation

uses
  Debugger,
  ReportGenerator,
  CoverageConfiguration,
  LoggerConsole,
  LogManager,
  EntryPointDump;

procedure ExecuteProgram;
var
  vCoverageConfiguration: ICoverageConfiguration;
  vReason: String;

  vDebugger: TDebugger;
  vDebuggerResult: TDebuggerResult;
begin
  vCoverageConfiguration := TCoverageConfiguration.Create( G_LogManager );
  if not vCoverageConfiguration.IsComplete( vReason ) then
  begin
    ConsoleOutput( 'The configuration was incomplete due to the following error:' );
    ConsoleOutput( vReason );
    PrintUsage;
    Exit;
  end;

  if vCoverageConfiguration.EntryPointDump then
  begin
    var
    vLogger := TLoggerConsole.Create;
    GenerateEntryPointDump( vCoverageConfiguration, vLogger );
    Exit;
  end;

  vDebugger := TDebugger.Create( vCoverageConfiguration );
  try
    vDebuggerResult := vDebugger.Start;

    if vDebuggerResult = TDebuggerResult.Success then
      GenerateReports( vCoverageConfiguration, vDebugger.BreakPoints, vDebugger.ModuleList );
  finally
    vDebugger.Free;
  end;
end;

procedure PrintUsage;
begin
  ConsoleOutput( 'Usage: PerfMeasure.exe [switches]' );
  ConsoleOutput( 'List of switches:' );
  // --------------------------------------------------------------------------
  ConsoleOutput( '' );
  ConsoleOutput( 'Mandatory switches:' );
  ConsoleOutput( cPARAMETER_EXECUTABLE + ' executable.exe   -- the executable to run' );
  ConsoleOutput( 'or' );
  ConsoleOutput( cPARAMETER_DPROJ + ' Project.dproj -- Delphi project file' );
  ConsoleOutput( '' );
  ConsoleOutput( 'Optional switches:' );
  ConsoleOutput( cPARAMETER_SYMBOL_ROOT + ' directory      -- the directory where mapfiles are located' );
  ConsoleOutput( cPARAMETER_UNIT + ' unit1 unit2 etc  -- a list of units to create reports for.' );
  ConsoleOutput( cPARAMETER_UNIT_FILE + ' filename        -- a file containing a list of units to create' );
  ConsoleOutput( '                       reports for - one unit per line' );
  ConsoleOutput( cParameter_Monitor_Proc + ' FullyQualifiedMethodName1 FullyQualifiedMethodNameN -- Name of the method to track.' );
  ConsoleOutput( cPARAMETER_GROUPPROJ + ' MyProjects.group -- Delphi projects group file. The units of the projects' );
  ConsoleOutput( '                       contained in the groups will be added to the covered units list' );
  ConsoleOutput( cPARAMETER_OUTPUT_DIRECTORY + ' directory       -- the output directory where reports shall be' );
  ConsoleOutput( '                       generated - default is current directory' );
  ConsoleOutput( cPARAMETER_EXECUTABLE_PARAMETER + ' param param2 etc -- a list of parameters to be passed to the' );
  ConsoleOutput( '                       application. Escape character:' + cESCAPE_CHARACTER + ' (if using from command-line or batch file, use ' +
    cESCAPE_CHARACTER + cESCAPE_CHARACTER + ')' );
  ConsoleOutput( cPARAMETER_LOGGING_TEXT + ' [filename]      -- Enable text logging, specifying filename. Default' );
  ConsoleOutput( '                       file name is:' + cDEFULT_DEBUG_LOG_FILENAME );
  ConsoleOutput( cPARAMETER_LOGGING_CONSOLE + '               -- Use Console for debug output.' );
  ConsoleOutput( '                       Note: Gives duplicate entries when used together with verbose output.' );
  ConsoleOutput( cPARAMETER_SOURCE_PATHS + ' directories     -- the directory(s) where source code is located -' );
  ConsoleOutput( '                       default is current directory. The given order of this list defines the search order.' );
  ConsoleOutput( cPARAMETER_SOURCE_PATHS_FILE + ' filename       -- a file containing a list of source path(s) to' );
  ConsoleOutput( '                       check for any units to report on' );
  ConsoleOutput( cPARAMETER_XML_OUTPUT + '                -- Output xml report as CodeCoverage_Summary.xml in the output directory' );
  ConsoleOutput( cPARAMETER_HTML_OUTPUT + '               -- Output html report as index.html in the output directory' );
  ConsoleOutput( cPARAMETER_DUMP_ENTRY_POINTS + '               -- Outputs all available entry points in this configuration to the console' );

end;

end.
