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
unit ClassInfoUnit;

interface

uses
  Generics.Collections,
  System.Diagnostics,
  System.TimeSpan,
  DebuggerApi;

type
  TSimpleBreakPointList = class( TList<IBreakPoint> )
  private
    FLine: Integer;
  public
    constructor Create( const aLine: Integer );
    procedure RemoveBreakPointsForModule( const aBinaryModule: IDebugModule );

    property Line: Integer read FLine;
  end;

  TProcedureInfo = class( TEnumerable<Integer> )
  private
    FName: String;
    FLines: TDictionary<Integer, TSimpleBreakPointList>;
    FEntryPoint: IBreakPoint;
    FExitPoint: IBreakPoint;
    FStopwatch: TStopwatch;

    FMinTime: TTimeSpan;
    FMaxTime: TTimeSpan;
    FElapsedTicks: Int64;
    FAverageTicks: Int64;

    function IsCovered( const ABreakPointList: TSimpleBreakPointList ): Boolean;
    procedure ClearLines;

    procedure HandleEntryPointHit( const aBreakPoint: IBreakPoint );
    procedure HandleExitPointHit( const aBreakPoint: IBreakPoint );

    procedure HandleEntryPoints( const aBreakPoint: IBreakPoint );

    function GetName: string;
  protected
    function DoGetEnumerator: TEnumerator<Integer>; override;
  public const
    BodySuffix = '$Body';

    function LineCount: Integer;
    function CoveredLineCount: Integer;
    function PercentCovered: Integer;
    function HitCount: Integer;

    function MinHitTime: TTimeSpan;
    function MaxHitTime: TTimeSpan;
    function ElapsedHitTime: TTimeSpan;
    function AverageHitTime: TTimeSpan;
    function FloatingAverageHitTime: TTimeSpan;

    function EntryPoint: IBreakPoint;
    function ExitPoint: IBreakPoint;

    function FullyQualifiedName: string;
    function LineNumbers: string;

    property Name: string read GetName;

    constructor Create( const AName: string );
    destructor Destroy; override;
    function IsLineCovered( const ALineNo: Integer ): Boolean;

    procedure AddBreakpoint( const aBreakPoint: IBreakPoint );
    procedure RemoveBreakPointsForModule( const aBinaryModule: IDebugModule );
  end;

  TClassInfo = class( TEnumerable<TProcedureInfo> )
  strict private
    FName: String;
    FProcedures: TDictionary<string, TProcedureInfo>;
    procedure ClearProcedures;

    function GetProcedureCount: Integer;
    function GetCoveredProcedureCount: Integer;
    function GetClassName: string;

    function GetIsCovered: Boolean;
  protected
    function DoGetEnumerator: TEnumerator<TProcedureInfo>; override;
  public
    property ProcedureCount: Integer read GetProcedureCount;
    property CoveredProcedureCount: Integer read GetCoveredProcedureCount;
    property TheClassName: string read GetClassName;
    property IsCovered: Boolean read GetIsCovered;

    function LineCount: Integer;
    function CoveredLineCount: Integer;
    function PercentCovered: Integer;

    constructor Create( const AClassName: string );
    destructor Destroy; override;
    function EnsureProcedure( const AProcedureName: string ): TProcedureInfo;
    procedure AddBreakpoint( const aBreakPoint: IBreakPoint );
    procedure RemoveBreakPointsForModule( const aBinaryModule: IDebugModule );
  end;

  TUnitInfo = class( TEnumerable<TClassInfo> )
  strict private
    FName: string;
    FFileName: string;
    FClasses: TDictionary<string, TClassInfo>;
    FBinaryModule: IDebugModule;
    function GetUnitName: string;
    function GetUnitFileName: string;
    function GetClassCount: Integer;
    function GetCoveredClassCount: Integer;
    function GetMethodCount: Integer;
    function GetCoveredMethodCount: Integer;
  protected
    function DoGetEnumerator: TEnumerator<TClassInfo>; override;
  public
    property BinaryModule: IDebugModule read FBinaryModule;
    property UnitName: string read GetUnitName;
    property UnitFileName: string read GetUnitFileName;

    property ClassCount: Integer read GetClassCount;
    property CoveredClassCount: Integer read GetCoveredClassCount;

    property MethodCount: Integer read GetMethodCount;
    property CoveredMethodCount: Integer read GetCoveredMethodCount;

    function LineCount: Integer;
    function CoveredLineCount: Integer;

    constructor Create( const aBinaryModule: IDebugModule; const aUnitName: string; const aUnitFileName: string );
    destructor Destroy; override;

    function ToString: string; override;

    function EnsureClassInfo( const AClassName: string ): TClassInfo;
    procedure ClearClasses;

    procedure AddBreakpoint( const aBreakPoint: IBreakPoint );
    procedure RemoveBreakPointsForModule( const aBinaryModule: IDebugModule );
  end;

  TModuleInfo = class( TEnumerable<TUnitInfo> )
  strict private
    FName: string;
    FFileName: string;
    FBinaryModule: IDebugModule;
    FUnits: TDictionary<string, TUnitInfo>;
    function GetModuleName: string;
    function GetModuleFileName: string;
    procedure ClearUnits;
    function GetCount: Integer;
    function GetTotalClassCount: Integer;
    function GetTotalCoveredClassCount: Integer;
    function GetTotalMethodCount: Integer;
    function GetTotalCoveredMethodCount: Integer;
    function GetTotalLineCount: Integer;
    function GetTotalCoveredLineCount: Integer;
  protected
    function DoGetEnumerator: TEnumerator<TUnitInfo>; override;
  public
    property ModuleName: string read GetModuleName;
    property ModuleFileName: string read GetModuleFileName;
    property Count: Integer read GetCount;

    property ClassCount: Integer read GetTotalClassCount;
    property CoveredClassCount: Integer read GetTotalCoveredClassCount;

    property MethodCount: Integer read GetTotalMethodCount;
    property CoveredMethodCount: Integer read GetTotalCoveredMethodCount;

    property LineCount: Integer read GetTotalLineCount;
    property CoveredLineCount: Integer read GetTotalCoveredLineCount;

    constructor Create( const aBinaryModule: IDebugModule; const aModuleName: string );
    destructor Destroy; override;

    function EnsureUnitInfo( const aBinaryModule: IDebugModule; const aUnitName: string; const aUnitFileName: string ): TUnitInfo;
    function GetUnitInfo( const aUnitName: string ): TUnitInfo;

    procedure AddBreakpoint( const aBreakPoint: IBreakPoint );
    procedure RemoveBreakPointsForModule( const aBinaryModule: IDebugModule );
  end;

  TModuleList = class( TEnumerable<TModuleInfo> )
  strict private
    FModules: TDictionary<string, TModuleInfo>;
    procedure ClearModules;
    function GetCount: Integer;
    function GetTotalClassCount: Integer;
    function GetTotalCoveredClassCount: Integer;
    function GetTotalMethodCount: Integer;
    function GetTotalCoveredMethodCount: Integer;
    function GetTotalLineCount: Integer;
    function GetTotalCoveredLineCount: Integer;
  protected
    function DoGetEnumerator: TEnumerator<TModuleInfo>; override;
  public
    property Count: Integer read GetCount;

    property ClassCount: Integer read GetTotalClassCount;
    property CoveredClassCount: Integer read GetTotalCoveredClassCount;

    property MethodCount: Integer read GetTotalMethodCount;
    property CoveredMethodCount: Integer read GetTotalCoveredMethodCount;

    property LineCount: Integer read GetTotalLineCount;
    property CoveredLineCount: Integer read GetTotalCoveredLineCount;

    constructor Create;
    destructor Destroy; override;

    function EnsureModuleInfo( const aBinaryModule: IDebugModule; const aModuleName: string ): TModuleInfo;
    function GetModuleInfo( const aModuleName: string ): TModuleInfo;

    procedure AddBreakpoint( const aBreakPoint: IBreakPoint );
    procedure RemoveBreakPointsForModule( const aBinaryModule: IDebugModule );
  end;

