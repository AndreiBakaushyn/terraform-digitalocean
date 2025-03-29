# ��������� ������������ ����������� � �� ������
terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean" # ��������� ��� DigitalOcean
      version = "~> 2.0"                     # ������������ ������ 2.x
    }
    helm = {
      source  = "hashicorp/helm"            # ��������� ��� Helm (���������� �������)
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"      # ��������� ��� Kubernetes (������ � ���������)
      version = "~> 2.11"
    }
  }
}

# ������������ � DigitalOcean, ��������� API-�����
provider "digitalocean" {
  token = var.do_token
}

# ��������� ������� � �������� Kubernetes
provider "kubernetes" {
  config_path = "${path.module}/kubeconfig.yaml" # ���� � kubeconfig, ���������������� ����� �������� ��������
}

# ��������� ���������� Helm (�� ���������� ��� �� kubeconfig)
provider "helm" {
  kubernetes {
    config_path = "${path.module}/kubeconfig.yaml"
  }
}

# �������� Kubernetes-�������� � DigitalOcean
resource "digitalocean_kubernetes_cluster" "my_cluster" {
  name    = "my-k8s-cluster"      # ��� ��������
  region  = "nyc1"                # ������ (����� �������� �� fra1, sgp1 � �.�.)
  version = "1.29.1-do.0"         # ������ Kubernetes, �������������� DO

  # ����������� ���-���� (������� ������)
  node_pool {
    name       = "web-pool"       # ��� ������ �����
    size       = "s-2vcpu-4gb"    # ��� ���������
    node_count = 3                # ���������� �����
  }
}

# ��������� kubeconfig �������� ����� �������� ��������
resource "local_file" "kubeconfig" {
  content  = digitalocean_kubernetes_cluster.my_cluster.kube_config[0].raw_config
  filename = "${path.module}/kubeconfig.yaml"
}

# -------------------------------
# ��������� ELK ����� ����� Helm
# -------------------------------

resource "helm_release" "elasticsearch" {
  name       = "elasticsearch"         # ��� ������ Helm
  namespace  = "logging"               # ������������ ��� Kubernetes
  create_namespace = true              # ������� namespace, ���� �� ����������
  repository = "https://helm.elastic.co"  # �������� �����
  chart      = "elasticsearch"         # ��� �����
}

resource "helm_release" "logstash" {
  name       = "logstash"
  namespace  = "logging"
  chart      = "logstash"
  repository = "https://helm.elastic.co"
  depends_on = [helm_release.elasticsearch]  # ������������� ������ ����� Elasticsearch
}

resource "helm_release" "kibana" {
  name       = "kibana"
  namespace  = "logging"
  chart      = "kibana"
  repository = "https://helm.elastic.co"
  depends_on = [helm_release.elasticsearch]
}

# -------------------------------
# ��������� Prometheus � Grafana
# -------------------------------

resource "helm_release" "prometheus" {
  name       = "prometheus"
  namespace  = "monitoring"
  create_namespace = true
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
}

resource "helm_release" "grafana" {
  name       = "grafana"
  namespace  = "monitoring"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
}
# Экспонируем Kibana наружу через LoadBalancer
resource "kubernetes_service" "kibana_external" {
  metadata {
    name      = "kibana-external"
    namespace = "logging"
  }

  spec {
    selector = {
      app = "kibana"  # метка, соответствующая Kibana
    }

    type = "LoadBalancer"  # даёт внешний IP-адрес

    port {
      port        = 5601           # внешний порт
      target_port = 5601           # внутренний порт приложения
    }
  }

  depends_on = [helm_release.kibana]
}

# Экспонируем Grafana наружу через LoadBalancer
resource "kubernetes_service" "grafana_external" {
  metadata {
    name      = "grafana-external"
    namespace = "monitoring"
  }

  spec {
    selector = {
      app.kubernetes.io/name = "grafana"  # метка по чарту Grafana
    }

    type = "LoadBalancer"

    port {
      port        = 3000
      target_port = 3000
    }
  }

  depends_on = [helm_release.grafana]
}
