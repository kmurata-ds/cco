param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9-]+$')][string]$Alias,
    [ValidatePattern('^[A-Za-z0-9.-]+$')] [string]$Domain,
    [Parameter(Mandatory=$true)][string]$csvPath,
    [string]$Name,
    [switch]$DisablePolicy
)

if (-not $Name) { $Name = $Alias }
if (-not $Domain) { $Domain = "cco.kanagawa-it.ac.jp" }
if ($Domain -notmatch '\.') { throw "Domainの形式が不正. 例) example.com" }
$Primary = "$Alias@$Domain"

# 確認
#Write-Host "($Name, $Alias, $csvPath, $Primary)"

# Exchange Online 接続.
Import-Module ExchangeOnlineManagement -ErrorAction Stop
Connect-ExchangeOnline | Out-Null

# 既存チェック→無ければ作成.
$dg = Get-DistributionGroup -Identity $Alias -ErrorAction SilentlyContinue
if (-not $dg) {
    New-DistributionGroup -Name $Name -Alias $Alias `
                        -PrimarySmtpAddress $Primary -Type Distribution | Out-Null
    Write-Host "Created DG: $Name ($Alias, $Primary)."
} else {
    Write-Host "Using existing DG: $($dg.Name) ($($dg.Alias)) Email: ($dg.EmailAddresses)."
}

# 外部メールを拒否
Set-DistributionGroup -Identity $Name -RequireSenderAuthenticationEnabled $true
Write-Host "[$Name] has been set to block external senders."


# CSV読み込み. ヘッダー Email 無ければ1行スキップして Email 列に割り当て.
try {
    $rows = Import-Csv -Path $csvPath -ErrorAction Stop
    $hasEmail = ($rows | Select-Object -First 1 | Get-Member -Name Email -MemberType NoteProperty) -ne $null
    if (-not $hasEmail) {
        throw "CSV file [$csvPath] does not contain an 'Email' column."
    }
} catch {
    throw "Fail to read CSV file.: $csvPath. $_"
}


# 既存メンバー一覧を取得して重複追加を抑止.
$existing = @{}
try {
    Get-DistributionGroupMember -Identity $Alias -ResultSize Unlimited |
        ForEach-Object { $existing[($_.PrimarySmtpAddress.ToString().ToLower())] = $true }
} catch { }

$added = 0
$skipped = 0
foreach ($r in $rows) {
    # 登録リストに不備があれば飛ばす
    $email = ($r.Email | ForEach-Object { $_.ToString().Trim() })
    if ([string]::IsNullOrWhiteSpace($email)) { $skipped++; continue }
    $key = $email.ToLower()
    # すでに登録されていれば飛ばす
    if ($existing.ContainsKey($key)) {
        Write-Host "Skip (exists): $email"
        $skipped++; continue
    }
    try { # 登録
        Add-DistributionGroupMember -Identity $Alias -Member $email -ErrorAction Stop
        $existing[$key] = $true
        $added++
    } catch { # エラーがあれば出力して飛ばす
        Write-Host "Skip (error): $email. $_"
        $skipped++
    }
}

# result
Write-Host "Done. Added: $added, Skipped: $skipped."
# 接続を解除
Disconnect-ExchangeOnline -Confirm:$false
