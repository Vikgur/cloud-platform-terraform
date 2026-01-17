resource "aws_iam_role" "ai_training" {
  name = "ai-training"

  assume_role_policy = data.aws_iam_policy_document.ai_training_trust.json
}

resource "aws_iam_policy" "ai_training_policy" {
  name = "ai-training-policy"

  policy = data.aws_iam_policy_document.ai_training_permissions.json
}

resource "aws_iam_role_policy_attachment" "ai_training_attach" {
  role       = aws_iam_role.ai_training.name
  policy_arn = aws_iam_policy.ai_training_policy.arn
}
