{%- from 'gerrit/install.sls' import gerrit_files -%}

include:
  - gerrit.install
  - gerrit.service

extend:
  gerrit_service:
    service:
      - watch:
        {%- for file in gerrit_files %}
        - {{ file }}
        {%- endfor %}
