<################################################################

random-wifi.ps1

 TO DO:
  1) Generate random two-word passwords from a dictionary file.
  2) Change shared key ("wifi password") on the wifi router.
  3) Update the computer's wifi connection with the new password.
 
################################################################>

param ( 
    [switch]$config     # If true, configure wifi router's username & 
                        # password and save in a configuration file
)

##### Constants/Globals #####

$baseDir="C:\Support\random-wifi"
$dictionaryFile ="$baseDir\little-dict.txt"
$configFile = "$baseDir\random-wifi.xml"
$wifiTxt = "$env:USERPROFILE\Desktop\wifi.txt"

##### Code #####

function main {
    if ($config -or !(Test-Path $configFile)) {
        write-config
    } else {
        $wifiConfig = Import-Clixml $configFile
        $newKey = create-password
        change-wifi-key $newKey $wifiConfig
        config-wireless $newKey $wifiConfig
    }
}

function change-wifi-key {
    param ( $newKey, $wifiConfig )

    # Written for a Lynksys WRT54G

    $wifiRouter = $wifiConfig.URL
    $user = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($wifiConfig.Username))
    $pass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($wifiConfig.Password))

    $pair = "${user}:${pass}"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $basicAuthValue = "Basic $base64"
    $headers = @{ Authorization = $basicAuthValue }

    $postBody = @{
        SecurityMode=3;
        CipherType=1;
        PassPhrase=$newKey;
        GkuInterval=3600;
        layout="en"
    }
    Invoke-WebRequest -Uri $wifiRouter -Headers $headers -Method POST -Body $postBody -ErrorAction "SilentlyContinue"
    $newKey | Out-File -Encoding ascii $wifiTxt
    notepad.exe $wifiTxt
}

function config-wireless {
    param ( $wifiKey, $wifiConfig )

    $wifiProfile = "$env:TEMP\wifi-profile.tmp"
    if (Test-Path $wifiProfile) { Remove-Item -Force -Recurse $wifiProfile }
    New-Item -ItemType Directory $wifiProfile | Out-Null
    $ssid = $wifiConfig.SSID
    $interface = $wifiConfig.Interface
    $router = $wifiConfig.Router
    netsh wlan export profile folder=$wifiProfile name=$ssid interface=$interface key=clear
    $filename = $(gci $wifiProfile).fullname
    $(Get-Content $filename) -replace "<keyMaterial>.*</keyMaterial>","<keyMaterial>$wifiKey</keyMaterial>" | Out-File $wifiProfile\new-profile.xml
    do {
        netsh wlan delete profile name=$ssid
        Start-Sleep 5
        netsh wlan add profile filename="$wifiProfile\new-profile.xml"
        $routerWorking = Test-Connection $router
        if (!$routerWorking) {
            write-host "Connection failure. Resetting and trying again..."
            netsh wlan delete profile name=$ssid
            Start-Sleep 5
            netsh wlan add profile filename="$filename"
            Start-Sleep 5
        }
    } until ($routerWorking)
    Write-Host "Connection made."
    Remove-Item -Force -Recurse $wifiProfile
}

function write-config {
    netsh wlan show profiles
    $regex=[regex]"Default Gateway\s(?:\.\s){9}:\s(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"
    $router=$regex.Matches($(ipconfig)).groups[1].value
    $interface = read-host "Wifi Interface"
    $routerURL = read-host "Wifi Router URL"
    do {
        $user = Read-Host "WiFi router username" -AsSecureString
        $usr1_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($user))
        $usr2 = Read-Host "Confirm username" -AsSecureString
        $usr2_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($usr2))
        if (!($usr1_text -ceq $usr2_text)) { write-host "Usernames don't match. Please try again."}
    } until ($usr1_text -ceq $usr2_text)
    do {
        $pwd1 = Read-Host "WiFi router password" -AsSecureString
        $pwd1_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd1))
        $pwd2 = Read-Host "Confirm password" -AsSecureString
        $pwd2_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd2))
        if (!($pwd1_text -ceq $pwd2_text)) { write-host "Passwords don't match. Please try again."}
    } until ($pwd1_text -ceq $pwd2_text)
    $ssid = read-host "Wifi SSID"
    @{
        URL = $routerURL
        Username = $user
        Password = $pwd1
        Interface = $interface
        SSID = $ssid
        Router = $router
    } | Export-Clixml $configFile
}

function create-password {
    # dictionary list from https://github.com/first20hours/google-10000-english/blob/master/google-10000-english-usa-no-swears-medium.txt
    # (simple English words, 5-8 characters long)

    #$specialChar = $("!@#$%^&*()")[$(Get-Random -Minimum 0 -Maximum 9)]
    $words = Get-Content $dictionaryFile
    $firstWord = $words[$(Get-Random -Minimum 0 -Maximum ($words.Count))]
    $secondWord = $words[$(Get-Random -Minimum 0 -Maximum ($words.Count))]
    write-host -ForegroundColor Yellow "New WiFi password:  $firstWord-$secondWord"
    "$firstWord-$secondWord"
}

function test-connection {
    param ( $router )
    Write-Host "Testing connection..."
    ping $router | Out-Null
    $?
}

main