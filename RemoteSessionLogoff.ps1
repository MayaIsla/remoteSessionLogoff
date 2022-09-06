
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

$memory = gwmi -Class win32_operatingsystem -computername localhost | 
Select-Object @{Name = "MemoryUsage"; Expression = {“{0:N0}” -f 
((($_.TotalVisibleMemorySize - $_.FreePhysicalMemory)*100)/ 
$_.TotalVisibleMemorySize)}} 

$memoryUsage = [int]$memory.MemoryUsage


if ($memoryUsage -gt 70){
    function New-RdpSessionTable() {
    $RDPSessionTable = New-Object System.Data.DataTable("RDPSessions")
    "COMPUTERNAME", "USERNAME", "ID", "STATE" | ForEach-Object {
        $Col = New-Object System.Data.DataColumn $_ 
        $RDPSessionTable.Columns.Add($Col)
    }
    return , $RDPSessionTable
}

function Get-RemoteRdpSession {
 
    
    [CmdletBinding()]
 
    [OutputType([int])]
    Param
    (        
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string[]]
        $computername,

        [Parameter(Mandatory = $false, Position = 1 )]
        [ValidateSet("Active", "Disc")]
        [string]
        $state       
    )
    Begin {
        $tab = New-RdpSessionTable
        $counter = 1
        $total = $computername.Length
    }
    Process {
        foreach ($hostname in $computername) {   
            Write-Progress -Activity "Get-RemoteRdpSession" -Status "Querying RDP Session on $hostname" -PercentComplete (($counter / $total) * 100) 
            if (Test-Connection -ComputerName $hostname -Quiet -Count 1){
                $result = query session /server:$hostname
                $rows = $result -split "`n"            
                foreach ($row in $rows) {                
                    if ($state) {
                        $regex = $state
                    }
                    else {
                        $regex = "Disc|Active"
                    }
                    
                    if ($row -NotMatch "services|console" -and $row -match $regex) {
                        $session = $($row -Replace ' {2,}', ',').split(',')            
                        $newRow = $tab.NewRow()
                        $newRow["COMPUTERNAME"] = $hostname
                        $newRow["USERNAME"] = $session[1]
                        $newRow["ID"] = $session[2]
                        $newRow["STATE"] = $session[3]
                        $tab.Rows.Add($newRow)
                    }
                }
            }
            $counter += 1
        }
    }
    End {
        return $tab
    }
}


$RDPDiscSessions = Get-RemoteRdpSession  -computername ("localhost") -state DISC    
           
foreach ($row in $RDPDiscSessions){
    Write-Progress -Activity "Logging Off all RDP Disc Sessions" -Status "Logging OFF $($row.Item("USERNAME")) from $($row.Item("COMPUTERNAME"))" 
    logoff $($row.Item("ID")) /server:$( $row.Item("COMPUTERNAME"))
}
}


