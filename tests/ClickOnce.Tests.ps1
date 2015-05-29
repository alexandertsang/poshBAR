$ErrorActionPreference = 'Stop'
$here = Split-Path $script:MyInvocation.MyCommand.Path

Describe 'ClickOnce' { 
    Context 'Sign Package'{
        # setup
        $manifestPath = 'foo'
        $pfxPath = 'C:\bar'
        $pfxPassword = 'baz'
        Mock poshBAR\Invoke-ExternalCommand {}
            
        # execute
        $execute = {Invoke-SignAppliationManifest $manifestPath $pfxPath $pfxPassword}

        # assert
        It 'Will not throw'  {
           $execute | should not throw
        }
        
        It 'Will call Invoke-ExternalCommand' {
            Assert-MockCalled poshBAR\Invoke-ExternalCommand
        }
    }
}
