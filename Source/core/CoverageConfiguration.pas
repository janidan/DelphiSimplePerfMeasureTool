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
unit CoverageConfiguration;

interface

uses
  System.Classes,
  System.SysUtils,
  XMLIntf,
  ConfigUnitList,
  LoggingApi;

type
  ICoverageConfiguration = interface
    function ApplicationParameters: string;
    function ExeFileName: string;
    function GetMapFileName( const aImageBinaryFilename: string ): string;
    function OutputDir: string;
    function UnitList: TConfigUnitList;
    function IsComplete( var aReason: string ): Boolean;

    function XmlOutput: Boolean;
    function HtmlOutput: Boolean;
    function ConsoleSummary: Boolean;

    function EntryPointDump: Boolean;

    function LogManager: ILogManager;
  end;

type
  TCoverageConfiguration = class( TInterfacedObject, ICoverageConfiguration )
  strict private
    FExeFileName: string;
    FExeParamsStrLst: TStrings;
    FSymbolRootPath: string;

    FConfigUnitList: TConfigUnitList;
    FLoadingFromDProj: Boolean;

    FOutputDir: string;
    FXmlOutput: Boolean;
    FHtmlOutput: Boolean;
    FConsoleSummary: Boolean;
    FEntryPointDump: Boolean;

    FLogManager: ILogManager;
  strict private
    function ParseParameter( const aParameter: Integer ): string;
    procedure ParseSwitch( var aParameter: Integer );
    procedure ParseBooleanSwitches;
    function GetCurrentConfig( const Project: IXMLNode ): string;
    function GetExeOutputFromDProj( const Project: IXMLNode; const ProjectName: TFileName ): string;
    function GetDCCReferencesFromDProj( const ItemGroup: IXMLNode; const Rootpath: TFileName ): string;
    procedure ParseDProj( const DProjFilename: TFileName );
    procedure ParseDProjForDccReferencesOnly( const DProjFilename: TFileName );
    procedure ParseProjGroup( const ProjGroupFilename: TFileName );
    function IsExecutableSet( var aReason: string ): Boolean;
    function GetInternalMapFilename( const aImageBinaryFilename: string ): string;
    function IsSymbolPathSet( var aReason: string ): Boolean;

    procedure ParseCommandLine;
    procedure ParseExecutableSwitch( var aParameter: Integer );
    procedure ParseSymbolRootSwitch( var aParameter: Integer );
    procedure ParseUnitSwitch( var aParameter: Integer );
    procedure ParseUnitFileSwitch( var aParameter: Integer );
    procedure ParseMontitorProcSwitch( var aParameter: Integer );
    procedure ParseMontitorProcFileSwitch( var aParameter: Integer );
    procedure ParseExecutableParametersSwitch( var aParameter: Integer );
    procedure ParseSourcePathsSwitch( var aParameter: Integer );
    procedure ParseSourcePathsFileSwitch( var aParameter: Integer );
    procedure ParseOutputDirectorySwitch( var aParameter: Integer );
    procedure ParseLoggingTextSwitch( var aParameter: Integer );
    procedure ParseLoggingConsoleSwitch( var aParameter: Integer );
    procedure ParseDprojSwitch( var aParameter: Integer );
    procedure ParseProjGroupSwitch( var aParameter: Integer );

  strict private
    function ApplicationParameters: string;
    function ExeFileName: string;
    function GetMapFileName( const aImageBinaryFilename: string ): string;
    function OutputDir: string;
    function UnitList: TConfigUnitList;
    function IsComplete( var aReason: string ): Boolean;
    function XmlOutput: Boolean;
    function HtmlOutput: Boolean;
    function ConsoleSummary: Boolean;
    function EntryPointDump: Boolean;
    function LogManager: ILogManager;
  public
    constructor Create( const ALogManager: ILogManager );
    destructor Destroy; override;
    procedure AfterConstruction; override;

  end;

  EConfigurationException = class( Exception );

