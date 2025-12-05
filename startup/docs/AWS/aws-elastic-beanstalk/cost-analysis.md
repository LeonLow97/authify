# Costs Breakdown

## AWS Elastic Container Registry (ECR)

- Storage Cost
  - ECR charges **$0.10 per GB per month** for stored images.
  - For IMS, we are pushing 2 images that are 500 MB each (approximately)
    - Storage Used = 500 MB x 2 = 1 GB
    - **Monthly Cost = $0.10 per month**
- ECR Data Transfer (Free within AWS):
  - Pushing and pulling images **within the same AWS region** (`ap-southeast-1`) is **free**.
  - If we deploy across regions, cross-region data transfer will incur costs.
- AWS CLI Authentication
  - Running `aws ecr get-login-password` is **free** (just an API call)
  - No direct cost here.
- Docker Image build and Push
  - `docker build` on your local machine is **free**.
  - `docker push` to ECR
    - The cost depends on the uploaded images.
    - If both images are 500MB each, 1GB of data uploaded.
    - AWS **does not charge ingress (uploading data to AWS)**, so **no cost** here.

| Service                         | Estimated Cost                      |
| ------------------------------- | ----------------------------------- |
| ECR Storage (1GB)               | $0.10 per month                     |
| ECR Data Transfer               | $0.00 (Free Within AWS Same Region) |
| AWS CLI Authentication API Call | $0.00                               |
| Docker Image Build and Push     | $0.00                               |

`Estimated Cost: $0.10 per month` _(assuming 1GB of image stored in ECR, cost increases if more images are stored over time)_

## AWS Relational Database Service (RDS)

- AWS RDS PostgreSQL Instance
  - In IMS, we are using `db.t3.micro` instance size, which falls under AWS Free Tier (if eligible).
  - If not in Free Tier, the cost is **$0.0168 per hour**
    - **Monthly Cost = $0.0168 x 24 hours x 31 days = $12.50 per month**
  - **Multi-AZ Disabled** (saves cost)
- RDS Storage
  - Allocated Storage: `1GB` (Minimum)
  - Cost = $0.115 per GB per month
  - Since we are using 2 images with 500 MB per image size, we are provisioning the minimum 1GB.
    - **Monthly Cost = $0.115 per month**
- Data Transfer Costs
  - Within AWS (Same Region) is **free**.
  - **Data Transfer OUT to the Internet**
    - **First 100 GB per month** is **free**.
    - **Beyond 100 GB** costs `$0.09 per GB`
  - **Monthly Cost = $0.00 per month** (unless you transfer > 100 GB per month outside AWS)
- RDS Backups
  - Backup Retention Period: `7 days` (can set as `0 days` for no cost)
  - AWS automatically takes daily snapshots of your RDS instance
  - **AWS provides free backup storage equal to your provisioned storage**
  - Since we provision 1 GB of database storage, AWS gives us **1GB of free backup storage**.
  - Any additional backup storage beyond this incurs a cost of **$0.095 per GB per month**
  - 7 days of Backups for a 1 GB Database
    - AWS retains 7 daily snapshots. If each snapshot is 1GB, we need 7GB of **backup storage** for IMS.
    - Free backup storage = 1GB (equal to provisioned storage)
    - Chargeable storage = 7GB - 1GB = 6GB
      - **Monthly Cost = 6 GB x $0.095 = $0.57 per month**

| Service                           | Estimated Cost                        |
| --------------------------------- | ------------------------------------- |
| RDS Instance (`db.t3.micro`)      | $0.00 (Free Tier) or $12.50 per month |
| RDS Storage (1 GB)                | $0.115 per month                      |
| Backups (7 days, 6 GB chargeable) | $0.57 per month                       |
| Data Transfer (Internal AWS)      | $0.00                                 |

`Estimated Cost = $13.19 per month` _(assuming no Free Tier, 24/7 usage, using only the minimum 1GB of storage size)_
