<#
CCOユーザのパスワードを変更。
・ユーザ名、パスワードを示したcsvファイルを引数として受け取る。
・該当ユーザのパスワードを変更する。
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$inputFile
)

# CSV読み込み. ヘッダー UserPrincipalName, passwd
try {
    $users = Import-Csv -Path $InputFile -Encoding UTF8 -ErrorAction Stop
} catch {
    throw "Fail to read CSV file.: $InputFile. $($_.Exception.Message)"
}

## MS Graphに接続（未接続なら対話的にログイン）
$scopes = @("User.ReadWrite.All","User-PasswordProfile.ReadWrite.All") # 必要スコープ
$ctx = Get-MgContext -ErrorAction SilentlyContinue
if (-not $ctx) {
    Connect-MgGraph -Scopes $scopes
}

try {
    $results = foreach ($u in $users) {
        $upn = ($u.UserPrincipalName).Trim()
        $pwd = ($u.passwd).Trim()

        if ([string]::IsNullOrWhiteSpace($upn) -or [string]::IsNullOrWhiteSpace($pwd)) {
            [pscustomobject]@{ User=$upn; Status='Skipped'; Note='Empty UPN or password' }
            continue
        }

        Update-MgUser -UserId $upn -PasswordProfile @{
            Password = $pwd
            ForceChangePasswordNextSignIn = $true
        } -ErrorAction Stop | Out-Null

        [pscustomobject]@{ User=$upn; Status='OK'; Note='' }
    }

    $results | Format-Table -AutoSize
}

# 接続解除
<# 
finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue
}
#>



