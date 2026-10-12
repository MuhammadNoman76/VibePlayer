; VibePlayer installer (Inno Setup 6)
; Built by build.ps1, which publishes each edition to ..\publish\<edition> and generates associations.iss.
;   /DEdition=x64     Windows 10/11, 64-bit Intel/AMD (also runs on ARM64 via emulation)
;   /DEdition=arm64   Windows 10/11 on ARM (Snapdragon, Surface Pro X...)
;   /DEdition=x86     Windows 10/11, 32-bit
;   /DEdition=legacy  Windows 7 SP1 / 8.1 (32- or 64-bit), needs .NET Framework 4.8

#define AppName "VibePlayer"
#ifndef AppVersion
  #define AppVersion "1.0.1"
#endif
#ifndef Edition
  #define Edition "x64"
#endif
#define AppExe "VibePlayer.exe"
#define ProgId "VibePlayer.Media"
#define PublishDir "..\publish\" + Edition

[Setup]
; Same AppId for every edition: installing another edition simply replaces the current one.
AppId={{6E1C2B7A-4D8F-4B3A-9C55-0F7B2E9D1A42}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppName}
AppComments=A VLC-powered media player with a YouTube-style interface
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=..\dist
#if Edition == "legacy"
OutputBaseFilename=VibePlayer-Setup-{#AppVersion}-win7-8
#else
OutputBaseFilename=VibePlayer-Setup-{#AppVersion}-{#Edition}
#endif
SetupIconFile=..\src\VibePlayer\Assets\VibePlayer.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
WizardStyle=modern
Compression=lzma2/ultra64
SolidCompression=yes
LZMANumBlockThreads=4
#if Edition == "x64"
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
#elif Edition == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
MinVersion=10.0
#elif Edition == "x86"
MinVersion=10.0
#else
; 32- or 64-bit Intel/AMD Windows (ARM PCs use the arm64 edition: .NET Framework 4.8.1 runs this app
; natively as ARM64 there, which can't load the x64 VLC engine). 64-bit Windows gets the 64-bit engine.
ArchitecturesAllowed=x86os or x64os
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=6.1sp1
#endif
; "Install for all users" (Program Files, like VLC) by default; "only for me" needs no admin rights.
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog commandline
ChangesAssociations=yes
CloseApplications=yes
RestartApplications=no
; Keep exact file times: VLC's plugin cache (plugins.dat) is only valid if plugin timestamps are unchanged.
TimeStampRounding=0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "fileassoc"; Description: "Add {#AppName} to ""Open with"" for video and audio files"; GroupDescription: "Windows integration:"
Name: "foldermenu"; Description: "Add ""Play with {#AppName}"" to the folder right-click menu"; GroupDescription: "Windows integration:"

[InstallDelete]
; Switching editions: remove the VLC engine the previous edition used and this one doesn't.
#if Edition == "x64"
Type: filesandordirs; Name: "{app}\libvlc\win-x86"
Type: filesandordirs; Name: "{app}\libvlc\win-arm64"
#elif Edition == "arm64"
Type: filesandordirs; Name: "{app}\libvlc\win-x64"
Type: filesandordirs; Name: "{app}\libvlc\win-x86"
#elif Edition == "x86"
Type: filesandordirs; Name: "{app}\libvlc\win-x64"
Type: filesandordirs; Name: "{app}\libvlc\win-arm64"
#else
Type: filesandordirs; Name: "{app}\libvlc\win-x64"; Check: not Is64BitInstallMode
Type: filesandordirs; Name: "{app}\libvlc\win-x86"; Check: Is64BitInstallMode
Type: filesandordirs; Name: "{app}\libvlc\win-arm64"
#endif

[Files]
#if Edition == "legacy"
; The package carries both VLC engines; only the one that matches Windows (64- or 32-bit) is installed.
Source: "{#PublishDir}\*"; DestDir: "{app}"; Excludes: "\libvlc"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PublishDir}\libvlc\win-x64\*"; DestDir: "{app}\libvlc\win-x64"; Check: Is64BitInstallMode; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PublishDir}\libvlc\win-x86\*"; DestDir: "{app}\libvlc\win-x86"; Check: not Is64BitInstallMode; Flags: ignoreversion recursesubdirs createallsubdirs
#else
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
#endif

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
; ---- ProgID used by every associated extension
Root: HKA; Subkey: "Software\Classes\{#ProgId}"; ValueType: string; ValueName: ""; ValueData: "Media file ({#AppName})"; Flags: uninsdeletekey; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#ProgId}"; ValueType: string; ValueName: "FriendlyTypeName"; ValueData: "Media file ({#AppName})"; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#ProgId}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"",0"; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#ProgId}\shell"; ValueType: string; ValueName: ""; ValueData: "open"; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#ProgId}\shell\open"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#AppName}"; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#ProgId}\shell\open"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#ProgId}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"" ""%1"""; Tasks: fileassoc

; ---- Application registration (shows up nicely in "Open with" / "Choose another app")
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#AppName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"",0"
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\shell\open"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"" ""%1"""

; ---- Default Apps (Settings > Apps > Default apps > VibePlayer)
Root: HKA; Subkey: "Software\{#AppName}"; Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "Software\{#AppName}\Capabilities"; ValueType: string; ValueName: "ApplicationName"; ValueData: "{#AppName}"; Flags: uninsdeletekey; Tasks: fileassoc
Root: HKA; Subkey: "Software\{#AppName}\Capabilities"; ValueType: string; ValueName: "ApplicationDescription"; ValueData: "Plays almost any video or audio file, powered by the VLC engine."; Tasks: fileassoc
Root: HKA; Subkey: "Software\{#AppName}\Capabilities"; ValueType: string; ValueName: "ApplicationIcon"; ValueData: """{app}\{#AppExe}"",0"; Tasks: fileassoc
Root: HKA; Subkey: "Software\RegisteredApplications"; ValueType: string; ValueName: "{#AppName}"; ValueData: "Software\{#AppName}\Capabilities"; Flags: uninsdeletevalue; Tasks: fileassoc

; ---- "Play with VibePlayer" on folders
Root: HKA; Subkey: "Software\Classes\Directory\shell\{#AppName}.Play"; ValueType: string; ValueName: ""; ValueData: "Play with {#AppName}"; Flags: uninsdeletekey; Tasks: foldermenu
Root: HKA; Subkey: "Software\Classes\Directory\shell\{#AppName}.Play"; ValueType: string; ValueName: "Icon"; ValueData: """{app}\{#AppExe}"",0"; Tasks: foldermenu
Root: HKA; Subkey: "Software\Classes\Directory\shell\{#AppName}.Play\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"" ""%1"""; Tasks: foldermenu

; ---- Per-extension entries (generated)
#include "associations.iss"

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; VLC's plugin cache (shipped for x64/x86; the app may create it itself on first run)
Type: files; Name: "{app}\libvlc\win-x64\plugins\plugins.dat"
Type: files; Name: "{app}\libvlc\win-x86\plugins\plugins.dat"
Type: files; Name: "{app}\libvlc\win-arm64\plugins\plugins.dat"

#if Edition == "legacy"
[Code]
function HasDotNet48(): Boolean;
var
  Release: Cardinal;
begin
  Result := RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Release', Release) and (Release >= 528040);
end;

function InitializeSetup(): Boolean;
var
  ErrorCode: Integer;
begin
  Result := True;
  if not HasDotNet48() then
  begin
    if SuppressibleMsgBox('VibePlayer for Windows 7 / 8.1 needs Microsoft .NET Framework 4.8, which is not installed on this PC.' + #13#10#13#10 +
              'Open Microsoft''s download page now? Install it, restart if asked, then run this setup again.',
              mbConfirmation, MB_YESNO, IDNO) = IDYES then
      ShellExec('open', 'https://dotnet.microsoft.com/download/dotnet-framework/net48', '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode);
    Result := False;
  end;
end;
#endif
