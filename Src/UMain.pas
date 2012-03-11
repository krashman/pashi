{
 * This Source Code Form is subject to the terms of the Mozilla Public License,
 * v. 2.0. If a copy of the MPL was not distributed with this file, You can
 * obtain one at http://mozilla.org/MPL/2.0/
 *
 * Copyright (C) 2007-2012, Peter Johnson (www.delphidabbler.com).
 *
 * $Rev$
 * $Date$
 *
 * Implements top level class that executes program.
}


unit UMain;


interface


uses
  // Delphi
  Classes,
  // Project
  Hiliter.UGlobals, UConfig, UConsole;


type

  {
  TMain:
    Class that executes program.
  }
  TMain = class(TObject)
  private
    fConfig: TConfig;     // Program configurations object
    fConsole: TConsole;   // Object used to write to console
    fSignedOn: Boolean;   // Flag shows if sign on message has been displayed
    procedure Configure;
      {Configure program from command line.
      }
    procedure SignOn;
      {Writes sign on message to console.
      }
    procedure ShowHelp;
      {Writes help text to console.
      }
    function GetInputSourceCode: string;
      {Reads program input as a string.
        @return Required input string.
      }
    procedure WriteOutput(const S: string);
      {Writes program output.
        @param S [in] String containing output.
      }
  public
    constructor Create;
      {Class constructor. Sets up object.
      }
    destructor Destroy; override;
      {Class destructor. Tears down object.
      }
    procedure Execute;
      {Executes program.
      }
  end;


implementation


uses
  // Delphi
  SysUtils, Windows,
  // Project
  IO.UTypes, IO.Readers.UFactory, IO.Writers.UFactory, UParams, URenderers;


function GetProductVersionStr: string;
  {Gets the program's product version number from version information.
    @return Version number as a dot delimited string.
  }
var
  Dummy: DWORD;           // unused variable required in API calls
  VerInfoSize: Integer;   // size of version information data
  VerInfoBuf: Pointer;    // buffer holding version information
  ValPtr: Pointer;        // pointer to a version information value
  FFI: TVSFixedFileInfo;  // fixed file information from version info
