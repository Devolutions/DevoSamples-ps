@{
    IncludeDefaultRules = $true
    Severity            = @('Error', 'Warning', 'Information')

    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