const
  cESCAPE_CHARACTER: char = '^';
  cDEFULT_DEBUG_LOG_FILENAME = 'DebugLog.log';
  cPARAMETER_EXECUTABLE = '-e';
  cPARAMETER_SYMBOL_ROOT = '-sym';
  cPARAMETER_UNIT = '-u';
  cPARAMETER_UNIT_FILE = '-uf';
  cPARAMETER_OUTPUT_DIRECTORY = '-od';
  cPARAMETER_EXECUTABLE_PARAMETER = '-a';
  cPARAMETER_LOGGING_TEXT = '-lt';
  cPARAMETER_LOGGING_CONSOLE = '-lcon';
  cPARAMETER_SOURCE_PATHS = '-sp';
  cPARAMETER_SOURCE_PATHS_FILE = '-spf';
  cPARAMETER_DUMP_ENTRY_POINTS = '-dump';
  cPARAMETER_XML_OUTPUT = '-xml';
  cPARAMETER_HTML_OUTPUT = '-html';
  cPARAMETER_CONSOLE_OUTPUT = '-summary';
  cPARAMETER_DPROJ = '-dproj';
  cPARAMETER_GROUPPROJ = '-groupproj';
  cPARAMETER_MONITOR_PROC = '-proc';
  cPARAMETER_MONITOR_PROC_FILE = '-procf';

implementation

uses
  System.StrUtils,
  JclFileUtils,
  IOUtils,
  DebuggerUtils,
  LoggerTextFile,
  LoggerConsole,
  LoggerDebugAPI,
  XMLDoc,
  Windows,
  Masks;

function TCoverageConfiguration.ConsoleSummary: Boolean;
begin
  // By default we will return the console output if no special output is set.
  Result := FConsoleSummary or ( not FHtmlOutput and not FXmlOutput );
end;

constructor TCoverageConfiguration.Create( const ALogManager: ILogManager );
begin
  inherited Create;

  FLogManager := ALogManager;

  FExeParamsStrLst := TStringList.Create;
  FHtmlOutput := False;
  FXmlOutput := False;
  FConsoleSummary := False;

  FConfigUnitList := TConfigUnitList.Create;
end;

destructor TCoverageConfiguration.Destroy;
begin
  FConfigUnitList.Free;
  FExeParamsStrLst.Free;
  inherited Destroy;
end;

function TCoverageConfiguration.IsComplete( var aReason: string ): Boolean;
begin
  Result := IsExecutableSet( aReason ) and IsSymbolPathSet( aReason );
end;

function TCoverageConfiguration.IsExecutableSet( var aReason: string ): Boolean;
begin
  aReason := '';

  if ( FExeFileName = '' ) then
    aReason := 'No executable was specified'
  else if not FileExists( FExeFileName ) then
    aReason := 'The executable file ' + FExeFileName + ' does not exist. Current dir is ' + GetCurrentDir;

  Result := ( aReason = '' );
end;

function TCoverageConfiguration.IsSymbolPathSet( var aReason: string ): Boolean;
begin
  aReason := '';

  //  if ( FSymbolRootPath = '' ) then
  //    AReason := 'No symbol path was specified'
  //  else if not FileExists( FMapFileName ) then
  //    AReason := 'The map file ' + FMapFileName + ' does not exist. Current dir is ' + GetCurrentDir;
  //
  Result := ( aReason = '' );
end;

function TCoverageConfiguration.LogManager: ILogManager;
begin
  Result := FLogManager;
end;

function TCoverageConfiguration.UnitList: TConfigUnitList;
begin
  Result := FConfigUnitList;
end;

procedure TCoverageConfiguration.AfterConstruction;
begin
  inherited AfterConstruction;
  ParseCommandLine;
end;

function TCoverageConfiguration.ApplicationParameters: string;
var
  lp: Integer;
begin
  Result := '';
  for lp := 0 to FExeParamsStrLst.Count - 1 do
    Result := Result + FExeParamsStrLst[lp] + ' ';

  Result := Copy( Result, 1, Length( Result ) - 1 );
end;

function TCoverageConfiguration.EntryPointDump: Boolean;
begin
  Result := FEntryPointDump;
end;

function TCoverageConfiguration.ExeFileName: string;
begin
  Result := FExeFileName;
end;

function TCoverageConfiguration.OutputDir: string;
begin
  Result := FOutputDir;
  if Result = '' then
    Result := TPath.GetDirectoryName( FExeFileName );
end;

function TCoverageConfiguration.XmlOutput: Boolean;
begin
  Result := FXmlOutput;
end;

function TCoverageConfiguration.HtmlOutput: Boolean;
begin
  Result := FHtmlOutput;
end;

