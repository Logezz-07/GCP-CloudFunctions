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

# Static bucket for CI/CD (do not recreate)
resource "google_storage_bucket" "function_bucket" {
  name                        = "${var.project_id}-gcf-source"
  location                    = var.region
  uniform_bucket_level_access = true

  lifecycle {
    prevent_destroy = true
  }
}

# Archive function source code
data "archive_file" "functions" {
  for_each    = toset(var.functions)
  type        = "zip"
  output_path = "../terraform/${each.key}.zip"
  source_dir  = "../${each.key}"
}

# Upload each zip to bucket with hash to detect changes
resource "google_storage_bucket_object" "function_objects" {
  for_each = toset(var.functions)
  name     = "${each.key}.zip"
  bucket   = google_storage_bucket.function_bucket.name
  source   = data.archive_file.functions[each.key].output_path
  source_hash = filemd5(data.archive_file.functions[each.key].output_path)
}

# Cloud Functions 2nd Gen
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
    ingress_settings   = "ALLOW_ALL" # public HTTP access
  }
}

# IAM for public invoke
resource "google_cloudfunctions2_function_iam_member" "invoker" {
  for_each = google_cloudfunctions2_function.functions

  project        = var.project_id
  region         = var.region
  cloud_function = each.value.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}

# Output URLs
output "function_urls" {
  value = {
    for k, f in google_cloudfunctions2_function.functions :
    k => f.status[0].url
  }
}
