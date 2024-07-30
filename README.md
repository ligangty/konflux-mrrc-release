# The PoC of MRRC release pipeline in Konflux Environment

---

To deploy this Demo to Konflux, please follow these steps. (Note: all following steps are experimented in Konflux env [https://console.redhat.com/preview/application-pipeline/](https://console.redhat.com/preview/application-pipeline/))

## Prerequisites

* Set up your personal tenant in Konflux env. Remember your tenant name which will be used later.
* Configure your kubectl or oc client to access the Konflux ocp.

## Create Application

To create application, follow the standard Konflux guide to do it.

* From the Konflux UI, click on Create Application button. Input "konflux-mrrc-release" in Application Name field.
* Click "Components" tab and then click "Add component" and fill details for the component with following inputs:
  * Git repository url: [https://github.com/ligangty/konflux-mrrc-release](https://github.com/ligangty/konflux-mrrc-release)
  * Docker file: Containerfile
  * Component name: konflux-mrrc-release
* Navigate to Overview tab and see the pipeline run
* Navigate to Components tab Ensure the 1st Build of your component and the 1st Test succeeds

## Install EC, RP and RPAs

* Change accordingly for following files:

  * spec.target to your tenant name in [release/kustomize/konflux-mrrc-release-plan.yaml](./release/kustomize/konflux-mrrc-release-plan.yaml)
  * spec.origin to your tenant name in [release/kustomize/konflux-mrrc-rpa-policy.yaml](./release/kustomize/konflux-mrrc-rpa.yaml)
* Make sure your kubectl or oc client can access your tenant
* Run

  ```shell
  kubectl(or oc) apply -k ./release/kustomize/ -n $your-tenant
  ```

## Setup config of cosign pub keys for signature verification

There is one task in pipeline which will verify the signature of the maven repo zip in oci registry. It will need the cosign.pub key to do.

* Use the following command to create the configmap:

  ``` shell
  kubectl(or oc) apply -f ./release/configs/cosign-pub-key-cm.yaml -n $your-tenant
  ```

## Setup charon configurations and AWS credentials

**NOTE**: The charon configurations and AWS credentials will controll the real charon publish actions. Please **BE CAREFUL NOT** use the production configurations to test this demo.

* Change the [release/configs/charon-cm.yaml](./release/configs/charon-cm.yaml) accordingly with your charon.yaml content. When you are done, you can use the following command to create the configmap of charon configuration

  ```shell
  kubectl(or oc) apply -f ./release/configs/charon-cm.yaml -n $your-tenant
  ```

* In Konflux UI, click "Secrets" at the right column bar, then click "Add Secret" button to create secret as following:

  * Secret type: Key/value secret
  * Secret name: charon-aws-credentials
  * Key: credentials
  * Value:

  ``` config
  [$your_aws_profile]
  aws_user = $your_aws_user
  aws_access_key_id = $your_aws_access_key_id
  aws_secret_access_key = $your_aws_access_key
  region = us-east-1
  ```

## Create Release CR to trigger the pipeline and see the pipeline runs

* Change [release/release.yaml.sample](./release/release.yaml.sample) to release/release.yaml, and change the content in it accordingly.
  * If you follow above steps to test, do not change the spec.data.product in the content.
  * For the snapshot, you can get it by running following command
  
  ```shell
  kubectl(or oc) get snapshot -n $your-tenant
  ```

* Run the following command to create the Release CR

  ```shell
  kubectl(or oc) apply -f ./release/release.yaml -n $your-tenant
  ```

  **Note**: sometimes it will report error which shows the release already exists. If so please change the metadata.name to different one and re apply it.
* In Konflux UI, navigate to "Applications" -> link of your application -> "Releases" tab. You will see the release you just created.
* Click the release name of yours, you can see the details of it. And in "Pipeline Run" item, you will see the pipeline run. Click the that pipeline run you will see the result of the whole pipeline run there.
* You can also check the logs of pipeline run and each task run in the pipeline by clicking "Logs"

## More: Prepare the maven repo zip for testing

The above demo steps are using a pre-defined maven repo zip. It is published to quay.io/ligangty/activemq.zip:0.0.1 with oci-artifact format, and signed with a self generated key-pair by cosign. If you want to test some other maven repo zip, you can follow these:

### Use oras to upload the maven repo zip

[oras](https://oras.land/) is a tool to publish any files to a oci registry with oci-artifact format. We can use it to publish the maven repo zip to quay.io. To run it, use the following command:

```shell
oras push quay.io/$org/yourmavenrepo.zip:0.1 \
--artifact-type application/zip \
./yourmavenrepo.zip
```

### Use cosign to sign the maven repo zip

[cosign](https://github.com/sigstore/cosign) is a tool to sign any oci-artifact. To use it, you need to generate a key-pair firstly by following command:

```shell
cosign generate-key-pair
```

Follow the steps of above command you will receive cosign.key and cosign.pub files.

Then you can use the following command to sign the maven repo zip

```shell
cosign sign -key cosign.key quay.io/$org/yourmavenrepo.zip:0.1
```
  
And the cosign.pub will used to verify the signature of the maven repo zip by following command:

```shell
cosign verify --key cosign.pub quay.io/$org/yourmavenrepo.zip:0.1
```

This command is used in the task of "repo-sign-verify.yaml" as well. If you want to use your own key to test the whole pipeline, please don't forget to replace the cosign.pub in the secrets with your own.

### Add the pull secret for charon image

In recent version, we have built the official charon image in konflux supported organizations in quay.io and started to use it in the pipeline. As it is a private repo, we need to add authentication to be able to pull it down successfully. Here are the steps to do it:

* Request access to the charon image registry: <https://quay.io/repository/redhat-services-prod/spmm-charon-containe-tenant/charon> from Konflux team.
* When done, generate the user token(cli password) in quay.io of your username, and put it into a file with following format:

```json
{
  "auths": {
    "quay.io": {
      "auth": "${your cli password}"
    }
  }
}

```

* Use following command to create the dockercfg secret:

```shell
oc create secret generic charon-container \
 --from-file=.dockerconfigjson=<path/to/your/jsonfile> \
 --type=kubernetes.io/dockerconfigjson
```

* Add above secret into your namespace's serviceaccount which can start the pipelinerun. Generally this sa should be "appstudio-pipeline". Please add above secret name into "imagePullSecrets" and "secrets" section.