implementation

uses
  Types,
  SysUtils,
  StrUtils,
  Math,
  Classes,
  CoverageConfiguration;

{$REGION 'TModuleList'}

constructor TModuleList.Create;
begin
  inherited Create;
  FModules := TDictionary<string, TModuleInfo>.Create;
end;

destructor TModuleList.Destroy;
begin
  ClearModules;
  FModules.Free;

  inherited Destroy;
end;

procedure TModuleList.ClearModules;
var
  Key: string;
begin
  for Key in FModules.Keys do
    FModules[Key].Free;
end;

function TModuleList.GetCount: Integer;
begin
  Result := FModules.Count;
end;

function TModuleList.GetModuleInfo( const aModuleName: string ): TModuleInfo;
begin
  FModules.TryGetValue( aModuleName, Result );
end;

function TModuleList.DoGetEnumerator: TEnumerator<TModuleInfo>;
begin
  Result := FModules.Values.GetEnumerator;
end;

function TModuleList.GetTotalClassCount: Integer;
var
  CurrentModuleInfo: TModuleInfo;
begin
  Result := 0;
  for CurrentModuleInfo in FModules.Values do
    Inc( Result, CurrentModuleInfo.ClassCount );
end;

function TModuleList.GetTotalCoveredClassCount: Integer;
var
  CurrentModuleInfo: TModuleInfo;
