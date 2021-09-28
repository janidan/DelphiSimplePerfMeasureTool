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
unit LoggerTextFile;

interface

uses
  System.SysUtils,
  LoggingApi;

type
  TLoggerTextFile = class( TInterfacedObject, ILogger )
  private
    FTextFile: TextFile;
  public
    constructor Create( const AFileName: TFileName );
    destructor Destroy; override;

    procedure Log( const AMessage: string );
  end;

implementation

uses IOUtils;

{ TLoggerTextFile }

constructor TLoggerTextFile.Create( const AFileName: TFileName );
begin
  inherited Create;

  ForceDirectories( TPath.GetDirectoryName( TPath.GetFullPath( AFileName ) ) );
  AssignFile( FTextFile, AFileName );
  ReWrite( FTextFile );
end;

destructor TLoggerTextFile.Destroy;
begin
  CloseFile( FTextFile );

  inherited;
end;

procedure TLoggerTextFile.Log( const AMessage: string );
begin
  WriteLn( FTextFile, AMessage );
  Flush( FTextFile );
end;

end.
