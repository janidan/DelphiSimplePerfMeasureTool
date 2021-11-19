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
unit DebugProcess;

interface

uses
  Classes,
  Windows,
  DebuggerApi,
  LoggingApi,
  Generics.Collections,
  JCLDebug;

type
  TDebugProcess = class( TInterfacedObject, IDebugProcess )
  private
    FProcessHandle: THandle;
    FProcessBase: NativeUInt;
    FModuleList: TList<IDebugModule>;

    FDebugThreadLst: IInterfaceList;
    FLogManager: ILogManager;
    FName: String;
    FFilename: string;
    FFilepath: string;
    FHFile: THandle;
    FMapScanner: TJCLMapScanner;
  public
    constructor Create( //
      const aProcessId: DWORD; //
      const aProcessHandle: THandle; //
      const aProcessBase: NativeUInt; //
      const aFilepath: string; //
      const aHFile: THandle; //
      const aMapScanner: TJCLMapScanner; //
      const aLogManager: ILogManager );
    destructor Destroy; override;

    procedure AddThread( const aDebugThread: IDebugThread );
    procedure RemoveThread( const aThreadId: DWORD );

    procedure AddModule( const aModule: IDebugModule );
    procedure RemoveModule( const aModule: IDebugModule );
    function GetModuleByFilename( const aFilepath: string ): IDebugModule;
    function GetModuleByBase( const aAddress: NativeUInt ): IDebugModule;

    function Name: string;
    function Filename: string;
    function Filepath: string;
    function HFile: THandle; inline;
    function Base: NativeUInt; inline;
    function Handle: THandle; inline;
    function Size: Cardinal;
    function CodeBegin: NativeUInt;
    function CodeEnd: NativeUInt;
    function MapScanner: TJCLMapScanner;
    function FindDebugModuleFromAddress( Addr: Pointer ): IDebugModule;

    function GetThreadById( const aThreadId: DWORD ): IDebugThread;
    function ReadProcessMemory( const aAddress, AData: Pointer; const aSize: Cardinal; const aChangeProtect: Boolean = False ): Integer;
    function WriteProcessMemory( const aAddress, AData: Pointer; const aSize: Cardinal; const aChangeProtect: Boolean = False ): Integer;
  end;

implementation

uses
  SysUtils,
  JwaWinBase,
  DebuggerUtils;

function TDebugProcess.CodeBegin: NativeUInt;
begin
  Result := FProcessBase + $1000;
end;

function TDebugProcess.CodeEnd: NativeUInt;
begin
  Result := FProcessBase + $1000 + Size;
end;

constructor TDebugProcess.Create( const aProcessId: DWORD; const aProcessHandle: THandle; const aProcessBase: NativeUInt; const aFilepath: string;
  const aHFile: THandle; const aMapScanner: TJCLMapScanner; const aLogManager: ILogManager );
begin
  inherited Create;

  FProcessHandle := aProcessHandle;
  FProcessBase := aProcessBase;
  FDebugThreadLst := TInterfaceList.Create;
  FModuleList := TList<IDebugModule>.Create;

  FFilepath := aFilepath;
  FFilename := ExtractFileName( aFilepath );
  FName := ChangeFileExt( FFilename, '' );

  FHFile := aHFile;
  FLogManager := aLogManager;
  FMapScanner := aMapScanner;
end;

destructor TDebugProcess.Destroy;
begin
  FDebugThreadLst := nil;
  FLogManager := nil;
  FModuleList.Free;
  FModuleList := nil;

  inherited;
end;

procedure TDebugProcess.AddThread( const aDebugThread: IDebugThread );
begin
  FDebugThreadLst.Add( aDebugThread );
end;

procedure TDebugProcess.RemoveThread( const aThreadId: DWORD );
var
  DebugThread: IDebugThread;
begin
  DebugThread := GetThreadById( aThreadId );
  if ( DebugThread <> nil ) then
    FDebugThreadLst.Remove( DebugThread );
end;

function TDebugProcess.Name: string;
begin
  Result := FName;
end;

procedure TDebugProcess.AddModule( const aModule: IDebugModule );
begin
  FModuleList.Add( aModule );
end;

procedure TDebugProcess.RemoveModule( const aModule: IDebugModule );
begin
  FModuleList.Remove( aModule );
end;

function TDebugProcess.GetModuleByFilename( const aFilepath: string ): IDebugModule;
var
  CurrentModule: IDebugModule;
begin
  Result := nil;
  for CurrentModule in FModuleList do
  begin
    if AnsiSameStr( CurrentModule.Filepath, aFilepath ) then
      Exit( CurrentModule );
  end;
end;

function TDebugProcess.GetModuleByBase( const aAddress: NativeUInt ): IDebugModule;
var
  CurrentModule: IDebugModule;
begin
  Result := nil;
  for CurrentModule in FModuleList do
  begin
    if CurrentModule.Base = aAddress then
      Exit( CurrentModule );
  end;
end;

function TDebugProcess.Handle: THandle;
begin
  Result := FProcessHandle;
end;

function TDebugProcess.HFile: THandle;
begin
  Result := FHFile;
end;

function TDebugProcess.Base: NativeUInt;
begin
  Result := FProcessBase;
end;

function TDebugProcess.Size: Cardinal;
begin
  Result := GetImageCodeSize( FFilepath );
end;

function TDebugProcess.MapScanner: TJCLMapScanner;
begin
  Result := FMapScanner;
end;

function TDebugProcess.Filename: string;
begin
  Result := FFilename;
end;

