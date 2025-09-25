terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.34.0"
    }
  }
}

variable "project_id" {}
variable "region" {}
variable "functions" {
  type = list(string)
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_storage_bucket_object" "function_objects" {
  for_each    = toset(var.functions)
  name        = "${each.key}.zip"
  bucket      = google_storage_bucket.function_bucket.name
  source      = data.archive_file.functions[each.key].output_path

  # 👇 This makes Terraform detect code changes and re-upload
  source_hash = filemd5(data.archive_file.functions[each.key].output_path)
}
# Archive each function source
data "archive_file" "functions" {
  for_each    = toset(var.functions)
  type        = "zip"
  output_path = "/tmp/${each.key}.zip"
  source_dir  = "../${each.key}"  # relative path from terraform folder
}

# Upload each zip to bucket, trigger updates when code changes
resource "google_storage_bucket_object" "function_objects" {
  for_each    = toset(var.functions)
  name        = "${each.key}.zip"
  bucket      = google_storage_bucket.function_bucket.name
  source      = data.archive_file.functions[each.key].output_path
  content_md5 = filemd5(data.archive_file.functions[each.key].output_path)
}

# Deploy Cloud Functions
resource "google_cloudfunctions2_function" "functions" {
  for_each    = toset(var.functions)
  name        = each.key
  location    = var.region
  description = "Terraform managed Cloud Function: ${each.key}"

  build_config {
    runtime     = "nodejs20"
    entry_point = "helloHttp"

    source {
      storage_source {
        bucket = google_storage_bucket.function_bucket.name
        object = google_storage_bucket_object.function_objects[each.key].name
      }
    }
  }

  service_config {
    min_instance_count = 1
    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
    ingress_settings   = "ALLOW_ALL" # allow external access
  }
}

# Allow public HTTP invoke
resource "google_cloud_run_service_iam_member" "invoker" {
  for_each = google_cloudfunctions2_function.functions

  location = each.value.location
  service  = each.value.service_config[0].service
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Output function URLs
output "function_uris" {
  value = {
    for k, f in google_cloudfunctions2_function.functions :
    k => f.service_config[0].uri
  }
}
