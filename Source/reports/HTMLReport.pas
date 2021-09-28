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
unit HTMLReport;

interface

uses
  System.Classes,
  System.TimeSpan,
  CoverageStatsApi,
  CoverageConfiguration,
  ClassInfoUnit,
  LoggingApi;

type
  THtmlDetails = record
    LinkFileName: string;
    LinkName: string;
    HasFile: Boolean;
  end;

type
  THTMLCoverageReport = class
  strict private
    FCoverageConfiguration: ICoverageConfiguration;

    procedure AddTableHeader( const aTableHeading: string; const aColumnHeading: string; const aOutputFile: TTextWriter );
    procedure IterateOverModulesStats( const aCoverageStats: ICoverageStats; const aModuleInfoList: TModuleList; const aOutputFile: TTextWriter ); overload;
    procedure IterateOverModuleStats( const aCoverageStats: ICoverageStats; const aModuleInfo: TModuleInfo; const aOutputFile: TTextWriter );
    procedure AddTableFooter( const aHeading: string; const aCoverageStats: ICoverageStats; const aOutputFile: TTextWriter );

    procedure AddTimingTableHeader( const aTableHeading: string; const aOutputFile: TTextWriter );
    procedure AddTimingStatistics( const aUnit: TUnitInfo; const aOutFile: TTextWriter ); overload;
    procedure AddTimingStatistics( const aModule: TModuleInfo; const aOutFile: TTextWriter ); overload;
    procedure AddTimingStatistics( const aModuleList: TModuleList; const aOutFile: TTextWriter ); overload;

    procedure AddTimingTableFooter( const aOutputFile: TTextWriter );

    procedure SetPrePostLink( const aHtmlDetails: THtmlDetails; out PreLink: string; out PostLink: string );

    procedure AddPostAmble( const aOutFile: TTextWriter );
    procedure AddPreAmble( const aOutFile: TTextWriter );

    procedure AddStatistics( const aCoverageBase: ICoverageStats; const aOutFile: TTextWriter );

    function GenerateModuleReport( const aCoverageModule: ICoverageStats; const aModuleInfo: TModuleInfo ): THtmlDetails;
    function GenerateUnitReport( const aCoverageUnit: ICoverageStats; const aUnit: TUnitInfo ): THtmlDetails;

    function FindSourceFile( const aCoverageUnit: ICoverageStats ): string;
    procedure GenerateCoverageTableForUnit( const aCoverageUnit: ICoverageStats; const aOutputFile: TTextWriter );
  public
    constructor Create( const ACoverageConfiguration: ICoverageConfiguration );

    procedure Generate( const aCoverage: ICoverageStats; const aModuleInfoList: TModuleList );
  end;

procedure GenerateHtmlReport( const ACoverageConfiguration: ICoverageConfiguration; const aCoverage: ICoverageStats; const aModuleInfoList: TModuleList );

implementation

uses
  SysUtils,
  System.Math,
  JclFileUtils,
  JvStrToHtml,
  DebuggerUtils,
  HtmlHelper,
  LogManager;

procedure GenerateHtmlReport( const ACoverageConfiguration: ICoverageConfiguration; const aCoverage: ICoverageStats; const aModuleInfoList: TModuleList );
var
  vReport: THTMLCoverageReport;
begin
  vReport := THTMLCoverageReport.Create( ACoverageConfiguration );
  try
    vReport.Generate( aCoverage, aModuleInfoList );
  finally
    vReport.Free;
  end;
end;

const
  SourceClass: string = ' class="s"';
  OverviewClass: string = ' class="o"';
  SummaryClass: string = ' class="sum"';

procedure THTMLCoverageReport.Generate( const aCoverage: ICoverageStats; const aModuleInfoList: TModuleList );
var
  OutputFile: TTextWriter;
  OutputFileName: TFileName;
