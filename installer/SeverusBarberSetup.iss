#ifndef AppVersion
  #define AppVersion "3.0.0"
#endif

[Setup]
AppId={{D8A4F4B8-6D3A-4A2A-B068-36E8D6CB0C9F}
AppName=Severus Barber
AppVersion={#AppVersion}
AppPublisher=Severus Barber
DefaultDirName={localappdata}\SeverusBarber
DefaultGroupName=Severus Barber
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=SeverusBarber-Setup-{#AppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\barbearia_pro.exe

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na area de trabalho"; GroupDescription: "Atalhos:"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Severus Barber"; Filename: "{app}\barbearia_pro.exe"
Name: "{autodesktop}\Severus Barber"; Filename: "{app}\barbearia_pro.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\barbearia_pro.exe"; Description: "Abrir Severus Barber"; Flags: nowait postinstall skipifsilent
