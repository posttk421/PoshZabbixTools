function Connect-ZabbixServer {
	<#
	.SYNOPSIS
		Sends a login request to a Zabbix server API service.
	.DESCRIPTION
		The Connect-ZabbixServer cmdlet retreives the Api authentication key for the session using the credentials provided.
	.PARAMETER Server
		Specifies the name of the Zabbix server to utilize in contrusting the connection URI.  If not using the default Zabbix configuration, please specify the full URI using the -Uri paramter.
	.PARAMETER Secure
		Specifies using HTTPS when the -Server parameter is specified.
	.PARAMETER Uri
		Specifies the Uniform Resource Identifier (URI) of the Internet resource to which the web request is sent. This parameter supports HTTP and HTTPS values.
	.PARAMETER Credential
		Specifies a user account that has permission to send the request. The default is the current user.

		Type a user name, such as "User01" or "Domain\User01", or enter a PSCredential object, such as one generated by the Get-Credential cmdlet.
	.EXAMPLE
		Connect-ZabbixServer -Server 'myserver' -Credential 'myuser'
		Connect to the Zabbix server 'myserver' with the username 'myuser'.  The connection URI will be 'http://myserver/zabbix/api_jsonrpc.php'.
	.EXAMPLE
		Connect-ZabbixServer -Uri 'http://myserver/zabbix/api_jsonrpc.php' -Credential 'Username'
	.EXAMPLE
		Connect-ZabbixServer -Uri 'http://myserver/zabbix/api_jsonrpc.php' -Credential (Get-Credential)
	.OUTPUTS
		This function provides no outputs.
    .NOTES
        Author: Trent Willingham
        Check out my other scripts and projects @ https://github.com/twillin912
    .LINK
        https://github.com/twillin912/PoshZabbixTools
	#>
	[CmdletBinding()]

	Param (
		[Parameter(Mandatory=$True,
			ParameterSetName='Uri')]
		[string] $Uri,

		[Parameter(Mandatory=$True,
			ParameterSetName='Server')]
		[string] $Server,

		[Parameter(ParameterSetName='Server')]
		[switch] $Secure,

		[Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
		$Credential
	)

	if ( $Global:ZabbixSession ) {
		Write-Warning -Message "$($MyInvocation.MyCommand.Name): Zabbix session information already exists. Disconnect any previous session before starting a new session."
		break
	}

	if ( $Server -and $Secure ) {
		$Uri = "https://$Server/zabbix/api_jsonrpc.php"
	} elseif ( $Server ) {
		$Uri = "http://$Server/zabbix/api_jsonrpc.php"
	}

	$ZabbixUser = $Credential.UserName
	$ZabbixPassword = $Credential.GetNetworkCredential().Password

	#Contruct request parameters
	$Params = @{}
	$Params.Add('user', $ZabbixUser)
	$Params.Add('password', $ZabbixPassword)

	$JsonRequest = ZabbixJsonObject -RequestType 'user.login' -Parameters $Params

	try {
		Write-Verbose -Message "Submitting login request to $Uri"
		$JsonResponse = Invoke-RestMethod -Uri $Uri -Method Put -Body $JsonRequest -ContentType 'application/json' -ErrorAction Stop
	}
	catch {
		Write-Error "StatusCode: $($_.Exception.Response.StatusCode.value__)"
		Write-Error "StatusDescription: $($_.Exception.Response.StatusDescription)"
		break
	}

	if (!$JsonResponse.Result) {
		Write-Warning -Message "$($MyInvocation.MyCommand.Name): Unable to connect to Zabbix, aborting"
		break
	}

	Write-Verbose "$($MyInvocation.MyCommand.Name): Connection to Zabbix is successfull"
	$Global:ZabbixSession = New-Object -Type PSObject
	$ZabbixSession | Add-Member -MemberType NoteProperty -Name "Uri" -Value $Uri
	$ZabbixSession | Add-Member -MemberType NoteProperty -Name "AuthId" -Value $JsonResponse.Result
}