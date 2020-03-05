output "role" {
  value = module.administration_role
}

output "locations" {
  value = {
    ipset          = "s3://${aws_s3_bucket_object.ipset.bucket}/${aws_s3_bucket_object.ipset.key}"
    threatintelset = "s3://${aws_s3_bucket_object.threatintelset.bucket}/${aws_s3_bucket_object.threatintelset.key}"
  }
}

