{
 * UPasH.pas
 *
 * Class that executes and communicates with PasH.exe.
 *
 * v1.0 of 14 Jun 2006 - Original version.
 *
 *
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with the
 * License. You may obtain a copy of the License at http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
 * the specific language governing rights and limitations under the License.
 *
 * The Original Code is UPasH.pas from PasHGUI.
 *
 * The Initial Developer of the Original Code is Peter Johnson
 * (http://www.delphidabbler.com/).
 *
 * Portions created by the Initial Developer are Copyright (C) 2006 Peter
 * Johnson. All Rights Reserved.
 *
 * Contributor(s): None
 *
 * ***** END LICENSE BLOCK *****
}


unit UPasH;


interface


uses
  // Delphi
  Classes,
  // Project
  UPipe;


type

  {
  TPasH:
    Interacts with PasH.exe to do syntax highlighting.
  }
  TPasH = class(TObject)
  private
    fInPipe: TPipe;
      {Pipe to PasH's standard input}
    fOutPipe: TPipe;
      {Pipe to PasH's standard output}
    fOutStream: TStream;
      {Stream that receives PasH's standard output}
    fErrPipe: TPipe;
      {Pipe to PasH's standard error output}
    fErrStream: TStringStream;
      {Stream that receives PasH's error output}
    fErrorMessage: string;
      {Any error messages generated by PasH - taken from standard error}
    procedure HandleAppOutput(Sender: TObject);
      {Handles TConsoleApp's OnWork event and copies contents of output pipes to
      respective data streams.
        @param Sender [in] Not used.
      }
    function BuildCommandLine(const CreateFragment: Boolean): string;
      {Creates command line needed to execute PasH.exe with required switches.
        @param CreateFragment [in] Flag indicating if code fragment (true) or
          complete HTML document to be generated.
        @return Required command line.
      }
    procedure RunPasH(const CmdLine: string);
      {Executes PasH with a given command line.
        @param CmdLine [in] PasH command line.
        @except Exception raised if can't execute PasH.exe.
      }
  public
    function Hilite(const SourceStream, HilitedStream: TStream;
      const CreateFragment: Boolean): Boolean;
      {Highlights source code by executing PasH.exe with appropriate parameters.
        @param SourceStream [in] Stream containing raw source code (input to PasH).
        @param HilitedStream [in] Stream that receives highlighted source code
          (output from PasH).
        @param CreateFragment [in] Flag indicating if code fragment (true) or
          complete HTML document to be generated.
        @return True if program completed normally, false on error.
      }
    property ErrorMessage: string read fErrorMessage;
      {Any error message reported by PasH.exe}
  end;


implementation


uses
  // Delphi
  SysUtils,
  // Project
  UConsoleApp;


{ TPasH }

function TPasH.BuildCommandLine(const CreateFragment: Boolean): string;
  {Creates command line needed to execute PasH.exe with required switches.
    @param CreateFragment [in] Flag indicating if code fragment (true) or
      complete HTML document to be generated.
    @return Required command line.
  }
begin
  // ** do not localise anything in this method
  Result := 'PasH';
  if CreateFragment then
    Result := Result + ' ' + '-frag';
end;

procedure TPasH.HandleAppOutput(Sender: TObject);
  {Handles TConsoleApp's OnWork event and copies contents of output pipes to
  respective data streams.
    @param Sender [in] Not used.
  }
begin
  fOutPipe.CopyToStream(fOutStream);
  fErrPipe.CopyToStream(fErrStream);
end;

function TPasH.Hilite(const SourceStream, HilitedStream: TStream;
  const CreateFragment: Boolean): Boolean;
  {Highlights source code by executing PasH.exe with appropriate parameters.
    @param SourceStream [in] Stream containing raw source code (input to PasH).
    @param HilitedStream [in] Stream that receives highlighted source code
      (output from PasH).
    @param CreateFragment [in] Flag indicating if code fragment (true) or
      complete HTML document to be generated.
    @return True if program completed normally, false on error.
  }
begin
  fErrPipe := nil;
  fErrStream := nil;
  fOutPipe := nil;
  // Create input pipe and copy data into it
  fInPipe := TPipe.Create(SourceStream.Size);
  try
    fInPipe.CopyFromStream(SourceStream);
    fInPipe.CloseWriteHandle;
    // Create output pipes
    fOutPipe := TPipe.Create;
    fErrPipe := TPipe.Create;
    // Create / record output streams
    fErrStream := TStringStream.Create('');
    fOutStream := HilitedStream;
    // Run program and check for success
    RunPasH(BuildCommandLine(CreateFragment));
    fErrorMessage := fErrStream.DataString;
    Result := AnsiPos('Error:', fErrorMessage) = 0;
  finally
    FreeAndNil(fErrStream);
    FreeAndNil(fOutPipe);
    FreeAndNil(fErrPipe);
    FreeAndNil(fInPipe);
  end;
end;

procedure TPasH.RunPasH(const CmdLine: string);
  {Executes PasH with a given command line.
    @param CmdLine [in] PasH command line.
    @except Exception raised if can't execute PasH.exe.
  }
var
  ConsoleApp: TConsoleApp;
begin
  // Create std out pipe
  ConsoleApp := TConsoleApp.Create;
  try
    // Set up and execute PasH command line program
    ConsoleApp.OnWork := HandleAppOutput;
    ConsoleApp.StdOut := fOutPipe.WriteHandle;
    ConsoleApp.StdErr := fErrPipe.WriteHandle;
    ConsoleApp.StdIn := fInPipe.ReadHandle;
    if not ConsoleApp.Execute(CmdLine, '') then
      raise Exception.Create(
        'Error executing PasH:'#13#10 + ConsoleApp.ErrorMessage
      );
  finally
    FreeAndNil(ConsoleApp);
  end;
end;

end.
