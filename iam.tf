data "aws_caller_identity" "current" {}

locals {
  principal_arns = var.principal_arns != null ? var.principal_arns : [data.aws_caller_identity.current.arn]
}

resource "aws_iam_role" "iam_role" {
  name = "${local.namespace}-terraform-state-assume-iam-role"

  # trust policy - defines principals that are trusted to assume the role
  #  ie - who is allowed to assume the associated role
  assume_role_policy = data.aws_iam_policy_document.assume_policy_doc.json

  tags = {
    (local.resource_group_tag_name) = local.namespace
  }
}

data "aws_iam_policy_document" "assume_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "AWS"
      identifiers = local.principal_arns
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalTag/Department"
      values = [
        "devops"
      ]
    }
  }
}

data "aws_iam_policy_document" "policy_doc" {
  statement {
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.s3_bucket.arn
    ]
  }
  statement {
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "${aws_s3_bucket.s3_bucket.arn}/*",
    ]
  }
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    resources = [aws_dynamodb_table.dynamodb_table.arn]
  }
}
resource "aws_iam_policy" "iam_policy" {
  name   = "${local.namespace}-terraform-state-read-write-iam-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.policy_doc.json
}

# Role is created by default with no permissions
# Attach a policy to define what role is able to do when it is assumed
resource "aws_iam_role_policy_attachment" "policy_attach" {
  role       = aws_iam_role.iam_role.name
  policy_arn = aws_iam_policy.iam_policy.arn
}