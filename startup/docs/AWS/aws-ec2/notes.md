# EC2

AWS EC2 (Elastic Compute Cloud) is a core service that allows users to run virtual servers in the cloud, known as instances.

# 1. What is EC2?

AWS EC2 is a scalable compute service that allows you to launch and manage **virtual machines (VMs) in the cloud**. These VMs are known as EC2 instances. EC2 provides flexible options for computing power, allowing you to scale your environment based on demand.

## 1.1 Key Concepts in EC2

- **Instance Types**: EC2 instances come in various sizes and configurations, each designed for specific use cases such as compute-heavy, memory-heavy or storage-heavy tasks.
- **AMI (Amazon Machine Images)**: Pre-configured templates for your instances. You can create your own or use AWS-provided AMIs (e.g., for Linux, Windows or other software configurations).
- **EBS (Elastic Block Store)**: Persistent block storage that is used to store data on your EC2 instances.
- **VPC (Virtual Private Cloud)**: Isolated network environment for your resources. You can launch EC2 instances within a VPC to control traffic flow.
- **Security Groups**: Virtual firewalls to control inbound and outbound traffic to/from EC2 instances.
- **Key Pairs**: Secure SSH access to EC2 instances. AWS generates a key pair when you launch an instance and you use that key to access your instance securely.

# 2. EC2 Instance Lifecycle

- **Launch**: Create an EC2 instance by choosing an AMI, instance type, security group, key pair and VPC settings.
- **Stop**: An EC2 instance can be stopped, which means it's not consuming compute resources, but the data on attached EBS volumes remains intact.
- **Terminate**: When you terminate an EC2 instance, it is deleted, and any data not on persistent storage (like EBS) is lost.
- **Reboot**: Reboots an EC2 instance without terminating it.

# 3. Types of EC2 Instances

- **General Purpose**: Balanced compute, memory and networking resources (e.g., t3, m5).
- **Compute Optimized**: For CPU-intensive applications (e.g., c5, c6g).
- **Memory Optimized**: For memory-intensive applications (e.g., r5, x1e).
- **Storage Optimized**: For workloads requiring high storage throughput (e.g., i3, d2).
- **Accelerated Computing**: For workloads requiring GPUs or hardware accelerators (e.g., p3, inf1).

# 4. AWS EC2 Associated Services

A production environment typically involves a suite of AWS services working together. Below are the key services integrated with EC2.

## 4.1 Networking Services

- **VPC (Virtual Private Cloud)**: A virtual network dedicated to your AWS account, where EC2 instances, databases, and other resources reside.
    - **Subnets**: Partition your VPC into subnets (public, private or VPN).
    - **Route Tables**: Direct traffic between subnets.
    - **NAT Gateway/Instance**: Allow instances in private subnets to access the internet.
    - **Elastic IP**: Static, public IP for dynamic cloud computing.
- **Elastic Load Balancer (ELB)**: Automatically distribute incoming application traffic across multiple EC2 instances. 
    - **Types**: Application Load Balancer (ALB), Network Load Balancer (NLB), Classic Load Balancer
- **AWS Direct Connect**: Private network connections from on-premises to AWS, improving performance and security.

## 4.2 Storage Services

- **EBS (Elastic Block Store)**: Persistent storage for EC2 instances, offering high-performance block-level storage.
    - **Snapshots**: Backup an EBS volume or entire instance.
    - **Provisioned IOPS (io1)**: High-performance storage for I/O-intensive applications.
- **S3 (Simple Storage Service)**: Object storage for large-scale data storage (backups, logs, etc).
- **EFS (Elastic File System)**: Managed file storage that can be mounted on EC2 instances for shared file storage across multiple instances.
- **Glacier**: Low-cost storage for archival and long-term backup.

## 4.3 Security Services

- **IAM (Identity and Access Management)**: Manage access to AWS services and resources.
    - **Roles**: Assign permissions to EC2 instances, enabling secure access to other AWS services.
    - **Policies**: Attach specific permissions to users, groups or roles.
