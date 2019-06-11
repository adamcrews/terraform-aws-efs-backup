resource "aws_kms_key" "default" {
  description             = "${module.backups_label.id}"
  deletion_window_in_days = "30"
  enable_key_rotation     = "true"
  tags                    = "${module.backups_label.tags}"
}

resource "aws_kms_alias" "default" {
  name          = "${format("alias/%v", module.backups_label.id)}"
  target_key_id = "${aws_kms_key.default.id}"
}

module "logs_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.3.1"
  namespace  = "${var.namespace}"
  stage      = "${var.stage}"
  name       = "${var.name}"
  delimiter  = "${var.delimiter}"
  attributes = ["${compact(concat(var.attributes, list("logs")))}"]
  tags       = "${var.tags}"
}

resource "aws_s3_bucket" "logs" {
  bucket        = "${module.logs_label.id}"
  force_destroy = true
  tags          = "${module.logs_label.tags}"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = "${aws_kms_key.default.arn}"
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

module "backups_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.3.1"
  namespace  = "${var.namespace}"
  stage      = "${var.stage}"
  name       = "${var.name}"
  delimiter  = "${var.delimiter}"
  attributes = ["${compact(concat(var.attributes, list("backups")))}"]
  tags       = "${var.tags}"
}

resource "aws_s3_bucket" "backups" {
  bucket = "${module.backups_label.id}"
  tags   = "${module.backups_label.tags}"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = "${aws_kms_key.default.arn}"
        sse_algorithm     = "aws:kms"
      }
    }
  }

  lifecycle_rule {
    enabled = true

    noncurrent_version_expiration {
      days = "${var.noncurrent_version_expiration_days}"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = "${aws_s3_bucket.backups.id}"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = "${aws_s3_bucket.logs.id}"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
