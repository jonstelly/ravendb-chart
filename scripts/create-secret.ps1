#This script creates a kubernetes secret for the RavenDB servers with the password and PFX provided.
#This certificate should be signed by your certificate authority you provided in your my-ravendb image
#The certificate should have Subject Alternative Names for at least the following hostnames (standard Kubernetes DNS usages):
#This assumes you're deploying to the 'default' namespace and your ravendb deployment is named 'ravendb'.  If you change those defaults, your certificate should match those
#DNS Name=ravendb
#DNS Name=*.ravendb
#DNS Name=ravendb.default.svc.cluster.local
#DNS Name=*.ravendb.default.svc.cluster.local

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
