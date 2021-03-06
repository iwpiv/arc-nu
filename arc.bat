@echo off

rem  Blatantly stolen and modified from https://gist.github.com/rocketnia/576688

rem  Lines beginning with "rem", like this one, are comments.

rem  The "@echo off" line above stops the following commands,
rem  including these comments, from being displayed to the terminal
rem  window. For a more transparent view of what this batch file is
rem  doing, you can take out that line.

rem  The @ at the beginning of "@echo off" causes that command to be
rem  invisible too.

rem  Now we'll keep track of ".", which is the current working
rem  directory, and return to that directory later on using "popd".
rem  This is mostly useful if we're running this batch file as part of
rem  a longer terminal session, so that when we exit Arc and return to
rem  the command prompt we're in the same directory we left.
pushd .

rem  Time to actually execute Arc
rem  http://stackoverflow.com/questions/3827567/how-to-get-the-path-of-the-batch-script-in-windows

rem  This is so it will work on both 64-bit and 32-bit systems
rem  http://stackoverflow.com/a/15060386/449477
rem  SET ProgFiles86Root="%ProgramFiles(x86)%"
rem  IF NOT "%ProgFiles86Root%"=="" GOTO amd64
rem  SET ProgFiles86Root="%ProgramFiles%"
rem  :amd64
rem  "%ProgFiles86Root%\Racket\Racket.exe" "%~dp0arc"
echo "%ProgramFiles(x86)%\Racket\Racket.exe"
rem   echo "%ProgFiles86Root%\Racket\Racket.exe"
"%ProgramFiles(x86)%\Racket\Racket.exe" "%~dp0arc"

rem  The "pause" command displays a "press any key" message. If Racket
rem  exits with an error, this command keeps the batch script running
rem  long enough for you to read the error message. (Double-clicking a
rem  batch file opens a window that closes once the script is
rem  complete.)
pause

rem  Finally, as planned, we restore the working directory we started
rem  with.
popd