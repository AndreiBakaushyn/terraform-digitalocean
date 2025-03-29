# Показывает IP-адреса, по которым можно будет подключиться к кластеру
output "kubeconfig_path" {
  description = "Путь к kubeconfig для kubectl"
  value       = local_file.kubeconfig.filename
}

output "kubernetes_cluster_status" {
  description = "Текущий статус кластера Kubernetes"
  value       = digitalocean_kubernetes_cluster.my_cluster.status
}
output "kibana_url" {
  description = "Внешний IP Kibana"
  value       = kubernetes_service.kibana_external.status[0].load_balancer[0].ingress[0].ip
}

output "grafana_url" {
  description = "Внешний IP Grafana"
  value       = kubernetes_service.grafana_external.status[0].load_balancer[0].ingress[0].ip
}
