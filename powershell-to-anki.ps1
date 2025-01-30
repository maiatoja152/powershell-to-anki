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

	[Int]$ExampleIndex = 0 ,

	[String]$AnkiConnectUri = "http://localhost:8765" ,
	[String]$Deck = "Parent::IT" ,
	[String]$HintSynopsis = "PowerShell command" ,
	[String[]]$TagsSynopsis = @("IT::PowerShell::Command") ,
	[String]$HintParameter = "PowerShell {0} parameter" ,
	[String[]]$TagsParameter = @("IT::PowerShell::Command::Parameter")
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
		[String]$Link ,
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
				Links = $Link
			}
			tags = $Tags
		}
	}
}

$Help = Get-Help $Command
$OnlineHelpUri = $Help.RelatedLinks.navigationLink[0].uri
$Link = "<a href=`"$($OnlineHelpUri)`" title=`"$($OnlineHelpUri)`">Source</a>"
$NoteIds = @()

function Format-Example {
	param(
		[Parameter(Mandatory, ValueFromPipeline)]
		[PSObject]$Example
	)
	if (-not $Example) {
		return ""
	}

	$Title = $Example.title
	$Title = $Title.Trim(@("-", " "))
	$Replace = [RegEx]::Matches($Title, "^Example \d+")
	$Title = $Title -replace $Replace, "<strong>$Replace</strong>"
	$Output = "<div class=`"powershell-example`">`n<div>$Title</div>"

	$Code = $Example.code
	$Lines = ($Code -split "\r?\n").Trim()
	$Lines | foreach {
		if ($PSItem)
		{
			$Output += "`n<div>$PSItem</div>"
		}
	}
	$Output += "`n</div>"

	return $Output
}

if ($Synopsis) {
	$Front = $Help.Synopsis
	$Back = $Help.Name
	$Example = $Help.examples.example[$ExampleIndex] | Format-Example

	$Result = New-AnkiNote $Deck $Front $Back $HintSynopsis $Link $TagsSynopsis $Example
	$NoteIds += $Result
}

if ($Parameter.Count -gt 0) {
	$HintParameter = $HintParameter -f $Help.Name
	$Parameter | ForEach-Object {
		$CurrentParameter = $Help.parameters.parameter | Where-Object name -eq $PSItem
		$Front = $CurrentParameter.description[0].Text
		$ParameterName = $CurrentParameter.name
		$Back = "<b>-$($ParameterName)</b> &lt;$($CurrentParameter.type.name)&gt;"
		$Example = $Help.examples.example | Where-Object { $PSItem.code.Contains("-$ParameterName") }
		$BackExtra = $Example | Format-Example

		$Result = New-AnkiNote $Deck $Front $Back $HintParameter $Link $TagsParameter $BackExtra
		$NoteIds += $Result
	}
}

Invoke-AnkiConnect -Action "guiBrowse" -Parameter @{
	query = "nid:" + $($NoteIds -join ",")
}
