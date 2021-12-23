<#
.SYNOPSIS
        Removes the JNDILookup.class from log4j JAR files to mitigate Log4Shell

.DESCRIPTION

    .PARAMETER FullName
        name of the file.  Can be passed as a string parameter, as a list of filenames, or in a FileSystemObject. See Examples.

    .PARAMETER LogFile
        name of logfile for all actions, defaults to Remove-JNDILookup.txt

    .INPUTS
        FileSystemObject or string with name of file

    .OUTPUTS
        An array of PSObjects with Member:
            FullName: The name of the file processed
            Result: The actions taken or Error encountered

    .EXAMPLE
        .\Remove-JNDILookup.ps1 -Fullname bundle.jar

    .EXAMPLE
        get-content list-of-jar-files.txt | .\Remove-JNDILookup.ps1 | Format-Table

    .EXAMPLE
        Get-ChildItem *.jar | .\Remove-JNDILookup.ps1

    .NOTES
        This won't dive into a ZIP file or a WAR file to find the enclosed JAR files

    .LINK
        https://github.com/jbalcorn/Remove-JNDILookup

#>
[cmdletBinding()]
Param(
    [Parameter(
        Mandatory,
        ValueFromPipelineByPropertyName,
        ValueFromPipeline
    )]$FullName,
    $Logfile = "Remove-JNDILookup.txt"
)

Begin {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.Filesystem

    Function New-LogObj {
        <#
            .SYNOPSIS
            Creates an object that can be consumed by Write-LogLine

            .DESCRIPTION
            Creates an object that points to a logfile and contains a default message

            .PARAMETER logfile
            Specifies the name of the log file.

            .PARAMETER function
            If this parameter exists, the default message will contain it and the date.

            .INPUTS
            The name of the logfile and, if passed by name, the function parameter

            .OUTPUTS
            The object that can be consumed by Write-LogLine

            .EXAMPLE
            PS> $msg = Get-LogObj $logfile # Return obj has date in default message

            .EXAMPLE
            PS> $msg = Get-LogObj -logfile "SomeLogFile.txt" # Return obj has date in default message

            .EXAMPLE
            PS> $msg = $logfile | Get-LogObj

            .EXAMPLE
            PS> $msg = $logfile | Get-LogObj -function "MyFunction"  # return object has "MyFunction: (Get-Date)" in edfault message
        #>

        Param(
            [Parameter(
                Mandatory,
                ValueFromPipelineByPropertyName)]
            [string]$logfile,
            [Parameter(ValueFromPipelineByPropertyName)]
            [string]$function
        )

        if ($function) {
            $msg = "$($function): $(Get-Date)"
        }
        else {
            $msg = Get-Date
        }

        [PSCustomObject]@{
            logfile = $logfile
            message = $msg
        }
    }

    Function Write-LogLine {
        <#
            .SYNOPSIS
            Logs the input message, and optionally outputs to the console

            .DESCRIPTION
            Allows every message to be logged and optionally output to the console in a single line.

            .PARAMETER message
            The string to be output

            .PARAMETER logfile
            The name of the logfile

            .PARAMETER console
            switch.  if true, output the message to the console

            .INPUTS
            [string]$message
            [string]$logfile
            [switch]$console

            .OUTPUTS
            No Output on pipeline

            .EXAMPLE
            Write-LogLine -logfile "my.txt" -message "A log file line" -console    # Outputs the message to the file and to the console

            .EXAMPLE
            $msg = Get-LogObj "My.txt"
            $msg | Write-LogLine    # Outputs the current date and time to the logfile
            $msg | Write-LogLine -message "A informational message"
            $msg | Write-LogLine -console -message "A more urgent message"   # Write to logfile and console
        #>

        Param(
            [Parameter(
                Mandatory,
                ValueFromPipelineByPropertyName)]
            [string]$message,
            [Parameter(
                Mandatory,
                ValueFromPipelineByPropertyName)]
            [string]$logfile,
            [Parameter()]
            [switch]$console
        )
        # Add an extra space so if file is set as outlook message, outlook will not remove line breaks.
        "$($message) " | Out-File -Append $logfile
        if ($console.IsPresent) {
            Write-Host $message
        }
    }

    $log = New-LogObj -logfile $logfile -Function $MyInvocation.MyCommand.Name
    $log | Write-LogLine
    $Output = [System.Collections.Generic.List[System.Object]]::new()
}

Process {

    try {
        $fn = Resolve-Path("$FullName") -ErrorAction Stop
    }
    catch {
        Write-Host "Cannot find $($Fullname)"
        $Output.Add([PSCustomObject]@{
            FullName = $fn.Path
            Result   = "Could not resolve path: $($Error[0])"
        })
    }

    try {
        $zip = [System.io.Compression.ZipFile]::Open("$fn", "Read")
    }
    catch {
        Write-Host "Cannot open $($Fullname) as a Zip File. $($Error[0])"
        $Output.Add([PSCustomObject]@{
            FullName = $fn.Path
            Result   = "Could not open as a ZIP file: $($Error[0])"
        })
    }

    $file = $zip.Entries | Where-Object { $_.name -eq "JNDILookup.class" }

    if ($null -ne $file) {
        $title = "Found JNDILookup.class in $($fn). I can back up the file and remove the class."
        $question = 'Are you sure you want to proceed?'
        $choices = '&Yes', '&No'

        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)

        if ($decision -eq 0) {
            Write-Host "Backing up $($fn) to $($fn).bak"
            # Close Zip so it can be copied
            $zip.Dispose()
            Copy-Item "$fn" "$($fn).bak"
            # Re-Open Zip File in Update mode
            $zip = [System.io.Compression.ZipFile]::Open($fn, "Update")
            $files = $zip.Entries.Where( { $_.name -eq "JNDILookup.class" } )
            $log | Write-LogLine -message "$($fn): Backing up as $($fn).bak"

            foreach ($file in $files) {
                $log | Write-LogLine  -console -message "$($fn):     Removing $($File.Fullname)"
                $file.Delete()
                $Output.add([PSCustomObject]@{
                    FullName = $fn.Path
                    Result   = "$($File.Fullname) Removed"
                })
            }
        }
        else {
            Write-Host 'cancelled'
            $Output.Add([PSCustomObject]@{
                FullName = $fn.Path
                Result   = "Did not process - `No` Chosen"
            })
        }

    }
    else {
        $log | Write-LogLine -message "$($fn): JNDILookup.class Not Found"
        $Output.Add([PSCustomObject]@{
            FullName = $fn.Path
            Result   = "JNDILookup.class not found in file"
        })
    }
    $zip.Dispose()
}

End {
    Write-Host "End"
    $Output
}