begin
  Result := '';
  // Get fixed file info from program's version info
  // get size of version info
  VerInfoSize := GetFileVersionInfoSize(PChar(ParamStr(0)), Dummy);
  if VerInfoSize > 0 then
  begin
    // create buffer and read version info into it
    GetMem(VerInfoBuf, VerInfoSize);
    try
      if GetFileVersionInfo(
        PChar(ParamStr(0)), Dummy, VerInfoSize, VerInfoBuf
      ) then
      begin
        // get fixed file info from version info (ValPtr points to it)
        if VerQueryValue(VerInfoBuf, '\', ValPtr, Dummy) then
        begin
          FFI := PVSFixedFileInfo(ValPtr)^;
          // Build version info string from product version field of FFI
          Result := Format(
            '%d.%d.%d',
            [
              HiWord(FFI.dwProductVersionMS),
              LoWord(FFI.dwProductVersionMS),
              HiWord(FFI.dwProductVersionLS)
            ]
          );
        end
      end;
    finally
      FreeMem(VerInfoBuf);
    end;
  end;
end;


resourcestring
  // Messages written to console
  sCompleted = 'Completed';
  sError = 'Error: %s';
  sUsage = 'Usage: PasHi ([-rc] [-wc] [-frag | -hidecss] [-q] ) | -h';
  sHelp =
      '  -rc      | Takes input from clipboard instead of standard input.'#13#10
    + '  -wc      | Writes HTML output to clipboard (CF_TEXT format) instead '
    + 'of '#13#10
    + '           | standard output.'#13#10
    + '  -frag    | Writes HTML fragment rather than complete XHTML '
    + 'document'#13#10
    + '           | contains only <pre> tag containing source - user must '
    + 'provide a'#13#10
    + '           | style sheet with required names. Do not use with '
    + '-hidecss'#13#10
    + '  -hidecss | Protects embedded CSS style in HTML comments (required '
    + 'for some'#13#10
    + '           | old browsers). Do not use with -frag.'#13#10
    + '  -q       | Quiet mode - does not write to console.'#13#10
    + '  -h       | Displays help screen (quiet mode ignored).'#13#10
    + #13#10
    + 'Input is read from standard input and highlighted HTML code is written '
    + 'to'#13#10
    + 'standard output unless -rc or -wc switches are used.'#13#10
    + 'If -frag and -hidecss are used together, last one used takes '
    + 'precedence.';

{ TMain }

procedure TMain.Configure;
  {Configure program from command line.
  }
var
  Params: TParams;  // object that gets configuration from command line
begin
  Params := TParams.Create(fConfig);
  try
    Params.Parse; // parse command line, updating configuration object
  finally
    FreeAndNil(Params);
  end;
end;

constructor TMain.Create;
  {Class constructor. Sets up object.
  }
begin
  fConfig := TConfig.Create;
  fConsole := TConsole.Create;
  inherited;
end;

destructor TMain.Destroy;
  {Class destructor. Tears down object.
  }
begin
  FreeAndNil(fConsole);
  FreeAndNil(fConfig);
  inherited;
end;

procedure TMain.Execute;
  {Executes program.
  }
var
  SourceCode: string;   // input Pascal source code
  XHTML: string;        // highlighted XHTML output
  Renderer: IRenderer;  // render customised output document
begin
  ExitCode := 0;
  try
    // Configure program
    Configure;
    // Decide if program is to write to console
    fConsole.Silent := fConfig.Quiet and not fConfig.ShowHelp;
    if fConfig.ShowHelp then
      // Want help so show it
      ShowHelp
    else
    begin
      // Sign on and initialise program
      SignOn;
      SourceCode := GetInputSourceCode;
      Renderer := TRendererFactory.CreateRenderer(SourceCode, fConfig);
      XHTML := Renderer.Render;
      WriteOutput(XHTML);
      // Sign off
      fConsole.WriteLn(sCompleted);
    end;
  except
    // Report any errors
    on E: Exception do
    begin
      if not fSignedOn then
        SignOn;
      fConsole.WriteLn(Format(sError, [E.Message]));
      ExitCode := 1;
    end;
  end;
end;

function TMain.GetInputSourceCode: string;
var
  Reader: IInputReader;
begin
  case fConfig.InputSource of
    isStdIn: Reader := TInputReaderFactory.StdInReaderInstance;
    isFiles: Reader := TInputReaderFactory.FilesReaderInstance(
      fConfig.InputFiles
    );
    isClipboard: Reader := TInputReaderFactory.ClipboardReaderInstance;
  else
    Reader := nil;
  end;
  Assert(Assigned(Reader), 'TMain.GetInputSourceCode: Reader is nil');
  Result := Reader.Read;
end;

procedure TMain.ShowHelp;
  {Writes help text to console.
  }
begin
  SignOn;
  fConsole.WriteLn;
  fConsole.WriteLn(sUsage);
  fConsole.WriteLn;
  fConsole.WriteLn(sHelp);
end;

procedure TMain.SignOn;
  {Writes sign on message to console.
  }
resourcestring
  // Sign on message format string
  sSignOn = 'PasHi %s by DelphiDabbler (www.delphidabbler.com)';
var
  Msg: string;  // sign on message text
begin
  // Create and write sign on message
  Msg := Format(sSignOn, [GetProductVersionStr]);
  fConsole.WriteLn(Msg);
  // underline sign-on message with dashes
  fConsole.WriteLn(StringOfChar('-', Length(Msg)));
  // record that we've signed on
  fSignedOn := True;
end;

procedure TMain.WriteOutput(const S: string);
var
  Writer: IOutputWriter;
  Encoding: TEncoding;
begin
  case fCOnfig.OutputSink of
    osStdOut:
      Writer := TOutputWriterFactory.StdOutWriterInstance;
    osFile:
      Writer := TOutputWriterFactory.FileWriterInstance(fConfig.OutputFile);
    osClipboard:
      Writer := TOutputWriterFactory.ClipboardWriterInstance;
  else
    Writer := nil;
  end;
  Assert(Assigned(Writer), 'TMain.WriteOutput: Writer is nil');
  Encoding := fConfig.OutputEncoding;
  try
    Writer.Write(S, Encoding);
  finally
    if Assigned(Encoding) and not TEncoding.IsStandardEncoding(Encoding) then
      Encoding.Free;
  end;
end;

end.

