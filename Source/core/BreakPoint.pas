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
unit BreakPoint;

interface

uses
  Classes,
  DebuggerApi,
  LoggingApi;

type
  TBreakPoint = class( TInterfacedObject, IBreakPoint )
  strict private
    FOld_Opcode: Byte;
    FActive: Boolean;
    FAddress: Pointer;
    FBreakCount: integer;
    FHitTime: TTime;
    FProcess: IDebugProcess;
    FModule: IDebugModule;
    FDetails: TBreakPointDetail;
    FLogManager: ILogManager;
    FOnHit: TBreakPointTrigger;

  strict private
    procedure DoOnHit;
    function GetOnHit: TBreakPointTrigger;
    procedure SetOnHit( const aEventHit: TBreakPointTrigger );

    procedure InternalClear( const AThread: IDebugThread; const aSetTrapFlag: Boolean );

    function DeActivate: Boolean;
    function Hit( const AThread: IDebugThread ): Boolean;

    procedure Clear( const AThread: IDebugThread );

    function Details: TBreakPointDetail;
    function DetailsToString: string;

    function IsActive: Boolean;

    function BreakCount: integer;
    function HitTime: TTime;

    procedure IncBreakCount;

    function Activate: Boolean;
    function Address: Pointer;
    function Module: IDebugModule;

    function GetCovered: Boolean;
  public
    constructor Create( const aDebugProcess: IDebugProcess; //
      const aAddress: Pointer; //
      const aVirtualAddress: Cardinal; //
      const aModule: IDebugModule; //
      const aFQName: string; //
      const aMethodEntryVirtualAddress: Cardinal; //
      const aModuleName: string; //
      const aUnitName: string; //
      const aUnitFileName: string; //
      const aLineNumber: integer; //
      const aLogManager: ILogManager );
    procedure BeforeDestruction; override;
  end;

implementation

uses
  SysUtils,
  Windows,
  CoverageConfiguration,
  DebuggerUtils;

constructor TBreakPoint.Create( const aDebugProcess: IDebugProcess; //
  const aAddress: Pointer; //
  const aVirtualAddress: Cardinal; //
  const aModule: IDebugModule; //
  const aFQName: string; //
  const aMethodEntryVirtualAddress: Cardinal; //
  const aModuleName: string; //
  const aUnitName: string; //
  const aUnitFileName: string; //
  const aLineNumber: integer; //
  const aLogManager: ILogManager );
begin
  inherited Create;

  FAddress := aAddress;
  FProcess := aDebugProcess;
  FActive := False;
  FBreakCount := 0;
  FModule := aModule;

  FDetails.FullyQualifiedMethodName := aFQName;
  FDetails.ModuleName := aModuleName;
  FDetails.MethodEntryVirtualAddress := aMethodEntryVirtualAddress;
  FDetails.UnitName := aUnitName;
  FDetails.UnitFileName := aUnitFileName;
  FDetails.Line := aLineNumber;
  FDetails.VirtualAddress := aVirtualAddress;
  FDetails.ParseFullyQualifiedName;

  FLogManager := aLogManager;
end;

function TBreakPoint.Activate: Boolean;
var
  OpCode: Byte;
  BytesRead: DWORD;
  BytesWritten: DWORD;
begin
  Result := FActive;
  if not Result then
  begin
    BytesRead := FProcess.ReadProcessMemory( FAddress, @FOld_Opcode, 1, true );
    if BytesRead = 1 then
    begin
      OpCode := $CC;
      BytesWritten := FProcess.WriteProcessMemory( FAddress, @OpCode, 1, true );
      FlushInstructionCache( FProcess.Handle, FAddress, 1 );
      if BytesWritten = 1 then
      begin
        FLogManager.Log( 'Activating ' + DetailsToString );
        FActive := true;
        Result := true;
      end;
    end;
  end;
end;

function TBreakPoint.DeActivate: Boolean;
var
  BytesWritten: DWORD;
