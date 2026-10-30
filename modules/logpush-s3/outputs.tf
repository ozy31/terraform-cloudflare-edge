output "bucket_name" {
  description = "S3 bucket receiving Cloudflare logs."
  value       = aws_s3_bucket.logs.id
}

output "logpush_job_ids" {
  description = "Logpush job IDs by dataset."
  value       = { for ds, job in cloudflare_logpush_job.this : ds => job.id }
}

output "opensearch_pipeline_arn" {
  description = "ARN of the OpenSearch Ingestion pipeline (null when disabled)."
  value       = try(aws_osis_pipeline.this[0].pipeline_arn, null)
}

output "opensearch_pipeline_role_arn" {
  description = "Role to map as a backend role with write access in OpenSearch fine-grained access control."
  value       = try(aws_iam_role.osis[0].arn, null)
}
