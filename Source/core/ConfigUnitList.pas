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
unit ConfigUnitList;

interface

uses
  System.Classes,
  System.Generics.Collections;

const
  IgnoreItemPrefix = '!';

type
  TConfigUnitData = class
    UnitName: string;
    Monitor: Boolean;
    SourceFilename: string;

    constructor Create( const aUnitName: string; const aSourcePath: string );
    function ToString: string; override;
  end;

  TConfigMethData = class
    FullyQualifiedMethodName: string;
    Monitor: Boolean;

    constructor Create( const aFullyQualifiedMethodName: string );
    function ToString: string; override;
  end;

  TConfigUnitList = class
  strict private
    FUnitRegistrations: TObjectDictionary<string, TConfigUnitData>;
    FMonitorAllUnits: Boolean;

    FMontitorProcedureRegistrations: TObjectDictionary<string, TConfigMethData>;

    FSourcePathLst: TStrings;
    function NormalizeUnitName( const aUnitName: string ): string;
    function NormalizeMethodName( const aFullyQualifiedMethodName: string ): string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddUnit( const aUnitName: string ); overload;
    procedure AddUnit( const aUnitName: string; const aSourcePath: string ); overload;
    procedure ReadUnitFile( const aFilename: string );
    function IsIncluded( const aUnitName: string ): Boolean;

    procedure AddMontitorProcedure( const aProcedureName: string );
    procedure ReadMonitorProcedureFile( const aFilename: string );
    function MonitorProcedure( const aUnitName: string; const aProcedureName: string ): Boolean;

    procedure AddSourceDirectory( const aSourceDirectory: string );
    function FindSourceFile( const aUnitName: string ): string;
    procedure ReadSourcePathFile( const aSourceFileName: string );

    procedure LogTracking;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  JclFileUtils,
  DebuggerUtils,
  LogManager;

{ TConfigUnitData }

constructor TConfigUnitData.Create( const aUnitName: string; const aSourcePath: string );
begin
  inherited Create;
  Monitor := not( aUnitName[1] = IgnoreItemPrefix );
  if not Monitor then
    UnitName := Copy( aUnitName, 2, Length( aUnitName ) - 1 )
  else
    UnitName := aUnitName;
  SourceFilename := aSourcePath;
end;

function TConfigUnitData.ToString: string;
begin
  Result := UnitName;

  if not Monitor then
    Result := IgnoreItemPrefix + UnitName;

  if SourceFilename <> '' then
    Result := Result + ' (' + SourceFilename + ')';
end;

{ TConfigMethData }

constructor TConfigMethData.Create( const aFullyQualifiedMethodName: string );
begin
  inherited Create;
  Monitor := not( aFullyQualifiedMethodName[1] = IgnoreItemPrefix );
  if not Monitor then
    FullyQualifiedMethodName := Copy( aFullyQualifiedMethodName, 2, Length( aFullyQualifiedMethodName ) - 1 )
  else
    FullyQualifiedMethodName := aFullyQualifiedMethodName;
end;

function TConfigMethData.ToString: string;
begin
  Result := FullyQualifiedMethodName;

  if not Monitor then
    Result := IgnoreItemPrefix + FullyQualifiedMethodName;
end;

{ TConfigUnitList }

function TConfigUnitList.NormalizeMethodName( const aFullyQualifiedMethodName: string ): string;
begin
  if aFullyQualifiedMethodName = '' then
    Exit( '' );
  Result := LowerCase( aFullyQualifiedMethodName );

  if Result[1] = IgnoreItemPrefix then
    Result := Copy( aFullyQualifiedMethodName, 2, Length( aFullyQualifiedMethodName ) - 1 );
end;

function TConfigUnitList.NormalizeUnitName( const aUnitName: string ): string;
begin
  if aUnitName = '' then
    Exit( '' );

  // Normalize the name by removing a possible .pas file extention and prefix and making it lower case.
  Result := LowerCase( aUnitName );

  if Result[1] = IgnoreItemPrefix then
    Result := Copy( aUnitName, 2, Length( aUnitName ) - 1 );

  if Result.EndsWith( '.pas' ) then
    Result := PathRemoveExtension( Result ); // Ensures that we strip out .pas if it was added for some reason
end;

procedure TConfigUnitList.AddUnit( const aUnitName: string );
begin
  AddUnit( aUnitName, '' );
end;

procedure TConfigUnitList.AddMontitorProcedure( const aProcedureName: string );
var
  vNormalized: string;
  vMonitorData: TConfigMethData;
begin
  vNormalized := NormalizeMethodName( aProcedureName );
  if vNormalized = '' then
    Exit;

  vMonitorData := TConfigMethData.Create( aProcedureName );
  FMontitorProcedureRegistrations.Add( vNormalized, vMonitorData );

  // Deactivate all units monitoring if we monitor a special method
  if vMonitorData.Monitor then
    FMonitorAllUnits := False;
end;

procedure TConfigUnitList.AddSourceDirectory( const aSourceDirectory: string );
var
  vItem: string;