begin
  FCoverageConfiguration.LogManager.Log( 'Generating coverage report' );
  FCoverageConfiguration.LogManager.Log( 'Output dir: ' + FCoverageConfiguration.OutputDir );
  ForceDirectories( FCoverageConfiguration.OutputDir );

  OutputFileName := PathAppend( FCoverageConfiguration.OutputDir, 'index.html' );
  OutputFile := TStreamWriter.Create( OutputFileName, False, TEncoding.UTF8 );
  try
    AddPreAmble( OutputFile );
    OutputFile.WriteLine( heading( 'Summary Report', 1 ) );

    AddTableHeader( 'Aggregate statistics for all modules', 'Unit Name', OutputFile );
    IterateOverModulesStats( aCoverage, aModuleInfoList, OutputFile );
    AddTableFooter( 'Aggregated for all units', aCoverage, OutputFile );

    AddTimingTableHeader( aCoverage.Name, OutputFile );
    AddTimingStatistics( aModuleInfoList, OutputFile );
    AddTimingTableFooter( OutputFile );

    AddPostAmble( OutputFile );
  finally
    OutputFile.Free;
  end;
end;

procedure THTMLCoverageReport.GenerateCoverageTableForUnit( const aCoverageUnit: ICoverageStats; const aOutputFile: TTextWriter );
  procedure WriteTableRow( const aClass: string; const aLineCnt: Integer; const aCount: Integer; const aLineContent: string );
  var
    vHtmlLineCount: string;
  begin
    if ( aCount <= 0 ) then
      vHtmlLineCount := td( '' ) // vCount is blank
    else
      vHtmlLineCount := td( IntToStr( aCount ) ); // vCount is given

    aOutputFile.WriteLine( tr( td( IntToStr( aLineCnt ) ) + vHtmlLineCount + td( pre( aLineContent ) ), 'class="' + aClass + '"' ) );
  end;

var
  vSourceFileName: string;
  vInputFile: TTextReader;
  vLineCoverage: TCoverageLine;
  vInputLine: string;
  vCurrentLine: Integer;
begin
  vSourceFileName := FindSourceFile( aCoverageUnit );
  if not FileExists( vSourceFileName ) then
  begin
    aOutputFile.WriteLine( Format( 'Source file (%s) not found. ', [vSourceFileName] ) );
    Exit;
  end;

  try
    vInputFile := TStreamReader.Create( vSourceFileName, TEncoding.ANSI, True );
  except
    on E: EFileStreamError do
    begin
      aOutputFile.WriteLine( Format( 'Exception during source file (%s) access. ', [vSourceFileName] ) );
      Exit;
    end;
  end;
  try
    vCurrentLine := 1;
    aOutputFile.WriteLine( StartTag( 'table', SourceClass ) );
    while vInputFile.Peek <> -1 do
    begin
      vInputLine := JvStrToHtml.StringToHtml( TrimRight( vInputFile.ReadLine ) );
      if aCoverageUnit.TryGetLineCoverage( vCurrentLine, vLineCoverage ) then
      begin
        if vLineCoverage.IsCovered then
          WriteTableRow( 'covered', vCurrentLine, vLineCoverage.LineCount, vInputLine )
        else
          WriteTableRow( 'notcovered', vCurrentLine, 0, vInputLine );
      end
      else
        WriteTableRow( 'nocodegen', vCurrentLine, 0, vInputLine );
      Inc( vCurrentLine );
    end;
    aOutputFile.WriteLine( EndTag( 'table' ) );
  finally
    vInputFile.Free;
  end;
end;

function THTMLCoverageReport.GenerateModuleReport( const aCoverageModule: ICoverageStats; const aModuleInfo: TModuleInfo ): THtmlDetails;
var
  OutputFile: TTextWriter;
  OutputFileName: string;
