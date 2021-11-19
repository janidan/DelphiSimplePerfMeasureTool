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
unit DebuggerUtils;

interface

uses
  System.TimeSpan,
  Winapi.Windows,
  JclPeImage,
  DebuggerApi;

function AddressToString( const address: Pointer ): string; overload;
function AddressToString( const address: NativeUInt ): string; overload;
function AddressToString( const address: UInt32 ): string; overload;
function AddressToString( const address: UInt64 ): string; overload;

function VAFromAddress( const AAddr: Pointer; const AAddressCodebase: NativeUInt ): DWORD; inline;
function AddressFromVA( const AVA: DWORD; const AAddressCodebase: NativeUInt ): Pointer; inline;

function GetDllName( const aProcessHandle: THandle; const lpBaseOfDll: Pointer ): string;

function Min( a, b: NativeUInt ): NativeUInt;
function Max( a, b: NativeUInt ): NativeUInt;

function TimeSpanToString( const aTimeSpan: TTimeSpan ): string;

type
  TBreakPointDetailHelper = record helper for TBreakPointDetail
    procedure ParseFullyQualifiedName;
    function GetFQNfromItems: string;
    function ToDebugString: string;
  end;

procedure OpenInputFileForReading( const aFileName: string; var InputFile: TextFile );
function ExpandEnvString( const aPath: string ): string;
function MakePathAbsolute( const aRelPath, aRootPath: string ): string;
function UnescapeParam( const aParameter: string ): string;
function LastOsErrorInfo: string;
function GetImageBitness( const aFileName: string ): TJclPeTarget;
function IsImageBitnessCompatible( const aFileName: string ): Boolean;
function GetImageCodeSize( const aFileName: string ): Integer;
function GetImportsList( const aFileName: string ): TArray<string>;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.IOUtils,
  System.Classes,
  Winapi.PsAPI,
  CoverageConfiguration,
  LogManager;

function AddressToString( const address: Pointer ): string;
begin
  // Respect the internal/native Bitness of the pointer
  Result := IntToHex( NativeUInt( address ) );
end;

function AddressToString( const address: NativeUInt ): string; overload;
begin
  // Respect the internal/native Bitness of the pointer
  Result := IntToHex( address );
end;

function AddressToString( const address: UInt32 ): string; overload;
begin
  Result := IntToHex( address, 8 );
end;

function AddressToString( const address: UInt64 ): string; overload;
begin
  Result := IntToHex( address, 16 );
end;

function VAFromAddress( const AAddr: Pointer; const AAddressCodebase: NativeUInt ): DWORD; inline;
begin
  Result := NativeUInt( AAddr ) - AAddressCodebase;
end;

function AddressFromVA( const AVA: DWORD; const AAddressCodebase: NativeUInt ): Pointer; inline;
begin
  Result := Pointer( NativeUInt( AVA + AAddressCodebase ) );
end;

function ExpandVolumeName( const aFileName: string ): string;
var
  LogicalDrives: TArray<string>;
  Drive: string;
  DeviceDrive: string;

  TempVolumeName: array [0 .. MAX_PATH + 1] of Char;
  TempVolumeNameLength: DWORD;
  VolumeName: string;
begin
  LogicalDrives := TDirectory.GetLogicalDrives;
  for Drive in LogicalDrives do
  begin
    DeviceDrive := Copy( Drive, 1, 2 ); // remove the tailing Backslash for the QueryDosDevice API call
    TempVolumeNameLength := QueryDosDevice( PChar( DeviceDrive ), TempVolumeName, MAX_PATH );
    if TempVolumeNameLength > 0 then
    begin
      VolumeName := TempVolumeName;
      if Pos( VolumeName, aFileName ) > 0 then
      begin
        TempVolumeNameLength := Length( VolumeName );
        Result := DeviceDrive + Copy( aFileName, TempVolumeNameLength + 1, DWORD( Length( aFileName ) ) - TempVolumeNameLength );
        Break;
      end;
    end;
  end;
end;

function GetDllName( const aProcessHandle: THandle; const lpBaseOfDll: Pointer ): string;
var
  MappedName: array [0 .. MAX_PATH + 1] of Char;
begin
  Result := '';
  if GetMappedFileName( aProcessHandle, lpBaseOfDll, @MappedName[0], MAX_PATH ) > 0 then
    Result := ExpandVolumeName( MappedName );
end;

function Min( a, b: NativeUInt ): NativeUInt;
begin
  Result := a;
  if Result > b then
    Result := b;
end;

function Max( a, b: NativeUInt ): NativeUInt;
begin
  Result := a;
  if Result < b then
    Result := b;
