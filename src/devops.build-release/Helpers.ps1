
# Invoke-DBMigration someAssembly.dll someAssembly.dll.config c:/outputFolder
Function Invoke-DBMigration ([string] $targetAssembly, [string] $startupDirectory, [string] $connectionString){
    Copy-Item "$entityFrameworkToolsDir\migrate.exe" $buildOutputDir
    exec {migrate.exe $targetAssembly /StartUpDirectory=$startupDirectory /verbose /connectionString=$connectionString /connectionProviderName="System.Data.SqlClient"}
}

Function Invoke-Nunit ( [string] $targetAssembly, [string] $outputDir, [string] $runCommand, [string] $testAssemblyRootNamespace ) {

    if ( $includeCoverage ){
        Invoke-NUnitWithCoverage $targetAssembly $outputDir $runCommand $testAssemblyRootNamespace
    } else {
        $fileName = Get-TestFileName $outputDir $runCommand

        $xmlFile = "$fileName-TestResults.xml"
        $txtFile = "$fileName-TestResults.txt"
        
        exec { nunit-console.exe $targetAssembly /fixture:$runCommand /xml=$xmlFile /out=$txtFile /nologo /framework=4.0 } "Running nunit test '$runCommand' failed."    
    }    
}

Function Invoke-NUnitWithCoverage ( [string] $targetAssembly, [string] $outputDir, [string] $runCommand, [string] $testAssemblyRootNamespace){
    $fileName = Get-TestFileName $outputDir $runCommand

    $xmlFile = "$fileName-TestResults.xml"
    $txtFile = "$fileName-TestResults.txt"
    $coverageFile = "$fileName-CoverageResults.dcvr"

    $coverageConfig = (Get-TestFileName "$buildFilesDir\coverageRules" $testAssemblyRootNamespace) + ".config"
    # /AttributeFilters="Test;TestFixture;SetUp;TearDown"
    Write-Host "dotcover.exe cover $coverageConfig /TargetExecutable=$nunitRunnerDir\nunit-console.exe /TargetArguments=$targetAssembly /fixture:$runCommand /xml=$xmlFile /out=$txtFile /nologo /framework=4.0 /Output=$coverageFile /ReportType=html /Filters=$coverageFilter"
    exec{ dotcover.exe cover $coverageConfig /TargetExecutable=$nunitRunnerDir\nunit-console.exe /TargetArguments="$targetAssembly /fixture:$runCommand /xml=$xmlFile /out=$txtFile /nologo /framework=4.0" /Output=$coverageFile /ReportType=html } "Running code coverage '$runCommand' failed."
    Write-Host "##teamcity[importData type='dotNetCoverage' tool='dotcover' path='$coverageFile']"
}

Function Invoke-SpecFlow ( [string] $testProjectFile, [string] $outputDir, [string] $runCommand ) {
    $fileName = Get-TestFileName $outputDir $runCommand

    $xmlFile = "$fileName-TestResults.xml"
    $txtFile = "$fileName-TestResults.txt"
    $htmlFile = "$fileName.html"

    Write-Host "specflow.exe nunitexecutionreport $testProjectFile /xmlTestResult:$xmlFile /testOutput:$txtFile /out:$htmlFile"

    exec { specflow.exe nunitexecutionreport $testProjectFile /xmlTestResult:$xmlFile /testOutput:$txtFile /out:$htmlFile } "Publishing specflow results failed."
}

Function Get-TestFileName ( [string] $outputDir, [string] $runCommand ){
    $fileName = $runCommand -replace "\.", "-"
    return "$outputDir\$fileName"
}

Function Get-WarningsFromMSBuildLog {
    Param(
        [parameter(Mandatory=$true)] [alias("f")] $FilePath,
        [parameter()] [alias("ro")] $rawOutputPath,
        [parameter()][alias("o")] $htmlOutputPath
    )
     
    $warnings = @(Get-Content -ErrorAction Stop $FilePath |       # Get the file content
                    Where {$_ -match '^.*warning CS.*$'} |        # Extract lines that match warnings
                    %{ $_.trim() -replace "^s*d+>",""  } |        # Strip out any project number and caret prefixes
                    sort-object | Get-Unique -asString)           # remove duplicates by sorting and filtering for unique strings
     
    $count = $warnings.Count
     
    # raw output
    Write-Host "MSBuild Warnings - $count warnings ==================================================="
    $warnings | % { Write-Host " * $_" }
     
    #TeamCity output
    Write-Host "##teamcity[buildStatus text='{build.status.text}, Build warnings: $count']"
    Write-Host "##teamcity[buildStatisticValue key='buildWarnings' value='$count']"
     
    # file output
    if( $rawOutputPath ){
        $stream = [System.IO.StreamWriter] $RawOutputPath
        $stream.WriteLine("Build Warnings")
        $stream.WriteLine("====================================")
        $stream.WriteLine("")
        $warnings | % { $stream.WriteLine(" * $_")}
        $stream.Close()
    }
     
    # html report output
    if( $htmlOutputPath -and $rawOutputPath ){
        $stream = [System.IO.StreamWriter] $htmlOutputPath
        $stream.WriteLine(@"
<html>
    <head>
        <style>*{margin:0;padding:0;box-sizing:border-box}body{margin:auto 10px}table{color:#333;font-family:sans-serif;font-size:.9em;font-weight:300;text-align:left;line-height:40px;border-spacing:0;border:1px solid #428bca;width:100%;margin:20px auto}thead tr:first-child{background:#428bca;color:#fff;border:none}th{font-weight:700}td:first-child,th:first-child{padding:0 15px 0 20px}thead tr:last-child th{border-bottom:2px solid #ddd}tbody tr:hover{background-color:#f0fbff}tbody tr:last-child td{border:none}tbody td{border-bottom:1px solid #ddd}td:last-child{text-align:left;padding-left:10px}</style>
</head>
<body>
"@)
        $stream.WriteLine("<table>")
        $stream.WriteLine(@"
<thead>
    <tr>
        <th colspan="2">Build Warnings</th>
    </tr>
    <tr>
        <th>#</th>
        <th>Message</th>
    </tr>
</thead>
<tbody>
"@)
        $warnings | % {$i=1} { $stream.WriteLine("<tr><td>$i</td><td>$_</td></tr>"); $i++ }
        $stream.WriteLine("</tbody></table>")
        $stream.WriteLine("</body></html>")
        $stream.Close()
    }
}


####################################################################

#
# Private Functions
#

# Borrowed from PSAKE. http://jameskovacs.com/2010/02/25/the-exec-problem/
function Exec([scriptblock]$cmd, [string]$errorMessage = "Error executing command: " + $cmd) { 
  & $cmd 
  if ($LastExitCode -ne 0) {
    throw $errorMessage 
  } 
}