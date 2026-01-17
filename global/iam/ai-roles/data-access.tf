resource "aws_iam_role" "ai_data_access" {
  name = "ai-data-access"

  assume_role_policy = data.aws_iam_policy_document.ai_data_trust.json
}

resource "aws_iam_policy" "ai_data_policy" {
  name = "ai-data-access-policy"

  policy = data.aws_iam_policy_document.ai_data_permissions.json
}

resource "aws_iam_role_policy_attachment" "ai_data_attach" {
  role       = aws_iam_role.ai_data_access.name
  policy_arn = aws_iam_policy.ai_data_policy.arn
}