function TDebugProcess.Filepath: string;
begin
  Result := FFilepath;
end;

function TDebugProcess.FindDebugModuleFromAddress( Addr: Pointer ): IDebugModule;
var
  CurrentModule: IDebugModule;
  ModuleAddress: NativeUInt;

  function AddressBelongsToModule( const aModule: IDebugModule ): Boolean;
  begin
    Result := ( ( ModuleAddress >= aModule.CodeBegin ) and ( ModuleAddress <= aModule.CodeEnd ) );
  end;

begin
  Result := nil;

  ModuleAddress := NativeUInt( Addr );

  if AddressBelongsToModule( IDebugProcess( Self ) ) then
    Result := IDebugProcess( Self )
  else
  begin
    for CurrentModule in FModuleList do
    begin
      if AddressBelongsToModule( CurrentModule ) then
        Exit( CurrentModule );
    end;
  end;
end;

function TDebugProcess.GetThreadById( const aThreadId: DWORD ): IDebugThread;
var
  ThreadIndex: Integer;
  CurrentThread: IInterface;
begin
  Result := nil;
  for ThreadIndex := 0 to FDebugThreadLst.Count - 1 do
  begin
    CurrentThread := FDebugThreadLst[ThreadIndex];
    if IDebugThread( CurrentThread ).Id = aThreadId then
      Exit( IDebugThread( CurrentThread ) );
  end;
end;

function TDebugProcess.ReadProcessMemory( const aAddress, AData: Pointer; const aSize: Cardinal; const aChangeProtect: Boolean = False ): Integer;
var
  oldprot: UINT;
  numbytes: DWORD;
  changed: Boolean;
begin
  changed := False;
  if not JwaWinBase.ReadProcessMemory( Handle, aAddress, AData, aSize, @numbytes ) then
  begin
    // try changing protection
    if aChangeProtect and not VirtualProtectEx( Handle, aAddress, aSize, PAGE_EXECUTE_READ, @oldprot ) then
    begin
      changed := true;
      if not JwaWinBase.ReadProcessMemory( Handle, aAddress, AData, aSize, @numbytes ) then
      begin
        FLogManager.Log( 'ReadProcessMemory failed reading address - ' + AddressToString( aAddress ) + ' Error:' + LastOsErrorInfo );
        Result := -1;
        Exit;
      end;
    end
    else
    begin
      FLogManager.Log( 'ReadProcessMemory failed to change protection - ' + AddressToString( aAddress ) + ' Error:' + LastOsErrorInfo );
    end;
  end;

  if numbytes <> aSize then
  begin
    FLogManager.Log( 'ReadProcessMemory failed to read address - ' + AddressToString( aAddress ) + ' Wrong number of bytes - ' + IntToStr( numbytes ) +
      ' Error:' + LastOsErrorInfo );
    Result := -1;
    Exit;
  end;

  if changed then
  begin
    if aChangeProtect and not VirtualProtectEx( Handle, aAddress, aSize, oldprot, @oldprot ) then
    begin
      FLogManager.Log( 'ReadProcessMemory Failed to restore access read address - ' + AddressToString( aAddress ) + ' Error:' + LastOsErrorInfo );
      Result := 0;
      Exit;
    end;
  end;

  Result := numbytes;
end;

function TDebugProcess.WriteProcessMemory( const aAddress, AData: Pointer; const aSize: Cardinal; const aChangeProtect: Boolean = False ): Integer;
var
  oldprot: UINT;
  numbytes: DWORD;
  changed: Boolean;
begin
  changed := False; // keep track if we changed page protection

  if not JwaWinBase.WriteProcessMemory( Handle, aAddress, AData, aSize, @numbytes ) then
  begin
    // Failed to write, thus we try to change the protection
    if aChangeProtect and not( VirtualProtectEx( Handle, aAddress, aSize, PAGE_EXECUTE_READWRITE, @oldprot ) ) then
    begin
      FLogManager.Log( 'WriteProcessMemory failed to change protection to PAGE_EXECUTE_READWRITE address - ' + AddressToString( aAddress ) + ' Error:' +
        LastOsErrorInfo );
      Result := -1;
      Exit;
    end
    else
    begin
      changed := true;

      // Try again after changing protection
      if not JwaWinBase.WriteProcessMemory( Handle, aAddress, AData, aSize, @numbytes ) then
      begin
        FLogManager.Log( 'WriteProcessMemory failed writing address - ' + AddressToString( aAddress ) + ' Error:' + LastOsErrorInfo );
        Result := -1;
        Exit;
      end;
    end;
  end;

  if ( numbytes <> aSize ) then
  begin
    FLogManager.Log( 'WriteProcessMemory failed to write address - ' + AddressToString( aAddress ) + ' Wrong number of bytes - ' + IntToStr( numbytes ) +
      ' Error:' + LastOsErrorInfo );
    Result := -1;
    Exit;
  end;

  if changed and aChangeProtect and not VirtualProtectEx( Handle, aAddress, aSize, oldprot, @oldprot ) then
  begin
    FLogManager.Log( 'WriteProcessMemory: Failed to restore access read address - ' + AddressToString( aAddress ) + ' Error:' + LastOsErrorInfo );
    Result := 0;
    Exit;
  end;

  if not( FlushInstructionCache( Handle, aAddress, numbytes ) ) then
  begin
    FLogManager.Log( 'WriteProcessMemory: FlushInstructionCache failed for address - ' + AddressToString( aAddress ) + ' Error:' + LastOsErrorInfo );
  end;

  Result := numbytes;
end;

end.
