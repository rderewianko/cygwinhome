# --------------------------------------------------------------------------------------
# Title: CIS-CAT Powershell Cmdlets
# Description: The functions contained in this script are utilized by a number of probes
#              contained within the CIS-CAT software.
#
# Author            Modification Date          Description of Modification(s)
# --------------------------------------------------------------------------------------
# Bill Munyan       April 17, 2013             Original Author
# --------------------------------------------------------------------------------------


#
#    Function: Wua-UpdateSearcher
# Description: Utilizing the passed in search parameter, probe the system for
#              matching Windows Update IDs
#
function Wua-UpdateSearcher {
	# Function Parameters.
	# According to the OVAL specification for WuaUpdateSearcherBehaviors, 
	#  'include_superseded_updates' is a boolean flag that when set to true 
	#  indicates that the search results should include updates that are superseded 
	#  by other updates in the search results. When set to 'false' superseded updates 
	#  should be excluded from the set of matching update items. 
	#  *** The default value is 'true'. ***
	Param (
		[string]$search_criteria, 
		[boolean]$include_superceded_updates = $true 
	)
	
	# create the windows update searcher from the update session...
	$wus = New-Object -ComObject Microsoft.Update.Searcher
	
	# execute the search query...
	$results  = $wus.Search($search_criteria)
	
	# check the return code for errors...
	if ($results.ResultCode -eq 2) {
		# create the output...
		if ($results.Updates.Count -gt 0) {
			$item_open_element  = "<wuaupdatesearcher_item status='exists'>"
			$criteria_element   = "<search_criteria datatype='string'>" + $search_criteria + "</search_criteria>"
			$item_close_element = "</wuaupdatesearcher_item>"

			Write-Output $item_open_element
			Write-Output $criteria_element

			# The "$results.Updates" represents the list of "Item"'s in the IUpdateCollection
			# returned from the Search method...
			foreach ($windows_update in $results.Updates) {
				# the Identity Gets an interface that contains the unique identifier of the update...
				$curr_update = "<update_id datatype='string'>" + $windows_update.Identity.UpdateId + "</update_id>"
				Write-Output $curr_update

				# output any superceded id's, if requested
				if (($include_superceded_updates) -and ($windows_update.SupercededUpdateIDs.Count -gt 0)) {
					# The "SupercededUpdateIDs" property of an IUpdate instance gets a 
					#  collection of update identifiers. This collection of identifiers 
					#  specifies the updates that are superseded by the update...
					foreach ($superceded_id in $windows_update.SupercededUpdateIDs) {
						$parent_update = "<update_id datatype='string'>" + $superceded_id + "</update_id>"
						Write-Output $parent_update
					}
				}
			}
			Write-Output $item_close_element
		} else {
			$item_open_element  = "<wuaupdatesearcher_item status='does not exist'>"
			$criteria_element   = "<search_criteria datatype='string'>" + $search_criteria + "</search_criteria>"
			$item_close_element = "</wuaupdatesearcher_item>"

			Write-Output $item_open_element
			Write-Output $criteria_element
			Write-Output $item_close_element
		}
	} else {
		$item_open_element  = "<wuaupdatesearcher_item status='error'>"
		$criteria_element   = "<search_criteria datatype='string'>" + $search_criteria + "</search_criteria>"
		$message_element    = "<message>Update Searcher did not return successfully</message>"
		$item_close_element = "</wuaupdatesearcher_item>"

		Write-Output $item_open_element
		Write-Output $criteria_element
		Write-Output $message_element
		Write-Output $item_close_element
	}
}

