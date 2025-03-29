# API токен DigitalOcean. Будет передан через команду или файл terraform.tfvars
variable "do_token" {
  description = "DigitalOcean API Token"
  type        = string
  sensitive   = true  # скрывает значение при выводе в терминале
}
