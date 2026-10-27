# Prepare a disposable project with the browser driver as an autoload.
# Production exports do not contain this driver or any test hooks.
$ErrorActionPreference = 'Stop'
$workspacePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$testProjectPath = Join-Path $workspacePath '.godot/web-test-project'
New-Item -ItemType Directory -Path $testProjectPath -Force | Out-Null
foreach ($folder in @('assets','scripts','scenes','shaders')) {
    Copy-Item -LiteralPath (Join-Path $workspacePath $folder) -Destination $testProjectPath -Recurse -Force
}
foreach ($file in @('icon.svg','export_presets.cfg','version.json')) {
    Copy-Item -LiteralPath (Join-Path $workspacePath $file) -Destination $testProjectPath -Force
}
$settings = [IO.File]::ReadAllText((Join-Path $workspacePath 'project.godot'))
$settings = $settings.Replace('[autoload]', "[autoload]`nWebSmoke=`"*res://web_probe.gd`"")
[IO.File]::WriteAllText((Join-Path $testProjectPath 'project.godot'), $settings, [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $workspacePath 'tools/test_web.gd') -Destination (Join-Path $testProjectPath 'web_probe.gd') -Force
$env:APPDATA = Join-Path $workspacePath '.godot/web-build-user'
$enginePath = Join-Path $workspacePath 'Godot_v4.7.2-stable_win64.exe'
$importArgs = @('--headless','--editor','--path',('"'+$testProjectPath+'"'),'--quit','--log-file',('"'+(Join-Path $workspacePath '.godot/web-smoke-import.log')+'"'))
$importProcess = Start-Process -FilePath $enginePath -ArgumentList $importArgs -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $workspacePath '.godot/web-smoke-import-output.log') -RedirectStandardError (Join-Path $workspacePath '.godot/web-smoke-import-error.log')
if ($importProcess.ExitCode -ne 0) { throw 'Godot test-project import failed; see .godot/web-smoke-import.log' }
$exportArgs = @('--headless','--path',('"'+$testProjectPath+'"'),'--export-release','Web',('"'+(Join-Path $workspacePath '.godot/web-export/smoke.html')+'"'),'--log-file',('"'+(Join-Path $workspacePath '.godot/web-smoke-export.log')+'"'))
$exportProcess = Start-Process -FilePath $enginePath -ArgumentList $exportArgs -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $workspacePath '.godot/web-smoke-export-output.log') -RedirectStandardError (Join-Path $workspacePath '.godot/web-smoke-export-error.log')
exit $exportProcess.ExitCode
