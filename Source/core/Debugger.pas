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
unit Debugger;

interface

uses
  Classes,
  JclDebug,
  JwaWinBase,
  JwaWinType,
  JwaImageHlp,
  DebuggerApi,
  CoverageConfiguration,
  CoverageStatsApi,
  LoggingApi,
  ConfigUnitList,
  ClassInfoUnit,
  JwaPsApi,
  JclMapFileReader;

type
  {$SCOPEDENUMS ON}
  TDebuggerResult = ( Unknown, Success, Error );

  TDebugger = class( TObject )
  strict private
    FMapScanner: TJclMapScannerEx;
    FDebugProcess: IDebugProcess;
    FProcessID: DWORD;
    FBreakPointList: IBreakPointList;
    FCoverageConfiguration: ICoverageConfiguration;
    FLogManager: ILogManager;
    FModuleList: TModuleList;
    FTestExeExitCode: Cardinal;
    FLastBreakPoint: IBreakPoint;
  strict private
    procedure AddBreakPoints( //
      const aUnitsList: TConfigUnitList; //
      const AModule: IDebugModule; //
      const AMapScanner: TJclMapScannerEx );

    function Debug: TDebuggerResult;
    function StartProcessToDebug: Boolean;

    procedure ProcessDebugEvents;

    procedure HandleExceptionDebug( const ADebugEvent: DEBUG_EVENT; var AContProcessEvents: Boolean; var ADebugEventHandlingResult: DWORD );
    procedure HandleCreateProcess( const ADebugEvent: DEBUG_EVENT );
    procedure HandleCreateThread( const ADebugEvent: DEBUG_EVENT );
    procedure HandleExitProcess( const ADebugEvent: DEBUG_EVENT; var AContProcessEvents: Boolean );
    procedure HandleExitThread( const ADebugEvent: DEBUG_EVENT );
    procedure HandleLoadDLL( const ADebugEvent: DEBUG_EVENT );
    procedure HandleOutputDebugString( const ADebugEvent: DEBUG_EVENT );
    procedure HandleUnLoadDLL( const ADebugEvent: DEBUG_EVENT );
    procedure HandleRip( const ADebugEvent: DEBUG_EVENT );

    procedure LogStackFrame( const ADebugEvent: DEBUG_EVENT );
  public
    constructor Create( const aCoverageConfiguration: ICoverageConfiguration );
    destructor Destroy; override;

    function Start: TDebuggerResult;

    property BreakPoints: IBreakPointList read FBreakPointList;
    property ModuleList: TModuleList read FModuleList;
  end;

function RealReadFromProcessMemory( const AhProcess: THANDLE; const AqwBaseAddress: DWORD64; const AlpBuffer: Pointer; const ASize: DWORD;
  var ANumberOfBytesRead: DWORD ): BOOL; stdcall;

implementation

uses
  ActiveX,
  SysUtils,
  JwaNtStatus,
  JwaWinNT,
  BreakPoint,
  BreakPointList,
  DebugProcess,
  DebugThread,
  LogManager,
  DebugModule,
  JclPEImage,
  JclFileUtils,
  DebuggerUtils;

function RealReadFromProcessMemory( const AhProcess: THANDLE; const AqwBaseAddress: DWORD64; const AlpBuffer: Pointer; const ASize: DWORD;
  var ANumberOfBytesRead: DWORD ): BOOL; stdcall;
var
  st: DWORD;
begin
  Result := JwaWinBase.ReadProcessMemory( AhProcess, Pointer( AqwBaseAddress ), AlpBuffer, ASize, @st );
  ANumberOfBytesRead := st;
end;

constructor TDebugger.Create( const aCoverageConfiguration: ICoverageConfiguration );
begin
  inherited Create;
  CoInitialize( nil );

  FBreakPointList := TBreakPointList.Create;
  FCoverageConfiguration := aCoverageConfiguration;

  FLogManager := aCoverageConfiguration.LogManager;
  FModuleList := TModuleList.Create;
end;

destructor TDebugger.Destroy;
begin
  FDebugProcess := nil;
  FBreakPointList := nil;
  FLogManager := nil;
  FModuleList.Free;
  CoUninitialize;

  inherited Destroy;
end;

function TDebugger.Start: TDebuggerResult;
begin
  Result := Debug;
end;

