# Указываем используемых провайдеров и их версии
terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean" # провайдер для DigitalOcean
      version = "~> 2.0"                     # использовать версию 2.x
    }
    helm = {
      source  = "hashicorp/helm"            # провайдер для Helm (управление чартами)
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"      # провайдер для Kubernetes (работа с объектами)
      version = "~> 2.11"
    }
  }
}

# Подключаемся к DigitalOcean, используя API-токен
provider "digitalocean" {
  token = var.do_token
}

# Настройка доступа к кластеру Kubernetes
provider "kubernetes" {
  config_path = "${path.module}/kubeconfig.yaml" # путь к kubeconfig, сгенерированному после создания кластера
}

# Настройка провайдера Helm (он использует тот же kubeconfig)
provider "helm" {
  kubernetes {
    config_path = "${path.module}/kubeconfig.yaml"
  }
}

# Создание Kubernetes-кластера в DigitalOcean
resource "digitalocean_kubernetes_cluster" "my_cluster" {
  name    = "my-k8s-cluster"      # имя кластера
  region  = "nyc1"                # регион (можно заменить на fra1, sgp1 и т.д.)
  version = "1.29.1-do.0"         # версия Kubernetes, поддерживаемая DO

  # Определение нод-пула (рабочие машины)
  node_pool {
    name       = "web-pool"       # имя группы узлов
    size       = "s-2vcpu-4gb"    # тип виртуалки
    node_count = 3                # количество узлов
  }
}

# Сохраняем kubeconfig локально после создания кластера
resource "local_file" "kubeconfig" {
  content  = digitalocean_kubernetes_cluster.my_cluster.kube_config[0].raw_config
  filename = "${path.module}/kubeconfig.yaml"
}

# -------------------------------
# Установка ELK стека через Helm
# -------------------------------

resource "helm_release" "elasticsearch" {
  name       = "elasticsearch"         # имя релиза Helm
  namespace  = "logging"               # пространство имён Kubernetes
  create_namespace = true              # создать namespace, если не существует
  repository = "https://helm.elastic.co"  # источник чарта
  chart      = "elasticsearch"         # имя чарта
}

resource "helm_release" "logstash" {
  name       = "logstash"
  namespace  = "logging"
  chart      = "logstash"
  repository = "https://helm.elastic.co"
  depends_on = [helm_release.elasticsearch]  # разворачивать только после Elasticsearch
}

resource "helm_release" "kibana" {
  name       = "kibana"
  namespace  = "logging"
  chart      = "kibana"
  repository = "https://helm.elastic.co"
  depends_on = [helm_release.elasticsearch]
}

# -------------------------------
# Установка Prometheus и Grafana
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
# Р­РєСЃРїРѕРЅРёСЂСѓРµРј Kibana РЅР°СЂСѓР¶Сѓ С‡РµСЂРµР· LoadBalancer
resource "kubernetes_service" "kibana_external" {
  metadata {
    name      = "kibana-external"
    namespace = "logging"
  }

  spec {
    selector = {
      app = "kibana"  # РјРµС‚РєР°, СЃРѕРѕС‚РІРµС‚СЃС‚РІСѓСЋС‰Р°СЏ Kibana
    }

    type = "LoadBalancer"  # РґР°С‘С‚ РІРЅРµС€РЅРёР№ IP-Р°РґСЂРµСЃ

    port {
      port        = 5601           # РІРЅРµС€РЅРёР№ РїРѕСЂС‚
      target_port = 5601           # РІРЅСѓС‚СЂРµРЅРЅРёР№ РїРѕСЂС‚ РїСЂРёР»РѕР¶РµРЅРёСЏ
    }
  }

  depends_on = [helm_release.kibana]
}

# Р­РєСЃРїРѕРЅРёСЂСѓРµРј Grafana РЅР°СЂСѓР¶Сѓ С‡РµСЂРµР· LoadBalancer
resource "kubernetes_service" "grafana_external" {
  metadata {
    name      = "grafana-external"
    namespace = "monitoring"
  }

  spec {
    selector = {
      app.kubernetes.io/name = "grafana"  # РјРµС‚РєР° РїРѕ С‡Р°СЂС‚Сѓ Grafana
    }

    type = "LoadBalancer"

    port {
      port        = 3000
      target_port = 3000
    }
  }

  depends_on = [helm_release.grafana]
}
