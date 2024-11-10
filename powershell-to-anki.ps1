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

	[String]$AnkiConnectUri = "http://localhost:8765" ,
	[String]$Deck = "Parent" ,
	[String]$HintSynopsis = "PowerShell command" ,
	[String[]]$TagsSynopsis = @("PowerShell::Command") ,
	[String]$HintParameter = "PowerShell {command} parameter" ,
	[String[]]$TagsParameter = @("PowerShell::Command::Parameter")
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
		[String]$Deck ,
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
			deckName = $Deck
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

function Get-ExampleFormatted {
	param(
		[Parameter(Mandatory)]
		[PSObject]$Help ,
		[Parameter(Mandatory)]
		[Int]$Index
	)
	$Example = $Help.examples.example[$Index]
	$Output = "<div style=`"margin-top: 1rem;`">$($Example.title)</div>"
	$Code = $Example.code
	# Wrap each line of example code in a div
	($Code -split "\r?\n").Trim() | ForEach-Object {
		$Output += "`n<div>$PSItem</div>"
	}

	return $Output
}

function Get-ParameterExample {
	param(
		[Parameter(Mandatory)]
		[PSObject]$Help ,
		[Parameter(Mandatory)]
		[String]$ParameterName
	)
	$Index = 0
	foreach ($PSItem in $Help.examples.example) {
		if ($PSItem.code.Contains("-$ParameterName")) {
			return Get-ExampleFormatted $Help $Index
		}
		$Index += 1
	}
	return ""
}

if ($Synopsis) {
	$Front = $Help.Synopsis
	$Back = $Help.Name
	$Example = Get-ExampleFormatted $Help 0

	$Result = New-AnkiNote $Deck $Front $Back $HintSynopsis $OnlineHelpUri $TagsSynopsis $Example
	$NoteIds += $Result
}

if ($Parameter.Count -gt 0) {
	$Parameter | ForEach-Object {
		$CurrentParameter = $Help.parameters.parameter | Where-Object name -eq $PSItem
		$Front = $CurrentParameter.description[0].Text
		$Back = "<b>-$($CurrentParameter.name)</b> &lt;$($CurrentParameter.type.name)&gt;"
		$Example = Get-ParameterExample $Help $CurrentParameter.name

		$Result = New-AnkiNote $Deck $Front $Back $HintParameter $OnlineHelpUri $TagsParameter $Example
		$NoteIds += $Result
	}
}

Invoke-AnkiConnect -Action "guiBrowse" -Parameter @{
	query = "nid:" + $($NoteIds -join ",")
}
