#!/usr/bin/env python3
"""Génère le NDJSON des objets Kibana (data view + visualisations + dashboard).

Objets « legacy aggregation-based » : les plus stables à importer via
l'API saved_objects/_import de Kibana 8.x. Régénère kibana-dashboard.ndjson.

Usage : python3 gen_dashboard.py > kibana-dashboard.ndjson
"""
import json

DV_ID = "filebeat-cia"          # id du data view
DV_TITLE = "filebeat-*"

objects = []


def add(obj):
    objects.append(obj)


def viz(vid, title, vis_state, query=""):
    """Construit un objet visualisation lié au data view.

    query : filtre KQL appliqué à la viz (ex: "event.module:nginx").
    """
    return {
        "id": vid,
        "type": "visualization",
        "attributes": {
            "title": title,
            "visState": json.dumps(vis_state),
            "uiStateJSON": "{}",
            "description": "",
            "version": 1,
            "kibanaSavedObjectMeta": {
                "searchSourceJSON": json.dumps({
                    "query": {"query": query, "language": "kuery"},
                    "filter": [],
                    "indexRefName": "kibanaSavedObjectMeta.searchSourceJSON.index",
                })
            },
        },
        "references": [
            {"name": "kibanaSavedObjectMeta.searchSourceJSON.index", "type": "index-pattern", "id": DV_ID}
        ],
    }


# ── Data view ────────────────────────────────────────────────────────────────
add({
    "id": DV_ID,
    "type": "index-pattern",
    "attributes": {"title": DV_TITLE, "timeFieldName": "@timestamp"},
    "references": [],
})

# ── 1. Métrique : nombre total de logs ───────────────────────────────────────
add(viz("cia-total", "CIA — Total logs", {
    "title": "CIA — Total logs",
    "type": "metric",
    "params": {"metric": {"metricColorMode": "None", "style": {"fontSize": 60}}},
    "aggs": [{"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}}],
}))

# ── 2. Volume de logs dans le temps (date histogram) ─────────────────────────
add(viz("cia-volume", "CIA — Volume de logs dans le temps", {
    "title": "CIA — Volume de logs dans le temps",
    "type": "histogram",
    "params": {"addLegend": True, "addTimeMarker": False, "legendPosition": "right",
               "seriesParams": [{"data": {"id": "1", "label": "Count"}, "type": "histogram",
                                 "mode": "stacked", "valueAxis": "ValueAxis-1", "show": True}]},
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "date_histogram", "schema": "segment",
         "params": {"field": "@timestamp", "interval": "auto", "min_doc_count": 1}},
    ],
}))

# ── 3. Logs par hôte (camembert) ─────────────────────────────────────────────
add(viz("cia-by-host", "CIA — Répartition des logs par hôte", {
    "title": "CIA — Répartition des logs par hôte",
    "type": "pie",
    "params": {"addLegend": True, "legendPosition": "right", "isDonut": True},
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "segment",
         "params": {"field": "host.name", "size": 10, "order": "desc", "orderBy": "1"}},
    ],
}))

# ── 4. Débit de logs par hôte dans le temps (lignes) ─────────────────────────
add(viz("cia-rate-host", "CIA — Débit de logs par hôte", {
    "title": "CIA — Débit de logs par hôte",
    "type": "line",
    "params": {"addLegend": True, "legendPosition": "right",
               "seriesParams": [{"data": {"id": "1", "label": "Count"}, "type": "line",
                                 "mode": "normal", "valueAxis": "ValueAxis-1", "show": True,
                                 "drawLinesBetweenPoints": True, "showCircles": True}]},
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "date_histogram", "schema": "segment",
         "params": {"field": "@timestamp", "interval": "auto", "min_doc_count": 1}},
        {"id": "3", "enabled": True, "type": "terms", "schema": "group",
         "params": {"field": "host.name", "size": 10, "order": "desc", "orderBy": "1"}},
    ],
}))

