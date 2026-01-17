resource "aws_iam_role" "ai_mlops_ci" {
  name = "ai-mlops-ci"

  assume_role_policy = data.aws_iam_policy_document.ai_ci_trust.json
}

resource "aws_iam_policy" "ai_mlops_ci_policy" {
  name = "ai-mlops-ci-policy"

  policy = data.aws_iam_policy_document.ai_ci_permissions.json
}

resource "aws_iam_role_policy_attachment" "ai_mlops_ci_attach" {
  role       = aws_iam_role.ai_mlops_ci.name
  policy_arn = aws_iam_policy.ai_mlops_ci_policy.arn
}
