## Overview

This is a Helm Chart for [RavenDB](https://ravendb.net/).  It creates a secure RavenDB cluster as a Kubernetes Stateful Set.

If there's interest, I'm happy to work with folks to get this into the Helm incubating repository but I'm not super sure what's required or what that process looks like.  So for now I'll keep the chart in this separate repository.

## Limitations

This works with custom certificates and a custom CA.  It may be simpler to set this up for Lets Encrypt, and would definitely be simpler to set it up without certificates, I'll happily take pull requests if you want to modify this chart to support either of those scenarios.

I'm using microk8s for running Kubernetes and do my development on a Windows machine.  That's the environment I've tested this on so things may break elsewhere.  Again, happy to take pull requests or issues if you run into problems.

RavenDB nodes aren't automatically added to a cluster so you'll need to do that by hand.  If you're using Kubernetes Persistence each RavenDB node will have its own volume.  Assuming those volumes aren't reclaimed when a node shuts down, once you add a node to the RavenDB cluster, it'll remain in the cluster even if it's destroyed and recreated.   From the documentation [here](https://ravendb.net/docs/article-page/4.1/csharp/studio/server/cluster/add-node-to-cluster) and [here](https://ravendb.net/docs/article-page/4.1/csharp/server/configuration/cluster-configuration) I don't see any way of configuring the nodes to automatically join a cluster.

## Prerequisites

You'll need to generate certificates for RavenDB as outlined [here](https://ravendb.net/docs/article-page/4.1/csharp/server/security/authentication/certificate-management).  *_NOTE: I have a slightly different certificate generation process, so there may be some gaps in this example chart but overall I think it's correct._*

You'll also need a Kubernetes Cluster with Helm/Tiller (I'm using Kubernetes v1.14.1 and Helm 2.13.1).

## Steps

1. If you use a custom Certificate Authority, you'll need to create a docker image that derives from RavenDB Ubuntu and simply adds your CA certificate to the Docker Image.  The Dockerfile and a place-holder my-ca.crt are in the [my-ravendb](./my-ravendb) directory of this repository.  If you have certificates from an already-trusted (by Ubuntu 18.04) third party CA then you don't need to build a custom ravendb docker image.
2. Copy the values.my-example.yaml as `values.{whatever}.yaml` so you can override Helm Chart settings as needed.
    - Values you must set
        - `security.adminCertificate` - You must set this value to match the thumbprint of your administrator secret
    - Values you may be interested in
        - `image.repository` - Assumes you have a custom CA and are pushing your my-ravendb image to the microk8s private registry (which defaults to localhost:32000).  If you're not using a custom CA, you can override this setting with `ravendb/ravendb` (or probably `ravendb/ravendb-nightly` but I haven't tested that)
        - `persistence.storage` - `Values.yaml` Defaults storage to 1 GB, the value in `values.my-example.yaml` is 20 GB
        - `resources` - Tweak CPU and Memory requests and limits to whatever makes sense for your environment
3. With Kubernetes configured and pointing to your target cluster, run the [scripts/create-secret.ps1](./scripts/create-secret.ps1) script and pass it the path to your server certificate PFX.  The script will prompt you for your PFX password and create a Kubernetes secret with both the PFX file contents and the password.
4. From a command prompt in this directory, run `helm install ./ -f ./{YOUR VALUES FILE YAML} -n ravendb;`
5. If you make changes and need to deploy the changes, run `helm upgrade ravendb ./ -f ./{YOUR VALUES FILE YAML} --recreate-pods;` (recreate-pods is optional depending on the change, but will ensure that all pods get recreated/restarted)

## Warnings/Gotchas/Limitations

If you run only a single instance of RavenDB then it's fairly easy to get access to your single instance from outside the Kubernetes cluster.

But if you're running a cluster of 2+ instances, because of the way that RavenDB does clustering/name resolution and provides the cluster map to clients, accessing RavenDB from outside the cluster is slightly tricky.  The short version is that name resolution outside the cluster has to match the names and ports you use to access RavenDB instances from inside the cluster and that's not the easiest thing to set up when developing on Windows (experts please point me in a better direction than what I outline below if there is one).

I'm not a Kubernetes expert, so I'm not sure of all the options to get name resolution like I mention above, but for me I'm running a bastion/VPN pod using SoftEther and SSTP where I push route entries for the cluster ip subnet, and set the DNS suffix of the connection to the kubernetes namespace DNS domain.  A SoftEther server config using microk8s (whose default cluster ip subnet is 10.152.183.0/24) looks like this:

```
declare VirtualDhcpServer
{
	string DhcpDnsServerAddress 192.168.30.1
	string DhcpDnsServerAddress2 0.0.0.0
	string DhcpDomainName default.svc.cluster.local
	bool DhcpEnabled true
	uint DhcpExpireTimeSpan 7200
	string DhcpGatewayAddress 192.168.30.1
	string DhcpLeaseIPEnd 192.168.30.200
	string DhcpLeaseIPStart 192.168.30.10
	string DhcpPushRoutes 10.1.1.0/255.255.255.0/192.168.30.1,10.152.183.0/255.255.255.0/192.168.30.1
	string DhcpSubnetMask 255.255.255.0
}
```

So when I need to connect to RavenDB (studio, etc...) I connect to this VPN and name resolution/routing works as needed.

After doing the above I can open a browser on my desktop and connect to https://ravendb-0.ravendb.default.svc.cluster.local/ (assuming you've trusted your CA certificate on your desktop computer).

One small gotcha here... in theory you should be able to access RavenDB studio at https://ravendb.default.svc.cluster.local/ and that mostly works, but I notice some slow loading and 404 errors in the console.  I think this is a RavenDB server issue based on how it handles serving the Studio content, but it may also just be an authentication issue.  I plan on opening an issue on this with RavenDB so we can hopefully track it down (or figure out I just missed something obvious)