procedure TCoverageConfiguration.ParseBooleanSwitches;
  function CleanSwitch( const Switch: string ): string;
  begin
    Result := Switch;
    if StartsStr( '-', Result ) then
      Delete( Result, 1, 1 );
  end;

  function IsSet( const Switch: string ): Boolean;
  begin
    Result := FindCmdLineSwitch( CleanSwitch( Switch ), ['-'], True );
  end;

begin
  FXmlOutput := IsSet( cPARAMETER_XML_OUTPUT );
  FHtmlOutput := IsSet( cPARAMETER_HTML_OUTPUT );
  FConsoleSummary := IsSet( cPARAMETER_CONSOLE_OUTPUT );
  FEntryPointDump := IsSet( cPARAMETER_DUMP_ENTRY_POINTS );
end;

procedure TCoverageConfiguration.ParseCommandLine;
var
  ParameterIdx: Integer;
begin
  // parse boolean switches first, so we don't have to care about the order here
  ParseBooleanSwitches;

  ParameterIdx := 1;
  while ParameterIdx <= ParamCount do
  begin
    ParseSwitch( ParameterIdx );
    Inc( ParameterIdx );
  end;
  FConfigUnitList.LogTracking;
end;

function TCoverageConfiguration.ParseParameter( const aParameter: Integer ): string;
var
  Param: string;
begin
  Result := '';

  if aParameter <= ParamCount then
  begin
    Param := ParamStr( aParameter );

    if ( LeftStr( Param, 1 ) <> '-' ) then
      Result := ExpandEnvString( UnescapeParam( Param ) );
  end;
end;

procedure TCoverageConfiguration.ParseProjGroup( const ProjGroupFilename: TFileName );
var
  Document: IXMLDocument;
  Node: IXMLNode;
  Project: IXMLNode;
  ProjectsItemGroup: IXMLNode;
  ProjectName: string;
  I: Integer;
  Rootpath: TFileName;
begin
  Rootpath := ExtractFilePath( TPath.GetFullPath( ProjGroupFilename ) );
  Document := TXMLDocument.Create( nil );
  Document.LoadFromFile( ProjGroupFilename );

  Project := Document.ChildNodes.FindNode( 'Project' );
  if Project <> nil then
  begin
    ProjectsItemGroup := Project.ChildNodes.FindNode( 'ItemGroup' );
    if Assigned( ProjectsItemGroup ) then
    begin
      for I := 0 to ProjectsItemGroup.ChildNodes.Count - 1 do
      begin
        Node := ProjectsItemGroup.ChildNodes.Get( I );
        if Node.LocalName = 'Projects' then
        begin
          ProjectName := TPath.GetFullPath( TPath.Combine( Rootpath, Node.Attributes['Include'] ) );
          ParseDProjForDccReferencesOnly( ProjectName );
        end;
      end;
    end;
  end;
end;

procedure TCoverageConfiguration.ParseProjGroupSwitch( var aParameter: Integer );
var
  vGroupProjPath: TFileName;
begin
  Inc( aParameter );
  vGroupProjPath := ParseParameter( aParameter );
  ParseProjGroup( vGroupProjPath );
end;

procedure TCoverageConfiguration.ParseSwitch( var aParameter: Integer );
var
  SwitchItem: string;
begin
  SwitchItem := ParamStr( aParameter );
  if SwitchItem = cPARAMETER_EXECUTABLE then
    ParseExecutableSwitch( aParameter )
  else if SwitchItem = cPARAMETER_SYMBOL_ROOT then
    ParseSymbolRootSwitch( aParameter )
  else if SwitchItem = cPARAMETER_UNIT then
    ParseUnitSwitch( aParameter )
  else if SwitchItem = cPARAMETER_UNIT_FILE then
    ParseUnitFileSwitch( aParameter )
  else if SwitchItem = cPARAMETER_MONITOR_PROC then
    ParseMontitorProcSwitch( aParameter )
  else if SwitchItem = cPARAMETER_MONITOR_PROC_FILE then
    ParseMontitorProcFileSwitch( aParameter )
  else if SwitchItem = cPARAMETER_EXECUTABLE_PARAMETER then
    ParseExecutableParametersSwitch( aParameter )
  else if SwitchItem = cPARAMETER_SOURCE_PATHS then
    ParseSourcePathsSwitch( aParameter )
  else if SwitchItem = cPARAMETER_SOURCE_PATHS_FILE then
    ParseSourcePathsFileSwitch( aParameter )
  else if SwitchItem = cPARAMETER_OUTPUT_DIRECTORY then
    ParseOutputDirectorySwitch( aParameter )
  else if SwitchItem = cPARAMETER_LOGGING_TEXT then
    ParseLoggingTextSwitch( aParameter )
  else if SwitchItem = cPARAMETER_LOGGING_CONSOLE then
    ParseLoggingConsoleSwitch( aParameter )
  else if ( SwitchItem = cPARAMETER_XML_OUTPUT ) or //
    ( SwitchItem = cPARAMETER_HTML_OUTPUT ) or //
    ( SwitchItem = cPARAMETER_CONSOLE_OUTPUT ) or //
    ( SwitchItem = cPARAMETER_DUMP_ENTRY_POINTS ) then
  begin
    // do nothing, because its already parsed
  end
  else if SwitchItem = cPARAMETER_DPROJ then
    ParseDprojSwitch( aParameter )
  else if SwitchItem = cPARAMETER_GROUPPROJ then
    ParseProjGroupSwitch( aParameter )
    //  else
    //    raise EConfigurationException.Create( 'Unexpected switch:' + SwitchItem );
