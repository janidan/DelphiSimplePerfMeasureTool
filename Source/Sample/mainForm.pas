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
unit mainForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls;

type
  TForm1 = class( TForm )
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    Button7: TButton;
    Button8: TButton;
    Button9: TButton;
    procedure Button1Click( Sender: TObject );
    procedure Button2Click( Sender: TObject );
    procedure Button3Click( Sender: TObject );
    procedure Button4Click( Sender: TObject );
    procedure Button5Click( Sender: TObject );
    procedure Button6Click( Sender: TObject );
    procedure Button7Click( Sender: TObject );
    procedure Button8Click( Sender: TObject );
    procedure Button9Click( Sender: TObject );
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses
  BplUnit,
  BplUnit.Second;

{$R *.dfm}

procedure TForm1.Button1Click( Sender: TObject );
begin
  //
end;

procedure TForm1.Button2Click( Sender: TObject );
begin
  DoSomethingInBpl;
end;

procedure TForm1.Button3Click( Sender: TObject );
begin
  TSomeRecord.DoSomethingInBplUnit2;
  DoSomethingInBpl2;
end;

procedure TForm1.Button4Click( Sender: TObject );
begin
  with TSimpleClass.Create do
  begin
    SimpleProc;
    Free;
  end;
end;

procedure TForm1.Button5Click( Sender: TObject );
begin
  with TSimpleGeneric<Byte>.Create do
  begin
    SimpleProc;
    Free;
  end;
end;

procedure TForm1.Button6Click( Sender: TObject );
begin
  TSimpleClassMeth.ClassProc;
end;

procedure TForm1.Button7Click( Sender: TObject );
begin
  TSimpleGeneric<Byte>.ClassProc;
  TSimpleClassWithGeneric.ClassProc<Byte>;
end;

procedure TForm1.Button8Click( Sender: TObject );
begin
  TAnonymousMeth.ClassProcAnon;
end;

procedure TForm1.Button9Click( Sender: TObject );
begin
  with TMetaAttClass.Create do
  begin
    SimpleProc;
    Free;
  end;
end;

end.