begin
  Result := not FActive;

  if not Result then
  begin
    BytesWritten := FProcess.WriteProcessMemory( FAddress, @FOld_Opcode, 1, true );
    FlushInstructionCache( FProcess.Handle, FAddress, 1 );
    FLogManager.Log( 'Deactivating Breakpoint: ' + DetailsToString );
    Result := ( BytesWritten = 1 );
    FActive := False;
  end;
end;

function TBreakPoint.Details: TBreakPointDetail;
begin
  Result := FDetails;
end;

function TBreakPoint.DetailsToString: string;
begin
  Result := Format( 'Breakpoint at %s[%s]: %s.%s.%s%d[%d]', [AddressToString( FAddress ), AddressToString( FDetails.VirtualAddress ), //
    FDetails.ModuleName, FDetails.ClassName, FDetails.MethodName, FDetails.MethodEntryVirtualAddress, FDetails.Line] );
end;

procedure TBreakPoint.DoOnHit;
begin
  if Assigned( FOnHit ) then
    FOnHit( Self );
end;

procedure TBreakPoint.Clear( const AThread: IDebugThread );
begin
  InternalClear( AThread, False );
end;

function TBreakPoint.IsActive: Boolean;
begin
  Result := FActive;
end;

function TBreakPoint.Address: Pointer;
begin
  Result := FAddress;
end;

function TBreakPoint.Module: IDebugModule;
begin
  Result := FModule;
end;

procedure TBreakPoint.SetOnHit( const aEventHit: TBreakPointTrigger );
begin
  FOnHit := aEventHit;
end;

procedure TBreakPoint.BeforeDestruction;
begin
  FLogManager.Log( 'Destroying ' + DetailsToString + ' Hitcount: ' + IntToStr( FBreakCount ) );
  inherited BeforeDestruction;
end;

function TBreakPoint.BreakCount: integer;
begin
  Result := FBreakCount;
end;

procedure TBreakPoint.IncBreakCount;
begin
  Inc( FBreakCount );
end;

procedure TBreakPoint.InternalClear( const AThread: IDebugThread; const aSetTrapFlag: Boolean );
const
  CONTEXT_FLAG_TRAP = $100;
var
  ContextRecord: CONTEXT;
  Result: BOOL;
begin
  FLogManager.Log( 'Clearing ' + DetailsToString + ' Hitcount: ' + IntToStr( FBreakCount ) );

  ContextRecord.ContextFlags := CONTEXT_CONTROL;
  Result := GetThreadContext( AThread.Handle, ContextRecord );
  if Result then
  begin
    DeActivate; // If aSetTrapFlag -> reenabled in the STATUS_SINGLE_STEP debugger event
    // Rewind to previous instruction
    {$IF Defined(CPUX64)}
    Dec( ContextRecord.Rip );
    {$ELSEIF Defined(CPUX86)}
    Dec( ContextRecord.Eip );
    {$ELSE}
    {$MESSAGE FATAL 'Unsupported Platform'}
    {$ENDIF}
    ContextRecord.ContextFlags := CONTEXT_CONTROL;
    if aSetTrapFlag then // Set TF (Trap Flag so we get debug exception after next instruction
      ContextRecord.EFlags := ContextRecord.EFlags or CONTEXT_FLAG_TRAP;
    Result := SetThreadContext( AThread.Handle, ContextRecord );
    if ( not Result ) then
      FLogManager.Log( 'Failed setting thread context:' + LastOsErrorInfo );
  end
  else
    FLogManager.Log( 'Failed to get thread context   ' + LastOsErrorInfo );
end;

function TBreakPoint.GetCovered: Boolean;
begin
  Result := FBreakCount > 0;
end;

function TBreakPoint.GetOnHit: TBreakPointTrigger;
begin
  Result := FOnHit;
end;

function TBreakPoint.Hit( const AThread: IDebugThread ): Boolean;
begin
  FHitTime := Now;
  IncBreakCount;
  DoOnHit;
  Result := Assigned( FOnHit ); // Reenable Breakpoints that are tracked
  InternalClear( AThread, Result );
end;

function TBreakPoint.HitTime: TTime;
begin
  Result := FHitTime;
end;

end.
