$pluginPath = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\flutter_local_notifications-12.0.4\android\src\main\java\com\dexterous\flutterlocalnotifications\FlutterLocalNotificationsPlugin.java"
$patchPath = ".\android\app\src\main\java\com\dexterous\flutterlocalnotifications\FlutterLocalNotificationsPlugin.java.patch"

# Make a backup of the original file
Copy-Item -Path $pluginPath -Destination "$pluginPath.bak" -Force

# Read the plugin file content
$content = Get-Content -Path $pluginPath -Raw

# Apply the patch manually (comment out the problematic line)
$content = $content -replace 'bigPictureStyle.bigLargeIcon\(null\);', '// bigPictureStyle.bigLargeIcon(null); // Commented out to fix ambiguous method reference'

# Write the modified content back to the file
Set-Content -Path $pluginPath -Value $content

Write-Host "Successfully patched flutter_local_notifications plugin to fix the BigPictureStyle issue."