end;

function TimeSpanToString( const aTimeSpan: TTimeSpan ): string;
var
  vDays: Integer;
  vHours: Integer;
  vMinutes: Integer;
  vSeconds: Integer;
  vMilliSec: Integer;
  vLeftTicks: Int64;
  vFmt: string;
begin
  if ( aTimeSpan = TTimeSpan.Zero ) then
    Exit( '' );
  //Result := aTimeSpan.ToString;
  vLeftTicks := aTimeSpan.Ticks;

  vDays := vLeftTicks div TTimeSpan.TicksPerDay;
  vLeftTicks := vLeftTicks mod TTimeSpan.TicksPerDay;
  if ( vLeftTicks < 0 ) then
    vLeftTicks := -vLeftTicks;

  vHours := ( vLeftTicks div TTimeSpan.TicksPerHour ) mod 24;
  vMinutes := ( vLeftTicks div TTimeSpan.TicksPerMinute ) mod 60;
  vSeconds := ( vLeftTicks div TTimeSpan.TicksPerSecond ) mod 60;
  vMilliSec := ( vLeftTicks div TTimeSpan.TicksPerMillisecond ) mod 1000;

  //vFmt := '%0:d.%1:.2d:%2:.2d:%3:.2d.%4:.7d';
  vFmt := '%3:.2d.%4:.7d'; // Sec.MilliSec

  if ( vMinutes <> 0 ) or ( vHours <> 0 ) or ( vDays <> 0 ) then
    vFmt := '%2:.2d:' + vFmt;
  if ( vHours <> 0 ) or ( vDays <> 0 ) then
    vFmt := '%1:.2d:' + vFmt;
  if ( vDays <> 0 ) then
    vFmt := '%0:d.' + vFmt;

  Result := Format( vFmt, [vDays, vHours, vMinutes, vSeconds, vMilliSec] );
end;

{ TBreakPointDetailHelper }

function TBreakPointDetailHelper.GetFQNfromItems: string;
begin
  Result := ModuleName + '.' + ClassName + '.' + MethodName;
end;

procedure TBreakPointDetailHelper.ParseFullyQualifiedName;
var
  //  List: TStrings;
  //  ClassName: string;
  //  ProcedureName: string;
  I: Integer;
  //  ClassProcName: string;
  //  UnitNameNoExt:string;
begin
  // At this point we can assume the following values are given:
  // * FullyQualifiedMethodName
  // * ModuleName
  // * UnitName
  // * UnitFileName
  // * Line
  // We just want to get the Class and Method name from the FullyQualifiedName

  // The typical form of this is ModuleName( typically unit without extention).ClassName.Methodname
  // Note that the unitname and the modulename may differ.
  // Also not that generics may have dotted namespaces. example:
  // ClassInfoUnit.{System.Generics.Collections}TList<ClassInfoUnit.TUnitInfo>.Add
  // Exception to this is the intialization section of a unit e.g.
  // BplUnit.BplUnit -> initialization section
  // BplUnit.Second.BplUnit.Second
  if ( FullyQualifiedMethodName = UnitName + '.' + UnitName ) then
  begin
    ClassName := 'Unit';
    MethodName := 'Initialization';
  end
  else
  begin
    I := LastDelimiter( '.', FullyQualifiedMethodName );
    MethodName := Copy( FullyQualifiedMethodName, I + 1, Length( FullyQualifiedMethodName ) - I );
    ClassName := Copy( FullyQualifiedMethodName, Length( UnitName ) + 2 {dot and firstletter}, I - Length( UnitName ) - 2 {dot and firstletter} );
  end;

  // Exceptions that we also cover:
  // BplUnit.DoSomethingInBpl -> Method declared in a unit
  // BplUnit.Finalization -> Finalization section
  // After the above parsing the classname is empty. We will bind it to the "unit" class
  if ( ClassName = '' ) then
    ClassName := 'Unit';

  // Generic classes -> Handled correctly above
  // mainForm..{BplUnit}TSimpleGeneric<System.Byte>
  // mainForm.{BplUnit}TSimpleGeneric<System.Byte>.ClassProc
  // mainForm.{BplUnit}TSimpleGeneric<System.Byte>.SimpleProc

  // Line numbers of Generic types refer to the defining pas file.
  // Where as the address referrs to this module.
  // e.g. mainForm.{BplUnit}TSimpleGeneric<System.Byte>.ClassProc
  // Line numbers for mainForm(BplUnit.pas) segment .text
  // 92 0001:00001C78    94 0001:00001C7F
  // UnitName := ModuleName;

  // Class constructors + Destructor suffix is @ -> they are correctly handled above
  // BplUnit.TSimpleClass.Create@
  // BplUnit.TSimpleClass.Destroy@

  // Intialization reads nicer and more intuative
  //if (MethodName = UnitNameNoExt) then
  //  MethodName := 'initialization';
