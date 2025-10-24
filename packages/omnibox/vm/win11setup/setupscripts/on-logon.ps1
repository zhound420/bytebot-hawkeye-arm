$scriptFolder = "\\host.lan\Data"
$pythonScriptFile = "$scriptFolder\server\main.py"
$pythonServerPort = 5000

# Use full path to Python (installed in user's AppData)
$pythonPath = "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe"

# Start the flask computer use server
Write-Host "Running the server on port $pythonServerPort using $pythonPath"
& $pythonPath $pythonScriptFile --port $pythonServerPort