# ── 5. Top fichiers de logs (table) ──────────────────────────────────────────
add(viz("cia-top-files", "CIA — Top fichiers sources", {
    "title": "CIA — Top fichiers sources",
    "type": "table",
    "params": {"perPage": 10, "showPartialRows": False, "showTotal": False},
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "bucket",
         "params": {"field": "log.file.path", "size": 15, "order": "desc", "orderBy": "1"}},
    ],
}))

# ── Dashboard ────────────────────────────────────────────────────────────────
panels = [
    ("cia-total",     {"x": 0,  "y": 0, "w": 12, "h": 8}),
    ("cia-by-host",   {"x": 12, "y": 0, "w": 18, "h": 15}),
    ("cia-volume",    {"x": 0,  "y": 8, "w": 12, "h": 15}),
    ("cia-rate-host", {"x": 30, "y": 0, "w": 18, "h": 15}),
    ("cia-top-files", {"x": 0,  "y": 23, "w": 48, "h": 12}),
]
panels_json, refs = [], []
for i, (vid, geo) in enumerate(panels, start=1):
    pid = f"panel_{i}"
    panels_json.append({
        "version": "8.19.0",
        "type": "visualization",
        "gridData": {**geo, "i": pid},
        "panelIndex": pid,
        "embeddableConfig": {},
        "panelRefName": f"panel_{i}",
    })
    refs.append({"name": f"panel_{i}", "type": "visualization", "id": vid})

add({
    "id": "cia-observability",
    "type": "dashboard",
    "attributes": {
        "title": "CIA — Observabilité Infrastructure",
        "description": "Vue centralisée des logs Filebeat des 4 VMs (netbox, elastic, bastion, web).",
        "panelsJSON": json.dumps(panels_json),
        "optionsJSON": json.dumps({"useMargins": True, "hidePanelTitles": False}),
        "version": 1,
        "timeRestore": True,
        "timeTo": "now",
        "timeFrom": "now-24h",
        "refreshInterval": {"pause": False, "value": 30000},
        "kibanaSavedObjectMeta": {"searchSourceJSON": json.dumps({"query": {"query": "", "language": "kuery"}, "filter": []})},
    },
    "references": refs,
})

# ══════════════════════════════════════════════════════════════════════════════
# Dashboard Nginx — exploite le parsing Filebeat (module nginx).
# Toutes les viz sont filtrées sur event.module:nginx.
# ══════════════════════════════════════════════════════════════════════════════
NGINX_Q = "event.module:nginx"

# ── N1. Total requêtes HTTP ──────────────────────────────────────────────────
add(viz("nginx-total", "Nginx — Total requêtes", {
    "title": "Nginx — Total requêtes",
    "type": "metric",
    "params": {"metric": {"metricColorMode": "None", "style": {"fontSize": 60}}},
    "aggs": [{"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}}],
}, query=NGINX_Q))

# ── N2. Répartition des codes HTTP (camembert) ───────────────────────────────
add(viz("nginx-status", "Nginx — Codes HTTP", {
    "title": "Nginx — Codes HTTP",
    "type": "pie",
    "params": {"addLegend": True, "legendPosition": "right", "isDonut": True},
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "segment",
         "params": {"field": "http.response.status_code", "size": 10, "order": "desc", "orderBy": "1"}},
    ],
}, query=NGINX_Q))

# ── N3. Top URLs demandées (table) ───────────────────────────────────────────
add(viz("nginx-urls", "Nginx — Top URLs", {
    "title": "Nginx — Top URLs",
    "type": "table",
    "params": {"perPage": 10, "showPartialRows": False, "showTotal": True, "totalFunc": "sum"},
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "bucket",
         "params": {"field": "url.original", "size": 20, "order": "desc", "orderBy": "1"}},
    ],
}, query=NGINX_Q))