begin
  try
    Result.HasFile := False;
    Result.LinkFileName := aCoverageModule.Name + '.html';
    Result.LinkName := aCoverageModule.Name;

    OutputFileName := PathAppend( FCoverageConfiguration.OutputDir, Result.LinkFileName );

    OutputFile := TStreamWriter.Create( OutputFileName, False, TEncoding.UTF8 );
    try
      AddPreAmble( OutputFile );
      OutputFile.WriteLine( p( 'Report for ' + bold( aCoverageModule.Name ) + '.' ) );

      AddTableHeader( 'Aggregate statistics for all units', 'Source File Name', OutputFile );
      IterateOverModuleStats( aCoverageModule, aModuleInfo, OutputFile );
      AddTableFooter( 'Aggregated for all files', aCoverageModule, OutputFile );

      AddTimingTableHeader( aCoverageModule.Name, OutputFile );
      AddTimingStatistics( aModuleInfo, OutputFile );
      AddTimingTableFooter( OutputFile );

      AddPostAmble( OutputFile );
    finally
      OutputFile.Free;
    end;
    Result.HasFile := True;
  except
    on E: EFileStreamError do
      ConsoleOutput( 'Exception during generation of unit coverage for:' + aCoverageModule.Name + ' could not write to: ' + OutputFileName + ' exception:' +
        E.message )
    else
      raise;
  end;
end;

function THTMLCoverageReport.GenerateUnitReport( const aCoverageUnit: ICoverageStats; const aUnit: TUnitInfo ): THtmlDetails;
var
  OutputFile: TTextWriter;
  OutputFileName: string;
begin
  Result.HasFile := False;
  Result.LinkFileName := aCoverageUnit.ReportFileName + '.html';
  Result.LinkName := aCoverageUnit.Name;

  try
    OutputFileName := Result.LinkFileName;
    OutputFileName := PathAppend( FCoverageConfiguration.OutputDir, OutputFileName );
    try
      OutputFile := TStreamWriter.Create( OutputFileName, False, TEncoding.UTF8 );
      try
        AddPreAmble( OutputFile );
        OutputFile.WriteLine( p( 'Coverage report for [' + bold( aCoverageUnit.Parent.Name + '] ' + aCoverageUnit.Name ) + '.' ) );
        AddStatistics( aCoverageUnit, OutputFile );

        AddTimingTableHeader( aCoverageUnit.Name, OutputFile );
        AddTimingStatistics( aUnit, OutputFile );
        AddTimingTableFooter( OutputFile );

        GenerateCoverageTableForUnit( aCoverageUnit, OutputFile );
        AddPostAmble( OutputFile );
      finally
        OutputFile.Free;
      end;
    except
      on E: EFileStreamError do
      begin
        ConsoleOutput( 'Exception during generation of unit coverage for:' + aCoverageUnit.Name + ' could not write to:' + OutputFileName );
        ConsoleOutput( 'Current directory:' + GetCurrentDir );
        raise;
      end;
    end;
    Result.HasFile := True;

  except
    on E: EFileStreamError do
      ConsoleOutput( 'Exception during generation of unit coverage for:' + aCoverageUnit.Name + ' exception:' + E.message )
    else
      raise;
  end;
end;

procedure THTMLCoverageReport.IterateOverModulesStats( const aCoverageStats: ICoverageStats; const aModuleInfoList: TModuleList;
  const aOutputFile: TTextWriter );
var
  HtmlDetails: THtmlDetails;
  PostLink: string;
  PreLink: string;
  CurrentStats: ICoverageStats;
begin
  for CurrentStats in aCoverageStats.GetCoverageReports do
  begin
    HtmlDetails := GenerateModuleReport( CurrentStats, aModuleInfoList.GetModuleInfo( CurrentStats.Name ) );

    SetPrePostLink( HtmlDetails, PreLink, PostLink );

    aOutputFile.WriteLine( tr( //
      td( PreLink + HtmlDetails.LinkName + PostLink ) + //
      td( IntToStr( CurrentStats.CoveredLineCount ) ) + //
      td( IntToStr( CurrentStats.LineCount ) ) + //
      td( em( IntToStr( CurrentStats.PercentCovered ) + '%' ) ) ) );
  end;
end;

procedure THTMLCoverageReport.IterateOverModuleStats( const aCoverageStats: ICoverageStats; const aModuleInfo: TModuleInfo; const aOutputFile: TTextWriter );
var
  HtmlDetails: THtmlDetails;
  PostLink: string;
  PreLink: string;
  CurrentStats: ICoverageStats;
