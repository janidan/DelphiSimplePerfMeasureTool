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
unit ReportGenerator;

interface

uses
  DebuggerApi,
  CoverageStatsApi,
  ClassInfoUnit,
  CoverageConfiguration;

procedure GenerateReports( const aCoverageConfiguration: ICoverageConfiguration; const aBreakpointList: IBreakPointList; const aModuleInfoList: TModuleList );

implementation

uses
  CoverageStats,
  HTMLReport,
  XMLReport,
  ConsoleReport;

procedure GenerateReports( const aCoverageConfiguration: ICoverageConfiguration; const aBreakpointList: IBreakPointList; const aModuleInfoList: TModuleList );
var
  ModuleStats: ICoverageStats;
  UnitStats: ICoverageStats;
  BreakPoint: IBreakPoint;
  BreakPointDetail: TBreakPointDetail;
  vCoverageStats: ICoverageStats;
begin
  aCoverageConfiguration.LogManager.Log( 'ProcedureReport' );

  vCoverageStats := TCoverageStats.Create( 'All', '', nil );

  ModuleStats := nil;
  UnitStats := nil;

  for BreakPoint in aBreakpointList.GetBreakPoints do
  begin
    BreakPointDetail := BreakPoint.Details;
    ModuleStats := vCoverageStats.GetCoverageReport( BreakPointDetail.ModuleName, BreakPoint.Module.Filename );
    UnitStats := ModuleStats.GetCoverageReport( BreakPointDetail.UnitName, BreakPointDetail.UnitFileName );
    UnitStats.AddLineCoverage( BreakPointDetail.Line, BreakPoint.BreakCount );
  end;

  vCoverageStats.Calculate;

  aCoverageConfiguration.LogManager.Log( 'Generating reports' );

  if ( aCoverageConfiguration.HtmlOutput ) then
    GenerateHtmlReport( aCoverageConfiguration, vCoverageStats, aModuleInfoList );

  if ( aCoverageConfiguration.XmlOutput ) then
    GenerateXmlReport( aCoverageConfiguration, vCoverageStats, aModuleInfoList );

  if ( aCoverageConfiguration.ConsoleSummary ) then
    GenerateConsoleReport( aCoverageConfiguration, vCoverageStats, aModuleInfoList );
end;

end.
