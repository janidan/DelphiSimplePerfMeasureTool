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
unit DebugModule;

interface

uses
  Classes,
  DebuggerApi,
  JCLDebug;

type
  TDebugModule = class( TInterfacedObject, IDebugModule )
  strict private
    FName: String;
    FFilename: string;
    FFilepath: string;
    FHFile: THandle;
    FBase: NativeUInt;
    FSize: Cardinal;
    FCodeBegin: NativeUInt;
    FCodeEnd: NativeUInt;
    FMapScanner: TJCLMapScanner;

    function Name: string;
    function Filename: string;
    function Filepath: string;

    function HFile: THandle;
    function Base: NativeUInt;
    function Size: Cardinal;
    function CodeBegin: NativeUInt;
    function CodeEnd: NativeUInt;
    function MapScanner: TJCLMapScanner;
  public
    constructor Create( const aFilepath: string; const aHFile: THandle; const aBase: NativeUInt; const aMapScanner: TJCLMapScanner );
    destructor Destroy; override;
    procedure AfterConstruction; override;
  end;

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  JclPEImage,
  DebuggerUtils,
  LogManager;

function TDebugModule.CodeBegin: NativeUInt;
begin
  Result := FCodeBegin;
end;

function TDebugModule.CodeEnd: NativeUInt;
begin
  Result := FCodeEnd;
end;

constructor TDebugModule.Create( const aFilepath: string; const aHFile: THandle; const aBase: NativeUInt; const aMapScanner: TJCLMapScanner );
begin
  inherited Create;
  FFilepath := aFilepath;
  FFilename := ExtractFileName( aFilepath );
  FName := ChangeFileExt( FFilename, '' );

  FHFile := aHFile;
  FBase := aBase;
  FMapScanner := aMapScanner;
end;

destructor TDebugModule.Destroy;
begin
  G_LogManager.LogFmt( 'Destroying Module for %s at %s with %d bytes - Code in [%s - %s]',
    [FName, AddressToString( FBase ), FSize, AddressToString( FCodeBegin ), AddressToString( FCodeEnd )] );
  inherited Destroy;
end;

function TDebugModule.Filename: string;
begin
  Result := FFilename;
end;

function TDebugModule.Filepath: string;
begin
  Result := FFilepath;
end;

function TDebugModule.HFile: THandle;
begin
  Result := FHFile;
end;

function TDebugModule.Name: string;
begin
  Result := FName;
end;

procedure TDebugModule.AfterConstruction;
var
  PEImage: TJCLPEImage;
  vSectionHeader: TImageSectionHeader;
  vSectionNumber: Integer;
begin
  inherited AfterConstruction;
  PEImage := TJCLPEImage.Create;
  try
    PEImage.Filename := FFilepath;
    {$IF Defined(WIN32)}
    FSize := PEImage.OptionalHeader32.SizeOfCode;
    {$ELSEIF Defined(WIN64)}
    FSize := PEImage.OptionalHeader64.SizeOfCode;
    {$ELSE}
    {$MESSAGE FATAL 'Unsupported Platform'}
    {$ENDIF}
    // Code section
    // we may have several sections containing code, so we will iterate and take
    // the lowest given address will be our code begin and the highest the end.
    // Typical samples would be .text and .itext sections
    FCodeBegin := NativeUInt.MaxValue;
    FCodeEnd := 0;
    for vSectionNumber := 0 to PEImage.ImageSectionCount - 1 do
    begin
      vSectionHeader := PEImage.ImageSectionHeaders[vSectionNumber];
      if ( ( vSectionHeader.Characteristics and IMAGE_SCN_CNT_CODE ) <> 0 ) then
      begin
        FCodeBegin := Min( FBase + vSectionHeader.VirtualAddress, FCodeBegin );
        FCodeEnd := Max( FBase + vSectionHeader.VirtualAddress + vSectionHeader.Misc.VirtualSize, FCodeEnd );
      end;
    end;

    if ( FCodeEnd = 0 ) then // This should not happen - but we will set the header data for the first section
    begin
      {$IF Defined(WIN32)}
      FCodeBegin := FBase + PEImage.OptionalHeader32.BaseOfCode;
      FCodeEnd := FCodeBegin + FSize; // PEImage.OptionalHeader32.SizeOfCode;
      {$ELSEIF Defined(WIN64)}
      FCodeBegin := FBase + PEImage.OptionalHeader64.BaseOfCode;
      FCodeEnd := FCodeBegin + FSize; //PEImage.OptionalHeader64.SizeOfCode;
      {$ELSE}
      {$MESSAGE FATAL 'Unsupported Platform'}
      {$ENDIF}
    end;
  finally
    PEImage.Free;
  end;
  G_LogManager.LogFmt( 'Adding Module for %s at %s with %d bytes - Code in [%s - %s]', [FName, AddressToString( FBase ), FSize, AddressToString( FCodeBegin ),
    AddressToString( FCodeEnd )] );
end;

function TDebugModule.Base: NativeUInt;
begin
  Result := FBase;
end;

function TDebugModule.Size: Cardinal;
begin
  Result := FSize;
end;

function TDebugModule.MapScanner: TJCLMapScanner;
begin
  Result := FMapScanner;
end;

end.
