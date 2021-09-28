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
unit BreakPointList;

interface

uses
  System.Generics.Collections,
  DebuggerApi;

type
  TBreakPointList = class( TInterfacedObject, IBreakPointList )
  strict private
    FBreakPointLst: TDictionary<Pointer, IBreakPoint>;

    function GetBreakPoints: TArray<IBreakPoint>;

    function GetBreakPointByAddress( const AAddress: Pointer ): IBreakPoint;

    procedure Add( const ABreakPoint: IBreakPoint );
    procedure RemoveModuleBreakpoints( const AModule: IDebugModule );

    function Count: Integer;
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

uses
  Classes,
  SysUtils,
  DebuggerUtils;

constructor TBreakPointList.Create;
begin
  inherited Create;
  FBreakPointLst := TDictionary<Pointer, IBreakPoint>.Create( 100 );
end;

destructor TBreakPointList.Destroy;
begin
  FBreakPointLst.Free;
  inherited Destroy;
end;

function TBreakPointList.Count: Integer;
begin
  Result := FBreakPointLst.Count;
end;

procedure TBreakPointList.Add( const ABreakPoint: IBreakPoint );
begin
  FBreakPointLst.AddOrSetValue( ABreakPoint.Address, ABreakPoint );
end;

function TBreakPointList.GetBreakPointByAddress( const AAddress: Pointer ): IBreakPoint;
begin
  FBreakPointLst.TryGetValue( AAddress, Result );
end;

function TBreakPointList.GetBreakPoints: TArray<IBreakPoint>;
begin
  Result := FBreakPointLst.Values.ToArray;
end;

procedure TBreakPointList.RemoveModuleBreakpoints( const AModule: IDebugModule );
var
  BreakPoint: IBreakPoint;
begin
  for BreakPoint in GetBreakPoints do
    if ( AModule = BreakPoint.Module ) then
      FBreakPointLst.Remove( BreakPoint.Address );
end;

end.
