param(
    [Parameter(Mandatory=$true)][string]$csvPath
)

# CSV読み込み. ヘッダー UserPrincipalName
try {
    $users = Import-Csv -Path $csvPath
} catch {
    throw "Fail to read CSV file.: $csvPath. $_"
    exit
}

Connect-MgGraph -Scopes "User.ReadWrite.All"
 
# ブロック
foreach ($u in $users) {
    #Write-Host $u.UserPrincipalName
    Update-MgUser -UserId $u.UserPrincipalName -AccountEnabled:$false
    Write-Host "Blocked: $($u.UserPrincipalName)"
}

Disconnect-ExchangeOnline -Confirm:$false


