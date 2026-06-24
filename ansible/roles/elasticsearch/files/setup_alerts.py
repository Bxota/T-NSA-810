#!/usr/bin/env python3
"""Provisionne les règles d'alerte Kibana (IaC, idempotent).

Crée :
  - un connector « server-log » (écrit dans les logs Kibana, aucune dépendance externe)
  - règle 1 : pic d'échecs d'authentification SSH (brute-force)
  - règle 2 : pic de logs d'erreur sur l'infra

Les règles sont de type `.es-query` : elles exécutent une requête ES sur filebeat-*
toutes les 5 min et déclenchent au-dessus d'un seuil.

Piloté par variables d'environnement : KIBANA_URL, ELASTIC_USER, ELASTIC_PASSWORD.
Idempotent : une règle/connector portant le même nom n'est pas recréé.
"""
import os
import sys
import requests

KIBANA_URL = os.environ.get("KIBANA_URL", "http://localhost:5601").rstrip("/")
USER = os.environ.get("ELASTIC_USER", "elastic")
PASSWORD = os.environ["ELASTIC_PASSWORD"]

s = requests.Session()
s.auth = (USER, PASSWORD)
s.headers.update({"kbn-xsrf": "true", "Content-Type": "application/json"})


def find_rule(name):
    r = s.get(f"{KIBANA_URL}/api/alerting/rules/_find",
              params={"search": name, "search_fields": "name"}, timeout=30)
    r.raise_for_status()
    for rule in r.json().get("data", []):
        if rule["name"] == name:
            return rule
    return None


def ensure_connector():
    """Connector server-log (idempotent par nom)."""
    name = "CIA - Journal Kibana"
    r = s.get(f"{KIBANA_URL}/api/actions/connectors", timeout=30)
    r.raise_for_status()
    for c in r.json():
        if c["name"] == name:
            return c["id"]
    r = s.post(f"{KIBANA_URL}/api/actions/connector",
               json={"name": name, "connector_type_id": ".server-log", "config": {}, "secrets": {}},
               timeout=30)
    r.raise_for_status()
    return r.json()["id"]


def es_query_rule(name, kuery, threshold, connector_id, message):
    if find_rule(name):
        print(f"[skip] règle déjà présente : {name}")
        return
    query = '{"bool":{"filter":[{"query_string":{"query":"%s"}}]}}' % kuery
    body = {
        "name": name,
        "rule_type_id": ".es-query",
        "consumer": "alerts",
        "schedule": {"interval": "5m"},
        "tags": ["cia", "securite"],
        "params": {
            "searchType": "esQuery",
            "timeField": "@timestamp",
            "esQuery": '{"query":%s}' % query,
            "index": ["filebeat-*"],
            "threshold": [threshold],
            "thresholdComparator": ">",
            "timeWindowSize": 5,
            "timeWindowUnit": "m",
            "size": 100,
            "aggType": "count",
            "groupBy": "all",
            "excludeHitsFromPreviousRun": True,
        },
        "actions": [{
            "group": "query matched",
            "id": connector_id,
            "params": {"level": "warn", "message": message},
            "frequency": {"notify_when": "onActiveAlert", "throttle": None, "summary": False},
        }],
    }
    r = s.post(f"{KIBANA_URL}/api/alerting/rule", json=body, timeout=30)
    r.raise_for_status()
    print(f"[ok] règle créée : {name}")


def main():
    cid = ensure_connector()
    es_query_rule(
        "CIA - Brute-force SSH",
        'message:(\\"Failed password\\" OR \\"authentication failure\\" OR \\"Invalid user\\")',
        10, cid,
        "Pic d'échecs d'authentification SSH détecté ({{context.value}} en 5 min) "
        "— possible brute-force. Vérifier le bastion.",
    )
    es_query_rule(
        "CIA - Pic de logs d'erreur",
        'message:(error OR ERROR OR critical OR fatal)',
        100, cid,
        "Pic de logs d'erreur sur l'infrastructure ({{context.value}} en 5 min).",
    )
    print("Provisioning des alertes terminé.")


if __name__ == "__main__":
    try:
        main()
    except requests.HTTPError as e:
        print(f"Erreur API Kibana : {e}\n{e.response.text}", file=sys.stderr)
        sys.exit(1)
