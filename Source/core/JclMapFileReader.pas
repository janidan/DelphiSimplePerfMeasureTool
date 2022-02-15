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

(* Contents of this file is taken from the JclDebug.pas and adapted    *)

{**************************************************************************************************}
{                                                                                                  }
{ Project JEDI Code Library (JCL)                                                                  }
{                                                                                                  }
{ The contents of this file are subject to the Mozilla Public License Version 1.1 (the "License"); }
{ you may not use this file except in compliance with the License. You may obtain a copy of the    }
{ License at http://www.mozilla.org/MPL/                                                           }
{                                                                                                  }
{ Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF   }
{ ANY KIND, either express or implied. See the License for the specific language governing rights  }
{ and limitations under the License.                                                               }
{                                                                                                  }
{ The Original Code is JclDebug.pas.                                                               }
{                                                                                                  }
{ The Initial Developers of the Original Code are Petr Vones and Marcel van Brakel.                }
{ Portions created by these individuals are Copyright (C) of these individuals.                    }
{ All Rights Reserved.                                                                             }
{                                                                                                  }
{ Contributor(s):                                                                                  }
{   Marcel van Brakel                                                                              }
{   Flier Lu (flier)                                                                               }
{   Florent Ouchet (outchy)                                                                        }
{   Robert Marquardt (marquardt)                                                                   }
{   Robert Rossmair (rrossmair)                                                                    }
{   Andreas Hausladen (ahuser)                                                                     }
{   Petr Vones (pvones)                                                                            }
{   Soeren Muehlbauer                                                                              }
{   Uwe Schuster (uschuster)                                                                       }
{                                                                                                  }
{**************************************************************************************************}
unit JclMapFileReader;

interface

uses
  System.SysUtils,
  WinApi.Windows,
  JclAnsiStrings,
  JclSysUtils,
  JclBase,
  JclPeImage,
  JclDebug;

type
  TJclMapScannerEx = class( TJclAbstractMapParser )
  private
    FSegmentClasses: array of TJclMapSegmentClass;
    FLineNumbers: array of TJclMapLineNumber;
    FProcNames: array of TJclMapProcName;
    FSegments: array of TJclMapSegment;
    FSourceNames: array of TJclMapProcName;
    FLineNumbersCnt: Integer;
    FLineNumberErrors: Integer;
    FNewUnitFileName: PJclMapString;
    FCurrentUnitName: PJclMapString;
    FProcNamesCnt: Integer;
    FSegmentCnt: Integer;
    FLastAccessedSegementIndex: Integer;
    function IndexOfSegment( Addr: DWORD ): Integer;
  protected
    function MAPAddrToVA( const Addr: DWORD ): DWORD;
    procedure ClassTableItem( const Address: TJclMapAddress; Len: Integer; SectionName, GroupName: PJclMapString ); override;
    procedure SegmentItem( const Address: TJclMapAddress; Len: Integer; GroupName, UnitName: PJclMapString ); override;
    function CanHandlePublicsByName: Boolean; override;
    function CanHandlePublicsByValue: Boolean; override;
    procedure PublicsByNameItem( const Address: TJclMapAddress; Name: PJclMapString ); override;
    procedure PublicsByValueItem( const Address: TJclMapAddress; Name: PJclMapString ); override;
    procedure LineNumbersItem( LineNumber: Integer; const Address: TJclMapAddress ); override;
    procedure LineNumberUnitItem( UnitName, UnitFileName: PJclMapString ); override;
    procedure Scan;
    function GetLineNumberByIndex( Index: Integer ): TJclMapLineNumber;
  public
    constructor Create( const MapFileName: TFileName; Module: HMODULE ); override;

    class function MapStringCacheToFileName( var MapString: TJclMapStringCache ): string;
    class function MapStringCacheToModuleName( var MapString: TJclMapStringCache ): string;
    class function MapStringCacheToStr( var MapString: TJclMapStringCache; IgnoreSpaces: Boolean = False ): string;

    // Addr are virtual addresses relative to (module base address + $10000)
    function LineNumberFromAddr( Addr: DWORD ): Integer; overload;
    function LineNumberFromAddr( Addr: DWORD; out Offset: Integer ): Integer; overload;
    function ModuleNameFromAddr( Addr: DWORD ): string;
    function ModuleStartFromAddr( Addr: DWORD ): DWORD;
    function ProcNameFromAddr( Addr: DWORD ): string; overload;
    function ProcNameFromAddr( Addr: DWORD; out Offset: Integer ): string; overload;
    function SourceNameFromAddr( Addr: DWORD ): string;

    function ProcDataFromAddr( Addr: DWORD ): TJclMapProcName; overload;

    property LineNumberErrors: Integer read FLineNumberErrors;
    property LineNumbersCnt: Integer read FLineNumbersCnt;
    property LineNumberByIndex[Index: Integer]: TJclMapLineNumber read GetLineNumberByIndex;
  end;

implementation

//=== { TJclMapScannerEx } =====================================================

constructor TJclMapScannerEx.Create( const MapFileName: TFileName; Module: HMODULE );
begin
  inherited Create( MapFileName, Module );
  Scan;
end;

function TJclMapScannerEx.MAPAddrToVA( const Addr: DWORD ): DWORD;
begin
  // MAP file format was changed in Delphi 2005
  // before Delphi 2005: segments started at offset 0
  //                     only one segment of code
  // after Delphi 2005: segments started at code base address (module base address + $10000)
  //                    2 segments of code
  if ( Length( FSegmentClasses ) > 0 ) and ( FSegmentClasses[0].Start > 0 ) and ( Addr >= FSegmentClasses[0].Start ) then
    // Delphi 2005 and later
    // The first segment should be code starting at module base address + $10000
    Result := Addr - FSegmentClasses[0].Start
  else
    // before Delphi 2005
    Result := Addr;
end;

class function TJclMapScannerEx.MapStringCacheToFileName( var MapString: TJclMapStringCache ): string;
begin
  Result := MapString.CachedValue;
  if Result = '' then
  begin
    Result := MapStringToFileName( MapString.RawValue );
    MapString.CachedValue := Result;
  end;
end;

class function TJclMapScannerEx.MapStringCacheToModuleName( var MapString: TJclMapStringCache ): string;
begin
  Result := MapString.CachedValue;
  if Result = '' then
  begin
    Result := MapStringToModuleName( MapString.RawValue );
    MapString.CachedValue := Result;
  end;
end;

class function TJclMapScannerEx.MapStringCacheToStr( var MapString: TJclMapStringCache; IgnoreSpaces: Boolean ): string;
begin
  Result := MapString.CachedValue;
  if Result = '' then
  begin
    Result := MapStringToStr( MapString.RawValue, IgnoreSpaces );
    MapString.CachedValue := Result;
  end;
end;

procedure TJclMapScannerEx.ClassTableItem( const Address: TJclMapAddress; Len: Integer; SectionName, GroupName: PJclMapString );
var
  C: Integer;
  SectionHeader: PImageSectionHeader;
begin
  C := Length( FSegmentClasses );
  SetLength( FSegmentClasses, C + 1 );
  FSegmentClasses[C].Segment := Address.Segment;
  FSegmentClasses[C].Start := Address.Offset;
  FSegmentClasses[C].Addr := Address.Offset; // will be fixed below while considering module mapped address
  // test GroupName because SectionName = '.tls' in Delphi and '_tls' in BCB
  if StrLICompA( GroupName, 'TLS', 3 ) = 0 then
  begin
    FSegmentClasses[C].VA := FSegmentClasses[C].Start;
    FSegmentClasses[C].GroupName.TLS := True;
  end
  else
  begin
    FSegmentClasses[C].VA := MAPAddrToVA( FSegmentClasses[C].Start );
    FSegmentClasses[C].GroupName.TLS := False;
  end;
  FSegmentClasses[C].Len := Len;
  FSegmentClasses[C].SectionName.RawValue := SectionName;
  FSegmentClasses[C].GroupName.RawValue := GroupName;

  if FModule <> 0 then
  begin
    { Fix the section addresses }
    SectionHeader := PeMapImgFindSectionFromModule( Pointer( FModule ), MapStringToStr( SectionName ) );
    if SectionHeader = nil then
      { before Delphi 2005 the class names where used for the section names }
      SectionHeader := PeMapImgFindSectionFromModule( Pointer( FModule ), MapStringToStr( GroupName ) );

    if SectionHeader <> nil then
    begin
      FSegmentClasses[C].Addr := TJclAddr( FModule ) + SectionHeader.VirtualAddress;
      FSegmentClasses[C].VA := SectionHeader.VirtualAddress;
    end;
  end;
end;

function TJclMapScannerEx.LineNumberFromAddr( Addr: DWORD ): Integer;
var
  Dummy: Integer;
begin
  Result := LineNumberFromAddr( Addr, Dummy );
end;

function Search_MapLineNumber( Item1, Item2: Pointer ): Integer;
begin
  Result := Integer( PJclMapLineNumber( Item1 )^.VA ) - PInteger( Item2 )^;
end;

function TJclMapScannerEx.LineNumberFromAddr( Addr: DWORD; out Offset: Integer ): Integer;
var
  I: Integer;
  ModuleStartAddr: DWORD;
begin
  ModuleStartAddr := ModuleStartFromAddr( Addr );
  Result := 0;
  Offset := 0;
  I := SearchDynArray( FLineNumbers, SizeOf( FLineNumbers[0] ), Search_MapLineNumber, @Addr, True );
  if ( I <> -1 ) and ( FLineNumbers[I].VA >= ModuleStartAddr ) then
  begin
    Result := FLineNumbers[I].LineNumber;
    Offset := Addr - FLineNumbers[I].VA;
  end;
end;

procedure TJclMapScannerEx.LineNumbersItem( LineNumber: Integer; const Address: TJclMapAddress );
var
  SegIndex, C: Integer;
  VA: DWORD;
  Added: Boolean;
begin
  Added := False;
  for SegIndex := Low( FSegmentClasses ) to High( FSegmentClasses ) do
    if ( FSegmentClasses[SegIndex].Segment = Address.Segment ) and ( DWORD( Address.Offset ) < FSegmentClasses[SegIndex].Len ) then
    begin
      if FSegmentClasses[SegIndex].GroupName.TLS then
        VA := Address.Offset
      else
        VA := MAPAddrToVA( Address.Offset + FSegmentClasses[SegIndex].Start );
      { Starting with Delphi 2005, "empty" units are listes with the last line and
        the VA 0001:00000000. When we would accept 0 VAs here, System.pas functions
       could be mapped to other units and line numbers. Discaring such items should
       have no impact on the correct information, because there can't be a function
       that starts at VA 0. }
      if VA = 0 then
        Continue;
      if FLineNumbersCnt = Length( FLineNumbers ) then
      begin
        if FLineNumbersCnt < 512 then
          SetLength( FLineNumbers, FLineNumbersCnt + 512 )
        else
          SetLength( FLineNumbers, FLineNumbersCnt * 2 );
      end;
      FLineNumbers[FLineNumbersCnt].Segment := FSegmentClasses[SegIndex].Segment;
      FLineNumbers[FLineNumbersCnt].VA := VA;
      FLineNumbers[FLineNumbersCnt].LineNumber := LineNumber;
      FLineNumbers[FLineNumbersCnt].UnitName := FCurrentUnitName;
      Inc( FLineNumbersCnt );
      Added := True;
      if FNewUnitFileName <> nil then
      begin
        C := Length( FSourceNames );
        SetLength( FSourceNames, C + 1 );
        FSourceNames[C].Segment := FSegmentClasses[SegIndex].Segment;
        FSourceNames[C].VA := VA;
        FSourceNames[C].ProcName.RawValue := FNewUnitFileName;
        FNewUnitFileName := nil;
      end;
      Break;
    end;
  if not Added then
    Inc( FLineNumberErrors );
end;

procedure TJclMapScannerEx.LineNumberUnitItem( UnitName, UnitFileName: PJclMapString );
begin
  FNewUnitFileName := UnitFileName;
  FCurrentUnitName := UnitName;
end;

function TJclMapScannerEx.GetLineNumberByIndex( Index: Integer ): TJclMapLineNumber;
begin
  Result := FLineNumbers[Index];
end;

function TJclMapScannerEx.IndexOfSegment( Addr: DWORD ): Integer;
var
  L, R: Integer;
  S: PJclMapSegment;
begin
  R := Length( FSegments ) - 1;
  Result := FLastAccessedSegementIndex;
  if Result <= R then
  begin
    S := @FSegments[Result];
    if ( S.StartVA <= Addr ) and ( Addr < S.EndVA ) then
      Exit;
  end;

  // binary search
  L := 0;
  while L <= R do
  begin
    Result := L + ( R - L ) div 2;
    S := @FSegments[Result];
    if Addr >= S.EndVA then
      L := Result + 1
    else
    begin
      R := Result - 1;
      if ( S.StartVA <= Addr ) and ( Addr < S.EndVA ) then
      begin
        FLastAccessedSegementIndex := Result;
        Exit;
      end;
    end;
  end;
  Result := -1;
end;

function TJclMapScannerEx.ModuleNameFromAddr( Addr: DWORD ): string;
var
  I: Integer;
begin
  I := IndexOfSegment( Addr );
  if I <> -1 then
    Result := MapStringCacheToModuleName( FSegments[I].UnitName )
  else
    Result := '';
end;

function TJclMapScannerEx.ModuleStartFromAddr( Addr: DWORD ): DWORD;
var
  I: Integer;
begin
  I := IndexOfSegment( Addr );
  Result := DWORD( -1 );
  if I <> -1 then
    Result := FSegments[I].StartVA;
end;

function TJclMapScannerEx.ProcNameFromAddr( Addr: DWORD ): string;
var
  Dummy: Integer;
begin
  Result := ProcNameFromAddr( Addr, Dummy );
end;

function Search_MapProcName( Item1, Item2: Pointer ): Integer;
begin
  Result := Integer( PJclMapProcName( Item1 )^.VA ) - PInteger( Item2 )^;
end;

function TJclMapScannerEx.ProcDataFromAddr( Addr: DWORD ): TJclMapProcName;
var
  I: Integer;
  ModuleStartAddr: DWORD;
begin
  ModuleStartAddr := ModuleStartFromAddr( Addr );
  FillChar( Result, SizeOf( TJclMapProcName ), 0 );
  I := SearchDynArray( FProcNames, SizeOf( FProcNames[0] ), Search_MapProcName, @Addr, True );
  if ( I <> -1 ) and ( FProcNames[I].VA >= ModuleStartAddr ) then
  begin
    MapStringCacheToStr( FProcNames[I].ProcName, True );
    Result := FProcNames[I];
  end;
end;

function TJclMapScannerEx.ProcNameFromAddr( Addr: DWORD; out Offset: Integer ): string;
var
  I: Integer;
  ModuleStartAddr: DWORD;
begin
  ModuleStartAddr := ModuleStartFromAddr( Addr );
  Result := '';
  Offset := 0;
  I := SearchDynArray( FProcNames, SizeOf( FProcNames[0] ), Search_MapProcName, @Addr, True );
  if ( I <> -1 ) and ( FProcNames[I].VA >= ModuleStartAddr ) then
  begin
    Result := MapStringCacheToStr( FProcNames[I].ProcName, True );
    Offset := Addr - FProcNames[I].VA;
  end;
end;

function TJclMapScannerEx.CanHandlePublicsByName: Boolean;
begin
  Result := False;
end;

function TJclMapScannerEx.CanHandlePublicsByValue: Boolean;
begin
  Result := True;
end;

procedure TJclMapScannerEx.PublicsByNameItem( const Address: TJclMapAddress; Name: PJclMapString );
begin
end;

procedure TJclMapScannerEx.PublicsByValueItem( const Address: TJclMapAddress; Name: PJclMapString );
var
  SegIndex: Integer;
begin
  for SegIndex := Low( FSegmentClasses ) to High( FSegmentClasses ) do
    if ( FSegmentClasses[SegIndex].Segment = Address.Segment ) and ( DWORD( Address.Offset ) < FSegmentClasses[SegIndex].Len ) then
    begin
      if FProcNamesCnt = Length( FProcNames ) then
      begin
        if FProcNamesCnt < 512 then
          SetLength( FProcNames, FProcNamesCnt + 512 )
        else
          SetLength( FProcNames, FProcNamesCnt * 2 );
      end;
      FProcNames[FProcNamesCnt].Segment := FSegmentClasses[SegIndex].Segment;
      if FSegmentClasses[SegIndex].GroupName.TLS then
        FProcNames[FProcNamesCnt].VA := Address.Offset
      else
        FProcNames[FProcNamesCnt].VA := MAPAddrToVA( Address.Offset + FSegmentClasses[SegIndex].Start );
      FProcNames[FProcNamesCnt].ProcName.RawValue := Name;
      Inc( FProcNamesCnt );
      Break;
    end;
end;

{function Sort_MapLineNumber(Item1, Item2: Pointer): Integer;
 begin
 Result := Integer(PJclMapLineNumber(Item1)^.VA) - Integer(PJclMapLineNumber(Item2)^.VA);
 end;}

function Sort_MapProcName( Item1, Item2: Pointer ): Integer;
begin
  Result := Integer( PJclMapProcName( Item1 )^.VA ) - Integer( PJclMapProcName( Item2 )^.VA );
end;

function Sort_MapSegment( Item1, Item2: Pointer ): Integer;
begin
  Result := Integer( PJclMapSegment( Item1 )^.EndVA ) - Integer( PJclMapSegment( Item2 )^.EndVA );
  if Result = 0 then
    Result := Integer( PJclMapSegment( Item1 )^.StartVA ) - Integer( PJclMapSegment( Item2 )^.StartVA );
end;

type
  PJclMapLineNumberArray = ^TJclMapLineNumberArray;
  TJclMapLineNumberArray = array [0 .. MaxInt div SizeOf( TJclMapLineNumber ) - 1] of TJclMapLineNumber;

  PJclMapProcNameArray = ^TJclMapProcNameArray;
  TJclMapProcNameArray = array [0 .. MaxInt div SizeOf( TJclMapProcName ) - 1] of TJclMapProcName;

  // specialized quicksort functions
procedure SortLineNumbers( ArrayVar: PJclMapLineNumberArray; L, R: Integer );
var
  I, J, P: Integer;
  Temp: TJclMapLineNumber;
  AV: PJclMapLineNumber;
  V: Integer;
begin
  repeat
    I := L;
    J := R;
    P := ( L + R ) shr 1;
    repeat
      V := Integer( ArrayVar[P].VA );
      AV := @ArrayVar[I];
      while Integer( AV.VA ) - V < 0 do
      begin
        Inc( I );
        Inc( AV );
      end;
      AV := @ArrayVar[J];
      while Integer( AV.VA ) - V > 0 do
      begin
        Dec( J );
        Dec( AV );
      end;
      if I <= J then
      begin
        if I <> J then
        begin
          Temp := ArrayVar[I];
          ArrayVar[I] := ArrayVar[J];
          ArrayVar[J] := Temp;
        end;
        if P = I then
          P := J
        else if P = J then
          P := I;
        Inc( I );
        Dec( J );
      end;
    until I > J;
    if L < J then
      SortLineNumbers( ArrayVar, L, J );
    L := I;
  until I >= R;
end;

procedure SortProcNames( ArrayVar: PJclMapProcNameArray; L, R: Integer );
var
  I, J, P: Integer;
  Temp: TJclMapProcName;
  V: Integer;
  AV: PJclMapProcName;
begin
  repeat
    I := L;
    J := R;
    P := ( L + R ) shr 1;
    repeat
      V := Integer( ArrayVar[P].VA );
      AV := @ArrayVar[I];
      while Integer( AV.VA ) - V < 0 do
      begin
        Inc( I );
        Inc( AV );
      end;
      AV := @ArrayVar[J];
      while Integer( AV.VA ) - V > 0 do
      begin
        Dec( J );
        Dec( AV );
      end;
      if I <= J then
      begin
        if I <> J then
        begin
          Temp := ArrayVar[I];
          ArrayVar[I] := ArrayVar[J];
          ArrayVar[J] := Temp;
        end;
        if P = I then
          P := J
        else if P = J then
          P := I;
        Inc( I );
        Dec( J );
      end;
    until I > J;
    if L < J then
      SortProcNames( ArrayVar, L, J );
    L := I;
  until I >= R;
end;

procedure TJclMapScannerEx.Scan;
begin
  FLineNumberErrors := 0;
  FSegmentCnt := 0;
  FProcNamesCnt := 0;
  FLastAccessedSegementIndex := 0;
  Parse;
  SetLength( FLineNumbers, FLineNumbersCnt );
  SetLength( FProcNames, FProcNamesCnt );
  SetLength( FSegments, FSegmentCnt );
  //SortDynArray(FLineNumbers, SizeOf(FLineNumbers[0]), Sort_MapLineNumber);
  if FLineNumbers <> nil then
    SortLineNumbers( PJclMapLineNumberArray( FLineNumbers ), 0, Length( FLineNumbers ) - 1 );
  //SortDynArray(FProcNames, SizeOf(FProcNames[0]), Sort_MapProcName);
  if FProcNames <> nil then
    SortProcNames( PJclMapProcNameArray( FProcNames ), 0, Length( FProcNames ) - 1 );
  SortDynArray( FSegments, SizeOf( FSegments[0] ), Sort_MapSegment );
  SortDynArray( FSourceNames, SizeOf( FSourceNames[0] ), Sort_MapProcName );
end;

procedure TJclMapScannerEx.SegmentItem( const Address: TJclMapAddress; Len: Integer; GroupName, UnitName: PJclMapString );
var
  SegIndex: Integer;
  VA: DWORD;
begin
  for SegIndex := Low( FSegmentClasses ) to High( FSegmentClasses ) do
    if ( FSegmentClasses[SegIndex].Segment = Address.Segment ) and ( DWORD( Address.Offset ) < FSegmentClasses[SegIndex].Len ) then
    begin
      if FSegmentClasses[SegIndex].GroupName.TLS then
        VA := Address.Offset
      else
        VA := MAPAddrToVA( Address.Offset + FSegmentClasses[SegIndex].Start );
      if FSegmentCnt mod 16 = 0 then
        SetLength( FSegments, FSegmentCnt + 16 );
      FSegments[FSegmentCnt].Segment := FSegmentClasses[SegIndex].Segment;
      FSegments[FSegmentCnt].StartVA := VA;
      FSegments[FSegmentCnt].EndVA := VA + DWORD( Len );
      FSegments[FSegmentCnt].UnitName.RawValue := UnitName;
      Inc( FSegmentCnt );
      Break;
    end;
end;

function TJclMapScannerEx.SourceNameFromAddr( Addr: DWORD ): string;
var
  I: Integer;
  ModuleStartVA: DWORD;
begin
  // try with line numbers first (Delphi compliance)
  ModuleStartVA := ModuleStartFromAddr( Addr );
  Result := '';
  I := SearchDynArray( FSourceNames, SizeOf( FSourceNames[0] ), Search_MapProcName, @Addr, True );
  if ( I <> -1 ) and ( FSourceNames[I].VA >= ModuleStartVA ) then
    Result := MapStringCacheToStr( FSourceNames[I].ProcName );
  if Result = '' then
  begin
    // try with module names (C++Builder compliance)
    I := IndexOfSegment( Addr );
    if I <> -1 then
      Result := MapStringCacheToFileName( FSegments[I].UnitName );
  end;
end;

end.
