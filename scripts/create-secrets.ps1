#This script creates a kubernetes secret based on the PFX provided, prompts for password and adds password to secret too
param([string]$PfxPath)

$password = Read-Host -Prompt "PFX Password" -AsSecureString;
$pwPointer = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($password)
$pw = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($pwPointer)
[System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($pwPointer)

$pfx = [IO.FileInfo](Join-Path -Path $PSScriptRoot -ChildPath $PfxPath);
if(-not $pfx.Exists) {
    throw "Couldn't find PFX: $pfxPath";
}

#TODO: Parameterize/align secret name with deployment name if we want to run multiple ravendb clusters in same namespace
kubectl create secret generic ravendb "--from-file=ravendb.pfx=$PfxPath" "--from-literal=password=$pw";
