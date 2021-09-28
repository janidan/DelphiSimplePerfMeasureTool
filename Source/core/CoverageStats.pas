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
unit CoverageStats;

interface

uses
  System.Classes,
  System.Generics.Collections,
  CoverageStatsApi;

type
  TCoverageStats = class( TInterfacedObject, ICoverageStats )
  private
    FName: string;
    FSourceModuleOrUnitFile: string;
    FParent: Pointer;

    FLineCount: Integer;
    FPercentCovered: Integer;
    FCoveredLineCount: Integer;

    FCoverageLines: TDictionary<Integer, TCoverageLine>;
    FCoverageStatsList: TDictionary<string, ICoverageStats>;
    procedure UpdatePercentCovered;

    procedure Calculate;

    function CoveredLineCount: Integer;
    function LineCount: Integer;
    function PercentCovered: Integer;

    function Count: Integer;
    function GetCoverageReportByIndex( const aIndex: Integer ): ICoverageStats;

    function GetCoverageReport( const aName: string; const aSourceModuleOrUnitFile: string ): ICoverageStats;
    function GetCoverageReports: TArray<ICoverageStats>;

    function Name: string;
    function SourceModuleOrUnitFile: string;
    function ReportFileName: string;
    function Parent: ICoverageStats;

    function GetCoverageLineCount: Integer;
    function CoverageLines: TArray<TCoverageLine>;

    procedure AddLineCoverage( const ALineNumber: Integer; const ALineCount: Integer );
    function TryGetLineCoverage( const ALineNumber: Integer; out ACoverageLine: TCoverageLine ): Boolean;
  public
    constructor Create( const aName: string; const aSourceModuleOrUnitFile: string; const AParent: ICoverageStats );
    destructor Destroy; override;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Defaults;

constructor TCoverageStats.Create( const aName: string; const aSourceModuleOrUnitFile: string; const AParent: ICoverageStats );
begin
  inherited Create;

  FName := aName;
  FSourceModuleOrUnitFile := aSourceModuleOrUnitFile;

  FCoverageStatsList := TDictionary<string, ICoverageStats>.Create;
  FCoverageLines := TDictionary<Integer, TCoverageLine>.Create;

  FParent := Pointer( AParent );
end;

destructor TCoverageStats.Destroy;
begin
  FCoverageStatsList.Free;
  FCoverageLines.Free;

  inherited;
end;

procedure TCoverageStats.AddLineCoverage( const ALineNumber: Integer; const ALineCount: Integer );
var
  vLineCoverage: TCoverageLine;
begin
  if FCoverageLines.TryGetValue( ALineNumber, vLineCoverage ) then
  begin
    vLineCoverage.LineCount := vLineCoverage.LineCount + ALineCount;
  end
  else
  begin
    vLineCoverage.LineNumber := ALineNumber;
    vLineCoverage.LineCount := ALineCount;
    FCoverageLines.Add( ALineNumber, vLineCoverage );
  end;
end;

procedure TCoverageStats.Calculate;
var
  CurrentStatistics: ICoverageStats;
  vLineCoverage: TCoverageLine;
begin
  FLineCount := 0;
  FPercentCovered := 0;
  FCoveredLineCount := 0;

  if ( FCoverageLines.Count = 0 ) then
  begin
    for CurrentStatistics in FCoverageStatsList.Values do
    begin
      CurrentStatistics.Calculate;

      Inc( FLineCount, CurrentStatistics.LineCount );
      Inc( FCoveredLineCount, CurrentStatistics.CoveredLineCount );
    end;

    if FLineCount > 0 then
      UpdatePercentCovered;
  end
  else
  begin
    FLineCount := GetCoverageLineCount;
    for vLineCoverage in FCoverageLines.Values.ToArray do
      if vLineCoverage.IsCovered then
        Inc( FCoveredLineCount );

    if ( FCoveredLineCount > 0 ) then
      UpdatePercentCovered;
  end;
end;

function TCoverageStats.Count: Integer;
begin
  Result := FCoverageStatsList.Count;
end;

function TCoverageStats.GetCoverageLineCount: Integer;
begin
  Result := FCoverageLines.Count;
end;

function TCoverageStats.GetCoverageReports: TArray<ICoverageStats>;
begin
  Result := FCoverageStatsList.Values.ToArray;
  TArray.Sort<ICoverageStats>( Result, TComparer<ICoverageStats>.Construct(
    function( const Left, Right: ICoverageStats ): Integer
    begin
      Result := CompareStr( Left.Name, Right.Name );
    end ) );
end;

function TCoverageStats.GetCoverageReport( const aName: string; const aSourceModuleOrUnitFile: string ): ICoverageStats;
begin
  if not FCoverageStatsList.TryGetValue( aName, Result ) then
  begin
    Result := TCoverageStats.Create( aName, aSourceModuleOrUnitFile, Self );
    FCoverageStatsList.Add( aName, Result );
  end;
end;

function TCoverageStats.GetCoverageReportByIndex( const aIndex: Integer ): ICoverageStats;
begin
  Result := FCoverageStatsList.Values.ToArray[aIndex];
end;

function TCoverageStats.Name: string;
begin
  Result := FName;
end;

function TCoverageStats.CoverageLines: TArray<TCoverageLine>;
begin
  Result := FCoverageLines.Values.ToArray;
  TArray.Sort<TCoverageLine>( Result, TComparer<TCoverageLine>.Construct(
    function( const Left, Right: TCoverageLine ): Integer
    begin
      if Left.LineNumber < Right.LineNumber then
        Exit( -1 )
      else if Left.LineNumber > Right.LineNumber then
        Exit( 1 )
      else
        Exit( 0 );
    end ) );
end;

function TCoverageStats.CoveredLineCount: Integer;
begin
  Result := FCoveredLineCount;
end;

function TCoverageStats.LineCount: Integer;
begin
  Result := FLineCount;
end;

function TCoverageStats.PercentCovered: Integer;
begin
  Result := FPercentCovered;
end;

function TCoverageStats.ReportFileName: string;
var
  tmp: string;
begin
  Result := ExtractFileName( SourceModuleOrUnitFile );

  if Self.Parent <> nil then
  begin
    tmp := Self.Parent.ReportFileName;
    if tmp <> '' then
      Result := tmp + '(' + Result + ')';
  end;
end;

function TCoverageStats.SourceModuleOrUnitFile: string;
begin
  Result := FSourceModuleOrUnitFile;
end;

function TCoverageStats.TryGetLineCoverage( const ALineNumber: Integer; out ACoverageLine: TCoverageLine ): Boolean;
begin
  Result := FCoverageLines.TryGetValue( ALineNumber, ACoverageLine );
end;

function TCoverageStats.Parent: ICoverageStats;
begin
  Result := ICoverageStats( FParent );
end;

procedure TCoverageStats.UpdatePercentCovered;
begin
  FPercentCovered := FCoveredLineCount * 100 div FLineCount;
end;

end.
