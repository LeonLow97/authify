# Create S3 Bucket
resource "aws_s3_bucket" "ims_bucket" {
  bucket        = "ims-bucket-jiewei"
  force_destroy = true # Allows terraform destroy to remove even non-empty buckets

  tags = {
    Name        = "IMS-Bucket"
    Environment = "Production"
  }
}

# Upload SQL Scripts to IMS S3 Bucket
resource "aws_s3_object" "upload_file" {
  bucket       = aws_s3_bucket.ims_bucket.bucket
  key          = "sql-uploads/init-authentication-db.sql"                  # Path in S3
  source       = "../../../init-db/init-authentication-db.sql" # Local path to file
  etag         = filemd5("../../../init-db/init-authentication-db.sql")
  content_type = "text/plain"

  depends_on = [aws_s3_bucket.ims_bucket]
}
