# Terraform AWS S3 Bucket

A Terraform configuration for provisioning an S3 bucket on AWS with versioning, lifecycle management, and public access blocking. This is an AWS equivalent of the GCS bucket setup from the Data Engineering Zoomcamp course.

---

## What This Creates

- **S3 bucket** — private bucket with a globally unique name
- **Versioning** — keeps multiple versions of each object
- **Lifecycle rule** — automatically deletes noncurrent object versions after 7 days
- **Public access block** — all public access is explicitly denied

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with a named profile `dtc`

### Configure AWS CLI profile

```bash
aws configure --profile dtc
```

You will be prompted for:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g. `us-east-1`)
- Output format (e.g. `json`)

---

## 1. Create an IAM User (equivalent of GCP Service Account)

In the original course a GCP Service Account was created with Storage Object Admin permissions. The AWS equivalent is an IAM user with S3 access.

### Via AWS Console

1. Go to **IAM → Users → Create user**
2. Set a name (e.g. `terraform-user`). Leave "Provide user access to the AWS Management Console" **unchecked** — programmatic access only.
3. Attach the `AmazonS3FullAccess` policy (sufficient for this tutorial; in production, scope it down to a specific bucket).
4. Finish creating the user.
5. Open the user, go to **Security credentials → Create access key**, choose **Application running outside AWS**, and save the **Access Key ID** and **Secret Access Key**.

### Export credentials to the terminal

Similar to how `GOOGLE_APPLICATION_CREDENTIALS` was exported in the video, set environment variables for the current session:

```bash
export AWS_ACCESS_KEY_ID="your_access_key_id"
export AWS_SECRET_ACCESS_KEY="your_secret_access_key"
export AWS_DEFAULT_REGION="us-east-1"
```

Terraform will pick these up automatically. Alternatively, credentials are loaded from the `dtc` AWS CLI profile (`~/.aws/credentials`) — whichever is configured.

> Never commit credentials to version control. The `.gitignore` in this project excludes credential files.

---

## 2. Project Structure

```
.
├── main.tf         # Main infrastructure configuration
├── variables.tf    # Input variables
├── outputs.tf      # Output values
├── .gitignore      # Excludes state files, credentials, and .terraform/
└── README.md
```

---

## 3. Usage

### Initialize

Downloads the AWS provider and sets up the working directory:

```bash
terraform init
```

This creates `.terraform.lock.hcl` which pins the provider version.

### Preview changes

Shows what will be created without applying anything:

```bash
terraform plan
```

You will see a plan for creating the S3 bucket, versioning, lifecycle rule, and public access block — equivalent to the "dry run" shown in the video.

### Apply

Creates the resources in AWS:

```bash
terraform apply
```

Terraform will show the plan again and ask for confirmation (`yes/no`). After confirmation, the bucket is created and state is saved locally in `terraform.tfstate`.

### Verify in AWS Console

Go to **S3 → Buckets**, confirm the bucket was created, versioning is enabled, and the lifecycle rule is present. You can upload a test file and see its versions.

### Destroy

Removes all created resources:

```bash
terraform destroy
```

`force_destroy = true` is set on the bucket, so it will be deleted even if it contains objects.

---

## 4. Variables

| Name          | Description                              | Default                         |
|---------------|------------------------------------------|---------------------------------|
| `region`      | AWS region where resources are created   | `us-east-1`                     |
| `bucket_name` | Globally unique S3 bucket name           | `dtc-terraform-bucket-20260508` |

Override variables at apply time:

```bash
terraform apply -var "bucket_name=my-custom-bucket-name"
```

---

## 5. Outputs

| Name            | Description                              |
|-----------------|------------------------------------------|
| `bucket_name`   | The name of the created S3 bucket        |
| `bucket_arn`    | The ARN of the S3 bucket                 |
| `bucket_region` | The AWS region where the bucket resides  |

---

## 6. Parallels with the Course Video

| GCP (video)                        | AWS (this project)                              |
|------------------------------------|-------------------------------------------------|
| GCS bucket                         | S3 bucket                                       |
| Service Account + JSON key         | IAM user + Access Key / AWS CLI profile         |
| `GOOGLE_APPLICATION_CREDENTIALS`   | `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY`   |
| Storage Class                      | S3 storage class (Standard by default per object)|
| Lifecycle rule (delete after N days)| `noncurrent_version_expiration` after 7 days   |
| Local state                        | Local `terraform.tfstate` (same approach)       |

---

## 7. Notes

- **Storage class** is not set at the bucket level in S3 — it is assigned per object at upload time. The default is `STANDARD`.
- **State** is stored locally (`terraform.tfstate`). For production, use a [remote S3 backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3) with DynamoDB for state locking — this is the AWS standard equivalent of a GCS remote backend.
- **`force_destroy = true`** makes `terraform destroy` work even if the bucket is not empty. Remove this in production environments.
- **Versioning + lifecycle** work together: versioning keeps old object versions, and the lifecycle rule cleans them up after 7 days — mirroring the lifecycle configuration shown in the video.
