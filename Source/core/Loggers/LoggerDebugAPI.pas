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
unit LoggerDebugAPI;

interface

uses
  LoggingApi;

type
  TLoggerAPI = class( TInterfacedObject, ILogger )
  public
    procedure Log( const AMessage: string );
  end;

implementation

uses
  Windows;

{ TLoggerAPI }

procedure TLoggerAPI.Log( const AMessage: string );
begin
  OutputDebugString( PChar( AMessage ) );
end;

end.