begin
  Result := 0;
  for CurrentModuleInfo in FModules.Values do
    Inc( Result, CurrentModuleInfo.CoveredClassCount );
end;

function TModuleList.GetTotalMethodCount: Integer;
var
  CurrentModuleInfo: TModuleInfo;
begin
  Result := 0;
  for CurrentModuleInfo in FModules.Values do
    Inc( Result, CurrentModuleInfo.MethodCount );
end;

function TModuleList.GetTotalCoveredMethodCount: Integer;
var
  CurrentModuleInfo: TModuleInfo;
begin
  Result := 0;
  for CurrentModuleInfo in FModules.Values do
    Inc( Result, CurrentModuleInfo.CoveredMethodCount );
end;

function TModuleList.GetTotalLineCount: Integer;
var
  CurrentModuleInfo: TModuleInfo;
begin
  Result := 0;
  for CurrentModuleInfo in FModules.Values do
    Inc( Result, CurrentModuleInfo.LineCount );
end;

function TModuleList.GetTotalCoveredLineCount( ): Integer;
var
  CurrentModuleInfo: TModuleInfo;
begin
  Result := 0;
  for CurrentModuleInfo in FModules.Values do
    Inc( Result, CurrentModuleInfo.CoveredLineCount );
end;

function TModuleList.EnsureModuleInfo( const aBinaryModule: IDebugModule; const aModuleName: string ): TModuleInfo;
begin
  if not FModules.TryGetValue( aModuleName, Result ) then
  begin
    Result := TModuleInfo.Create( aBinaryModule, aModuleName );
    FModules.Add( aModuleName, Result );
  end;
end;

procedure TModuleList.AddBreakpoint( const aBreakPoint: IBreakPoint );
var
  BreakpointDetails: TBreakPointDetail;
  Module: TModuleInfo;
begin
  BreakpointDetails := aBreakPoint.Details;
  Module := EnsureModuleInfo( aBreakPoint.Module, BreakpointDetails.ModuleName );
  Module.AddBreakpoint( aBreakPoint );
end;

procedure TModuleList.RemoveBreakPointsForModule( const aBinaryModule: IDebugModule );
var
  CurrentModuleInfo: TModuleInfo;
begin
  for CurrentModuleInfo in FModules.Values.ToArray do
  begin
    CurrentModuleInfo.RemoveBreakPointsForModule( aBinaryModule );
    if ( CurrentModuleInfo.ClassCount = 0 ) then
    begin
      FModules.Remove( CurrentModuleInfo.ModuleName );
      CurrentModuleInfo.Free;
    end;
  end;
