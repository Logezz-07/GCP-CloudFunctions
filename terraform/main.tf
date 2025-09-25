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

resource "random_id" "bucket" {
  byte_length = 4
}

resource "google_storage_bucket" "function_bucket" {
  name                        = "${var.project_id}-gcf-source-${random_id.bucket.hex}"
  location                    = var.region
  uniform_bucket_level_access = true
}

data "archive_file" "functions" {
  for_each    = toset(var.functions)
  type        = "zip"
  output_path = "/tmp/${each.key}.zip"
  source_dir  = "../${each.key}"
}

resource "google_storage_bucket_object" "function_objects" {
  for_each = toset(var.functions)
  
  # Append hash of archive content to object name to force update on change
  name     = "${each.key}-${data.archive_file.functions[each.key].output_sha}.zip"
  bucket   = google_storage_bucket.function_bucket.name
  source   = data.archive_file.functions[each.key].output_path
}

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
    available_memory   = "256M"
    timeout_seconds    = 60
    ingress_settings   = "ALLOW_INTERNAL_ONLY"
  }
}

resource "google_cloud_run_service_iam_member" "member" {
  for_each = google_cloudfunctions2_function.functions

  location = each.value.location
  service  = each.value.service_config[0].service
  role     = "roles/run.invoker"
  member   = "allUsers"

  depends_on = [google_cloudfunctions2_function.functions]
}

output "function_uris" {
  value = {
    for k, f in google_cloudfunctions2_function.functions :
    k => f.service_config[0].uri
  }
}
