param(
    [string]$Server = '72.60.197.131',
    [string]$Container = 'sivamangai-sivamangai-c0m98v-app-1'
)
$ErrorActionPreference = 'Stop'
if ($Server -notmatch '^[a-zA-Z0-9.-]+$' -or $Container -notmatch '^[a-zA-Z0-9_.-]+$') {
    throw 'Invalid server or container name.'
}
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$releaseDir = Join-Path $projectRoot 'artifacts/mobile_release/1.0.5-build-6'
$apk = Join-Path $releaseDir 'silvamang-ai.apk'
$metadata = Join-Path $releaseDir 'release.json'
$expected = 'daaec2b7999f6053b8c4cd0dc04d118d821888ad6dab63e8438316b58e3c5813'
if (!(Test-Path -LiteralPath $apk) -or !(Test-Path -LiteralPath $metadata)) { throw 'Release files are missing.' }
if ((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) { throw 'APK checksum does not match the verified release.' }
$release = Get-Content -LiteralPath $metadata -Raw | ConvertFrom-Json
if ($release.version -ne '1.0.5' -or $release.build -ne '6' -or $release.sha256 -ne $expected) { throw 'Release metadata does not match the APK.' }
$tag = 'silvamang-publish-' + [guid]::NewGuid().ToString('N')
$bundle = Join-Path ([IO.Path]::GetTempPath()) ($tag + '.tar')
try {
    & tar -cf $bundle -C $releaseDir silvamang-ai.apk release.json
    if ($LASTEXITCODE -ne 0) { throw 'Could not package the release.' }
    Write-Host 'Uploading: enter your VPS password when prompted. It will not appear as you type.'
    Write-Host 'For a new SSH host key, compare its fingerprint with your VPS provider before accepting.'
    & scp $bundle "root@${Server}:/tmp/$tag.tar"
    if ($LASTEXITCODE -ne 0) { throw 'Upload failed. Nothing was published.' }
    $remoteScript = @'
set -eu
container='__CONTAINER__'
tag='__TAG__'
expected='__HASH__'
stage="/tmp/$tag"
release=/var/www/html/storage/app/releases
mkdir -m 700 "$stage"
tar -xf "/tmp/$tag.tar" -C "$stage"
printf '%s  %s\n' "$expected" "$stage/silvamang-ai.apk" | sha256sum -c -
docker inspect "$container" >/dev/null
docker exec -u root "$container" mkdir -p "$release"
docker cp "$stage/silvamang-ai.apk" "$container:$release/silvamang-ai.apk.new"
docker cp "$stage/release.json" "$container:$release/release.json.new"
actual=$(docker exec "$container" sha256sum "$release/silvamang-ai.apk.new" | cut -d ' ' -f 1)
[ "$actual" = "$expected" ] || { echo 'Container checksum mismatch; release was not replaced.'; exit 1; }
docker exec -u root "$container" sh -c 'set -eu; cd /var/www/html/storage/app/releases; stamp=$(date +%Y%m%d%H%M%S); if [ -f silvamang-ai.apk ]; then cp -p silvamang-ai.apk "silvamang-ai.apk.backup-$stamp"; fi; if [ -f release.json ]; then cp -p release.json "release.json.backup-$stamp"; fi; chmod 644 silvamang-ai.apk.new release.json.new; mv silvamang-ai.apk.new silvamang-ai.apk; mv release.json.new release.json'
rm -- "$stage/silvamang-ai.apk" "$stage/release.json" "/tmp/$tag.tar"
rmdir "$stage"
echo 'Release installed in the website download folder.'
'@
    $remoteScript = $remoteScript.Replace('__CONTAINER__', $Container).Replace('__TAG__', $tag).Replace('__HASH__', $expected)
    Write-Host 'Publishing: SSH may ask for your VPS password again.'
    $remoteScript.Replace("`r", '') | & ssh "root@$Server" 'bash -s'
    if ($LASTEXITCODE -ne 0) { throw 'Server publishing failed. Read the error above before retrying.' }
    $response = Invoke-WebRequest -Uri 'https://silvamangai.online/download/android' -Method Head -UseBasicParsing
    if ($response.StatusCode -ne 200 -or [long]$response.Headers['Content-Length'] -ne (Get-Item -LiteralPath $apk).Length) {
        throw 'The public download did not match the APK size. Check the active app container.'
    }
    Write-Host 'SUCCESS: https://silvamangai.online/download now serves version 1.0.5 (build 6).' -ForegroundColor Green
} finally {
    if (Test-Path -LiteralPath $bundle) { Remove-Item -LiteralPath $bundle }
}
