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
unit EntryPointDump;

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  JclDebug,
  LoggingApi,
  CoverageConfiguration,
  ConfigUnitList,
  DebuggerUtils;

procedure GenerateEntryPointDump( const aCoverageConfiguration: ICoverageConfiguration; const aOutputLogger: ILogger );

implementation

function DumpMapFileEntrypoints( const aBinaryFile: string; const aCoverageConfiguration: ICoverageConfiguration; const aOutputLogger: ILogger ): Boolean;
var
  vMapFilename: string;
  vMapScanner: TJCLMapScanner;
  vUnitList: TConfigUnitList;
  vMapLineNumber: TJclMapLineNumber;
  vUnitModuleName: string;
  vFullyQualifiedMethodName: string;
  vEntryPoints: TStringList;
begin
  vMapFilename := aCoverageConfiguration.GetMapFileName( aBinaryFile );
  if not FileExists( vMapFilename ) then
    Exit( False );

  vUnitList := aCoverageConfiguration.UnitList;
  vEntryPoints := TStringList.Create;
  try
    vEntryPoints.Duplicates := TDuplicates.dupIgnore;
    vEntryPoints.Sorted := True;
    vMapScanner := TJCLMapScanner.Create( vMapFilename );
    try
      for var vLineIndex := 0 to vMapScanner.LineNumbersCnt - 1 do
      begin
        vMapLineNumber := vMapScanner.LineNumberByIndex[vLineIndex];
        // RINGN:Segment 2 are .itext (ICODE). and 1 = Code
        if ( vMapLineNumber.Segment in [1, 2] ) then
        begin
          vUnitModuleName := vMapScanner.ModuleNameFromAddr( vMapLineNumber.VA );
          vFullyQualifiedMethodName := vMapScanner.ProcNameFromAddr( vMapLineNumber.VA );
          if vUnitList.MonitorProcedure( vUnitModuleName, vFullyQualifiedMethodName ) then
            vEntryPoints.Add( vFullyQualifiedMethodName );
        end;
      end;
    finally
      vMapScanner.Free;
    end;

    if vEntryPoints.Count > 0 then
    begin
      aOutputLogger.Log( '# Entrypoints for: ' + TPath.GetFileName( aBinaryFile ) );
      aOutputLogger.Log( '# ----------------' );
      for var i := 0 to vEntryPoints.Count - 1 do
        aOutputLogger.Log( vEntryPoints[i] );
    end;
  finally
    vEntryPoints.Free;
  end;
  Result := True;
end;

procedure InterateOverBinaryFile( const aBinaryFile: string; const aCoverageConfiguration: ICoverageConfiguration; const aOutputLogger: ILogger;
  const aVisitedModules: TStrings );
begin
  if aVisitedModules.IndexOf( aBinaryFile ) >= 0 then
    Exit;
  aVisitedModules.Add( aBinaryFile );

  if not DumpMapFileEntrypoints( aBinaryFile, aCoverageConfiguration, aOutputLogger ) then
    Exit;

  for var vImport in GetImportsList( aBinaryFile ) do
    InterateOverBinaryFile( vImport, aCoverageConfiguration, aOutputLogger, aVisitedModules );
end;

procedure GenerateEntryPointDump( const aCoverageConfiguration: ICoverageConfiguration; const aOutputLogger: ILogger );
var
  vVisitedModules: TStringList;
begin
  vVisitedModules := TStringList.Create;
  try
    InterateOverBinaryFile( aCoverageConfiguration.ExeFileName, aCoverageConfiguration, aOutputLogger, vVisitedModules );
  finally
    vVisitedModules.Free;
  end;
end;

end.
