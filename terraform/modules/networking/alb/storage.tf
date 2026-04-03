#========================================================================
#              *** ALB Service Account & Logging Support ***
#========================================================================
data "aws_elb_service_account" "main" {}

data "aws_caller_identity" "current" {}

#========================================================================
#              *** S3 Bucket Policy for ALB Access Logs ***
#========================================================================
resource "aws_s3_bucket_policy" "alb_access_logs" {
  count  = var.enable_access_logs ? 1 : 0
  bucket = var.access_logs_s3_bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ALBWriteAccess"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.access_logs_s3_bucket}/${var.access_logs_s3_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      },
      {
        Sid    = "LogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.access_logs_s3_bucket}/${var.access_logs_s3_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "LogDeliveryRead"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${var.access_logs_s3_bucket}"
      }
    ]
  })
}