end;

{$ENDREGION 'TModuleList'}
{$REGION 'TModuleInfo'}

constructor TModuleInfo.Create( const aBinaryModule: IDebugModule; const aModuleName: string );
begin
  inherited Create;
  FUnits := TDictionary<string, TUnitInfo>.Create;
  FName := aModuleName;
  FBinaryModule := aBinaryModule;
  FFileName := aBinaryModule.Filename;
end;

destructor TModuleInfo.Destroy;
begin
  ClearUnits;
  FUnits.Free;

  inherited Destroy;
end;

procedure TModuleInfo.ClearUnits;
var
  Key: string;
begin
  for Key in FUnits.Keys do
    FUnits[Key].Free;
end;

function TModuleInfo.GetCount: Integer;
begin
  Result := FUnits.Count;
end;

function TModuleInfo.GetModuleFileName: string;
begin
  Result := FFileName;
end;

function TModuleInfo.GetUnitInfo( const aUnitName: string ): TUnitInfo;
begin
  FUnits.TryGetValue( aUnitName, Result );
end;

function TModuleInfo.GetModuleName: string;
begin
  Result := FName;
end;

function TModuleInfo.DoGetEnumerator: TEnumerator<TUnitInfo>;
begin
  Result := FUnits.Values.GetEnumerator;
end;

function TModuleInfo.GetTotalClassCount: Integer;
var
  CurrentModuleInfo: TUnitInfo;
begin
  Result := 0;
  for CurrentModuleInfo in FUnits.Values do
    Inc( Result, CurrentModuleInfo.ClassCount );
end;

function TModuleInfo.GetTotalCoveredClassCount: Integer;
var
  CurrentModuleInfo: TUnitInfo;
begin
  Result := 0;
  for CurrentModuleInfo in FUnits.Values do
    Inc( Result, CurrentModuleInfo.CoveredClassCount );
end;

function TModuleInfo.GetTotalMethodCount: Integer;
var
  CurrentModuleInfo: TUnitInfo;
begin
  Result := 0;
  for CurrentModuleInfo in FUnits.Values do
    Inc( Result, CurrentModuleInfo.MethodCount );
end;

function TModuleInfo.GetTotalCoveredMethodCount: Integer;
var
  CurrentModuleInfo: TUnitInfo;
begin
  Result := 0;
  for CurrentModuleInfo in FUnits.Values do
    Inc( Result, CurrentModuleInfo.CoveredMethodCount );
end;

function TModuleInfo.GetTotalLineCount: Integer;
var
  CurrentModuleInfo: TUnitInfo;
begin
  Result := 0;
  for CurrentModuleInfo in FUnits.Values do
    Inc( Result, CurrentModuleInfo.LineCount );
end;

function TModuleInfo.GetTotalCoveredLineCount( ): Integer;
var
  CurrentModuleInfo: TUnitInfo;
begin
  Result := 0;
  for CurrentModuleInfo in FUnits.Values do
    Inc( Result, CurrentModuleInfo.CoveredLineCount );
end;

function TModuleInfo.EnsureUnitInfo( const aBinaryModule: IDebugModule; const aUnitName: string; const aUnitFileName: string ): TUnitInfo;
begin
  if not FUnits.TryGetValue( aUnitName, Result ) then
  begin
    Result := TUnitInfo.Create( aBinaryModule, aUnitName, aUnitFileName );
    FUnits.Add( aUnitName, Result );
  end;
end;

procedure TModuleInfo.AddBreakpoint( const aBreakPoint: IBreakPoint );
var
  vBreakpointDetails: TBreakPointDetail;
  vUnit: TUnitInfo;
begin
  vBreakpointDetails := aBreakPoint.Details;
  vUnit := EnsureUnitInfo( aBreakPoint.Module, vBreakpointDetails.UnitName, vBreakpointDetails.UnitFileName );
  vUnit.AddBreakpoint( aBreakPoint );
