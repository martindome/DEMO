function Get-AdUserDefaultPassword {
    # [CmdletBinding()]
    # param(
    #     [Parameter()]
    #     [ValidateNotNullOrEmpty()]
    #     [string]$FilePath = "$($PSScriptRoot | Split-Path -Parent)\Artifacts\DefaultUserPassword.xml"
    # )

    # echo "here!"

    # ## To save a new password, do this: Get-Credential -UserName 'DOESNOTMATTER' | Export-CliXml $defaultPasswordXmlFile
    # Write-Verbose -Message "Reading default password from [$FilePath]..."
    # $defaultCredential = Import-CliXml -Path $FilePath
    # $defaultPassword = $defaultCredential.GetNetworkCredential().Password
    $defaultPassword =  "Encr1pt4d012"
    ConvertTo-SecureString -String $defaultPassword -AsPlainText -Force
}

function Get-ActiveEmployee {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath = "$($PSScriptRoot | Split-Path -Parent)\Artifacts\Employees.csv"
    )

    if (-not (Test-Path -Path $FilePath)) {
        throw "The employee CSV file at [$($FilePath)] could not be found."
    } else {
        Write-Verbose -Message "The employee CSV file at [$($FilePath)] exists."
    }

    $selectProperties = @(
        '*'
        @{ n= 'ADUsername';e={Get-EmployeeUsername -FirstName $_.Firstname -LastName $_.LastName } }
        @{ n= 'OUPath';e={Get-DepartmentOUPath -OUPath $_.Department } }
    )

    Import-Csv -Path $FilePath | Select-Object $selectProperties
    
}

function Get-InactiveEmployee {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscustomobject[]]$ActiveEmployee = (Get-ActiveEmployee)
    )
    
    $adUsers = Get-ADuser -Filter "Enabled -eq 'True' -and SamAccountName -ne 'Administrator'"
    $adUsers.where({ $_.samAccountName -notin $ActiveEmployee.ADUsername })
    
}

function Get-EmployeeUsername {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FirstName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LastName
    )

    ## Our standard username pattern is <FirstInitial><LastName>
    $firstInitial = $FirstName.SubString(0,1)
    '{0}{1}' -f $firstInitial,$LastName
    
}

function Get-DepartmentOUPath {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OUPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DomainDistinguishedName = 'DC=demolab,DC=com'
    )

    "OU=$OUPath,$DomainDistinguishedName"
}

function Test-AdUserExists {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Username
    )

    if (Get-ADUser -Filter "Name -eq '$UserName'") {
        Write-Verbose -Message "The user account [$($Username)] exists."
        $true
    } else {
        Write-Verbose -Message "The user account [$($Username)] does not exist."
        $false
    }
    
}

function Test-AdGroupExists {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    if (Get-ADGroup -Filter "Name -eq '$Name'") {
        Write-Verbose -Message "The group [$($Name)] exists."
        $true
    } else {
        Write-Verbose -Message "The group [$($Name)] does not exist."
        $false
    }
    
}

function Test-AdGroupMemberExists {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Username,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$GroupName
    )

    $groupMembers = (Get-ADGroupMember -Identity $GroupName).Name
    if ($UserName -in $groupMembers) {
        Write-Verbose -Message "[$($UserName)] is a member of [$GroupName]"
        $true
    } else {
        Write-Verbose -Message "[$($UserName)] is not a a member of [$GroupName]"
        $false
    }
    
}

function Test-ADOrganizationalUnitExists {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistinguishedName
    )

    if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$DistinguishedName'") {
        Write-Verbose -Message "The organizational unit [$DistinguishedName] exists."
        $true
    } else {
        Write-Verbose -Message "The organizational unit [$DistinguishedName] does not exist."
        $false
    }   
}

function New-CompanyAdUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [pscustomobject]$Employee,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Username,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OrganizationalUnit,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [securestring]$Password = (Get-AdUserDefaultPassword)
    )
    $newUserParams = @{
        UserPrincipalName = $Username
        Name = $Username
        GivenName = $Employee.FirstName
        Surname = $Employee.LastName
        Title = $Employee.Title
        Department = $Employee.Department
        SamAccountName = $Username
        AccountPassword = $Password
        Path = $OrganizationalUnit
        Enabled = $true
        ChangePasswordAtLogon = $true
    }
    
    Write-Output -Message "Creating the new user account [$($Username)]..."
    New-AdUser @newUserParams

    #Write-Output "HERE!"
    #New-ADUser -Name "Jack Robin" -GivenName "Jack" -Surname "Robin" -SamAccountName "J.Robin" -UserPrincipalName "J.Robin@demolab.com" -Path "OU=Accounting,DC=demolab,DC=com" -AccountPassword(Read-Host -AsSecureString "Input Password") -Enabled $true

    
    #New-ADUser -Name $Username -GivenName $Employee.FirstName -Surname $Employee.LastName -SamAccountName $Employee.username -Path $OrganizationalUnit -AccountPassword (Read-Host -AsSecureString "Input Password") -Enabled $true
    
}