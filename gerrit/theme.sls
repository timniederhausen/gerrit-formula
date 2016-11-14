# -*- coding: utf-8 -*-
# vim: ft=yaml

{% from 'gerrit/map.jinja' import settings, directory, sls_block with context -%}

{% if settings.theme.header %}
gerrit_site_header:
  file.managed:
    - name: {{ directory }}/etc/GerritSiteHeader.html
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - watch_in:
      - service: gerrit_service
    {{ sls_block(settings.theme.header) | indent(4) }}
{% endif %}

{% if settings.theme.css %}
gerrit_site_css:
  file.managed:
    - name: {{ directory }}/etc/GerritSite.css
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - watch_in:
      - service: gerrit_service
    {{ sls_block(settings.theme.css) | indent(4) }}
{% endif %}

gerrit_static:
  file.directory:
    - name: {{ directory }}/static
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - makedirs: true

{% for name, opts in settings.theme.static.items() %}
gerrit_static_{{ name }}:
  file.managed:
    - name: {{ directory }}/{{ name }}
    {{ sls_block(opts) | indent(4) }}
    - requires:
      - file: gerrit_static
    - watch_in:
      - service: gerrit_service
{% endfor %}