# ── N4. Top IPs clientes (table) ─────────────────────────────────────────────
add(viz("nginx-ips", "Nginx — Top IPs clientes", {
    "title": "Nginx — Top IPs clientes",
    "type": "table",
    "params": {"perPage": 10, "showPartialRows": False, "showTotal": True, "totalFunc": "sum"},
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "bucket",
         "params": {"field": "source.address", "size": 15, "order": "desc", "orderBy": "1"}},
    ],
}, query=NGINX_Q))

# ── N5. Codes HTTP dans le temps, empilés par classe (barres) ────────────────
add(viz("nginx-status-time", "Nginx — Codes HTTP dans le temps", {
    "title": "Nginx — Codes HTTP dans le temps",
    "type": "histogram",
    "params": {"addLegend": True, "legendPosition": "right",
               "seriesParams": [{"data": {"id": "1", "label": "Count"}, "type": "histogram",
                                 "mode": "stacked", "valueAxis": "ValueAxis-1", "show": True}]},
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "date_histogram", "schema": "segment",
         "params": {"field": "@timestamp", "interval": "auto", "min_doc_count": 1}},
        {"id": "3", "enabled": True, "type": "terms", "schema": "group",
         "params": {"field": "http.response.status_code", "size": 10, "order": "desc", "orderBy": "1"}},
    ],
}, query=NGINX_Q))

# ── N6. Erreurs 4xx/5xx dans le temps (lignes, filtre status>=400) ───────────
add(viz("nginx-errors", "Nginx — Erreurs 4xx/5xx", {
    "title": "Nginx — Erreurs 4xx/5xx",
    "type": "line",
    "params": {"addLegend": True, "legendPosition": "right",
               "seriesParams": [{"data": {"id": "1", "label": "Erreurs"}, "type": "line",
                                 "mode": "normal", "valueAxis": "ValueAxis-1", "show": True,
                                 "drawLinesBetweenPoints": True, "showCircles": True}]},
    "aggs": [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "date_histogram", "schema": "segment",
         "params": {"field": "@timestamp", "interval": "auto", "min_doc_count": 1}},
    ],
}, query=f"{NGINX_Q} and http.response.status_code >= 400"))

nginx_panels = [
    ("nginx-total",       {"x": 0,  "y": 0,  "w": 12, "h": 8}),
    ("nginx-status",      {"x": 12, "y": 0,  "w": 18, "h": 15}),
    ("nginx-errors",      {"x": 30, "y": 0,  "w": 18, "h": 15}),
    ("nginx-status-time", {"x": 0,  "y": 15, "w": 30, "h": 15}),
    ("nginx-urls",        {"x": 30, "y": 15, "w": 18, "h": 15}),
    ("nginx-ips",         {"x": 0,  "y": 30, "w": 48, "h": 12}),
]
n_panels_json, n_refs = [], []
for i, (vid, geo) in enumerate(nginx_panels, start=1):
    pid = f"npanel_{i}"
    n_panels_json.append({
        "version": "8.19.0",
        "type": "visualization",
        "gridData": {**geo, "i": pid},
        "panelIndex": pid,
        "embeddableConfig": {},
        "panelRefName": f"panel_{i}",
    })
    n_refs.append({"name": f"panel_{i}", "type": "visualization", "id": vid})

add({
    "id": "cia-nginx",
    "type": "dashboard",
    "attributes": {
        "title": "CIA — Nginx (logs parsés)",
        "description": "Trafic web Nginx issu du parsing Filebeat (module nginx) : codes HTTP, URLs, IPs, erreurs.",
        "panelsJSON": json.dumps(n_panels_json),
        "optionsJSON": json.dumps({"useMargins": True, "hidePanelTitles": False}),
        "version": 1,
        "timeRestore": True,
        "timeTo": "now",
        "timeFrom": "now-24h",
        "refreshInterval": {"pause": False, "value": 30000},
        "kibanaSavedObjectMeta": {"searchSourceJSON": json.dumps({"query": {"query": "", "language": "kuery"}, "filter": []})},
    },
    "references": n_refs,
})

for o in objects:
    print(json.dumps(o))
