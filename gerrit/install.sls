# -*- coding: utf-8 -*-
# vim: ft=yaml

{% from "gerrit/map.jinja" import settings, directory with context -%}
{% set gerrit_war_file = "gerrit-" ~ settings.package.version ~ ".war" -%}

{%- set gerrit_files = [] -%}

install_jre:
  pkg.installed:
    - name: {{ settings.jre }}

install_git:
  pkg.installed:
    - name: git

gerrit_user:
  user.present:
    - name: {{ settings.user }}

gerrit_group:
  group.present:
    - name: {{ settings.group }}

create_etc_dir:
  file.directory:
    - name: {{ directory }}/etc
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - makedirs: true

create_lib_dir:
  file.directory:
    - name: {{ directory }}/lib
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - makedirs: true

{% for name, library in salt['pillar.get']('gerrit:libraries', {}).items() %}
install_{{ name }}_lib:
  file.managed:
    - name: {{ directory }}/lib/{{ name }}.jar
    - source: {{ library.source }}
{% if library.source_hash is defined %}
    - source_hash: {{ library.source_hash }}
{% endif %}
    - user: {{ settings.user }}
    - group: {{ settings.group }}
{% do gerrit_files.append('install_' + name + '_lib') %}
{% endfor %}

create_plugins_dir:
  file.directory:
    - name: {{ directory }}/plugins
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - makedirs: true

{% for name, plugin in salt['pillar.get']('gerrit:plugins', {}).items() %}
install_{{ name }}_plugin:
  file.managed:
    - name: {{ directory }}/plugins/{{ name }}.jar
    - source: {{ plugin.source }}
{% if plugin.source_hash is defined %}
    - source_hash: {{ plugin.source_hash }}
{% endif %}
    - user: {{ settings.user }}
    - group: {{ settings.group }}
{% do gerrit_files.append('install_' + name + '_plugin') %}
{% endfor %}

gerrit_war:
  file.managed:
    - name: {{ settings.base_directory }}/{{ gerrit_war_file }}
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - source: {{ settings.package.base_url }}/{{ gerrit_war_file }}
    - skip_verify: true

gerrit_config:
  file.managed:
    - name: {{ directory }}/etc/gerrit.config
    - source: salt://gerrit/files/gerrit.config
    - template: jinja
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - makedirs: true
    - defaults:
        settings: {{ settings|json }}
        war_file: {{ gerrit_war_file }}
{% do gerrit_files.append('gerrit_config') %}

secure_config:
  file.managed:
    - name: {{ directory }}/etc/secure.config
    - source: salt://gerrit/files/secure.config
    - template: jinja
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - makedirs: true
    - defaults:
        secure: {{ settings.secure|json }}
{% do gerrit_files.append('secure_config') %}

{% if settings.custom_log4j_config %}
gerrit_log4j_config:
  file.managed:
    - name: {{ directory }}/etc/log4j.properties
    - source: salt://gerrit/files/log4j.properties
    - template: jinja
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - defaults:
        directory: {{ directory | yaml_encode }}
{% do gerrit_files.append('gerrit_log4j_config') %}
{% endif %}

{% if settings.custom_cacerts %}
gerrit_cacerts:
  file.managed:
    - name: {{ directory }}/etc/cacerts
    - source: salt://gerrit/files/cacerts
    - user: {{ settings.user }}
    - group: {{ settings.group }}
{% do gerrit_files.append('gerrit_cacerts') %}
{% endif %}

{# On FreeBSD setting the site path is handled by the rc.d script,
   which allows us to skip writing to /etc
   (which shouldn't be used for installed applications). #}
{% if grains.os_family != 'FreeBSD' %}
/etc/default/gerritcodereview:
  file.managed:
    - contents: GERRIT_SITE={{ directory }}
    - user: root
    - group: root
    - mode: 0755
{% endif %}

gerrit_init:
  cmd.run:
    - name: |
{%- if settings.core_plugins is not none %}
    {% for plugin in settings.core_plugins %}
        java -jar {{ settings.base_directory }}/{{ gerrit_war_file }} init --batch --install-plugin {{ plugin }} -d {{ directory }}
    {%- endfor %}
{%- else %}
        java -jar {{ settings.base_directory }}/{{ gerrit_war_file }} init --batch -d {{ directory }}
{%- endif %}
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - cwd: {{ settings.base_directory }}
    - unless: test -d {{ directory }}/bin

{% if settings.secondary_index %}
secondary_index:
  cmd.wait:
    - name: |
        java -jar {{ settings.base_directory }}/{{ gerrit_war_file }} reindex -d {{ directory }}
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - cwd: {{ settings.base_directory }}
    - watch:
      - cmd: gerrit_init
{% endif %}

link_logs_to_var_log_gerrit:
  file.symlink:
    - name: /var/log/gerrit
    - target: {{ directory }}/logs

gerrit_init_script:
{% if grains.os_family == 'FreeBSD' %}
  file.managed:
    - name: /usr/local/etc/rc.d/{{ settings.service }}
    - source: salt://gerrit/files/freebsd-rc.sh
    - template: jinja
    - mode: 755
    - defaults:
        service_name: {{ settings.service }}
        directory: {{ directory | yaml_encode }}
        user: {{ settings.user | yaml_encode }}
{% else %}
  file.symlink:
    - name: /etc/init.d/{{ settings.service }}
    - target: {{ directory }}/bin/gerrit.sh
    - user: root
    - group: root
{% endif %}
{% do gerrit_files.append('gerrit_init_script') %}
