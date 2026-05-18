@{
    Run        = @{
        Path = @('tools/tests', 'src')
    }
    Output     = @{
        Verbosity = 'Detailed'
    }
    CodeCoverage = @{
        Enabled = $false
    }
    TestResult = @{
        Enabled = $false
    }
}
