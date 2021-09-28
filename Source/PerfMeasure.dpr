(***********************************************************************)
(* Delphi Code Coverage                                                *)
(*                                                                     *)
(* A quick hack of a Code Coverage Tool for Delphi                     *)
(* by Christer Fahlgren and Nick Ring                                  *)
(* Portions by Tobias Rörig                                            *)
(*                                                                     *)
(* This Source Code Form is subject to the terms of the Mozilla Public *)
(* License, v. 2.0. If a copy of the MPL was not distributed with this *)
(* file, You can obtain one at http://mozilla.org/MPL/2.0/.            *)
program PerfMeasure;
{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  CoverageStatsApi in 'api\CoverageStatsApi.pas',
  DebuggerApi in 'api\DebuggerApi.pas',
  LoggingApi in 'api\LoggingApi.pas',
  HTMLReport in 'reports\HTMLReport.pas',
  HtmlHelper in 'reports\HtmlHelper.pas',
  XMLReport in 'reports\XMLReport.pas',
  CoverageStats in 'core\CoverageStats.pas',
  Debugger in 'core\Debugger.pas',
  DebuggerUtils in 'core\DebuggerUtils.pas',
  DebugModule in 'core\DebugModule.pas',
  DebugProcess in 'core\DebugProcess.pas',
  DebugThread in 'core\DebugThread.pas',
  CoverageConfiguration in 'core\CoverageConfiguration.pas',
  BreakPoint in 'core\BreakPoint.pas',
  BreakpointList in 'core\BreakpointList.pas',
  ClassInfoUnit in 'core\ClassInfoUnit.pas',
  LogManager in 'core\Loggers\LogManager.pas',
  LoggerDebugAPI in 'core\Loggers\LoggerDebugAPI.pas',
  LoggerConsole in 'core\Loggers\LoggerConsole.pas',
  LoggerTextFile in 'core\Loggers\LoggerTextFile.pas',
  ConfigUnitList in 'core\ConfigUnitList.pas',
  ConsoleReport in 'reports\ConsoleReport.pas',
  MainProgram in 'core\MainProgram.pas',
  ReportGenerator in 'reports\ReportGenerator.pas',
  EntryPointDump in 'reports\EntryPointDump.pas';

// -dproj ..\..\Source\Sample\SimpleSample.dproj -od report -lcon -u BplUnit BplUnit.Second mainForm SimpleSample -html -xml
// -e ..\..\build\Win32\SimpleSample.exe -m ..\..\build\Win32\SimpleSample.map -sd ..\..\Source -od report -lcon -u BplUnit BplUnit.Second mainForm SimpleSample -html -xml
begin
  try
    ExecuteProgram;
  except
    on E: Exception do
    begin
      WriteLn( E.ClassName, ': ', E.message );
      PrintUsage;
    end;
  end;
  {$IFDEF DEBUG}
  WriteLn( 'Press Enter to continue.' );
  Readln;
  {$ENDIF}

end.
