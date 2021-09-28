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
unit LogManager;

interface

uses
  Generics.Collections,
  LoggingApi;

type
  TLogManager = class( TInterfacedObject, ILogManager )
  private
    FLoggers: TList<ILogger>;
    FLevel: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Log( const AMessage: string );
    procedure LogFmt( const AMessage: string; const Args: array of const );

    procedure AddLogger( const ALogger: ILogger );

    procedure Indent;
    procedure Undent;
  end;

function G_LogManager: ILogManager;
procedure ConsoleOutput( const AMessage: string );

implementation

uses
  System.SysUtils;

var
  LocalG_LogManager: ILogManager;

function G_LogManager: ILogManager;
begin
  if not Assigned( LocalG_LogManager ) then
    LocalG_LogManager := TLogManager.Create;
  Result := LocalG_LogManager;
end;

procedure Log( const AMessage: string );
begin
  G_LogManager.Log( AMessage );
end;

procedure ConsoleOutput( const AMessage: string );
begin
  {$IFNDEF CONSOLE_TESTRUNNER}
  if IsConsole then
  begin
    Writeln( AMessage );
  end;
  {$ENDIF}
  Log( AMessage );
end;

{ TLoggerManager }

constructor TLogManager.Create;
begin
  inherited;
  FLoggers := TList<ILogger>.Create;
end;

destructor TLogManager.Destroy;
begin
  FLoggers.Free;
  inherited;
end;

procedure TLogManager.Indent;
begin
  inc( FLevel );
end;

procedure TLogManager.AddLogger( const ALogger: ILogger );
begin
  FLoggers.Add( ALogger );
end;

procedure TLogManager.Log( const AMessage: string );
var
  Logger: ILogger;
begin
  for Logger in FLoggers do
    Logger.Log( StringOfChar( ' ', FLevel ) + AMessage );
end;

procedure TLogManager.LogFmt( const AMessage: string; const Args: array of const );
begin
  Self.Log( Format( AMessage, Args ) );
end;

procedure TLogManager.Undent;
begin
  Dec( FLevel );
  if FLevel < 0 then
    FLevel := 0;
end;

end.
