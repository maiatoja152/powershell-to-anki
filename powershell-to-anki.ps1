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

	[String]$AnkiConnectUri = "http://localhost:8765"
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
	$Response = Invoke-RestMethod -Uri $AnkiConnectUri -Method Post -Body $RequestJson

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

$Help = Get-Help $Command
$OnlineHelpUri = $Help.RelatedLinks.navigationLink[0].uri
$NoteIds = @()

if ($Synopsis) {
	$Front = $Help.Synopsis
	$Back = $Help.Name
	$Example = "<div style=`"margin-top: 1rem;`">$($Help.examples.example[0].title)</div>`n<div>$($Help.examples.example[0].code)</div>"
	$Result = New-AnkiNote "Parent" $Front $Back "PowerShell command" $OnlineHelpUri @("PowerShell::Command") $Example
	$NoteIds += $Result
}

if ($Parameter.Count -gt 0) {
	$Parameter | ForEach-Object {
		$CurrentParameter = $Help.parameters.parameter | Where-Object name -eq $PSItem
		$Front = $CurrentParameter.description[0].Text
		$Back = "<b>-$($CurrentParameter.name)</b> &lt;$($CurrentParameter.type.name)&gt;"
		$Result = New-AnkiNote "Parent" $Front $Back "PowerShell $Command parameter" $OnlineHelpUri @("PowerShell::Command::Parameter")
		$NoteIds += $Result
	}
}

Invoke-AnkiConnect -Action "guiBrowse" -Parameter @{
	query = "nid:" + $($NoteIds -join ",")
}
