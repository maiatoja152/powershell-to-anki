param(
	[Parameter(Mandatory, ParameterSetName="SynopsisOnly")]
	[Parameter(Mandatory, ParameterSetName="OptionOnly")]
	[Parameter(Mandatory, ParameterSetName="SynopsisAndOption")]
	[String]$Command ,

	[Parameter(Mandatory, ParameterSetName="SynopsisOnly")]
	[Parameter(Mandatory, ParameterSetName="SynopsisAndOption")]
	[Switch]$Synopsis ,

	[Parameter(Mandatory, ParameterSetName="OptionOnly")]
	[Parameter(Mandatory, ParameterSetName="SynopsisAndOption")]
	[String[]]$Parameter ,

	[String]$AnkiConnectUri = "http://127.0.0.1:8765"
)

function Get-AnkiConnectRequestTable {
	param(
		[Parameter(Mandatory)]
		[String]$Action ,

		[Parameter(Mandatory)]
		[Hashtable]$Parameter
	)
	return @{
		action = $Action
		params = $Parameter
		version = 6
	}
}

function Invoke-AnkiConnect {
	param(
		[Parameter(Mandatory)]
		[String]$Action ,

		[Parameter(Mandatory)]
		[Hashtable]$Parameter
	)
	$RequestJson = ConvertTo-Json -Depth 4 (Get-AnkiConnectRequestTable $Action $Parameter)
	$Response = Invoke-RestMethod -Uri $AnkiConnectUri -Body $RequestJson

	if ($Response["error"]) {
		throw $Response["error"]
	}

	return $Response.result
}

function New-AnkiNote {
	param(
		[Parameter(Mandatory)]
		[String]$DeckName ,
		[Parameter(Mandatory)]
		[String]$Front ,
		[Parameter(Mandatory)]
		[String]$Back ,
		[Parameter(Mandatory)]
		[String]$Hint ,
		[Parameter(Mandatory)]
		[String]$Source ,
		[Parameter(Mandatory)]
		[String[]]$Tags ,
		[String]$BackExtra
	)
	return Invoke-AnkiConnect -Action "addNote" -Parameter @{
		note = @{
			deckName = $DeckName
			modelName = "Basic"
			fields = @{
				Front = $Front
				Back = $Back
				Hint = $Hint
				"Back Extra" = $BackExtra
				Source = $Source
			}
			tags = $Tags
		}
	}
}

$HelpPage = Get-Help $Command
$OnlineHelpUri = $HelpPage.RelatedLinks.navigationLink[0].uri
$NoteIds = @()

if ($Synopsis) {
	$Front = $HelpPage.Synopsis
	$Example = '<div style="margin-top: 1rem">' + $HelpPage.examples.example[0].title + '</div>' + "<div>" + $HelpPage.examples.example[0].code + "</div>"
	$Result = New-AnkiNote "Parent" $Front $Command "PowerShell command" $OnlineHelpUri @("PowerShell::Command") $Example
	$NoteIds += $Result
}

if ($Parameter.Count -gt 0) {
	$Parameter | ForEach-Object {
		$CurrentParameter = $HelpPage.parameters.parameter | Where-Object name -eq $PSItem
		$Front = $CurrentParameter.description[0].Text
		$Back = $CurrentParameter.name
		$Result = New-AnkiNote "Parent" $Front $Back "PowerShell $Command parameter" $OnlineHelpUri @("PowerShell::Command::Parameter")
		$NoteIds += $Result
	}
}

Invoke-AnkiConnect -Action "guiBrowse" -Parameter @{
	query = "nid:" + $($NoteIds -join ",")
}