end;

procedure TModuleInfo.RemoveBreakPointsForModule( const aBinaryModule: IDebugModule );
var
  CurrentModuleInfo: TUnitInfo;
begin
  for CurrentModuleInfo in FUnits.Values.ToArray do
  begin
    CurrentModuleInfo.RemoveBreakPointsForModule( aBinaryModule );
    if ( CurrentModuleInfo.ClassCount = 0 ) then
    begin
      FUnits.Remove( CurrentModuleInfo.UnitName );
      CurrentModuleInfo.Free;
    end;
  end;
end;

{$ENDREGION 'TModuleInfo'}
{$REGION 'TUnitInfo'}

constructor TUnitInfo.Create( const aBinaryModule: IDebugModule; const aUnitName: string; const aUnitFileName: string );
begin
  inherited Create;

  FBinaryModule := aBinaryModule;
  FName := aUnitName;
  FFileName := aUnitFileName;
  FClasses := TDictionary<string, TClassInfo>.Create;
end;

destructor TUnitInfo.Destroy;
begin
  ClearClasses;
  FClasses.Free;
  inherited Destroy;
end;

procedure TUnitInfo.ClearClasses;
var
  Key: string;
begin
  for Key in FClasses.Keys do
    FClasses[Key].Free;
end;

function TUnitInfo.ToString: string;
begin
  Result := 'Unit[' + FName + ' in ' + FFileName + ' ]';
end;

function TUnitInfo.GetUnitName: string;
begin
  Result := FName;
end;

procedure TUnitInfo.AddBreakpoint( const aBreakPoint: IBreakPoint );
var
  BreakpointDetails: TBreakPointDetail;
  ClsInfo: TClassInfo;
begin
  BreakpointDetails := aBreakPoint.Details;
  ClsInfo := EnsureClassInfo( BreakpointDetails.ClassName );
  ClsInfo.AddBreakpoint( aBreakPoint );
end;

function TUnitInfo.GetUnitFileName: string;
begin
  Result := FFileName;
end;

function TUnitInfo.EnsureClassInfo( const AClassName: string ): TClassInfo;
begin
  if not FClasses.TryGetValue( AClassName, Result ) then
  begin
    Result := TClassInfo.Create( AClassName );
    FClasses.Add( AClassName, Result );
  end;
end;

function TUnitInfo.GetClassCount: Integer;
begin
  Result := FClasses.Count;
end;

function TUnitInfo.DoGetEnumerator: TEnumerator<TClassInfo>;
begin
  Result := FClasses.Values.GetEnumerator;
end;

function TUnitInfo.GetCoveredClassCount: Integer;
var
  CurrentClassInfo: TClassInfo;
begin
  Result := 0;
  for CurrentClassInfo in FClasses.Values do
    Inc( Result, IfThen( CurrentClassInfo.IsCovered, 1, 0 ) );
end;

function TUnitInfo.GetMethodCount: Integer;
var
  CurrentClassInfo: TClassInfo;
begin
  Result := 0;
  for CurrentClassInfo in FClasses.Values do
    Inc( Result, CurrentClassInfo.ProcedureCount );
end;

function TUnitInfo.GetCoveredMethodCount: Integer;
var
  CurrentClassInfo: TClassInfo;
begin
  Result := 0;
  for CurrentClassInfo in FClasses.Values do
    Inc( Result, CurrentClassInfo.CoveredProcedureCount );
end;

function TUnitInfo.LineCount: Integer;
var
  CurrentClassInfo: TClassInfo;
begin
  Result := 0;
  for CurrentClassInfo in FClasses.Values do
    Inc( Result, CurrentClassInfo.LineCount );
end;

procedure TUnitInfo.RemoveBreakPointsForModule( const aBinaryModule: IDebugModule );
var
  CurrentClassInfo: TClassInfo;