end;

procedure TCoverageConfiguration.ParseSymbolRootSwitch( var aParameter: Integer );
begin
  Inc( aParameter );
  FSymbolRootPath := ParseParameter( aParameter );
  //  if FSymbolRootPath = '' then
  //    raise EConfigurationException.Create( 'Expected parameter for symbol root' );
end;

procedure TCoverageConfiguration.ParseExecutableSwitch( var aParameter: Integer );
begin
  Inc( aParameter );
  FExeFileName := ParseParameter( aParameter );
  if FExeFileName = '' then
    raise EConfigurationException.Create( 'Expected parameter for executable' );

  if FSymbolRootPath = '' then
    FSymbolRootPath := TPath.GetDirectoryName( FExeFileName );
end;

procedure TCoverageConfiguration.ParseMontitorProcFileSwitch( var aParameter: Integer );
var
  vMonitorMethodsFileName: string;
begin
  Inc( aParameter );
  vMonitorMethodsFileName := ParseParameter( aParameter );

  if vMonitorMethodsFileName <> '' then
    FConfigUnitList.ReadMonitorProcedureFile( vMonitorMethodsFileName )
  else
    raise EConfigurationException.Create( 'Expected parameter for procedure file name' );
end;

procedure TCoverageConfiguration.ParseMontitorProcSwitch( var aParameter: Integer );
var
  vMonitorProc: string;
begin
  Inc( aParameter );
  vMonitorProc := ParseParameter( aParameter );
  while vMonitorProc <> '' do
  begin
    FConfigUnitList.AddMontitorProcedure( vMonitorProc );
    Inc( aParameter );
    vMonitorProc := ParseParameter( aParameter );
  end;
  Dec( aParameter );
end;

procedure TCoverageConfiguration.ParseUnitSwitch( var aParameter: Integer );
var
  UnitString: string;
begin
  Inc( aParameter );
  UnitString := ParseParameter( aParameter );
  while UnitString <> '' do
  begin
    FConfigUnitList.AddUnit( UnitString );
    Inc( aParameter );
    UnitString := ParseParameter( aParameter );
  end;
  Dec( aParameter );
end;

procedure TCoverageConfiguration.ParseUnitFileSwitch( var aParameter: Integer );
var
  UnitsFileName: string;
begin
  Inc( aParameter );
  UnitsFileName := ParseParameter( aParameter );

  if UnitsFileName <> '' then
    FConfigUnitList.ReadUnitFile( UnitsFileName )
  else
    raise EConfigurationException.Create( 'Expected parameter for units file name' );
end;

procedure TCoverageConfiguration.ParseExecutableParametersSwitch( var aParameter: Integer );
var
  ExecutableParam: string;
begin
  Inc( aParameter );
  ExecutableParam := ParseParameter( aParameter );

  while ExecutableParam <> '' do
  begin
    FExeParamsStrLst.Add( ExecutableParam );
    Inc( aParameter );
    ExecutableParam := ParseParameter( aParameter );
  end;

  if FExeParamsStrLst.Count = 0 then
    raise EConfigurationException.Create( 'Expected at least one executable parameter' );

  Dec( aParameter );
end;

procedure TCoverageConfiguration.ParseSourcePathsSwitch( var aParameter: Integer );
var
  SourcePathString: string;