begin
  for CurrentStats in aCoverageStats.GetCoverageReports do
  begin
    HtmlDetails := GenerateUnitReport( CurrentStats, aModuleInfo.GetUnitInfo( CurrentStats.Name ) );

    SetPrePostLink( HtmlDetails, PreLink, PostLink );

    aOutputFile.WriteLine( tr( //
      td( PreLink + HtmlDetails.LinkName + PostLink ) + //
      td( IntToStr( CurrentStats.CoveredLineCount ) ) + //
      td( IntToStr( CurrentStats.LineCount ) ) + //
      td( em( IntToStr( CurrentStats.PercentCovered ) + '%' ) ) ) );
  end;
end;

procedure THTMLCoverageReport.SetPrePostLink( const aHtmlDetails: THtmlDetails; out PreLink: string; out PostLink: string );
var
  LLinkFileName: string;
begin
  PreLink := '';
  PostLink := '';
  if aHtmlDetails.HasFile then
  begin
    LLinkFileName := StringReplace( aHtmlDetails.LinkFileName, '\', '/', [rfReplaceAll] );
    PreLink := StartTag( 'a', 'href="' + LLinkFileName + '"' );
    PostLink := EndTag( 'a' );
  end;
end;

procedure THTMLCoverageReport.AddPreAmble( const aOutFile: TTextWriter );
begin
  aOutFile.WriteLine( '<!DOCTYPE html>' );
  aOutFile.WriteLine( StartTag( 'html' ) );
  aOutFile.WriteLine( StartTag( 'head' ) );
  aOutFile.WriteLine( '    <meta content="text/html; charset=utf-8" http-equiv="Content-Type" />' );
  aOutFile.WriteLine( '    ' + WrapTag( 'Delphi CodeCoverage Coverage Report', 'title' ) );
  if FileExists( 'style.css' ) then
    aOutFile.WriteLine( '    <link rel="stylesheet" href="style.css" type="text/css" />' )
  else
  begin
    aOutFile.WriteLine( StartTag( 'style', 'type="text/css"' ) );
    aOutFile.WriteLine( 'table {border-spacing:0; border-collapse:collapse;}' );
    aOutFile.WriteLine( 'table, td, th {border: 1px solid black;}' );
    aOutFile.WriteLine( 'td, th {background: white; margin: 0; padding: 2px 0.5em 2px 0.5em}' );
    aOutFile.WriteLine( 'td {border-width: 0 1px 0 0;}' );
    aOutFile.WriteLine( 'th {border-width: 1px 1px 1px 0;}' );
    aOutFile.WriteLine( 'p, h1, h2, h3, th {font-family: verdana,arial,sans-serif; font-size: 10pt;}' );
    aOutFile.WriteLine( 'td {font-family: courier,monospace; font-size: 10pt;}' );
    aOutFile.WriteLine( 'th {background: #CCCCCC;}' );

    aOutFile.WriteLine( 'table.o tr td:nth-child(1) {font-weight: bold;}' );
    aOutFile.WriteLine( 'table.o tr td:nth-child(2) {text-align: right;}' );
    aOutFile.WriteLine( 'table.o tr td {border-width: 1px;}' );

    aOutFile.WriteLine( 'table.s {width: 100%;}' );
    aOutFile.WriteLine( 'table.s tr td {padding: 0 0.25em 0 0.25em;}' );
    aOutFile.WriteLine( 'table.s tr td:first-child {text-align: right; font-weight: bold;}' );
    aOutFile.WriteLine( 'table.s tr.notcovered td {background: #DDDDFF;}' );
    aOutFile.WriteLine( 'table.s tr.nocodegen td {background: #FFFFEE;}' );
    aOutFile.WriteLine( 'table.s tr.covered td {background: #CCFFCC;}' );
    aOutFile.WriteLine( 'table.s tr.covered td:first-child {color: green;}' );
    aOutFile.WriteLine( 'table.s {border-width: 1px 0 1px 1px;}' );

    aOutFile.WriteLine( 'table.sum tr td {border-width: 1px;}' );
    aOutFile.WriteLine( 'table.sum tr th {text-align:right;}' );
    aOutFile.WriteLine( 'table.sum tr th:first-child {text-align:center;}' );
    aOutFile.WriteLine( 'table.sum tr td {text-align:right;}' );
    aOutFile.WriteLine( 'table.sum tr td:first-child {text-align:left;}' );
    aOutFile.WriteLine( EndTag( 'style' ) );
  end;
  aOutFile.WriteLine( EndTag( 'head' ) );
  aOutFile.WriteLine( StartTag( 'body' ) );
end;

procedure THTMLCoverageReport.AddPostAmble( const aOutFile: TTextWriter );
begin
  aOutFile.WriteLine( EndTag( 'body' ) );
  aOutFile.WriteLine( EndTag( 'html' ) );
end;

procedure THTMLCoverageReport.AddStatistics( const aCoverageBase: ICoverageStats; const aOutFile: TTextWriter );
begin
  aOutFile.WriteLine( p( 'Code coverage statistics' ) );
  aOutFile.WriteLine( table( //
    tr( td( 'Number of lines covered' ) + td( IntToStr( aCoverageBase.CoveredLineCount ) ) ) + //
    tr( td( 'Number of lines with code gen' ) + td( IntToStr( aCoverageBase.LineCount ) ) ) + //
    tr( td( 'Line coverage' ) + td( IntToStr( aCoverageBase.PercentCovered ) + '%' ) ), OverviewClass ) );
  aOutFile.WriteLine( lineBreak );
end;

procedure THTMLCoverageReport.AddTableFooter( const aHeading: string; const aCoverageStats: ICoverageStats; const aOutputFile: TTextWriter );
begin
  aOutputFile.WriteLine( tr( //
    th( JvStrToHtml.StringToHtml( aHeading ) ) + //
    th( IntToStr( aCoverageStats.CoveredLineCount ) ) + //
    th( IntToStr( aCoverageStats.LineCount ) ) + //
    th( em( IntToStr( aCoverageStats.PercentCovered ) + '%' ) ) ) );
  aOutputFile.WriteLine( EndTag( 'table' ) );
end;

procedure THTMLCoverageReport.AddTableHeader( const aTableHeading: string; const aColumnHeading: string; const aOutputFile: TTextWriter );
begin
  aOutputFile.WriteLine( p( JvStrToHtml.StringToHtml( aTableHeading ) ) );
  aOutputFile.WriteLine( StartTag( 'table', SummaryClass ) );
  aOutputFile.WriteLine( tr( //
    th( JvStrToHtml.StringToHtml( aColumnHeading ) ) + //
    th( 'Number of covered lines' ) + //
    th( 'Number of lines (which generated code)' ) + //
    th( 'Percent(s) covered' ) ) );
end;

procedure THTMLCoverageReport.AddTimingStatistics( const aUnit: TUnitInfo; const aOutFile: TTextWriter );
begin
  for var vClassInfo in aUnit do
    for var vMethInfo in vClassInfo do
      aOutFile.WriteLine( tr( //
        td( JvStrToHtml.StringToHtml( vMethInfo.FullyQualifiedName ) ) + //
        td( vMethInfo.LineNumbers ) + //
        td( IntToStr( vMethInfo.HitCount ) ) + //
        td( TimeSpanToString( vMethInfo.MinHitTime ) ) + //
        td( TimeSpanToString( vMethInfo.MaxHitTime ) ) + //
        td( TimeSpanToString( vMethInfo.ElapsedHitTime ) ) + //
        td( TimeSpanToString( vMethInfo.AverageHitTime ) ) + //
        td( TimeSpanToString( vMethInfo.FloatingAverageHitTime ) )
        //{$IFDEF DEBUG} + td( JvStrToHtml.StringToHtml( vMethInfo.EntryPoint.Details.ToDebugString ) ) {$ENDIF DEBUG}
        ) );
end;

procedure THTMLCoverageReport.AddTimingStatistics( const aModule: TModuleInfo; const aOutFile: TTextWriter );
begin
  for var vUnitInfo in aModule do
    for var vClassInfo in vUnitInfo do
      for var vMethInfo in vClassInfo do
        if ( vMethInfo.HitCount > 0 ) then
          aOutFile.WriteLine( tr( //
            td( JvStrToHtml.StringToHtml( vMethInfo.FullyQualifiedName ) ) + //
            td( vMethInfo.LineNumbers ) + //
            td( IntToStr( vMethInfo.HitCount ) ) + //
            td( TimeSpanToString( vMethInfo.MinHitTime ) ) + //
            td( TimeSpanToString( vMethInfo.MaxHitTime ) ) + //
            td( TimeSpanToString( vMethInfo.ElapsedHitTime ) ) + //
            td( TimeSpanToString( vMethInfo.AverageHitTime ) ) + //
            td( TimeSpanToString( vMethInfo.FloatingAverageHitTime ) )
            //{$IFDEF DEBUG} + td( JvStrToHtml.StringToHtml( vMethInfo.EntryPoint.Details.ToDebugString ) ) {$ENDIF DEBUG}
            ) );
end;

procedure THTMLCoverageReport.AddTimingStatistics( const aModuleList: TModuleList; const aOutFile: TTextWriter );
begin
  for var vModule in aModuleList do
    for var vUnitInfo in vModule do
      for var vClassInfo in vUnitInfo do
        for var vMethInfo in vClassInfo do
          if ( vMethInfo.HitCount > 0 ) then
            aOutFile.WriteLine( tr( //
              td( JvStrToHtml.StringToHtml( vMethInfo.FullyQualifiedName ) ) + //
              td( vMethInfo.LineNumbers ) + //
              td( IntToStr( vMethInfo.HitCount ) ) + //
              td( TimeSpanToString( vMethInfo.MinHitTime ) ) + //
              td( TimeSpanToString( vMethInfo.MaxHitTime ) ) + //
              td( TimeSpanToString( vMethInfo.ElapsedHitTime ) ) + //
              td( TimeSpanToString( vMethInfo.AverageHitTime ) ) + //
              td( TimeSpanToString( vMethInfo.FloatingAverageHitTime ) )
              //{$IFDEF DEBUG} + td( JvStrToHtml.StringToHtml( vMethInfo.EntryPoint.Details.ToDebugString ) ) {$ENDIF DEBUG}
              ) );
end;

procedure THTMLCoverageReport.AddTimingTableFooter( const aOutputFile: TTextWriter );
begin
  aOutputFile.WriteLine( EndTag( 'table' ) );
  aOutputFile.WriteLine( lineBreak );
end;

procedure THTMLCoverageReport.AddTimingTableHeader( const aTableHeading: string; const aOutputFile: TTextWriter );
begin
  aOutputFile.WriteLine( p( JvStrToHtml.StringToHtml( Format( 'Timings for %s in the format [Days.Hours:Minutes:Seconds.Fraction]', [aTableHeading] ) ) ) );
  aOutputFile.WriteLine( StartTag( 'table', SummaryClass ) );
  aOutputFile.WriteLine( tr( //
    th( 'Fully qualified Method name' ) + //
    th( 'Line Number' ) + //
    th( 'Hitcount' ) + //
    th( 'Min time' ) + //
    th( 'Max time' ) + //
    th( 'Total time' ) + //
    th( 'Avg time' ) + //
    th( 'Floating Avg' )
    //{$IFDEF DEBUG} + th( 'Debug' ) {$ENDIF DEBUG}
    ) );
end;

constructor THTMLCoverageReport.Create( const ACoverageConfiguration: ICoverageConfiguration );
begin
  inherited Create;
  FCoverageConfiguration := ACoverageConfiguration;
end;

function THTMLCoverageReport.FindSourceFile( const aCoverageUnit: ICoverageStats ): string;
begin
  Result := FCoverageConfiguration.UnitList.FindSourceFile( aCoverageUnit.SourceModuleOrUnitFile );
  if Result = '' then
    Result := aCoverageUnit.SourceModuleOrUnitFile;
end;

end.
