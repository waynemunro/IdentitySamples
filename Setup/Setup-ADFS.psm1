function Initialize-AdfsApplicationGroup ($ConfigurationValues)
{
    # Verify that we are running on a supported AD FS server.
    $IsAdfsSupported = [bool](Get-Command "Get-AdfsApplicationGroup" -CommandType Cmdlet -ErrorAction SilentlyContinue)
    if (!($IsAdfsSupported))
    {
        throw "Please execute this script on Windows Server 2016 (or higher) with AD FS installed"
    }

    # Determine the STS configuration values.
    $ApplicationGroupIdentifier = "IdentitySamples"
    $AdfsProperties = Get-AdfsProperties
    $AdfsHostName = $AdfsProperties.HostName
    $AdfsHttpsPort = $AdfsProperties.HttpsPort
    $ConfigurationValues["StsRootUrl"] = "https://${AdfsHostName}:${AdfsHttpsPort}/"
    $ConfigurationValues["StsPath"] = "adfs"
    $ConfigurationValues["StsSupportsLogOut"] = "false"
    $ConfigurationValues["CanValidateAuthority"] = "false"

    # Ensure we start from scratch.
    $ApplicationGroup = Get-AdfsApplicationGroup -ApplicationGroupIdentifier $ApplicationGroupIdentifier
    if ($ApplicationGroup)
    {
        Write-Host "Deleting Application Group ""$ApplicationGroupIdentifier"""
        Remove-AdfsApplicationGroup -TargetApplicationGroupIdentifier $ApplicationGroupIdentifier
    }

    # Create the application group containing all the applications.
    Write-Host "Creating Application Group ""$ApplicationGroupIdentifier"""
    New-AdfsApplicationGroup -Name $ApplicationGroupIdentifier -ApplicationGroupIdentifier $ApplicationGroupIdentifier

    # Register the Native application for the Web SPA app.
    $WebSpaClientDisplayName = "$ApplicationGroupIdentifier - Web SPA Client"
    Write-Host "Creating ""$WebSpaClientDisplayName"" in AD FS"
    $WebSpaClient = Add-AdfsNativeClientApplication -ApplicationGroupIdentifier $ApplicationGroupIdentifier -Name $WebSpaClientDisplayName -Identifier $(New-Guid) -RedirectUri @($ConfigurationValues["TodoListWebSpaRootUrl"]) -PassThru
    $ConfigurationValues["TodoListWebSpaClientId"] = $WebSpaClient.Identifier

    # Register the Native application for the Windows 10 app.
    $Windows10ClientDisplayName = "$ApplicationGroupIdentifier - Windows 10 Client"
    Write-Host "Creating ""$Windows10ClientDisplayName"" in AD FS"
    $Windows10Client = Add-AdfsNativeClientApplication -ApplicationGroupIdentifier $ApplicationGroupIdentifier -Name $Windows10ClientDisplayName -Identifier $(New-Guid) -RedirectUri @($ConfigurationValues["TodoListWindows10RedirectUrl"]) -PassThru
    $ConfigurationValues["TodoListWindows10ClientId"] = $Windows10Client.Identifier
    $ConfigurationValues["AccountProviderAuthority"] = "organizations"

    # Register the Native application for the Console app.
    $ConsoleClientDisplayName = "$ApplicationGroupIdentifier - Console Client"
    Write-Host "Creating ""$ConsoleClientDisplayName"" in AD FS"
    $ConsoleClient = Add-AdfsNativeClientApplication -ApplicationGroupIdentifier $ApplicationGroupIdentifier -Name $ConsoleClientDisplayName -Identifier $(New-Guid) -RedirectUri @($ConfigurationValues["TodoListConsoleRedirectUrl"]) -PassThru
    $ConfigurationValues["TodoListConsoleClientId"] = $ConsoleClient.Identifier

    # Register the Native application for the WPF app.
    $WpfClientDisplayName = "$ApplicationGroupIdentifier - WPF Client"
    Write-Host "Creating ""$WpfClientDisplayName"" in AD FS"
    $WpfClientApp = Add-AdfsNativeClientApplication -ApplicationGroupIdentifier $ApplicationGroupIdentifier -Name $WpfClientDisplayName -Identifier $(New-Guid) -RedirectUri @($ConfigurationValues["TodoListWpfRedirectUrl"]) -PassThru
    $ConfigurationValues["TodoListWpfClientId"] = $WpfClientApp.Identifier

    # Register the Server application for the Web app.
    $WebAppClientDisplayName = "$ApplicationGroupIdentifier - Web App Client"
    Write-Host "Creating ""$WebAppClientDisplayName"" in AD FS"
    $WebAppClient = Add-AdfsServerApplication -ApplicationGroupIdentifier $ApplicationGroupIdentifier -Name $WebAppClientDisplayName -Identifier $(New-Guid) -RedirectUri @($ConfigurationValues["TodoListWebAppRootUrl"]) -GenerateClientSecret -PassThru
    $ConfigurationValues["TodoListWebAppClientId"] = $WebAppClient.Identifier
    $ConfigurationValues["TodoListWebAppClientSecret"] = $WebAppClient.ClientSecret

    # Register the Server application for the Daemon app.
    $DaemonClientDisplayName = "$ApplicationGroupIdentifier - Daemon Client"
    Write-Host "Creating ""$DaemonClientDisplayName"" in AD FS"
    $DaemonClientCertificate = Get-ClientCertificate -SubjectName $ConfigurationValues["TodoListDaemonCertificateName"]
    $DaemonClient = Add-AdfsServerApplication -ApplicationGroupIdentifier $ApplicationGroupIdentifier -Name $DaemonClientDisplayName -Identifier $(New-Guid) -JWTSigningCertificate @($DaemonClientCertificate) -PassThru
    $ConfigurationValues["TodoListDaemonClientId"] = $DaemonClient.Identifier

    # Register the Web API application for the TodoList API.
    $TodoListApiDisplayName = "$ApplicationGroupIdentifier - TodoList API"
    Write-Host "Creating ""$TodoListApiDisplayName"" in AD FS"
    $TodoListApiIssuanceTransformRules = @"
        @RuleName = "Passthrough all claims"
        c:[]
        => issue(claim = c);

        @RuleName = "Send user_impersonation scope"
        => issue(Type = "scp", Value = "user_impersonation");
"@
    $TodoListApi = Add-AdfsWebApiApplication -ApplicationGroupIdentifier $ApplicationGroupIdentifier -Name $TodoListApiDisplayName -Identifier $($ConfigurationValues["TodoListWebApiResourceId"]) -AccessControlPolicyName "Permit everyone" -IssuanceTransformRules $TodoListApiIssuanceTransformRules -PassThru
    $ConfigurationValues["TodoListWebApiClientId"] = $TodoListApi.Identifier[0]

    # Register the Server application for the TodoList API acting as a confidential client towards the Taxonomy API.
    # NOTE: The Identifier (Client ID) must be exactly the same as the Identifier (Relying Party Identifier) of the Web API above.
    $TodoListApiClientDisplayName = "$ApplicationGroupIdentifier - TodoList API Client"
    Write-Host "Creating ""$TodoListApiClientDisplayName"" in AD FS"
    $TodoListApiClient = Add-AdfsServerApplication -ApplicationGroupIdentifier $ApplicationGroupIdentifier -Name $TodoListApiClientDisplayName -Identifier $ConfigurationValues["TodoListWebApiResourceId"] -GenerateClientSecret -PassThru
    $ConfigurationValues["TodoListWebApiClientSecret"] = $TodoListApiClient.ClientSecret

    # Register the Web API application for the Taxonomy API.
    $TaxonomyApiIssuanceTransformRules = @"
        @RuleName = "Passthrough all claims"
        c:[]
        => issue(claim = c);
"@
    $TaxonomyApiDisplayName = "$ApplicationGroupIdentifier - Taxonomy API"
    Write-Host "Creating ""$TaxonomyApiDisplayName"" in AD FS"
    $TaxonomyApi = Add-AdfsWebApiApplication -ApplicationGroupIdentifier $ApplicationGroupIdentifier -Name $TaxonomyApiDisplayName -Identifier $($ConfigurationValues["TaxonomyWebApiResourceId"]) -AccessControlPolicyName "Permit everyone" -IssuanceTransformRules $TaxonomyApiIssuanceTransformRules -PassThru
    $ConfigurationValues["TaxonomyWebApiClientId"] = $TaxonomyApi.Identifier[0]
    $ConfigurationValues["TaxonomyWebApiClientSecret"] = "" # Not needed in this case

    # Grant client applications access to the TodoList API.
    Write-Host "Granting client applications access to ""$TodoListApiDisplayName"""
    Grant-AdfsApplicationPermission -ServerRoleIdentifier $TodoListApi.Identifier[0] -ClientRoleIdentifier $WebSpaClient.Identifier -ScopeNames "user_impersonation"
    Grant-AdfsApplicationPermission -ServerRoleIdentifier $TodoListApi.Identifier[0] -ClientRoleIdentifier $Windows10Client.Identifier -ScopeNames "user_impersonation"
    Grant-AdfsApplicationPermission -ServerRoleIdentifier $TodoListApi.Identifier[0] -ClientRoleIdentifier $ConsoleClient.Identifier -ScopeNames "user_impersonation"
    Grant-AdfsApplicationPermission -ServerRoleIdentifier $TodoListApi.Identifier[0] -ClientRoleIdentifier $WpfClientApp.Identifier -ScopeNames "user_impersonation"
    Grant-AdfsApplicationPermission -ServerRoleIdentifier $TodoListApi.Identifier[0] -ClientRoleIdentifier $WebAppClient.Identifier -ScopeNames "user_impersonation"
    Grant-AdfsApplicationPermission -ServerRoleIdentifier $TodoListApi.Identifier[0] -ClientRoleIdentifier $DaemonClient.Identifier -ScopeNames "user_impersonation"

    # Grant client applications access to the Taxonomy API.
    Write-Host "Granting client applications access to ""$TaxonomyApiDisplayName"""
    # The "openid" scope is hard-coded into the On-Behalf-Of claim that the TodoList API receives.
    Grant-AdfsApplicationPermission -ServerRoleIdentifier $TaxonomyApi.Identifier[0] -ClientRoleIdentifier $TodoListApi.Identifier[0] -ScopeNames "openid"
}