begin
  Inc( aParameter );
  SourcePathString := ParseParameter( aParameter );

  while SourcePathString <> '' do
  begin
    SourcePathString := MakePathAbsolute( SourcePathString, GetCurrentDir );

    if SourcePathString.EndsWith( '*' ) then
    begin
      SourcePathString := TPath.GetDirectoryName( SourcePathString );
      var
      vSubDirectories := TDirectory.GetDirectories( SourcePathString, '*', TSearchOption.soAllDirectories );
      for var vDir in vSubDirectories do
      begin
        var
        vFiles := TDirectory.GetFiles( vDir, '*.pas' );
        if Length( vFiles ) > 0 then
          FConfigUnitList.AddSourceDirectory( vDir );
      end;
    end;

    if DirectoryExists( SourcePathString ) then
      FConfigUnitList.AddSourceDirectory( SourcePathString );

    Inc( aParameter );
    SourcePathString := ParseParameter( aParameter );
  end;
  Dec( aParameter );
end;

procedure TCoverageConfiguration.ParseSourcePathsFileSwitch( var aParameter: Integer );
var
  SourcePathFileName: string;
begin
  Inc( aParameter );
  SourcePathFileName := ParseParameter( aParameter );

  if SourcePathFileName <> '' then
    FConfigUnitList.ReadSourcePathFile( SourcePathFileName )
  else
    raise EConfigurationException.Create( 'Expected parameter for source path file name' );
end;

procedure TCoverageConfiguration.ParseOutputDirectorySwitch( var aParameter: Integer );
begin
  Inc( aParameter );
  FOutputDir := ParseParameter( aParameter );
  if FOutputDir = '' then
    raise EConfigurationException.Create( 'Expected parameter for output directory' );
end;

procedure TCoverageConfiguration.ParseLoggingConsoleSwitch( var aParameter: Integer );
begin
  if Assigned( FLogManager ) then
    FLogManager.AddLogger( TLoggerConsole.Create );
end;

procedure TCoverageConfiguration.ParseLoggingTextSwitch( var aParameter: Integer );
var
  vDebugLogFileName: string;
begin
  Inc( aParameter );
  vDebugLogFileName := ParseParameter( aParameter );

  if vDebugLogFileName = '' then
  begin
    vDebugLogFileName := cDEFULT_DEBUG_LOG_FILENAME;
    Dec( aParameter );
  end;

  if Assigned( FLogManager ) and ( vDebugLogFileName <> '' ) then
    FLogManager.AddLogger( TLoggerTextFile.Create( vDebugLogFileName ) );
end;

procedure TCoverageConfiguration.ParseDprojSwitch( var aParameter: Integer );
var
  DProjPath: TFileName;
begin
  Inc( aParameter );
  DProjPath := ParseParameter( aParameter );
  ParseDProj( DProjPath );
end;

function TCoverageConfiguration.GetCurrentConfig( const Project: IXMLNode ): string;
var
  Node: IXMLNode;
  CurrentConfigNode: IXMLNode;
begin
  Assert( Assigned( Project ) );
  Result := '';
  Node := Project.ChildNodes.Get( 0 );
  if ( Node.LocalName = 'PropertyGroup' ) then
  begin
    CurrentConfigNode := Node.ChildNodes.FindNode( 'Config' );
    if CurrentConfigNode <> nil then
      Result := CurrentConfigNode.Text;
  end;
end;

function TCoverageConfiguration.GetDCCReferencesFromDProj( const ItemGroup: IXMLNode; const Rootpath: TFileName ): string;
var
  I: Integer;
  Node: IXMLNode;
  vUnitSourceFile: string;
begin
  if ItemGroup <> nil then
  begin
    FLoadingFromDProj := True;
    for I := 0 to ItemGroup.ChildNodes.Count - 1 do
    begin
      Node := ItemGroup.ChildNodes.Get( I );
      if Node.LocalName = 'DCCReference' then
      begin
        vUnitSourceFile := TPath.GetFullPath( TPath.Combine( Rootpath, Node.Attributes['Include'] ) );
        FConfigUnitList.AddUnit( TPath.GetFileNameWithoutExtension( vUnitSourceFile ), vUnitSourceFile );
      end;
    end;
  end;
end;