begin
  for CurrentClassInfo in FClasses.Values.ToArray do
  begin
    CurrentClassInfo.RemoveBreakPointsForModule( aBinaryModule );
    if ( CurrentClassInfo.ProcedureCount = 0 ) then
    begin
      FClasses.Remove( CurrentClassInfo.TheClassName );
      CurrentClassInfo.Free;
    end;
  end;
end;

function TUnitInfo.CoveredLineCount: Integer;
var
  CurrentClassInfo: TClassInfo;
begin
  Result := 0;
  for CurrentClassInfo in FClasses.Values do
    Inc( Result, CurrentClassInfo.CoveredLineCount );
end;
{$ENDREGION 'TUnitInfo'}
{$REGION 'TClassInfo'}

constructor TClassInfo.Create( const AClassName: string );
begin
  inherited Create;
  FName := AClassName;
  FProcedures := TDictionary<string, TProcedureInfo>.Create;
end;

destructor TClassInfo.Destroy;
begin
  ClearProcedures;
  FProcedures.Free;
  inherited Destroy;
end;

function TClassInfo.DoGetEnumerator: TEnumerator<TProcedureInfo>;
begin
  Result := FProcedures.Values.GetEnumerator;
end;

procedure TClassInfo.ClearProcedures;
var
  Key: string;
begin
  for Key in FProcedures.Keys do
    FProcedures[Key].Free;
end;

function TClassInfo.EnsureProcedure( const AProcedureName: string ): TProcedureInfo;
begin
  if not FProcedures.TryGetValue( AProcedureName, Result ) then
  begin
    Result := TProcedureInfo.Create( AProcedureName );
    FProcedures.Add( AProcedureName, Result );
  end;
end;

function TClassInfo.PercentCovered: Integer;
var
  Total: Integer;
  Covered: Integer;
  CurrentInfo: TProcedureInfo;
begin
  Total := 0;
  Covered := 0;

  for CurrentInfo in FProcedures.Values do
  begin
    Total := Total + CurrentInfo.LineCount;
    Covered := Covered + CurrentInfo.CoveredLineCount;
  end;

  Result := Covered * 100 div Total;
end;

procedure TClassInfo.RemoveBreakPointsForModule( const aBinaryModule: IDebugModule );
var
  CurrentInfo: TProcedureInfo;
begin
  for CurrentInfo in FProcedures.Values.ToArray do
  begin
    CurrentInfo.RemoveBreakPointsForModule( aBinaryModule );
    if ( CurrentInfo.LineCount = 0 ) then
    begin
      FProcedures.Remove( CurrentInfo.Name );
      CurrentInfo.Free;
    end;
  end;
end;

function TClassInfo.GetClassName: string;
begin
  Result := FName;
end;

function TClassInfo.GetProcedureCount: Integer;
begin
  Result := FProcedures.Count;
end;

procedure TClassInfo.AddBreakpoint( const aBreakPoint: IBreakPoint );
var
  BreakpointDetails: TBreakPointDetail;
  ProcInfo: TProcedureInfo;
begin
  BreakpointDetails := aBreakPoint.Details;
  ProcInfo := EnsureProcedure( BreakpointDetails.FullyQualifiedMethodName );
  ProcInfo.AddBreakpoint( aBreakPoint );
end;

function TClassInfo.GetCoveredProcedureCount: Integer;
var
  CurrentProcedureInfo: TProcedureInfo;
begin
  Result := 0;

  for CurrentProcedureInfo in FProcedures.Values do
    if CurrentProcedureInfo.CoveredLineCount > 0 then
      Inc( Result );
end;

function TClassInfo.LineCount: Integer;
var
  CurrentProcedureInfo: TProcedureInfo;
begin
  Result := 0;
  for CurrentProcedureInfo in FProcedures.Values do
    Inc( Result, CurrentProcedureInfo.LineCount );
end;

function TClassInfo.CoveredLineCount: Integer;
var
  CurrentProcedureInfo: TProcedureInfo;
