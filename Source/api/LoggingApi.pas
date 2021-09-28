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
unit LoggingApi;

interface

type
  ILogger = interface
    procedure Log( const AMessage: string );
  end;

  ILogManager = interface
    procedure Log( const AMessage: string );
    procedure LogFmt( const AMessage: string; const Args: array of const );

    procedure AddLogger( const ALogger: ILogger );
    /// <summary>Indent the output - for better reading an grouping.</summary>
    procedure Indent;
    /// <summary>Remove a indentation.</summary>
    procedure Undent;
  end;

implementation

end.