- **Security Groups**: Control inbound and outbound traffic to EC2 instances at the instance level.
- **Network ACLs (Access Control Lists)**: Control traffic at the subnet level within a VPC.
- **AWS Shield**: DDoS protection for your AWS resources.
- **AWS WAF**: Web Application Firewall to protect EC2 instances from web exploits.

## 4.4 Monitoring & Logging Services

- **CloudWatch**: Monitor EC2 instance performance (CPU, memory, disk usage, etc.). Set alarms for metrics.
    - **Logs**: Collect logs from EC2 instances and applications.
- **CloudTrail**: Track API calls and changes made to AWS resources.
- **X-Ray**: Analyze and debug production applications.

## 4.5 Scaling & Automation

- **Auto Scaling**: Automatically scale the number of EC2 instances up or down based on demand.
    - **Scaling Policies**: Define thresholds to trigger scaling events (e.g., CPU usage > 80% for 5 minutes).
    - **Launch Configurations**: Define the EC2 instance setup for Auto Scaling.
- **Elastic Beanstalk**: Platform-as-a-Service (PaaS) that automates deployment, scaling and management of applications (such as web apps) running on EC2.
- **AWS Lambda**: Serverless computing that automatically runs code in response to triggers (e.g., S3 uploads, DynamoDB changes).

## 4.6 Database Services

- **RDS (Relational Database Service)**: Managed relational database service for MySQL, PostgreSQL, Oracle, SQL Server and MariaDB
    - **Multi-AZ**: Automatically replicated database across multiple availability zones for high availability.
- **DynamoDB**: Managed NoSQL database service for high-performance application.
- **ElastiCache**: Managed in-memory data store service for caching (e.g., Redis, Memcached).
- **Aurora**: A high-performance, scalable relational database compatible with MySQL and PostgreSQL.

## 4.7 Content Delivery & CDN

- **CloudFront**: Content delivery network (CDN) for distributing static content with low latency.
- **Route 53**: DNS Service that allows you to manage domain names and route traffic to resources like EC2 instances.

## 4.8 Backup & Disaster Recovery

- **AWS Backup**: Centralized backup management for EC2, EBS and other AWS resources.
- **Elastic Disaster Recovery (DRS)**: Protect EC2 instances and other AWS resources from failures.

# 5. Production Environment Considerations

## 5.1 High Availability and Fault Tolerance

- **Multi-AZ**: Deploy EC2 instances across multiple availability zones to ensure high availability.
- **Elastic Load Balancer (ELB)**: Distribute traffic across multiple EC2 instances to avoid bottlenecks.
- **Auto Scaling**: Scale instances up or down based on demand to ensure your application remains performant.

## 5.2 Security Best Practices

- **Least Privilege Principles**: Use IAM roles with the least privilege, granting only the permissions required.
- **Security Groups & NACLs**: Set up fine-grained access controls to secure your EC2 instances and VPC resources.
- **Encryption**: Encrypt data at rest using EBS encryption and in transit using SSL/TLS.

## 5.3 Cost Optimization

- **Reserved Instances**: Commit to long-term EC2 usage (1 or 3 years) at a discounted rate.
- **Spot Instances**: Take advantage of unused EC2 capacity at a lower cost for non-critical workloads.
- **AWS Cost Explorer**: Monitor and analyze EC2 usage and costs to identify savings opportunities.

## 5.4 CI/CD Integration

- **CodePipeline**: Automate the deployment of your application to EC2.
- **CodeDeploy**: Automated application deployment to EC2 instances.
- **CodeBuild**: Build and test your code before deploying to EC2.

## 5.5 Networking Best Practices

- **Private Subnet**: Place EC2 instances that don't need direct internet access in private subnets.
- **VPN or Direct Connect**: For secure communication between on-premises environments and AWS.

# Conclusion

In a production environment, AWS EC2 is central to the compute infrastructure. To managed EC2 efficiently, it is crucial to integrate services like VPC for networking, IAM for security, RDS/DynamoDB for database, CloudWatch for monitoring and Auto Scaling for dynamic scaling. Always consider high availability, security and cost optimization in your EC2 deployment strategy.