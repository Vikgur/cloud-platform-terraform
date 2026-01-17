resource "aws_iam_role" "ai_inference" {
  name = "ai-inference"

  assume_role_policy = data.aws_iam_policy_document.ai_inference_trust.json
}

resource "aws_iam_policy" "ai_inference_policy" {
  name = "ai-inference-policy"

  policy = data.aws_iam_policy_document.ai_inference_permissions.json
}

resource "aws_iam_role_policy_attachment" "ai_inference_attach" {
  role       = aws_iam_role.ai_inference.name
  policy_arn = aws_iam_policy.ai_inference_policy.arn
}