begin
  Result := 0;
  for CurrentProcedureInfo in FProcedures.Values do
    Inc( Result, CurrentProcedureInfo.CoveredLineCount );
end;

function TClassInfo.GetIsCovered: Boolean;
begin
  Result := CoveredLineCount > 0;
end;
{$ENDREGION 'TClassInfo'}
{$REGION 'TProcedureInfo'}

constructor TProcedureInfo.Create( const AName: string );
begin
  inherited Create;

  FName := AName;
  FLines := TDictionary<Integer, TSimpleBreakPointList>.Create;
  // init time counters
  FMinTime := TTimeSpan.MaxValue;
  FMaxTime := TTimeSpan.MinValue;
  FElapsedTicks := 0;
  FAverageTicks := 0;
end;

destructor TProcedureInfo.Destroy;
begin
  ClearLines;
  FLines.Free;
  inherited Destroy;
end;

function TProcedureInfo.DoGetEnumerator: TEnumerator<Integer>;
begin
  Result := FLines.Keys.GetEnumerator;
end;

function TProcedureInfo.ElapsedHitTime: TTimeSpan;
begin
  Result := TTimeSpan.FromTicks( FElapsedTicks );
end;

function TProcedureInfo.EntryPoint: IBreakPoint;
begin
  Result := FEntryPoint;
end;

function TProcedureInfo.ExitPoint: IBreakPoint;
begin
  Result := FExitPoint;
end;

function TProcedureInfo.FloatingAverageHitTime: TTimeSpan;
begin
  Result := TTimeSpan.FromTicks( FAverageTicks );
end;

function TProcedureInfo.FullyQualifiedName: string;
begin
  if Assigned( FEntryPoint ) then
    Exit( FEntryPoint.Details.FullyQualifiedMethodName );
  Result := FName;
end;

function TProcedureInfo.AverageHitTime: TTimeSpan;
begin
  if ( HitCount = 0 ) then
    Exit( TTimeSpan.Zero );
  Result := TTimeSpan.FromTicks( FElapsedTicks div HitCount );
end;

procedure TProcedureInfo.ClearLines;
begin
  for var I in FLines.Keys do
    FLines[I].Free;
end;

function TProcedureInfo.LineCount: Integer;
begin
  Result := FLines.Keys.Count;
end;

function TProcedureInfo.LineNumbers: string;
begin
  Result := '';
  if Assigned( FEntryPoint ) then
    Result := Result + IntToStr( FEntryPoint.Details.Line );
  Result := Result + '..';
  if Assigned( FExitPoint ) then
    Result := Result + IntToStr( FExitPoint.Details.Line );
end;

function TProcedureInfo.MaxHitTime: TTimeSpan;
begin
  if ( FMaxTime = TTimeSpan.MinValue ) then
    Exit( TTimeSpan.Zero );
  Result := FMaxTime;
end;

function TProcedureInfo.MinHitTime: TTimeSpan;
begin
  if ( FMinTime = TTimeSpan.MaxValue ) then
    Exit( TTimeSpan.Zero );
  Result := FMinTime;
end;

function TProcedureInfo.CoveredLineCount: Integer;
var
  I: Integer;
  BreakPointList: TSimpleBreakPointList;
begin
  Result := 0;
  for I in FLines.Keys do
  begin
    BreakPointList := FLines[I];
    if IsCovered( BreakPointList ) then
    begin
      Inc( Result );
    end;
  end;
end;

function TProcedureInfo.IsCovered( const ABreakPointList: TSimpleBreakPointList ): Boolean;
var
  CurrentBreakPoint: IBreakPoint;
begin
  Result := False;
  for CurrentBreakPoint in ABreakPointList do
  begin
    if CurrentBreakPoint.IsCovered then
    begin
      Exit( True );
    end;
  end;
end;

function TProcedureInfo.IsLineCovered( const ALineNo: Integer ): Boolean;
var
  BreakPointList: TSimpleBreakPointList;
