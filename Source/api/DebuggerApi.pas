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
unit DebuggerApi;

interface

uses
  WinApi.Windows,
  JCLDebug;

type
  IDebugThread = interface
    function Handle: THandle;
    function Id: DWORD;
  end;

  ///<summary>The Binary module on disk. Such as a exe/dll/bpl</summary>
  IDebugModule = interface
    ///<summary>Name of the Module as given on Disk</summary>
    function Name: string;
    ///<summary>Name of the Module as given on Disk</summary>
    function Filename: string;
    ///<summary>Name of the Module as given on Disk</summary>
    function Filepath: string;
    ///<summary>Handle to the phyical file on Disk</summary>
    function HFile: THandle;
    ///<summary>Address of the base address of the Dll in the process address space</summary>
    function Base: NativeUInt;
    ///<summary>Codesize of the Dll</summary>
    function Size: Cardinal;

    ///<summary>Begin addess of the Code section</summary>
    function CodeBegin: NativeUInt;
    ///<summary>End address of the Code section</summary>
    function CodeEnd: NativeUInt;

    ///<summary>Map file associated with the module. Returns nil if no map file is given</summary>
    function MapScanner: TJCLMapScanner;
  end;

  IDebugProcess = interface( IDebugModule )
    procedure AddThread( const aDebugThread: IDebugThread );
    procedure RemoveThread( const aThreadId: DWORD );

    procedure AddModule( const aModule: IDebugModule );
    procedure RemoveModule( const aModule: IDebugModule );
    function GetModuleByFilename( const aFilepath: string ): IDebugModule;
    function GetModuleByBase( const aAddress: NativeUInt ): IDebugModule;

    function Handle: THandle;
    function FindDebugModuleFromAddress( aAddr: Pointer ): IDebugModule;
    function GetThreadById( const aThreadId: DWORD ): IDebugThread;
    function ReadProcessMemory( const aAddress, AData: Pointer; const aSize: Cardinal; const aChangeProtect: Boolean = False ): Integer;
    function WriteProcessMemory( const aAddress, AData: Pointer; const aSize: Cardinal; const aChangeProtect: Boolean = False ): Integer;
  end;

  /// <summary>Source information of a breakpoint</summary>
  TBreakPointDetail = record
    /// <summary>The fully qualifified name of the method, as defined in the MAP file.
    /// This typically consists of ModuleName.ClassName.Methodname</summary>
    FullyQualifiedMethodName: string;
    /// <summary>The name of the module. This is the name of the module (w/o dpr/dpk/exe/bpl) where the binary code resides</summary>
    ModuleName: string;

    /// <summary>This is the name of the module/unit where code is defined. UnitName w/o pas</summary>
    UnitName: string;
    /// <summary>This is the name of the unit (including .pas) where the class/method is defined.</summary>
    UnitFileName: string;
    /// <summary>This is the name of class that contains the procedure</summary>
    ClassName: string;
    /// <summary>The name of the method where this breakpoint is defined</summary>
    MethodName: string;
    /// <summary>The line of source code this breakpoint covers in the unit name.</summary>
    Line: Integer;
  end;

type
  IBreakPoint = interface; // forward;
  TBreakPointTrigger = reference to procedure( const aBreakpoint: IBreakPoint );

  /// <summary>
  /// Interface of a source code breakpoint.
  /// The debugger will halt on active breakpoints.
  /// </summary>
  IBreakPoint = interface
    function GetOnHit: TBreakPointTrigger;
    procedure SetOnHit( const aEventHit: TBreakPointTrigger );

    ///<summary>Removes Breakpoint without updating the BreakCount.</summary>
    procedure Clear( const AThread: IDebugThread );
    /// <summary>Activate the breakpoint. The Debugger will halt when it is hit.</summary>
    function Activate: Boolean;
    /// <summary>Deactivate the breakpoint. The Debugger will no longer halt on this position. Warning! This method does not reset the instruction pointer.</summary>
    function DeActivate: Boolean;
    ///<summary>Hit the given Breakpoint. If the function returns true,
    /// the Breakpoint needs to be reactivated in the STATUS_SINGLE_STEP event.
    /// (Trap flag has been set.)</summary>
    function Hit( const AThread: IDebugThread ): Boolean;
    /// <summary>Number of times the breakpoint was hit.</summary>
    function BreakCount: Integer;
    /// <summary>Time when the breakpoint was last hit.</summary>
    function HitTime: TTime;
    /// <summary>The memory address of the breakpoint. This is a absolute address.</summary>
    function Address: Pointer;
    /// <summary>Module to which this breakpoint belongs.</summary>
    function Module: IDebugModule;

    /// <summary>Get the source details for the given breakpoint.</summary>
    function Details: TBreakPointDetail;
    /// <summary>Convienience method that gives a nice string representation for logging.</summary>
    function DetailsToString: string;
    /// <summary>Is the breakpoint currently active.</summary>
    function IsActive: Boolean;
    /// <summary>Query if the breakpoint was hit at least once.</summary>
    function GetCovered: Boolean;
    property IsCovered: Boolean read GetCovered;

    property OnHit: TBreakPointTrigger read GetOnHit write SetOnHit;
  end;

  IBreakPointList = interface
    procedure Add( const aBreakpoint: IBreakPoint );

    procedure RemoveModuleBreakpoints( const aModule: IDebugModule );

    function Count: Integer;
    function GetBreakPoints: TArray<IBreakPoint>;

    function GetBreakPointByAddress( const aAddress: Pointer ): IBreakPoint;
    property BreakPointByAddress[const aAddress: Pointer]: IBreakPoint read GetBreakPointByAddress;
  end;

implementation

end.
