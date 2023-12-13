# Project Dance

This helm chart installs and configures the following projects/products :


| Product | Installation    | Configuration   |
| :---:   | :---: | :---: |
| OpenShift GitOps | Operator `Subscription`   | Sets up an Argo CD in the `developer-argo` namespace for developer teams   |
| OpenShift Pipelines | Operator  `Subscription` | (TODO) Enables Tekton Chains & sets up signing keys   |
| Quay | (TODO) Operator `Subscription`  |    |
| ACS | (TODO)   |    |
| Trusted Artifact Signer | (TODO) Helm Dependency   |    |
| Trusted Profile Analyzer | (TODO) Helm Dependecy   |    |


# Try it

## CLI

0. Login to an OpenShift 4.14 cluster and create a new Project.

1. Add the helm repository to your local system 

    `helm repo add rhtap-dance https://redhat-appstudio.github.io/helm-repository`
    
    If you've already added this, run a `helm repo update` time to time to pull the latest packages.

2. Edit `values.yaml` to set your configuration parameters.

3. Install Dance

    `helm install rhtap-dance/dance --generate-name --namespace dance-installer --values values.yaml`

    Sample output:
    
    ```
    NAME: dance-1700107222
    LAST DEPLOYED: Wed Nov 15 23:00:25 2023
    NAMESPACE: dance-installer
    STATUS: deployed
    REVISION: 1
    TEST SUITE: None
    ```


3. Uninstall Dance

    `helm uninstall --namespace dance-installer dance-1700107222`

4. Upgrade an existing installation of Dance

    `TODO`

## UI ( a.k.a OpenShift Console )

1. Add the Helm Chart Repository to OpenShift 

```
apiVersion: helm.openshift.io/v1beta1
kind: HelmChartRepository
metadata:
  name: dance-rhtap
spec:
  connectionConfig:
    url: 'https://redhat-appstudio.github.io/helm-repository'
  name: dance
```

2. Install the Chart from the catalog

<img width="1365" alt="image" src="https://user-images.githubusercontent.com/545280/283235252-c3dfc4d7-c11b-43ff-8a52-8b1321727b3e.png">



## Development

### "Inner loop"

1. Download/Clone this Git Repository.
2. `./bin/make.sh apply`

### Tests

TODO

### Release a new version of Dance

#### Generate a tarball of the chart


```
$ git clone https://github.com/redhat-appstudio/dance
$ helm package dance
$ mv dance-0.2.0.tgz /tmp/
```

#### Push the tarball into the helm chart repository


```
$ git clone https://github.com/redhat-appstudio/helm-repository
$ cd helm-repository
$ mv /tmp/dance-0.2.0.tgz
$ rm -rf /tmp/dance-0.1.0.tgz
$ helm repo index --url https://redhat-appstudio.github.io/helm-repository/ .
```