end;

function TBreakPointDetailHelper.ToDebugString: string;
begin
  Result := 'FQN:' + FullyQualifiedMethodName + ' ' + //
    'module:' + ModuleName + ' ' + //
    'unit:' + UnitName + ' ' + //
    'file:' + UnitFileName + ' ' + //
    'class:' + ClassName + ' ' + //
    'method:' + MethodName + ' ' + //
    'line:' + Line.ToString + ' ' + //
    'gen: ' + GetFQNfromItems;
end;

procedure OpenInputFileForReading( const aFileName: string; var InputFile: TextFile );
begin
  AssignFile( InputFile, aFileName );
  try
    System.FileMode := fmOpenRead;
    Reset( InputFile );
  except
    on E: EInOutError do
    begin
      ConsoleOutput( 'Could not open:' + aFileName );
      raise;
    end;
  end;
end;

function ExpandEnvString( const aPath: string ): string;
var
  Size: Cardinal;
begin
  Result := aPath;
  Size := ExpandEnvironmentStrings( PChar( aPath ), nil, 0 );
  if Size > 0 then
  begin
    SetLength( Result, Size );
    ExpandEnvironmentStrings( PChar( aPath ), PChar( Result ), Size );
    SetLength( Result, Length( Result ) - 1 );
  end;
end;

function MakePathAbsolute( const aRelPath, aRootPath: string ): string;
begin
  Result := ExpandEnvString( aRelPath );
  if TPath.IsRelativePath( Result ) then
    Result := TPath.GetFullPath( TPath.Combine( aRootPath, Result ) );
end;

function UnescapeParam( const aParameter: string ): string;
var
  lp: Integer;
begin
  Result := '';
  if Length( aParameter ) > 0 then
  begin
    lp := Low( aParameter );
    while lp <= High( aParameter ) do
    begin
      if aParameter[lp] = '^' then
        Inc( lp );
      Result := Result + aParameter[lp];
      Inc( lp );
    end;
  end;
end;

function LastOsErrorInfo: string;
var
  LastError: DWORD;
begin
  LastError := GetLastError;
  Result := IntToStr( LastError ) + '(' + IntToHex( LastError, 8 ) + ') -> ' + System.SysUtils.SysErrorMessage( LastError );
end;

function GetImageBitness( const aFileName: string ): TJclPeTarget;
begin
  var
  PEImage := TJCLPEImage.Create;
  try
    PEImage.Filename := aFileName;
    Result := PEImage.Target;
  finally
    PEImage.Free;
  end;
end;

function IsImageBitnessCompatible( const aFileName: string ): Boolean;
begin
  {$IF Defined(WIN32)}
  Result := GetImageBitness( aFileName ) = TJclPeTarget.taWin32;
  {$ELSEIF Defined(WIN64)}
  Result := GetImageBitness( aFileName ) = TJclPeTarget.taWin64;
  {$ELSE}
  {$MESSAGE FATAL 'Unsupported Platform'}
  {$ENDIF}
end;

function GetImageCodeSize( const aFileName: string ): Integer;
begin
  var
  PEImage := TJCLPEImage.Create;
  try
    PEImage.Filename := aFileName;
    {$IF Defined(WIN32)}
    Result := PEImage.OptionalHeader32.SizeOfCode;
    {$ELSEIF Defined(WIN64)}
    Result := PEImage.OptionalHeader64.SizeOfCode;
    {$ELSE}
    {$MESSAGE FATAL 'Unsupported Platform'}
    {$ENDIF}
  finally
    PEImage.Free;
  end;
end;

function GetImportsList( const aFileName: string ): TArray<string>;
var
  vImage: TJCLPEImage;
  vImportList: TJclPeImportList;
  vResults: TStringList;
begin
  vImage := TJCLPEImage.Create( True );
  try
    vImage.Filename := aFileName;
    if ( vImage.Status <> TJclPeImageStatus.stOk ) then
      Exit( nil );

    vResults := TStringList.Create;
    try
      vImportList := vImage.ImportList;
      for var I := 0 to vImportList.Count - 1 do
        vResults.Add( vImportList.Items[I].Filename );
      Result := vResults.ToStringArray;
    finally
      vResults.Free;
    end;
  finally
    vImage.Free;
  end;
end;

end.
