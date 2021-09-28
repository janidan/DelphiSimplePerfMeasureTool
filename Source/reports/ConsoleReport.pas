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
unit ConsoleReport;

interface

uses
  System.SysUtils,
  CoverageStatsApi,
  LoggingApi,
  CoverageConfiguration,
  ClassInfoUnit,
  LogManager,
  DebuggerUtils;

type
  TConsoleReport = class
  strict private
    FCoverageConfiguration: ICoverageConfiguration;

    procedure WriteTableHeader;
    procedure WriteTableEntry( const aMethod: TProcedureInfo );
    procedure WriteTableFooter( const aCoverage: ICoverageStats );
  public
    constructor Create( const aCoverageConfiguration: ICoverageConfiguration );

    procedure Generate( const aCoverage: ICoverageStats; const aModuleInfoList: TModuleList );
  end;

procedure GenerateConsoleReport( const aCoverageConfiguration: ICoverageConfiguration; const aCoverage: ICoverageStats; const aModuleInfoList: TModuleList );

implementation

procedure GenerateConsoleReport( const aCoverageConfiguration: ICoverageConfiguration; const aCoverage: ICoverageStats; const aModuleInfoList: TModuleList );
var
  vReport: TConsoleReport;
begin
  vReport := TConsoleReport.Create( aCoverageConfiguration );
  try
    vReport.Generate( aCoverage, aModuleInfoList );
  finally
    vReport.Free;
  end;
end;

function PadString( const aString: string; const aMaxLength: Integer ): string;
begin
  Result := aString + ' ';
  while Length( Result ) < aMaxLength do
    Result := ' ' + Result;

  Result := Copy( Result, 1, aMaxLength );
end;

function RightPadString( const aString: string; const aMaxLength: Integer ): string;
begin
  Result := aString + ' ';
  while Length( Result ) < aMaxLength do
    Result := Result + ' ';

  Result := Copy( Result, 1, aMaxLength );
end;

{ TConsoleReport }

constructor TConsoleReport.Create( const aCoverageConfiguration: ICoverageConfiguration );
begin
  inherited Create;
  FCoverageConfiguration := aCoverageConfiguration;
end;

procedure TConsoleReport.Generate( const aCoverage: ICoverageStats; const aModuleInfoList: TModuleList );
begin
  WriteTableHeader;

  for var vModule in aModuleInfoList do
    for var vUnitInfo in vModule do
      for var vClassInfo in vUnitInfo do
        for var vMethInfo in vClassInfo do
          if ( vMethInfo.HitCount > 0 ) then
            WriteTableEntry( vMethInfo );

  WriteTableFooter( aCoverage );
end;

procedure TConsoleReport.WriteTableEntry( const aMethod: TProcedureInfo );
var
  vFullyQualifiedName: string;
const
  FullyQuanlifiedNameLength = 27;
begin
  vFullyQualifiedName := aMethod.FullyQualifiedName;
  // Split the FQN into chunks of max 29 Chars.
  // Line 1:
  ConsoleOutput( Format( '|%s|%s|%s|%s|', [ //
    RightPadString( Copy( vFullyQualifiedName, 1, FullyQuanlifiedNameLength ), 29 ), // Name
    PadString( IntToStr( aMethod.HitCount ), 13 ), // HitCount
    PadString( TimeSpanToString( aMethod.ElapsedHitTime ), 16 ), // TotalTime
    PadString( TimeSpanToString( aMethod.AverageHitTime ), 16 )] ) ); // AverageTime
  // Line 2:
  ConsoleOutput( Format( '|%s|%s|%s|%s|', [ //
    RightPadString( Copy( vFullyQualifiedName, FullyQuanlifiedNameLength + 1, FullyQuanlifiedNameLength ), 29 ), // Name part2
    PadString( aMethod.LineNumbers, 13 ), // LineNumber
    PadString( TimeSpanToString( aMethod.MinHitTime ), 16 ), // MinTime
    PadString( TimeSpanToString( aMethod.MaxHitTime ), 16 )] ) ); // MaxTime
  // Line 3:
  ConsoleOutput( Format( '|%s|%s|%s|%s|', [ //
    RightPadString( Copy( vFullyQualifiedName, 2 * FullyQuanlifiedNameLength + 1, FullyQuanlifiedNameLength ), 29 ), // Name part 3
    PadString( IntToStr( aMethod.LineCount ), 13 ), // LineCount
    PadString( IntToStr( aMethod.CoveredLineCount ), 16 ), // CoveredLines
    PadString( IntToStr( aMethod.PercentCovered ), 16 )] ) ); // PercentCovered
  ConsoleOutput( '+-----------------------------+-------------+----------------+----------------+' );
end;

procedure TConsoleReport.WriteTableFooter( const aCoverage: ICoverageStats );
begin
  //  ConsoleOutput( Format( '| Overall Coverage            |%s|%s|%s|', [ //
  //    PadString( IntToStr( aCoverage.LineCount ), 13 ), // LineCount
  //    PadString( IntToStr( aCoverage.CoveredLineCount ), 16 ), // CoveredLines
  //    PadString( IntToStr( aCoverage.PercentCovered ), 16 )] ) ); // PercentCovered
  //  ConsoleOutput( '+-----------------------------+-------------+----------------+----------------+' );
end;

procedure TConsoleReport.WriteTableHeader;
begin
  ConsoleOutput( '+-----------------------------+-------------+----------------+----------------+' );
  ConsoleOutput( '| Fully qualified Method      |    HitCount |     Total Time |       Avg Time |' );
  ConsoleOutput( '| Name                        | LinesNumber |       Min Time |       Max Time |' );
  ConsoleOutput( '|                             |   LineCount |   CoveredLines |      Covered % |' );
  ConsoleOutput( '+-----------------------------+-------------+----------------+----------------+' );
end;

end.
