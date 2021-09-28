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
unit BplUnit.Second;

interface

type
  TSomeRecord = record
    class procedure DoSomethingInBplUnit2; static;
  end;

  TClassWithGenerics = class
    procedure SimpleGenericProc<T>;
    class procedure ClassProc<T>;
  end;

procedure DoSomethingInBpl2;

implementation

uses
  Vcl.Dialogs;

procedure DoSomethingInBpl2;
begin
  ShowMessage( 'DoSomethingInBplUnit2' );
end;

{ TSomeRecord }

class procedure TSomeRecord.DoSomethingInBplUnit2;
begin
  DoSomethingInBpl2;
end;

{ TClassWithGenerics }

class procedure TClassWithGenerics.ClassProc<T>;
begin
  //
end;

procedure TClassWithGenerics.SimpleGenericProc<T>;
begin
  //
end;

initialization

finalization

end.
