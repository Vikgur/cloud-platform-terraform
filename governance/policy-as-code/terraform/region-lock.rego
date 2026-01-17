package terraform.region

deny[msg] {
  input.provider.region != "me-central-1"
  msg := "AI инфраструктура должна находиться в утверждённом регионе"
}
