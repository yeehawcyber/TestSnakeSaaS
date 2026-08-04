output "bucket_name" { value = aws_s3_bucket.state.bucket }
output "bucket_arn" { value = aws_s3_bucket.state.arn }
output "kms_key_arn" { value = aws_kms_key.state.arn }
output "kms_key_alias" { value = aws_kms_alias.state.name }
