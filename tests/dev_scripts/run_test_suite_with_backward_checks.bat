FOR /F "tokens=*" %%i in ('git rev-parse --show-toplevel') do SET GIT_ROOT=%%i
cd /d "%GIT_ROOT%"
luajit tests\Test.lua --verbose --shuffle --enable-full-backward-compact-check & pause
pause