function TDebugger.StartProcessToDebug: Boolean;
var
  StartInfo: TStartupInfo;
  ProcInfo: TProcessInformation;
  Parameters: string;
begin
  Parameters := FCoverageConfiguration.ApplicationParameters;
  FLogManager.Log( 'Trying to start ' + FCoverageConfiguration.ExeFileName + ' with the Parameters :' + Parameters );

  FillChar( StartInfo, SizeOf( TStartupInfo ), #0 );
  FillChar( ProcInfo, SizeOf( TProcessInformation ), #0 );
  StartInfo.cb := SizeOf( TStartupInfo );

  StartInfo.dwFlags := STARTF_USESTDHANDLES;
  StartInfo.hStdInput := GetStdHandle( STD_INPUT_HANDLE );
  StartInfo.hStdOutput := GetStdHandle( STD_OUTPUT_HANDLE );
  StartInfo.hStdError := GetStdHandle( STD_ERROR_HANDLE );

  Parameters := '"' + FCoverageConfiguration.ExeFileName + '" ' + Parameters;
  Result := CreateProcess( nil, PChar( Parameters ), nil, nil, True, CREATE_NEW_PROCESS_GROUP + NORMAL_PRIORITY_CLASS + DEBUG_PROCESS, nil, nil, StartInfo,
    ProcInfo );

  FProcessID := ProcInfo.dwProcessId;
end;

function TDebugger.Debug: TDebuggerResult;
var
  vMapFilename: string;
begin
  if not IsImageBitnessCompatible( FCoverageConfiguration.ExeFileName ) then
  begin
    {$IF Defined(WIN32)}
    ConsoleOutput( 'Bitness of application (win64) does not correspond to tool bitness (win32).' );
    {$ELSEIF Defined(WIN64)}
    ConsoleOutput( 'Bitness of application (win32) does not correspond to tool bitness (win64).' );
    {$ENDIF}
    Exit( TDebuggerResult.Error );
  end;

  vMapFilename := FCoverageConfiguration.GetMapFileName( FCoverageConfiguration.ExeFileName );
  if not FileExists( vMapFilename ) then
  begin
    ConsoleOutput( 'No map file found in Symbolpath. ' + vMapFilename );
    Exit( TDebuggerResult.Error );
  end;

  FMapScanner := TJclMapScannerEx.Create( vMapFilename );
  try
    if FMapScanner.LineNumbersCnt = 0 then
    begin
      ConsoleOutput( 'No line information in map file. Enable Debug Information in project options' );
      Exit( TDebuggerResult.Error );
    end;

    if StartProcessToDebug then
    begin
      FLogManager.Log( 'Started successfully' );
      ProcessDebugEvents;
      FLogManager.Log( 'Finished processing debug events' );
      Exit( TDebuggerResult.Success );
    end
    else
    begin
      ConsoleOutput( 'Unable to start executable "' + FCoverageConfiguration.ExeFileName + '"' );
      ConsoleOutput( 'Error :' + LastOsErrorInfo );
      Exit( TDebuggerResult.Error );
    end;

  finally
    FMapScanner.Free;
  end;
end;

function GetEventCodeName( const DebugEventCode: DWORD ): string;
begin
  case DebugEventCode of
    CREATE_PROCESS_DEBUG_EVENT:
      Result := 'CREATE_PROCESS_DEBUG_EVENT';
    CREATE_THREAD_DEBUG_EVENT:
      Result := 'CREATE_THREAD_DEBUG_EVENT';
    EXCEPTION_DEBUG_EVENT:
      Result := 'EXCEPTION_DEBUG_EVENT';
    EXIT_PROCESS_DEBUG_EVENT:
      Result := 'EXIT_PROCESS_DEBUG_EVENT';
    EXIT_THREAD_DEBUG_EVENT:
      Result := 'EXIT_THREAD_DEBUG_EVENT';
    LOAD_DLL_DEBUG_EVENT:
      Result := 'LOAD_DLL_DEBUG_EVENT';
    UNLOAD_DLL_DEBUG_EVENT:
      Result := 'UNLOAD_DLL_DEBUG_EVENT';
    RIP_EVENT:
      Result := 'RIP_EVENT';
    OUTPUT_DEBUG_STRING_EVENT:
      Result := 'OUTPUT_DEBUG_STRING_EVENT';
  else
    Result := IntToStr( DebugEventCode );
  end;
end;

procedure TDebugger.ProcessDebugEvents;
var
  WaitOK: Boolean;
  DebugEvent: DEBUG_EVENT;
  DebugEventHandlingResult: DWORD;
  CanContinueDebugEvent: Boolean;
  ContProcessEvents: Boolean;
begin
  ContProcessEvents := True;
  while ContProcessEvents do
  begin
    WaitOK := WaitForDebugEvent( DebugEvent, 1000 );

    DebugEventHandlingResult := DBG_CONTINUE;

    if WaitOK then
    begin
      if DebugEvent.dwProcessId <> FProcessID then
      begin
        FLogManager.Log( 'Skip subprocess event ' + GetEventCodeName( DebugEvent.dwDebugEventCode ) + ' for process ' + IntToStr( DebugEvent.dwProcessId ) );
      end
      else
      begin
        case DebugEvent.dwDebugEventCode of
          CREATE_PROCESS_DEBUG_EVENT:
            HandleCreateProcess( DebugEvent );
          CREATE_THREAD_DEBUG_EVENT:
            HandleCreateThread( DebugEvent );
          EXCEPTION_DEBUG_EVENT:
            HandleExceptionDebug( DebugEvent, ContProcessEvents, DebugEventHandlingResult );
          EXIT_PROCESS_DEBUG_EVENT:
            HandleExitProcess( DebugEvent, ContProcessEvents );
          EXIT_THREAD_DEBUG_EVENT:
            HandleExitThread( DebugEvent );
          LOAD_DLL_DEBUG_EVENT:
            HandleLoadDLL( DebugEvent );
          UNLOAD_DLL_DEBUG_EVENT:
            HandleUnLoadDLL( DebugEvent );
          RIP_EVENT:
            HandleRip( DebugEvent );
          OUTPUT_DEBUG_STRING_EVENT:
            HandleOutputDebugString( DebugEvent );
        end;
      end;

      CanContinueDebugEvent := ContinueDebugEvent( DebugEvent.dwProcessId, DebugEvent.dwThreadId, DebugEventHandlingResult );

      if not CanContinueDebugEvent then
      begin
        FLogManager.Log( 'Continue Debug Event error :' + LastOsErrorInfo );
        ContProcessEvents := False;
      end;
    end;
    //    else
    //      FLogManager.Log('Wait For Debug Event timed-out');
  end;
end;

procedure TDebugger.AddBreakPoints( const aUnitsList: TConfigUnitList; const AModule: IDebugModule; const AMapScanner: TJclMapScannerEx );
var
  vLineIndex: Integer;
  vBreakPoint: IBreakPoint;
  vUnitFileName: string;
  vUnitModuleName: string;
  vMapLineNumber: TJclMapLineNumber;
  vProcData: TJclMapProcName;
  vFullyQualifiedMethodName: string;
  vBreakpointAddress: Pointer;
begin
  if ( AMapScanner <> nil ) then
  begin
    FLogManager.Log( 'Adding breakpoints for module:' + AModule.Name );
    FLogManager.Indent;

    for vLineIndex := 0 to AMapScanner.LineNumbersCnt - 1 do
    begin
      vMapLineNumber := AMapScanner.LineNumberByIndex[vLineIndex];

      // RINGN:Segment 2 are .itext (ICODE). and 1 = Code
      if ( vMapLineNumber.Segment in [1, 2] ) then
      begin
        vUnitFileName := AMapScanner.SourceNameFromAddr( vMapLineNumber.VA );
        if ExtractFileExt( vUnitFileName ) = '' then
          vUnitFileName := vUnitFileName + '.pas';
        vUnitModuleName := AMapScanner.ModuleNameFromAddr( vMapLineNumber.VA );
        vProcData := AMapScanner.ProcDataFromAddr( vMapLineNumber.VA );
        vFullyQualifiedMethodName := vProcData.ProcName.CachedValue;

        if aUnitsList.MonitorProcedure( vUnitModuleName, vFullyQualifiedMethodName ) then
        begin
          vBreakpointAddress := AddressFromVA( vMapLineNumber.VA, AModule.CodeBegin );
          vBreakPoint := FBreakPointList.BreakPointByAddress[vBreakpointAddress];
          if not Assigned( vBreakPoint ) then
          begin
            vBreakPoint := TBreakPoint.Create( FDebugProcess, //
              vBreakpointAddress, vMapLineNumber.VA, //
              AModule, //
              vFullyQualifiedMethodName, vProcData.VA, //
              AModule.Name, vUnitModuleName, vUnitFileName, vMapLineNumber.LineNumber, FLogManager );
            FBreakPointList.Add( vBreakPoint );
            FModuleList.AddBreakpoint( vBreakPoint );
            FLogManager.Log( 'Adding: ' + vBreakPoint.DetailsToString );
          end;
          if ( not vBreakPoint.Activate ) then
            FLogManager.Log( 'BP FAILED to activate successfully' );
        end
        else
          FLogManager.Log( 'Skip ' + vFullyQualifiedMethodName );
      end;
    end;

    FLogManager.Undent;
    FLogManager.Log( 'Done adding  BreakPoints' );
  end;
end;

procedure TDebugger.HandleCreateProcess( const ADebugEvent: DEBUG_EVENT );
var
  DebugThread: IDebugThread;
  ProcessName: String;
begin
  ProcessName := FCoverageConfiguration.ExeFileName;
  FLogManager.Log( 'Create Process:' + IntToStr( ADebugEvent.dwProcessId ) + ' name:' + ProcessName );

  FDebugProcess := TDebugProcess.Create( //
    ADebugEvent.dwProcessId, //
    ADebugEvent.CreateProcessInfo.hProcess, //
    DWORD( ADebugEvent.CreateProcessInfo.lpBaseOfImage ), //
    ProcessName, ADebugEvent.CreateProcessInfo.hFile, FMapScanner, FLogManager );

  DebugThread := TDebugThread.Create( ADebugEvent.dwThreadId, ADebugEvent.CreateProcessInfo.hThread );

  FDebugProcess.AddThread( DebugThread );

  try
    AddBreakPoints( //
      FCoverageConfiguration.UnitList, //
      FDebugProcess, FMapScanner );

  except
    on E: Exception do
    begin
      FLogManager.Log( 'Exception during add breakpoints:' + E.message + ' ' + E.ToString( ) );
    end;
  end;
end;

procedure TDebugger.HandleCreateThread( const ADebugEvent: DEBUG_EVENT );
var
  DebugThread: IDebugThread;
begin
  FLogManager.Log( 'Create thread:' + IntToStr( ADebugEvent.dwThreadId ) );

  DebugThread := TDebugThread.Create( ADebugEvent.dwThreadId, ADebugEvent.CreateThread.hThread );

  FDebugProcess.AddThread( DebugThread );
end;

procedure TDebugger.HandleExceptionDebug( const ADebugEvent: DEBUG_EVENT; var AContProcessEvents: Boolean; var ADebugEventHandlingResult: DWORD );
var
  DebugThread: IDebugThread;
  BreakPoint: IBreakPoint;
  BreakPointDetailIndex: Integer;
  ExceptionRecord: EXCEPTION_RECORD;
  Module: IDebugModule;
  MapScanner: TJclMapScannerEx;
begin
  ADebugEventHandlingResult := Cardinal( DBG_EXCEPTION_NOT_HANDLED );

  ExceptionRecord := ADebugEvent.Exception.ExceptionRecord;
  Module := FDebugProcess.FindDebugModuleFromAddress( ExceptionRecord.ExceptionAddress );
  if Assigned( Module ) then
    MapScanner := Module.MapScanner
  else
    MapScanner := nil;

  case ExceptionRecord.ExceptionCode of
    Cardinal( EXCEPTION_ACCESS_VIOLATION ):
      begin
        FLogManager.Log( 'ACCESS VIOLATION at Address:' + AddressToString( ExceptionRecord.ExceptionAddress ) );
        FLogManager.Log( AddressToString( ExceptionRecord.ExceptionCode ) + ' not a debug BreakPoint' );

        if ExceptionRecord.NumberParameters > 1 then
        begin
          if ExceptionRecord.ExceptionInformation[0] = 0 then
            FLogManager.Log( 'Tried to read' );
          if ExceptionRecord.ExceptionInformation[0] = 1 then
            FLogManager.Log( 'Tried to write' );
          if ExceptionRecord.ExceptionInformation[0] = 8 then
            FLogManager.Log( 'DEP exception' );

          FLogManager.Log( 'Trying to access Address:' + AddressToString( ExceptionRecord.ExceptionInformation[1] ) );

          if Assigned( MapScanner ) then
          begin
            for BreakPointDetailIndex := 0 to MapScanner.LineNumbersCnt - 1 do
            begin
              if MapScanner.LineNumberByIndex[BreakPointDetailIndex].VA = VAFromAddress( ExceptionRecord.ExceptionAddress, Module.CodeBegin ) then
              begin
                FLogManager.Log( MapScanner.ModuleNameFromAddr( MapScanner.LineNumberByIndex[BreakPointDetailIndex].VA ) + ' line ' +
                  IntToStr( MapScanner.LineNumberByIndex[BreakPointDetailIndex].LineNumber ) );
                break;
              end;
            end;
          end
          else
          begin
            if not Assigned( Module ) then
              FLogManager.Log( 'No map information available Address:' + AddressToString( ExceptionRecord.ExceptionInformation[1] ) + ' in unknown module' )
            else
              FLogManager.Log( 'No map information available Address:' + AddressToString( ExceptionRecord.ExceptionInformation[1] ) + ' module ' +
                Module.Name );
          end;

          LogStackFrame( ADebugEvent );
        end;
      end;

    // Cardinal(EXCEPTION_ARRAY_BOUNDS_EXCEEDED) :
    Cardinal( EXCEPTION_BreakPoint ):
      begin
        BreakPoint := FBreakPointList.BreakPointByAddress[ExceptionRecord.ExceptionAddress];
        if Assigned( BreakPoint ) then
        begin
          FLogManager.Log( 'Adding coverage for ' + BreakPoint.DetailsToString );
          DebugThread := FDebugProcess.GetThreadById( ADebugEvent.dwThreadId );
          if ( DebugThread <> nil ) then
          begin
            if ( BreakPoint.IsActive ) then
            begin
              if BreakPoint.Hit( DebugThread ) then
                FLastBreakPoint := BreakPoint;
            end
            else
            begin
              FLogManager.Log( 'BreakPoint already cleared - BreakPoint in source?' );
            end;
          end
          else
            FLogManager.Log( 'Couldn''t find thread:' + IntToStr( ADebugEvent.dwThreadId ) );
        end
        else
        begin
          // A good contender for this is ntdll.DbgBreakPoint {$7C90120E}
          FLogManager.Log( 'Couldn''t find BreakPoint for exception address:' + AddressToString( ExceptionRecord.ExceptionAddress ) );
        end;
        ADebugEventHandlingResult := Cardinal( DBG_CONTINUE );
      end;
    Cardinal( EXCEPTION_SINGLE_STEP ):
      begin
        // This is triggered after a breakpoint by TF - it is automatically reset by the interrupt
        // We need to let the breakpoint instruction execute, then reset the breakpoint
        if Assigned( FLastBreakPoint ) then
        begin
          FLastBreakPoint.Activate;
          FLastBreakPoint := nil;
        end;
        ADebugEventHandlingResult := Cardinal( DBG_CONTINUE );
      end;

    Cardinal( EXCEPTION_DATATYPE_MISALIGNMENT ):
      begin
        FLogManager.Log( 'EXCEPTION_DATATYPE_MISALIGNMENT Address:' + AddressToString( ExceptionRecord.ExceptionAddress ) );
        FLogManager.Log( AddressToString( ExceptionRecord.ExceptionCode ) + ' not a debug BreakPoint' );
        AContProcessEvents := False;
      end;

    // Cardinal(EXCEPTION_FLT_DENORMAL_OPERAND)
    // Cardinal(EXCEPTION_FLT_DIVIDE_BY_ZERO)
    // Cardinal(EXCEPTION_FLT_INEXACT_RESULT)
    // Cardinal(EXCEPTION_FLT_INVALID_OPERATION)
    // Cardinal(EXCEPTION_FLT_OVERFLOW)
    // Cardinal(EXCEPTION_FLT_STACK_CHECK)
    // Cardinal(EXCEPTION_FLT_UNDERFLOW)
    // Cardinal(EXCEPTION_ILLEGAL_INSTRUCTION)
    // Cardinal(EXCEPTION_IN_PAGE_ERROR)
    // Cardinal(EXCEPTION_INT_DIVIDE_BY_ZERO)
    // Cardinal(EXCEPTION_INT_OVERFLOW)
    // Cardinal(EXCEPTION_INVALID_DISPOSITION)
    // Cardinal(EXCEPTION_NONCONTINUABLE_EXCEPTION)
    // Cardinal(EXCEPTION_PRIV_INSTRUCTION)
    // Cardinal(EXCEPTION_SINGLE_STEP)
    // Cardinal(EXCEPTION_STACK_OVERFLOW)
  else
    begin
      FLogManager.Log( 'EXCEPTION CODE:' + AddressToString( ExceptionRecord.ExceptionCode ) );
      FLogManager.Log( 'Address:' + AddressToString( ExceptionRecord.ExceptionAddress ) );
      FLogManager.Log( 'EXCEPTION flags:' + AddressToString( ExceptionRecord.ExceptionFlags ) );
      LogStackFrame( ADebugEvent );
    end;
  end
end;

procedure TDebugger.LogStackFrame( const ADebugEvent: DEBUG_EVENT );
var
  ContextRecord: TContext;
  StackFrame: TSTACKFRAME64;
  LineIndex: Integer;
  MapLineNumber: TJclMapLineNumber;
  DebugThread: IDebugThread;
  Module: IDebugModule;
  vMapScanner: TJclMapScannerEx;
begin
  ContextRecord.ContextFlags := CONTEXT_ALL;

  DebugThread := FDebugProcess.GetThreadById( ADebugEvent.dwThreadId );

  if DebugThread <> nil then
  begin
    if GetThreadContext( DebugThread.Handle, ContextRecord ) then
    begin
      FillChar( StackFrame, SizeOf( StackFrame ), 0 );
      StackFrame.AddrPC.Offset := ContextRecord.Eip;
      StackFrame.AddrPC.Mode := AddrModeFlat;
      StackFrame.AddrFrame.Offset := ContextRecord.Ebp;
      StackFrame.AddrFrame.Mode := AddrModeFlat;
      StackFrame.AddrStack.Offset := ContextRecord.Esp;
      StackFrame.AddrStack.Mode := AddrModeFlat;

      StackWalk64( IMAGE_FILE_MACHINE_I386, FDebugProcess.Handle, DebugThread.Handle, StackFrame, @ContextRecord, @RealReadFromProcessMemory, nil, nil, nil );

      FLogManager.Log( '---------------Stack trace --------------' );
      while StackWalk64( IMAGE_FILE_MACHINE_I386, FDebugProcess.Handle, DebugThread.Handle, StackFrame, @ContextRecord, @RealReadFromProcessMemory, nil,
        nil, nil ) do
      begin
        if ( StackFrame.AddrPC.Offset <> 0 ) then
        begin
          Module := FDebugProcess.FindDebugModuleFromAddress( Pointer( StackFrame.AddrPC.Offset ) );
          if ( Module <> nil ) then
          begin
            vMapScanner := Module.MapScanner;

            FLogManager.Log( 'Module : ' + Module.Name + ' Stack frame:' + AddressToString( Pointer( StackFrame.AddrPC.Offset ) ) );
            if Assigned( vMapScanner ) then
            begin
              for LineIndex := 0 to vMapScanner.LineNumbersCnt - 1 do
              begin
                MapLineNumber := vMapScanner.LineNumberByIndex[LineIndex];
                if MapLineNumber.VA = VAFromAddress( Pointer( StackFrame.AddrPC.Offset ), Module.CodeBegin ) then
                begin
                  FLogManager.Log( 'Exact line:' + vMapScanner.ModuleNameFromAddr( MapLineNumber.VA ) + ' line ' + IntToStr( MapLineNumber.LineNumber ) );
                  break;
                end
                else if ( MapLineNumber.VA > VAFromAddress( Pointer( StackFrame.AddrPC.Offset ), Module.CodeBegin ) ) and
                  ( VAFromAddress( Pointer( StackFrame.AddrPC.Offset ), Module.CodeBegin ) < vMapScanner.LineNumberByIndex[LineIndex + 1].VA ) then
                begin
                  FLogManager.Log( 'After line:' + vMapScanner.ModuleNameFromAddr( MapLineNumber.VA ) + ' line ' + IntToStr( MapLineNumber.LineNumber ) );
                  break;
                end;
              end;
            end
            else
              FLogManager.Log( 'Module : ' + Module.Name + ' - no MAP information exists' );
          end
          else
          begin
            FLogManager.Log( 'No module found for exception address:' + AddressToString( StackFrame.AddrPC.Offset ) );
          end;
        end;
      end;
      FLogManager.Log( '---------------End of Stack trace --------------' );
    end
    else
      FLogManager.Log( 'Failed to get thread context : ' + LastOsErrorInfo );
  end
  else
    FLogManager.Log( 'Thread not found : ' + IntToStr( ADebugEvent.dwThreadId ) );
end;

procedure TDebugger.HandleExitProcess( const ADebugEvent: DEBUG_EVENT; var AContProcessEvents: Boolean );
begin
  FTestExeExitCode := ADebugEvent.ExitProcess.dwExitCode;
  FLogManager.Log( 'Process ' + IntToStr( ADebugEvent.dwProcessId ) + ' exiting. Exit code :' + IntToStr( FTestExeExitCode ) );

  AContProcessEvents := False;
end;

procedure TDebugger.HandleExitThread( const ADebugEvent: DEBUG_EVENT );
begin
  FLogManager.Log( 'Thread exit:' + IntToStr( ADebugEvent.dwThreadId ) );
  FDebugProcess.RemoveThread( ADebugEvent.dwThreadId );
end;

procedure TDebugger.HandleLoadDLL( const ADebugEvent: DEBUG_EVENT );
var
  DllName: string;
  Module: TDebugModule;
  MapFile: string;
  MapScanner: TJclMapScannerEx;
begin
  DllName := GetDllName( FDebugProcess.Handle, ADebugEvent.LoadDll.lpBaseOfDll );

  FLogManager.Log( Format( 'Loading DLL (%s) at addr: %s with Handle %d', [DllName, AddressToString( ADebugEvent.LoadDll.lpBaseOfDll ),
    ADebugEvent.LoadDll.hFile] ) );

  if DllName = 'WOW64_IMAGE_SECTION' then
  begin
    FLogManager.Log( 'DllName = WOW64_IMAGE_SECTION' );
    Exit;
  end;

  if ( DllName <> '' ) and PathIsAbsolute( DllName ) then
  begin
    if FDebugProcess.GetModuleByFilename( DllName ) = nil then
    begin
      MapFile := FCoverageConfiguration.GetMapFileName( DllName );

      if FileExists( MapFile ) then
      begin
        FLogManager.Log( 'Loading map file:' + MapFile );
        MapScanner := TJclMapScannerEx.Create( MapFile );
      end
      else
        MapScanner := nil;

      Module := TDebugModule.Create( DllName, ADebugEvent.LoadDll.hFile, NativeUInt( ADebugEvent.LoadDll.lpBaseOfDll ), MapScanner );
      FDebugProcess.AddModule( Module );
      try
        AddBreakPoints( //
          FCoverageConfiguration.UnitList, //
          Module, MapScanner );
      except
        on E: Exception do
        begin
          FLogManager.Log( 'Exception during add breakpoints:' + E.message + ' ' + E.ToString( ) );
        end;
      end;
    end
    else
    begin
      FLogManager.Log( 'WARNING: The module ' + DllName + ' was already loaded. Skipping breakpoint generation for subsequent load.' );
    end;
  end;

  CloseHandle( ADebugEvent.LoadDll.hFile ); // according to MS Documentation we shall close the handle once we are done.
end;

procedure TDebugger.HandleUnLoadDLL( const ADebugEvent: DEBUG_EVENT );
var
  DbgModule: IDebugModule;
begin
  DbgModule := FDebugProcess.GetModuleByBase( NativeUInt( ADebugEvent.UnloadDll.lpBaseOfDll ) );
  if not Assigned( DbgModule ) then
  begin
    FLogManager.Log( 'UnLoading DLL:' + AddressToString( ADebugEvent.UnloadDll.lpBaseOfDll ) );
    Exit;
  end;

  FLogManager.Log( Format( 'UnLoading DLL: %s (%s)', [DbgModule.Name, AddressToString( DbgModule.Base )] ) );
  FLogManager.Indent;
  FBreakPointList.RemoveModuleBreakpoints( DbgModule );
  FModuleList.RemoveBreakPointsForModule( DbgModule );
  FDebugProcess.RemoveModule( DbgModule );
  FLogManager.Undent;
end;

procedure TDebugger.HandleOutputDebugString( const ADebugEvent: DEBUG_EVENT );
begin
end;

procedure TDebugger.HandleRip( const ADebugEvent: DEBUG_EVENT );
begin
end;

end.