function TCoverageConfiguration.GetExeOutputFromDProj( const Project: IXMLNode; const ProjectName: TFileName ): string;
var
  CurrentConfig: string;
  CurrentPlatform: string;
  DCC_ExeOutputNode: IXMLNode;
  DCC_ExeOutput: string;
  GroupIndex: Integer;
  Node: IXMLNode;
begin
  Result := '';
  Assert( Assigned( Project ) );
  CurrentConfig := GetCurrentConfig( Project );

  {$IFDEF WIN64}
  CurrentPlatform := 'Win64';
  {$ELSE}
  CurrentPlatform := 'Win32';
  {$ENDIF}
  for GroupIndex := 0 to Project.ChildNodes.Count - 1 do
  begin
    Node := Project.ChildNodes.Get( GroupIndex );
    if ( Node.LocalName = 'PropertyGroup' ) and Node.HasAttribute( 'Condition' ) and
      ( ( Node.Attributes['Condition'] = '''$(Base)''!=''''' ) or ( Node.Attributes['Condition'] = '''$(Basis)''!=''''' ) ) then
    begin
      if CurrentConfig <> '' then
      begin
        DCC_ExeOutputNode := Node.ChildNodes.FindNode( 'DCC_ExeOutput' );
        if DCC_ExeOutputNode <> nil then
        begin
          DCC_ExeOutput := DCC_ExeOutputNode.Text;
          DCC_ExeOutput := StringReplace( DCC_ExeOutput, '$(Platform)', CurrentPlatform, [rfReplaceAll, rfIgnoreCase] );
          DCC_ExeOutput := StringReplace( DCC_ExeOutput, '$(Config)', CurrentConfig, [rfReplaceAll, rfIgnoreCase] );
          Result := IncludeTrailingPathDelimiter( DCC_ExeOutput ) + ChangeFileExt( ExtractFileName( ProjectName ), '.exe' );
        end
        else
          Result := ChangeFileExt( ProjectName, '.exe' );
      end;
    end;
  end;
end;

function TCoverageConfiguration.GetInternalMapFilename( const aImageBinaryFilename: string ): string;
begin
  Result := TPath.GetFileName( ChangeFileExt( aImageBinaryFilename, '.map' ) );
end;

function TCoverageConfiguration.GetMapFileName( const aImageBinaryFilename: string ): string;
begin
  Result := TPath.Combine( FSymbolRootPath, GetInternalMapFilename( aImageBinaryFilename ) );
  // Fallback to application directory itself
  if not TFile.Exists( Result ) then
    Result := ChangeFileExt( aImageBinaryFilename, '.map' );
end;

procedure TCoverageConfiguration.ParseDProj( const DProjFilename: TFileName );
var
  Document: IXMLDocument;
  ItemGroup: IXMLNode;
  Project: IXMLNode;
  Rootpath: TFileName;
  ExeFileName: TFileName;
begin
  Rootpath := ExtractFilePath( TPath.GetFullPath( DProjFilename ) );
  Document := TXMLDocument.Create( nil );
  Document.LoadFromFile( DProjFilename );
  Project := Document.ChildNodes.FindNode( 'Project' );
  if Project <> nil then
  begin
    ExeFileName := GetExeOutputFromDProj( Project, DProjFilename );
    if ExeFileName <> '' then
    begin
      if FExeFileName = '' then
        FExeFileName := TPath.GetFullPath( TPath.Combine( Rootpath, ExeFileName ) );
      if FSymbolRootPath = '' then
        FSymbolRootPath := TPath.GetDirectoryName( FExeFileName );
    end;

    ItemGroup := Project.ChildNodes.FindNode( 'ItemGroup' );
    GetDCCReferencesFromDProj( ItemGroup, Rootpath );
  end;
end;

procedure TCoverageConfiguration.ParseDProjForDccReferencesOnly( const DProjFilename: TFileName );
var
  Document: IXMLDocument;
  ItemGroup: IXMLNode;
  Project: IXMLNode;
  Rootpath: TFileName;
begin
  Rootpath := ExtractFilePath( TPath.GetFullPath( DProjFilename ) );
  Document := TXMLDocument.Create( nil );
  Document.LoadFromFile( DProjFilename );
  Project := Document.ChildNodes.FindNode( 'Project' );
  if Project <> nil then
  begin
    ItemGroup := Project.ChildNodes.FindNode( 'ItemGroup' );
    GetDCCReferencesFromDProj( ItemGroup, Rootpath );
  end;
end;

end.
