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
unit XMLReport;

interface

uses
  JclSimpleXml,
  JclFileUtils,
  CoverageStatsApi,
  CoverageConfiguration,
  LoggingApi,
  ClassInfoUnit,
  DebuggerUtils;

type
  TXMLCoverageReport = class
  strict private
    FCoverageConfiguration: ICoverageConfiguration;
    procedure ProcessTimingStatistics( const aRootElement: TJclSimpleXMLElem; const aModuleInfoList: TModuleList );
    procedure ProcessTimingEntry( const aRootElement: TJclSimpleXMLElem; const aMethod: TProcedureInfo );
  public
    constructor Create( const aCoverageConfiguration: ICoverageConfiguration );

    procedure Generate( const aCoverage: ICoverageStats; const aModuleInfoList: TModuleList );
  end;

procedure GenerateXmlReport( const aCoverageConfiguration: ICoverageConfiguration; const aCoverage: ICoverageStats; const aModuleInfoList: TModuleList );

implementation

procedure GenerateXmlReport( const aCoverageConfiguration: ICoverageConfiguration; const aCoverage: ICoverageStats; const aModuleInfoList: TModuleList );
var
  vReport: TXMLCoverageReport;
begin
  vReport := TXMLCoverageReport.Create( aCoverageConfiguration );
  try
    vReport.Generate( aCoverage, aModuleInfoList );
  finally
    vReport.Free;
  end;
end;

{ TXMLCoverageReport }

constructor TXMLCoverageReport.Create( const aCoverageConfiguration: ICoverageConfiguration );
begin
  inherited Create;
  FCoverageConfiguration := aCoverageConfiguration;
end;

procedure TXMLCoverageReport.Generate( const aCoverage: ICoverageStats; const aModuleInfoList: TModuleList );
var
  vXML: TJclSimpleXML;
begin
  FCoverageConfiguration.LogManager.Log( 'Generating xml report' );
  ForceDirectories( FCoverageConfiguration.OutputDir );

  vXML := TJclSimpleXML.Create;
  try
    vXML.Root.Name := 'report';
    ProcessTimingStatistics( vXML.Root, aModuleInfoList );
    vXML.SaveToFile( PathAppend( FCoverageConfiguration.OutputDir, 'Results.xml' ) );
  finally
    vXML.Free;
  end;
end;

procedure TXMLCoverageReport.ProcessTimingEntry( const aRootElement: TJclSimpleXMLElem; const aMethod: TProcedureInfo );
var
  vElement: TJclSimpleXMLElem;
begin
  vElement := aRootElement.Items.Add( 'info' );
  vElement.Properties.Add( 'name', aMethod.FullyQualifiedName );
  vElement.Properties.Add( 'lines', aMethod.LineNumbers );
  vElement.Properties.Add( 'hitCount', aMethod.HitCount );
  vElement.Properties.Add( 'minTime', TimeSpanToString( aMethod.MinHitTime ) );
  vElement.Properties.Add( 'maxTime', TimeSpanToString( aMethod.MaxHitTime ) );
  vElement.Properties.Add( 'total', TimeSpanToString( aMethod.ElapsedHitTime ) );
  vElement.Properties.Add( 'average', TimeSpanToString( aMethod.AverageHitTime ) );
  vElement.Properties.Add( 'floatAvg', TimeSpanToString( aMethod.FloatingAverageHitTime ) );
  vElement.Properties.Add( 'totalLines', aMethod.LineCount );
  vElement.Properties.Add( 'coveredLines', aMethod.CoveredLineCount );
  vElement.Properties.Add( 'percentCovered', aMethod.PercentCovered );
end;

procedure TXMLCoverageReport.ProcessTimingStatistics( const aRootElement: TJclSimpleXMLElem; const aModuleInfoList: TModuleList );
begin
  for var vModule in aModuleInfoList do
    for var vUnitInfo in vModule do
      for var vClassInfo in vUnitInfo do
        for var vMethInfo in vClassInfo do
          if ( vMethInfo.HitCount > 0 ) then
            ProcessTimingEntry( aRootElement, vMethInfo );
end;

end.