begin
  Result := False;
  if FLines.TryGetValue( ALineNo, BreakPointList ) then
  begin
    Result := IsCovered( BreakPointList );
  end;
end;

function TProcedureInfo.PercentCovered: Integer;
begin
  Result := ( 100 * CoveredLineCount ) div LineCount;
end;

procedure TProcedureInfo.RemoveBreakPointsForModule( const aBinaryModule: IDebugModule );
var
  BreakPointList: TSimpleBreakPointList;
begin
  for BreakPointList in FLines.Values.ToArray do
  begin
    BreakPointList.RemoveBreakPointsForModule( aBinaryModule );
    if ( BreakPointList.Count = 0 ) then
    begin
      FLines.Remove( BreakPointList.Line );
      BreakPointList.Free;
    end;
  end;
end;

function TProcedureInfo.GetName: string;
begin
  Result := FName;
end;

procedure TProcedureInfo.AddBreakpoint( const aBreakPoint: IBreakPoint );
var
  vBreakPointList: TSimpleBreakPointList;
begin
  if not( FLines.TryGetValue( aBreakPoint.Details.Line, vBreakPointList ) ) then
  begin
    vBreakPointList := TSimpleBreakPointList.Create( aBreakPoint.Details.Line );
    FLines.Add( aBreakPoint.Details.Line, vBreakPointList );
  end;
  vBreakPointList.Add( aBreakPoint );
  HandleEntryPoints( aBreakPoint );
end;

procedure TProcedureInfo.HandleEntryPoints( const aBreakPoint: IBreakPoint );
begin
  if not Assigned( FEntryPoint ) then
    FEntryPoint := aBreakPoint;
  if not Assigned( FExitPoint ) then
    FExitPoint := aBreakPoint;

  // Clear the event handlers from the breakpoints
  FEntryPoint.OnHit := nil;
  FExitPoint.OnHit := nil;

  if ( FEntryPoint.Details.Line > aBreakPoint.Details.Line ) then
    FEntryPoint := aBreakPoint;
  if ( FExitPoint.Details.Line < aBreakPoint.Details.Line ) then
    FExitPoint := aBreakPoint;

  // Set the events
  if ( FEntryPoint <> FExitPoint ) then
  begin
    FEntryPoint.OnHit := HandleEntryPointHit;
    FExitPoint.OnHit := HandleExitPointHit;
  end;
end;

procedure TProcedureInfo.HandleEntryPointHit( const aBreakPoint: IBreakPoint );
begin
  FStopwatch := TStopwatch.StartNew;
end;

procedure TProcedureInfo.HandleExitPointHit( const aBreakPoint: IBreakPoint );
var
  vElapsed: TTimeSpan;
begin
  FStopwatch.Stop;
  vElapsed := FStopwatch.Elapsed;

  if ( FMinTime > vElapsed ) then
    FMinTime := vElapsed;
  if ( FMaxTime < vElapsed ) then
    FMaxTime := vElapsed;

  FElapsedTicks := FElapsedTicks + vElapsed.Ticks;
  // Calculate floating Mean value
  // MeanValue = CurrentMean + (CurrentTime - CurrentMean) / NumberOfValuesNow
  if HitCount <> 0 then
    FAverageTicks := FAverageTicks + ( vElapsed.Ticks - FAverageTicks ) div HitCount;
end;

function TProcedureInfo.HitCount: Integer;
begin
  if Assigned( FEntryPoint ) then
    Result := FEntryPoint.BreakCount
  else
    Result := 0;
end;

{$ENDREGION 'TProcedureInfo'}
{ TSimpleBreakPointList }

constructor TSimpleBreakPointList.Create( const aLine: Integer );
begin
  inherited Create;
  FLine := aLine;
end;

procedure TSimpleBreakPointList.RemoveBreakPointsForModule( const aBinaryModule: IDebugModule );
var
  BreakPoint: IBreakPoint;
begin
  for BreakPoint in ToArray do
    if ( BreakPoint.Module = aBinaryModule ) then
      Remove( BreakPoint );
end;

end.
