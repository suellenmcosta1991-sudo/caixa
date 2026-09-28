#define MyAppName "Sistema Caixa de Roupas - PDV"
#define MyAppVersion "1.0.0"
#define MyAppExeName "sistema_caixa_roupas.exe"

[Setup]
AppId={{8B6CDEB7-489A-4F48-9421-60E471A1564E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Sistema Caixa de Roupas
DefaultDirName={autopf}\Sistema Caixa de Roupas
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
OutputDir=..\build\windows\installer
OutputBaseFilename=Instalador-Sistema-Caixa-de-Roupas
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar um atalho na área de trabalho"; GroupDescription: "Atalhos:"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Iniciar {#MyAppName}"; Flags: postinstall nowait skipifsilent