begin
  vItem := ExpandEnvString( aSourceDirectory );
  if FSourcePathLst.IndexOf( vItem ) < 0 then
    FSourcePathLst.Add( vItem );
end;

procedure TConfigUnitList.AddUnit( const aUnitName, aSourcePath: string );
var
  vNormalized: string;
begin
  vNormalized := NormalizeUnitName( aUnitName );
  if vNormalized = '' then
    Exit;

  FUnitRegistrations.Add( vNormalized, TConfigUnitData.Create( aUnitName, aSourcePath ) );
  if aSourcePath <> '' then
    AddSourceDirectory( TPath.GetDirectoryName( aSourcePath ) );
  FMonitorAllUnits := False;
end;

constructor TConfigUnitList.Create;
begin
  inherited Create;
  FUnitRegistrations := TObjectDictionary<string, TConfigUnitData>.Create( [doOwnsValues] );
  FMonitorAllUnits := True;

  FMontitorProcedureRegistrations := TObjectDictionary<string, TConfigMethData>.Create( [doOwnsValues] );

  FSourcePathLst := TStringList.Create;
end;

destructor TConfigUnitList.Destroy;
begin
  FMontitorProcedureRegistrations.Free;
  FSourcePathLst.Free;
  FUnitRegistrations.Free;
  inherited Destroy;
end;

function TConfigUnitList.FindSourceFile( const aUnitName: string ): string;
var
  vInfo: TConfigUnitData;
begin
  if FUnitRegistrations.TryGetValue( NormalizeUnitName( aUnitName ), vInfo ) and ( vInfo.SourceFilename <> '' ) then
    Exit( vInfo.SourceFilename );

  for var vSourcePath in FSourcePathLst do
  begin
    Result := TPath.GetFullPath( TPath.Combine( vSourcePath, aUnitName ) );
    if FileExists( Result ) then
    begin
      if Assigned( vInfo ) then
        vInfo.SourceFilename := Result;
      Exit;
    end;
  end;
  Result := ''; // not found
end;

function TConfigUnitList.IsIncluded( const aUnitName: string ): Boolean;
var
  vInfo: TConfigUnitData;
begin
  // We consider a unit included when :
  // * it is in the list as monitored or
  // * the list is empty
  Result := FMonitorAllUnits or ( FUnitRegistrations.TryGetValue( NormalizeUnitName( aUnitName ), vInfo ) and vInfo.Monitor );
end;

procedure TConfigUnitList.LogTracking;
begin
  for var vUnitInfo in FUnitRegistrations.Values do
    G_LogManager.Log( 'Unit Tracking: ' + vUnitInfo.ToString );
end;

function TConfigUnitList.MonitorProcedure( const aUnitName: string; const aProcedureName: string ): Boolean;
var
  vInfo: TConfigMethData;
begin
  // We consider a procedure to be monitored when :
  // * it is in the list as monitored or
  // * the unit is in the watched list -> IsIncluded
  // We consider a procedure not monitored if:
  // * When the above is not true and
  // * when we monitor a unit, but explicitly don't monitor a method

  if FMontitorProcedureRegistrations.TryGetValue( NormalizeMethodName( aProcedureName ), vInfo ) then
    Result := vInfo.Monitor
  else
    Result := IsIncluded( aUnitName );
end;

procedure TConfigUnitList.ReadMonitorProcedureFile( const aFilename: string );
var
  InputFile: TextFile;
  vMethodName: string;
begin
  G_LogManager.Log( 'Reading procedures from the following file: ' + aFilename );

  OpenInputFileForReading( aFilename, InputFile );
  try
    while not Eof( InputFile ) do
    begin
      ReadLn( InputFile, vMethodName );
      AddMontitorProcedure( vMethodName );
    end;
  finally
    CloseFile( InputFile );
  end;
end;

procedure TConfigUnitList.ReadSourcePathFile( const aSourceFileName: string );
var
  InputFile: TextFile;
  SourcePathLine: string;
  vRootPath: string;
begin
  vRootPath := TPath.GetDirectoryName( aSourceFileName );
  OpenInputFileForReading( aSourceFileName, InputFile );
  try
    while ( not Eof( InputFile ) ) do
    begin
      ReadLn( InputFile, SourcePathLine );

      SourcePathLine := MakePathAbsolute( SourcePathLine, vRootPath );

      if DirectoryExists( SourcePathLine ) then
        FSourcePathLst.Add( SourcePathLine );
    end;
  finally
    CloseFile( InputFile );
  end;
end;

procedure TConfigUnitList.ReadUnitFile( const aFilename: string );
var
  InputFile: TextFile;
  UnitLine: string;
begin
  G_LogManager.Log( 'Reading units from the following file: ' + aFilename );

  OpenInputFileForReading( aFilename, InputFile );
  try
    while not Eof( InputFile ) do
    begin
      ReadLn( InputFile, UnitLine );
      AddUnit( UnitLine );
    end;
  finally
    CloseFile( InputFile );
  end;
end;

end.
