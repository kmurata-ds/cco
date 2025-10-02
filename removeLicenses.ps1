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

## MSに接続
# 必要スコープ
$scopes = @("User.ReadWrite.All", "Organization.Read.All")

# Graphに接続（未接続なら対話的にログイン）
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes $scopes
}


foreach ($u in $users) {
    $upn = ($u.UserPrincipalName).Trim()
    $user = Get-MgUser -UserId $upn -Property Id,AssignedLicenses -ErrorAction Stop

    if (-not $user.AssignedLicenses -or $user.AssignedLicenses.Count -eq 0) {
        Write-Host "[SKIP] $($upn): no licenses."
        continue
    }

    $skuIds = @($user.AssignedLicenses.SkuId)  # GUID配列.
    try {
        # 直接RESTでやる場合.
        $uri = "https://graph.microsoft.com/v1.0/users/$($user.Id)/assignLicense"
        $body = @{
            addLicenses    = @()          # 空配列必須.
            removeLicenses = $skuIds      # ← 配列. オブジェクトにしない.
        } | ConvertTo-Json -Depth 4

        Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -ContentType "application/json" -ErrorAction Stop
        Write-Host "[OK] removed licenses via direct API call: $upn"
    }
    catch {
        Write-Warning "Failed to assign/remove license via direct call: $upn - $($_.Exception.Message)"
    }
}

# 接続解除
Disconnect-MgGraph