@rem ---------------------------------------------------------------------------
@rem Script used to build PasHGUI's Pascal files
@rem
@rem Copyright (C) Peter Johnson (www.delphidabbler.com), 2006
@rem
@rem v1.0 of 17 Jun 2006 - First version.
@rem ---------------------------------------------------------------------------

@echo off
echo BUILDING PASCAL PROJECT
cd ..\Src
call Build.bat pas
cd ..\DevTools