#
#    Function: Ciscat-GetPSModules
# Description: Retrieve the loaded PowerShell Module(s)
#
function Ciscat-GetPSModules {
	# Function Parameters -- None
	
	# Get Snap-ins loaded by default.  these are noted as modules which 
	#  start with "Microsoft.PowerShell.", such as:
	#	- Microsoft.PowerShell.Diagnostics
	#	- Microsoft.PowerShell.Core
	#	- Microsoft.PowerShell.Utility
	#	- Microsoft.PowerShell.Host
	#	- Microsoft.PowerShell.Management
	#	- Microsoft.PowerShell.Security, as well as
	#	- Microsoft.WSMan.Management
	$imported_snapins   = Get-PSSnapin
	
	#
	# <modules>
	#   <module name="[$name]" guid="[$guid./<none>]" version="[$vers]" loaded="[$loaded]"/>
	#   ...
	# </modules>
	#
	$modules_start = "<modules>"
	$modules_end   = "</modules>"
	
	Write-Output $modules_start
	
	#
	# Imported Snap-Ins
	#
	foreach ($imported_snapin in $imported_snapins) {
		$name   = $imported_snapin.Name
		$guid   = "[none]"
		$vers   = [string]::Concat($imported_snapin.Version.Major, ".", $imported_snapin.Version.Minor)
		$loaded = "true"
		$module =  "<module name=`"" + $name + "`" guid=`"" + $guid + "`" version=`"" + $vers + "`" loaded=`"" + $loaded + "`"/>"
		
		Write-Output $module
	}
	
	#
	# get modules that have been imported into the current session.
	#
	$imported_modules = Get-Module
	
	# get all available modules...
	$installed_modules = Get-Module -ListAvailable
	
	foreach ($installed_module in $installed_modules) {
		$name = $installed_module.Name
		$guid = $installed_module.Guid
		$vers = [string]::Concat($installed_module.Version.Major, ".", $installed_module.Version.Minor)
	
		$loaded = "false"
		foreach ($imported_module in $imported_modules) {
			if ($imported_module.Name -eq $installed_module.Name) {
				$loaded = "true"
			}
		}
		
		$module = "<module name=`"" + $name + "`" guid=`"" + $guid + "`" version=`"" + $vers + "`" loaded=`"" + $loaded + "`"/>"
				
		Write-Output $module
	}
	Write-Output $modules_end
}

#
#    Function: Ciscat-InvokeCmdlet
# Description: Invoke
#       Usage: Ciscat-InvokeCmdlet "Get-service -name lanman* | Select-Object displayname"
#
function Ciscat-InvokeCmdlet {
	# Function Parameters.
	Param (
		[string]$cmdlet_string = $(throw "Mandatory parameter -cmdlet_string"), 
		[string]$import_string = ""
	)

	if ($import_string -ne "") {
		$import_command = [string]::Concat($import_string, " -ErrorAction Stop")
		try {
			Invoke-Expression $import_command
		} catch [Exception] {
			$msg    = "Error importing module specified by '" + $import_string + "'"
			$out    = ConvertFrom-StringData -StringData $msg
			$xml    = $out | ConvertTo-XML -As String -NoTypeInformation
			$result = $xml -replace '<Object>([^<]+)</Object>', '<Object><Property Name="result">$1</Property></Object>' -replace '<([/]?)Objects>', '<$1RecordSet>' -replace '<([/]?)Object>', '<$1Record>' -replace '<([/]?)Property', '<$1Field'
			return $result
		}
	}
	
	# Output should be in the form of:
	# <Objects>
	#     <Object>
	#     ...
	#     </Object>
	# </Objects>
	
	$command = [string]::Concat($cmdlet_string, " -ErrorAction Stop")
	try {
		$out = Invoke-Expression $command
	} catch [Exception] {
		$msg = "Error=Error invoking cmdlet '" + $cmdlet_string + "'"
		$out = ConvertFrom-StringData -StringData $msg
	}
	$xml    = $out | ConvertTo-XML -As String -NoTypeInformation
	$result = $xml -replace '<Object>([^<]+)</Object>', '<Object><Property Name="result">$1</Property></Object>' -replace '<([/]?)Objects>', '<$1RecordSet>' -replace '<([/]?)Object>', '<$1Record>' -replace '<([/]?)Property', '<$1Field'
	return $result
}

