# Route53 A record pointing to EC2 public IP
resource "aws_route53_record" "vault" {
  zone_id = var.route53_zone_id
  name    = var.vault_domain
  type    = "A"
  ttl     = 300
  records = [aws_instance.vault.public_ip]

  depends_on = [aws_instance.vault]
}