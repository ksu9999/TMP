#!/bin/bash

SUPINFO_VERSION="1.19.4"

DB_USER_CONFIG=
DB_PASS_CONFIG=
DB_HOST_CONFIG=
DB_NAME_CONFIG=
DB_PORT_CONFIG=

PRODUCT_NAME_LC="r-vision"
PRODUCT_BASE_PATH="/opt/$PRODUCT_NAME_LC"

CRED="\e[1;31m"
CGREEN="\e[1;32m"
CNORM="\e[0m"

AGG_HOST_LOG=aggregated_host_info.log
AGG_APP_LOG=aggregated_app_info.log


init_dir() {
  if [[ $DEBUG ]]; then echo "[DEBUG] init_dir function LOG_PATH var is $LOG_PATH"; fi
  mkdir -p "$LOG_PATH"
  cd "$LOG_PATH" || exit_on_error "Directory $LOG_PATH not available, exit script"
  mkdir -p "$LOG_PATH"/system
  mkdir -p "$LOG_PATH"/logs
  mkdir -p "$LOG_PATH"/config
  mkdir -p "$LOG_PATH"/pm2
  mkdir -p "$LOG_PATH"/sql/stats
  mkdir -p "$LOG_PATH"/sql/config
  mkdir -p "$LOG_PATH"/sql/devstat
  mkdir -p "$LOG_PATH"/docker
  mkdir -p "$LOG_PATH"/cluster
  mkdir -p "$LOG_PATH"/app_cluster
  mkdir -p "$LOG_PATH"/db_cluster
  mkdir -p "$LOG_PATH"/diagnostic
  chmod -R 777 "$LOG_PATH"
  echo "$SUPINFO_VERSION" >script_version.txt
}

get_installation_type() {
  local MARKER_DOCKER_OLD="${PRODUCT_BASE_PATH}/.env"
  local MARKER_DOCKER_5_3="${PRODUCT_BASE_PATH}/data/smp/volumes/common/config"
  local MARKER_PM2='/opt/smp/package.json'
  local MARKER_DOCKER_5_4="${PRODUCT_BASE_PATH}/data/smp/.env"

  CONFIG_FILE=
  SYS_TYPE=
  if [ -f "$MARKER_DOCKER_5_3" ]; then
    SYS_TYPE="DOCKER"
    CONFIG_FILE="${PRODUCT_BASE_PATH}/data/smp/volumes/common/config"
    CONFIG_5_3=yes
  elif [ -f "$MARKER_DOCKER_5_4" ]; then
    SYS_TYPE="DOCKER"
    CONFIG_FILE="${PRODUCT_BASE_PATH}/data/smp/.env"
    CONFIG_5_4=yes
  elif [ -f "$MARKER_DOCKER_OLD" ]; then
    SYS_TYPE="DOCKER_OLD"
  elif [ -f "$MARKER_PM2" ]; then
    SYS_TYPE="PM2"
    CONFIG_FILE="/etc/smp/config"
  else
    echo -e "\n${CRED}Failed to determine installation type, assume it's Collector or DB server${CNORM}\n"
    SYS_TYPE="NOAPP"
  fi

  # if [ -z "$SYS_TYPE" ]; then
  #   echo -e "\n${CRED}Failed to determine installation type, assume it's Docker${CNORM}\n"
  #   SYS_TYPE="DOCKER"
  # fi

}

get_installed_version(){
  SYS_VERSION=
  case "$SYS_TYPE" in
    "DOCKER")
      SYS_VERSION="$(head -q -n1 ${PRODUCT_BASE_PATH}/app/smp/packageVersion 2>/dev/null)"
    ;;
    "PM2")
      SYS_VERSION="$(grep version /opt/smp/package.json | sed "s/.*: \"\(.*\)\".*/\1/")"
    ;;
  esac
  if [[ $SYS_TYPE == "NOAPP" ]]; then
    echo "No application on server"
  elif [ -z "$SYS_VERSION" ]; then
    echo -e "\n${CRED}Failed to determine version${CNORM}\n"
  else
    echo "$SYS_VERSION" >"$LOG_PATH"/system/sys_version.txt
  fi
}


collect_system_info() {
  # System and devices
  cd "$LOG_PATH"/system || exit_on_error "Directory $LOG_PATH/system not available, exit script"
  echo "Gathering system info"
  dmidecode >sys_dmidecode.txt        # List devices
  cat /etc/*-release >sys_release.txt # OS version for Centos/Redhat
  if command -v lsb_release &>/dev/null; then lsb_release -idrc >>sys_release.txt; else echo "lsb_release not installed" >&2; fi # OS version for Debian/Ubuntu
  uname -a >sys_uname.txt             # Kernel version
  cat /proc/meminfo >sys_memory.txt   # Memory status
  timedatectl >sys_timedatectl.txt    # Time, NTP, timezone info
  uptime >sys_uptime.txt              # Time from the last boot
  last >sys_last.txt                  # Last users login and system reboot
  if command -v yum &>/dev/null; then yum list installed >sys_yum.txt; else echo "yum not installed" >&2; fi     # Installed packages for Centos/Redhat
  if command -v dpkg &>/dev/null; then dpkg -l >sys_dpkg.txt; else echo "dpkg not installed" >&2; fi                # Installed packages for Debian/Ubuntu
  dmesg -H >sys_dmesg.txt             # Last boot system info + kernel and hardware errors
  lsmod >sys_lsmod.txt                # Loaded modules
  # Disks and partitions
  echo "Gathering free space info"
  df -haT >disk_df_hat.txt       # Disk usage/free space
  parted -l >disk_parted_l.txt   # Disks and partitions - full info
  lsblk -i >disk_lsblk_i.txt # Disks and partitions - short info
  pvdisplay >disk_lvm.txt        # Status LVM - PV
  vgdisplay >>disk_lvm.txt       # Status LVM - VG
  lvdisplay >>disk_lvm.txt       # Status LVM - LV
  # Directory with possible problems
  #{
  #  ls -la /etc/ /root/ /var/log
  #  ls -la /opt/ /opt/smp/ /opt/collectorjs/ /opt/smp/dataFiles/
  #  ls -la /opt/smp/logs /opt/collectorjs/logs
  #  ls -la /etc/nginx/ /etc/nginx/ssl/ /etc/nginx/ssl/backup
  #  ls -la /var/lib/pgsql/11/data/ /opt/smp/updates/
  #} >dir_list.txt
  #du -hd2 /opt/ >dir_du_opt.txt                #
  #du -hd2 /var/lib/pgsql/11/ >dir_du_pgsql.txt #
  # Processes and files
  echo "Gathering processes info"
  ps aux >proc_ps_aux.txt                      # Active procesess
  top -b -n 1 >proc_top_1.txt                  # System load - CPU, RAM, running processes
  if command -v pstree &>/dev/null; then pstree -a >proc_pstree_a.txt; else echo "pstree not found" >&2; fi                 # Processes tree
  if  [[ "command -v lsof &>/dev/null" ]] && [[ -z $LIMIT ]]; then lsof -nlP >proc_lsof_nlp.txt; else echo "lsof not found or limited collection" >&2; fi                  # Opened files, connections, etc
  systemctl >proc_systemctl.txt                # Full system services info
  systemctl status >proc_systemctl_status.txt  # Active system services and short info
  # Python
  python -V &>py2_version.txt                  # Python2 Version
  if command -v pip &>/dev/null; then pip list -v >py2_pip_list.txt; else echo "pip not found" >&2; fi                # List of PIP installed packages
  if command -v python3 &>/dev/null; then python3 -V &>py3_version.txt; else echo "python3 not found" >&2; fi                 # Python3 Version
  if command -v pip3 &>/dev/null; then pip3 list -v >py3_pip_list.txt; else echo "pip3 not found" >&2; fi               # List of PIP3 installed packages
  # Network and firewall
  echo "Gathering network info"
  ip addr >ip_addr.txt                         # Network interfaces
  ip route >ip_route.txt                       # Route table
  cat /etc/resolv.conf >ip_dns.txt             # DNS settings
  netstat -nlp >ip_netstat_nlp.txt             # Ports and sockets in LISTENING status
  netstat -np >ip_netstat_np.txt               # All established connections
  if command -v firewall-cmd &>/dev/null; then firewall-cmd --list-all >ip_firewall_cmd.txt; else echo "firewall-cmd not found" >&2; fi  # Active firewall zones
  {
    iptables -vnL -t filter
    iptables -vnL -t nat
    iptables -vnL -t mangle
    iptables -vnL -t raw
    iptables -vnL -t security
  } >ip_iptables_nl.txt # Full IpTables list
  iptables-save >ip_iptables_save.txt          # Full iptables-save list
  # Mandatory access control info
  if command -v apparmor_status &>/dev/null; then apparmor_status --verbose >mandat_apparmor.txt; else echo "apparmor_status not found" >&2; fi
  if command -v sestatus &>/dev/null; then sestatus -v >mandat_se_status.txt; else echo "sestatus not found" >&2; fi

}

collect_file_config() {
  cd "$LOG_PATH"/config || exit_on_error "Directory $LOG_PATH/config not available, exit script"

    case "$SYS_TYPE" in
    "DOCKER")
      grep "HOST_FOR_PORTS" /etc/environment >host_env_port_open.txt

      if [[ -d "${PRODUCT_BASE_PATH}"/app/smp ]];then
        if [[ -f "${PRODUCT_BASE_PATH}"/data/smp/volumes/common/config ]];then
           echo "Config file in common" >&2
           grep -av "pass" "${PRODUCT_BASE_PATH}"/data/smp/volumes/common/config >config_smp.txt
           cat "${PRODUCT_BASE_PATH}"/data/smp/.env > smp_env.log
           grep -a "version" "${PRODUCT_BASE_PATH}"/data/smp/volumes/common/config >smp_version.txt                   # System version

        elif [[ -f "${PRODUCT_BASE_PATH}"/data/smp/.env ]];then
           echo "Config file in env-s(5.4)" >&2
           grep -av "pass" "${PRODUCT_BASE_PATH}"/data/smp/.env >config_smp.txt;
           grep -a "version" "${PRODUCT_BASE_PATH}"/data/smp/.env >smp_version.txt
        else
           echo "Config file not found" >&2
        fi
        cat "${PRODUCT_BASE_PATH}"/data/smp/defaults.env > smp_defaults_env.log
        if [[ -f "${PRODUCT_BASE_PATH}"/data/smp/.env.defaults ]];then cat "${PRODUCT_BASE_PATH}"/data/smp/.env.defaults > smp_env_defaults.log; fi
        cat "${PRODUCT_BASE_PATH}"/data/smp/.env-s3 > smp_envs-s3.log
        cat "${PRODUCT_BASE_PATH}"/app/smp/packageVersion > smp_installed_version.log
        mkdir smp-compose
        cp "${PRODUCT_BASE_PATH}"/app/smp/docker-compose/*.yml ./smp-compose/
      fi
      if [[ -d "${PRODUCT_BASE_PATH}"/app/db ]];then
        docker exec "$(docker ps -qaf "name=postgresql")" cat /var/lib/postgresql/data/postgresql.conf >config_postgresql.txt # Config postgresql
        docker exec "$(docker ps -qaf "name=postgresql")" cat /var/lib/postgresql/data/rvision.conf >config_postgresql_rvision.txt # Config postgresql
        cat "${PRODUCT_BASE_PATH}"/data/db/cfg/custom.conf >config_postgresql_custom.txt # Config postgresql
        docker exec "$(docker ps -qaf "name=postgresql")" cat /var/lib/postgresql/data/pg_hba.conf >config_pg_hba.txt         # Config pg_hba
        cat "${PRODUCT_BASE_PATH}"/app/db/packageVersion > db_installed_version.log
        mkdir db-compose
        cp "${PRODUCT_BASE_PATH}"/app/db/docker-compose.yml ./db-compose/
      fi
      if [[ -d "${PRODUCT_BASE_PATH}"/app/collectors ]];then
        cat "${PRODUCT_BASE_PATH}"/data/collectors/collectorjs/.env > collector_envs.log
        systemctl status -l collector-updater > collector_updater_status.log
        cat "${PRODUCT_BASE_PATH}"/app/collectors/version > collector_installed_version.log
        mkdir collector-compose
        cp "${PRODUCT_BASE_PATH}"/app/collectors/docker-compose/*.yml ./collector-compose/
      fi

      if [[ -f "${PRODUCT_BASE_PATH}"/data/smp/volumes/nats/nats-server.conf ]];then cp "${PRODUCT_BASE_PATH}"/data/smp/volumes/nats/nats-server.conf .; fi

    ;;
    "PM2")
      grep -av "pass=" /etc/smp/config >config_smp.txt                   # Base config RVision Docker
      cat /etc/nginx/nginx.conf >config_nginx.txt                       # Config Nginx
      cat /var/lib/pgsql/11/data/postgresql.conf >config_postgresql.txt # Config postgresql
      cat /var/lib/pgsql/11/data/pg_hba.conf >config_pg_hba.txt         # Config pg_hba
    ;;
  esac



}

collect_logs_info() {
  cd "$LOG_PATH"/logs || exit_on_error "Directory $LOG_PATH/logs not available, exit script"
  # System install logs
  if [[ -d /tmp/rvn-update-logs ]];then cp -r /tmp/rvn-update-logs .; fi
  if [[ -d /var/lib/pgsql/11/data/log/ ]];then cp $(ls -td /var/lib/pgsql/11/data/log/* | tail -n10) .; fi
  if [[ -d /var/lib/pgsql/14/data/log/ ]];then cp $(ls -td /var/lib/pgsql/14/data/log/* | tail -n10) .; fi
  if [[ -d /var/lib/pgpro/std-11/data/log/ ]];then cp $(ls -td /var/lib/pgpro/std-11/data/log/* | tail -n10) .; fi
  if [[ -d /var/lib/pgpro/std-14/data/log/ ]];then cp $(ls -td /var/lib/pgpro/std-14/data/log/* | tail -n10) .; fi
  if [[ -d /etc/postgresql/11/data/log/ ]];then cp $(ls -td /etc/postgresql/11/data/log/* | tail -n10) .; fi
  if [[ -d /etc/postgresql/14/data/log/ ]];then cp $(ls -td /etc/postgresql/14/data/log/* | tail -n10) .; fi
  if [[ -d /var/lib/jatoba/4/data/log/ ]];then cp $(ls -td /var/lib/jatoba/4/data/log/* | tail -n10) .; fi
  if [[ -f /var/log/messages ]];then tail -n 25000 /var/log/messages >system_app1.log; fi
  if [[ -f /var/log/syslog ]];then tail -n 25000 /var/log/syslog >>system.log; fi
  if [[ -d "${PRODUCT_BASE_PATH}"/bak/logs ]];then find "${PRODUCT_BASE_PATH}"/bak/logs/ -type f -amin +14400 -exec cp -t . {} +; fi
}

collect_cluster_info() {
  # Old cluster info
  cd "$LOG_PATH"/cluster || exit_on_error "Directory $LOG_PATH/cluster not available, exit script"
  crm_mon -Afr -1 >crm_mon_afr.txt
  pcs config >crm_mon_afr.txt
  pcs status --full >psc_status.txt
  pcs status quorum >psc_status_quorum.txt
  pcs status cluster >psc_status_cluster.txt
  pcs status corosync >psc_status_corosync.txt
  pcs status groups >psc_status_groups.txt
  pcs status resources --full >psc_status_resources.txt
  crm_mon -r -1 -X >crm_mon.xml
  # Copy cluster logs
  cp /var/log/cluster/corosync.log* .
  cp /var/log/pacemaker.log* .
}

collect_app_cluster_info(){
cd "$LOG_PATH"/app_cluster || exit_on_error "Directory $LOG_PATH/app_cluster not available, exit script"

systemctl status -l keepalived > keepalive_$(hostname)_status.log
journalctl -u keepalived > keepalive_$(hostname)_journal.log
cat /opt/healtcheck/nodestate > nodestate_$(hostname).log
cat /opt/healtcheck/log > cluster_log_$(hostname).log
grep -v PGPASS  /opt/healthcheck/app_healthcheck.sh > healthcheck_script_$(hostname).log

}

collect_db_cluster_info(){
cd "$LOG_PATH"/db_cluster || exit_on_error "Directory $LOG_PATH/db_cluster not available, exit script"

systemctl status -l patroni > patroni_$(hostname)_status.log
journalctl -u patroni > patroni_$(hostname)_journal.log

#todo: for loop
is_config=$(ls /etc/patroni/*.yml)
if [[ $(systemctl status patroni | grep "$is_config") ]]; then
  patroni_config="$is_config"
elif
  [[ -f /etc/patroni/patroni.yml ]]; then
  patroni_config=/etc/patroni/patroni.yml
else
  echo "Cannot determine patroni config" >&2
  return
fi

patronictl -c $patroni_config list -e > patroni_list_$(hostname).log
patronictl -c /etc/patroni/patroni.yml history > patroni_history_$(hostname).log

}

collect_pm2_info() {
  cd "$LOG_PATH"/pm2 || exit_on_error "Directory $LOG_PATH/pm2 not available, exit script"
  pm2 status >pm2_status.txt                                  # PM2 processes status
  pm2 prettylist | grep -av "__pass" >pm2_prettylist.txt       # List processe + environment variables
  tail -n 15000 /opt/smp/logs/* >pm2_smp_log.txt               # Last 15000 lines of syste, logs
  tail -n 15000 /opt/collectorjs/logs/* >pm2_collector_log.txt # Last 15000 lines of collector logs

}

collect_docker_info() {
  cd "$LOG_PATH"/docker || exit_on_error "Directory $LOG_PATH/docker not available, exit script"
  docker info >docker_info.txt                  # Docker info
  docker version >docker_version.txt            # Docker versions info
  docker ps -a -s >docker_ps.txt                # All containers in system with status
  docker images -a >docker_images.txt           # All images
  docker stats -a --no-stream >docker_stats.txt # Container statistics

  if [ -z "$date_arc" ]; then
    date_log="--tail=15000"
  else
    date_log="--since=$date_arc"
  fi
  # Each container info, logs,status
  cont=$(docker ps -aq | tr '\n' ' ')
  for cont_id in $cont; do
    cont_name=$(docker inspect "$cont_id" -f "{{.Name}}" | awk -F "/" '{print $2}')
    img_name=$(docker ps -a | grep "$cont_id" | awk '{print $2}')
#    echo "$cont_id" "$cont_name" "$img_name"
    mkdir -p container_"$cont_name"
    docker inspect "$cont_id" >container_"$cont_name"/container.json                   # Containers configuration
    docker inspect "$img_name" >container_"$cont_name"/image.json                      # Image configuration
    docker history --no-trunc -H "$img_name" >container_"$cont_name"/image_history.txt # image history
    docker logs -t "$cont_id" "$date_log" &>container_"$cont_name"/logs.txt                # Container logs
    docker top "$cont_id" aux >container_"$cont_name"/top.txt                          # Processes in container
    if [[ "$cont_name" == *"license"* ]]; then
      { 
      echo -e "Server id:"
      docker exec "$cont_id" node /app/sysInfo.js | grep "New Xor" | awk '{print $4}';
      echo -e "License expire:"
      local lic_time=$(docker exec "$cont_id" node /app/checkLicenseStatus.js | grep License | awk '{print $3}');
      local now=$(date +%s)
      if [[ -z "$lic_time" ]]; then 
          echo "License check error" 
      else
        if (( "${lic_time::-3}" - "$now" - 108000000 < 10 ));then
            echo "License is unlimited"  
          else
            date -d \@${lic_time::-3};  
        fi
      fi

      echo -e "Support expire:"
      local supp_time=$(docker exec "$cont_id" node /app/checkLicenseStatus.js | grep Support | awk '{print $3}');

      if [[ -z "$supp_time" ]]; then 
        echo "Support check error" 
      else
        date -d \@${supp_time::-3}; 
      fi 
       
      } >> license.txt
      
      
    fi
  done

  # Volumes info
  docker volume ls >docker_volume.txt # Docker volumes
  volume=$(docker volume ls -q | tr '\n' ' ')
  for volume_id in $volume; do
    mkdir -p volume_"$volume_id"
    docker volume inspect "$volume_id" >volume_"$volume_id"/volume.json # Volumes config
  done


}

collect_db_config_file(){
cd "$LOG_PATH"/config || exit_on_error "Directory $LOG_PATH/config not available, exit script"
echo "Collecting DB config"
detect_db > /dev/null
  
echo "Gathering db config info"
  # Active requests
  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    select * from pg_settings
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >sql_pg_settings.csv

  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    SELECT pg_size_pretty(pg_database_size('rvision')) as rvision_db_size
)
TO STDOUT WITH CSV HEADER;

COPY (
    SELECT pg_size_pretty(pg_database_size('mail_service_db')) as mail_service_db_size
)
TO STDOUT WITH CSV HEADER;

COPY (
    SELECT pg_size_pretty(pg_database_size('collmanager')) as collmanager_db_size
)
TO STDOUT WITH CSV HEADER;

EOF"
  } >sql_pg_table_size.csv


    # DB use statistics
  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY ( select * from pg_stat_statements ) TO STDOUT WITH CSV HEADER;
EOF"
  } >sql_pg_query_statistic_pg_stat_statement.csv

  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    select application_name,count(*) from pg_catalog.pg_stat_activity group by application_name order by count desc
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >sql_pg_stat_group_by_app.csv


{
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    SELECT * FROM pg_stat_activity
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >sql_pg_stat_activity.csv


}


collect_db_stats() {
  cd "$LOG_PATH"/sql/stats || exit_on_error "Directory $LOG_PATH/sql/stats not available, exit script"
if [[ "$NO_DB_ACCESS" == 1 ]]; then return 0;fi

  echo "Gathering db logs"
  # Active requests
  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    SELECT * FROM pg_read_file(pg_current_logfile(),0,15000)
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >sql_pg_logs.csv



  echo "Gathering db stats info"
  # Active requests
  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    select * from pg_settings
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >sql_pg_settings.csv

  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    SELECT pg_size_pretty(pg_database_size('rvision')) as rvision_db_size
)
TO STDOUT WITH CSV HEADER;

COPY (
    SELECT pg_size_pretty(pg_database_size('mail_service_db')) as mail_service_db_size
)
TO STDOUT WITH CSV HEADER;

COPY (
    SELECT pg_size_pretty(pg_database_size('collmanager')) as collmanager_db_size
)
TO STDOUT WITH CSV HEADER;

EOF"
  } >sql_pg_table_size.csv



  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    select application_name,count(*) from pg_catalog.pg_stat_activity group by application_name order by count desc
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >sql_pg_stat_group_by_app.csv


{
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    SELECT * FROM pg_stat_activity
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >sql_pg_stat_activity.csv

{
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    SELECT * FROM pg_locks
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >sql_pg_locks.csv


# incidents info
{
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    SELECT count(*) as all_incident FROM im_incident
)
TO STDOUT WITH CSV HEADER;

COPY (
    SELECT count(*) as open_incidents FROM im_incident
    INNER JOIN im_catalog_status ON im_incident.status_id = im_catalog_status.id
    WHERE im_catalog_status.type != 'closed' and  archived = 'false' and deleted = 'false'
)
TO STDOUT WITH CSV HEADER;

COPY (
    SELECT count(*) as archived_incident FROM im_incident WHERE archived = true
)
TO STDOUT WITH CSV HEADER;

COPY (
    SELECT count(*) as closed_incidents FROM im_incident
INNER JOIN im_catalog_status ON im_incident.status_id = im_catalog_status.id
WHERE im_catalog_status.type = 'closed' and archived = false
)
TO STDOUT WITH CSV HEADER;

COPY (
    SELECT count(*) as deleted_incidents FROM im_incident WHERE deleted = true
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >sql_incidents_data.csv

# assets politics
{
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    SELECT count (*) FROM public.am_device_assign_politic where enabled = true
)
TO STDOUT WITH CSV HEADER;

COPY (
    SELECT id, asset_type, enabled, cron, repeat, \"time\", \"interval\", days, days_of_month, minutes, started_at, is_running, created_at, updated_at FROM public.am_device_assign_policies_schedule
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >sql_assets_politics.csv

  # All db class stats
  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
  SELECT st.schemaname || '.' || st.relname tablename,
      pg_size_pretty(pg_relation_size(c.oid)),
      pg_relation_size(c.oid),
      pg_size_pretty(pg_indexes_size(c.oid)) AS indexes_size,
      pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
      pg_total_relation_size(c.oid),
      CASE c.relkind
        WHEN 'r' THEN 'table'
        WHEN 'i' THEN 'index'
        WHEN 'S' THEN 'sequence'
        WHEN 'v' THEN 'view'
        WHEN 't' THEN 'toast'
        ELSE c.relkind::text
      END,
    st.*
  FROM   pg_stat_all_tables st,
     pg_class c
  WHERE  c.oid = st.relid
  ORDER BY pg_relation_size(c.oid) DESC
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >sql_pg_class_size.csv

  # Table statistics. To correctly display the number of lines, you may need to execute the command - ANALYZE;
  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    SELECT
        table_name,
        pg_size_pretty(pg_table_size(quote_ident(table_name))) AS table_size,
        pg_size_pretty(pg_indexes_size(quote_ident(table_name))) AS indexes_size,
        pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) AS total_size,
        n_live_tup as row_count,
        ut.*
    FROM information_schema.tables AS it
    JOIN pg_stat_user_tables AS ut
        ON it.table_name = ut.relname
        AND it.table_schema = ut.schemaname
    WHERE table_schema = 'public'
    ORDER BY 2 DESC
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >sql_pg_statistic.csv

  # DB use statistics
  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY ( select * from pg_stat_statements ) TO STDOUT WITH CSV HEADER;
EOF"
  } >sql_pg_query_statistic_pg_stat_statement.csv

  # Backend requests stats
  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    select * from request_stats
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >sql_request_stats.csv

  # DB migrations
  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    select * from migrations
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >sql_pg_migrations.csv

{
$CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp -a $PG_ATTR  <<EOF

-- count vulners																		
select count(*) vulnerabilities_count from am_vulnerabilities;

-- Unique vulnerabilities (name, unique vulnerability identifier):
SELECT name, identifier
FROM am_vulnerabilities;
 
-- Number of unique vulnerabilities:
SELECT COUNT(DISTINCT vulnerabilities_id)
FROM am_devices_vulnerabilities;

-- Number of unique open vulnerabilities:
SELECT COUNT(DISTINCT vulnerabilities_id)
FROM am_devices_vulnerabilities
WHERE status != 'closed';

-- Total number of vulnerabilities:
SELECT COUNT(*)
FROM am_devices_vulnerabilities;

-- Total number of open vulnerabilities:
SELECT COUNT(*)
FROM am_devices_vulnerabilities
WHERE status != 'closed';

EOF" 
} > sql_vm_stats.log



  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
with foo as (
  SELECT
    schemaname, tablename, hdr, ma, bs,
    SUM((1-null_frac)*avg_width) AS datawidth,
    MAX(null_frac) AS maxfracsum,
    hdr+(
      SELECT 1+COUNT(*)/8
      FROM pg_stats s2
      WHERE null_frac<>0 AND s2.schemaname = s.schemaname AND s2.tablename = s.tablename
    ) AS nullhdr
  FROM pg_stats s, (
    SELECT
      (SELECT current_setting('block_size')::NUMERIC) AS bs,
      CASE WHEN SUBSTRING(v,12,3) IN ('8.0','8.1','8.2') THEN 27 ELSE 23 END AS hdr,
      CASE WHEN v ~ 'mingw32' THEN 8 ELSE 4 END AS ma
    FROM (SELECT version() AS v) AS foo
  ) AS constants
  GROUP BY 1,2,3,4,5
), rs as (
  SELECT
    ma,bs,schemaname,tablename,
    (datawidth+(hdr+ma-(CASE WHEN hdr%ma=0 THEN ma ELSE hdr%ma END)))::NUMERIC AS datahdr,
    (maxfracsum*(nullhdr+ma-(CASE WHEN nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2
  FROM foo
), sml as (
  SELECT
    schemaname, tablename, cc.reltuples, cc.relpages, bs,
    CEIL((cc.reltuples*((datahdr+ma-
      (CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::FLOAT)) AS otta,
    COALESCE(c2.relname,'?') AS iname, COALESCE(c2.reltuples,0) AS ituples, COALESCE(c2.relpages,0) AS ipages,
    COALESCE(CEIL((c2.reltuples*(datahdr-12))/(bs-20::FLOAT)),0) AS iotta -- very rough approximation, assumes all cols
  FROM rs
  JOIN pg_class cc ON cc.relname = rs.tablename
  JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname = rs.schemaname AND nn.nspname <> 'information_schema'
  LEFT JOIN pg_index i ON indrelid = cc.oid
  LEFT JOIN pg_class c2 ON c2.oid = i.indexrelid
)
SELECT
  current_database(), schemaname, tablename, /*reltuples::bigint, relpages::bigint, otta,*/
  ROUND((CASE WHEN otta=0 THEN 0.0 ELSE sml.relpages::FLOAT/otta END)::NUMERIC,1) AS tbloat,
  CASE WHEN relpages < otta THEN 0 ELSE bs*(sml.relpages-otta)::BIGINT END AS wastedbytes,
  iname, /*ituples::bigint, ipages::bigint, iotta,*/
  ROUND((CASE WHEN iotta=0 OR ipages=0 THEN 0.0 ELSE ipages::FLOAT/iotta END)::NUMERIC,1) AS ibloat,
  CASE WHEN ipages < iotta THEN 0 ELSE bs*(ipages-iotta) END AS wastedibytes
FROM sml
ORDER BY wastedbytes DESC
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >table_bloats.csv



#   # Object creation stats
#   {
#     $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
# COPY (
#     WITH users AS (
#         SELECT "createdAt"::date as "created", COUNT(*) AS users_count FROM users GROUP BY 1
#     ), roles AS (
#         SELECT "createdAt"::date as "created", COUNT(*) AS roles_count FROM roles GROUP BY 1
#     ), logs AS (
#         SELECT "createdAt"::date as "created", COUNT(*) AS logs_count FROM logs GROUP BY 1
#     ), am_assets AS (
#         SELECT "createdAt"::date as "created", COUNT(*) AS am_assets_count FROM am_assets GROUP BY 1
#     ), am_custom_assets AS (
#         SELECT "createdAt"::date as "created", COUNT(*) AS am_custom_assets_count FROM am_custom_assets GROUP BY 1
#     ), am_devices AS (
#         SELECT "createdAt"::date as "created", COUNT(*) AS am_devices_count FROM am_devices GROUP BY 1
#     ), am_users AS (
#         SELECT "createdAt"::date as "created", COUNT(*) AS am_users_count FROM am_users GROUP BY 1
#     ), am_vulnerabilities AS (
#         SELECT "createdAt"::date as "created", COUNT(*) AS am_vulnerabilities_count FROM am_vulnerabilities GROUP BY 1
#     ), am_devices_vulnerabilities AS (
#         SELECT "createdAt"::date as "created", COUNT(*) AS am_devices_vulnerabilities_count FROM am_devices_vulnerabilities GROUP BY 1
#     ), im_incident AS (
#         SELECT "createdAt"::date as "created", COUNT(*) AS im_incident_count FROM im_incident GROUP BY 1
#     ), im_playbooks_launches AS (
#         SELECT "created_at"::date as "created", COUNT(*) AS im_playbooks_launches_count FROM im_playbooks_launches GROUP BY 1
#     ), files AS (
#         SELECT "createdAt"::date as "created", COUNT(*) AS files_count FROM files GROUP BY 1
#     ), doc AS (
#         SELECT "createdAt"::date as "created", COUNT(*) AS doc_count FROM doc GROUP BY 1
#     ), mails AS (
#         SELECT "createdAt"::date as "created", COUNT(*) AS mails_count FROM mails GROUP BY 1
#     )
#     SELECT
#         *
#     FROM
#         logs
#         FULL JOIN roles USING (created)
#       FULL JOIN users USING (created)
#       FULL JOIN am_assets USING (created)
#       FULL JOIN am_custom_assets USING (created)
#       FULL JOIN am_devices USING (created)
#       FULL JOIN am_users USING (created)
#       FULL JOIN am_vulnerabilities USING (created)
#       FULL JOIN am_devices_vulnerabilities USING (created)
#       FULL JOIN im_incident USING (created)
#       FULL JOIN im_playbooks_launches USING (created)
#       FULL JOIN files USING (created)
#       FULL JOIN doc USING (created)
#       FULL JOIN mails USING (created)
#     ORDER BY
#         created
# )
# TO STDOUT WITH CSV HEADER;
# EOF"
#   } >sql_pg_count_by_day.csv

#   # Case sort by status, category and type
#   {
#     $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
# COPY (
#     SELECT
#         inc."createdAt"::date as "created",
#         inc_st.name as status,
#         inc.archived,
#         inc.deleted,
#         count(*) as im_incident_count
#     FROM
#         im_incident as inc
#         LEFT JOIN im_catalog_status as inc_st on inc_st.id = inc.status_id
#     GROUP BY 1,2,3,4
#     ORDER BY 1 DESC
# )
# TO STDOUT WITH CSV HEADER;
# EOF"
#   } >sql_pg_count_incident_by_day_by_categories.csv


}

collect_db_dev_stats() {
  cd "$LOG_PATH"/sql/devstat || exit_on_error "Directory $LOG_PATH/sql/devstat not available, exit script"

if [[ "$NO_DB_ACCESS" == 1 ]]; then return 0;fi
echo -e "Collecting db info for devs" |& tee -a "$LOG_PATH"/script_errors.log

$CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp -a $PG_ATTR  <<EOF
-- Number of entries in the grid - accounts
SELECT protocols.\"type\", COUNT(accounts.id) AS \"account count\"
    FROM am_accounts accounts
    LEFT JOIN am_protocols protocols ON accounts.protocols_id = protocols.id
    GROUP BY protocols.\"type\"
    ORDER BY protocols.\"type\";

    -- Number of entries in the grid
SELECT COUNT(*) devices_count
FROM am_devices;

-- Number of entries in the grid. Grouped by source
SELECT ds.source_uid source_name, COUNT(*) devices_count
FROM am_devices d
         LEFT JOIN am_devices_data_sources ds ON ds.device_id = d.id
GROUP BY source_name
ORDER BY source_name;

-- Data from history about the maximum number of hosts loaded by import.
--- OpenVas
SELECT MAX(rows_count) openvas_import_count_max
FROM (
         SELECT DATE_TRUNC('hour', \"createdAt\"), COUNT(logs.id) rows_count
         FROM logs
         WHERE message ILIKE '%openvas%'
           AND reference_table = 'am_devices'
         GROUP BY DATE_TRUNC('hour', \"createdAt\")
     ) log;

-- Interfave counts (max/avr)
SELECT MAX(rows_count) ifs_count_max, AVG(rows_count) ifs_count_avg
FROM (
         SELECT COUNT(*) rows_count
         FROM am_devices_ifs ifs
         GROUP BY ifs.devices_id
     ) tbl;

-- Software relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS soft_relations_count_max,
       AVG(tbl.relations_count) AS soft_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'devices')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'software')
         GROUP BY r.asset1_id
     ) tbl;

-- Staff relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS staff_relations_count_max,
       AVG(tbl.relations_count) AS staff_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'devices')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'users')
           AND r.asset2_id IN (SELECT id FROM am_users u WHERE u.local = FALSE AND u.domains_id IS NULL)
         GROUP BY r.asset1_id
     ) tbl;

-- Local accounts on host count (max/avr)
SELECT MAX(tbl.relations_count) AS local_accounts_relations_count_max,
       AVG(tbl.relations_count) AS local_accounts_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'devices')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'users')
           AND r.asset2_id IN (SELECT id FROM am_users u WHERE u.local = TRUE AND u.domains_id IS NULL)
         GROUP BY r.asset1_id
     ) tbl;


-- Domain accounts on host count (max/avr)
SELECT MAX(tbl.relations_count) AS domain_accounts_relations_count_max,
       AVG(tbl.relations_count) AS domain_accounts_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'devices')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'users')
           AND r.asset2_id IN (SELECT id FROM am_users u WHERE u.local = FALSE AND u.domains_id IS NOT NULL)
         GROUP BY r.asset1_id
     ) tbl;

-- GIT relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS assets_relations_count_max,
       AVG(tbl.relations_count) AS assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'devices')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'assets')
         GROUP BY r.asset1_id
     ) tbl;

-- Office(room) relation counts (max/avr)
--- only one office with one device can be related/linked
SELECT COUNT(*) offices_relations_count
FROM am_devices
WHERE offices_id IS NOT NULL;

-- division relation counts (max/avr)
--- only one division with one device can be related/linked
SELECT COUNT(*) orgs_relations_count
FROM am_devices
WHERE organization_id is NOT NULL;

-- Incidents relation counts (max/avr)
SELECT MAX(tbl.rows_count) incidents_count_max, AVG(tbl.rows_count) incidents_count_avg
FROM (
         SELECT COUNT(inc.id) rows_count
         FROM im_incident_device inc
         GROUP BY inc.device_id
     ) tbl;

-- Devices relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS devices_relations_count_max,
       AVG(tbl.relations_count) AS devices_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'devices')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'devices')
         GROUP BY r.asset1_id
     ) tbl;

-- User assets relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS custom_assets_relations_count_max,
       AVG(tbl.relations_count) AS custom_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'devices')
           AND r.asset2_type_id IN (SELECT id FROM am_asset_types WHERE type_id IS NULL)
         GROUP BY r.asset1_id
     ) tbl;

-- Vulnerabilities counts (max/avr)
SELECT MAX(tbl.rows_count) vulns_count_max, AVG(tbl.rows_count) vulns_count_avg
FROM (
         SELECT COUNT(t.id) rows_count
         FROM am_devices_vulnerabilities t
         GROUP BY t.devices_id
     ) tbl;

-- Tasks relation counts (max/avr)
SELECT MAX(tbl.rows_count) tasks_count_max, AVG(tbl.rows_count) tasks_count_avg
FROM (
         SELECT COUNT(t.id) rows_count
         FROM tm_task_devices t
         GROUP BY t.devices_id
     ) tbl;

-- Documents relation counts (max/avr)
SELECT MAX(tbl.rows_count) docs_count_max, AVG(tbl.rows_count) docs_count_avg
FROM (
         SELECT COUNT(t.id) rows_count
         FROM doc_devices t
         GROUP BY t.devices_id
     ) tbl;

-- Audit relation counts (max/avr)
-- summaries
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_summary_audit t
         GROUP BY t.devices_id
     ) tbl;
-- evaluations
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_evaluations_devices t
         GROUP BY t.devices_id
     ) tbl;
-- issues
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_remark_devices t
         GROUP BY t.devices_id
     ) tbl;
-- remediation plans
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_remediation_plans_devices t
         GROUP BY t.devices_id
     ) tbl;

-- Number of entries in the grid
SELECT COUNT(*) fields_count
FROM am_fields;

-- Number of entries in the grid grouped by assets type
SELECT aat.name type_name, aat.system is_system, COUNT(*) fields_count
FROM am_fields f
         JOIN am_asset_types aat ON f.asset_type_id = aat.id
GROUP BY aat.id;

-- Number of entries in the grid grouped by field type
SELECT f.system is_system, f.type field_type, COUNT(*) fields_count
FROM am_fields f
GROUP BY f.system, f.type
ORDER BY f.system, f.type;

-- Number of entries in the grid - Information
SELECT COUNT(*)
FROM am_information;


-- GIT relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS assets_relations_count_max,
       AVG(tbl.relations_count) AS assets_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'info')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'assets')
         GROUP BY r.asset1_id
     ) tbl;

-- Bussines process relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS processes_relations_count_max,
       AVG(tbl.relations_count) AS processes_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'info')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'processes')
         GROUP BY r.asset1_id
     ) tbl;

-- division relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS orgs_relations_count_max,
       AVG(tbl.relations_count) AS orgs_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'info')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'organization')
         GROUP BY r.asset1_id
     ) tbl;

-- Incidents relation counts (max/avr)
SELECT MAX(tbl.rows_count) incidents_count, AVG(tbl.rows_count) incidents_count_avg
FROM (
         SELECT COUNT(inc.id) rows_count
         FROM im_incidents_information inc
         GROUP BY inc.information_id
     ) tbl;

-- User assets relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS custom_assets_relations_count_max,
       AVG(tbl.relations_count) AS custom_assets_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'info')
           AND r.asset2_type_id IN (SELECT id FROM am_asset_types WHERE type_id IS NULL)
         GROUP BY r.asset1_id
     ) tbl;

-- Documents relation counts (max/avr)
SELECT MAX(tbl.inc_count) docs_count_max, AVG(tbl.inc_count) docs_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM doc_information t
         GROUP BY t.information_id
     ) tbl;

-- Number of entries in the grid - Integrations
SELECT COUNT(*) AS \"count\", 'all count' AS \"parameter value\", '' AS \"parameter name\" FROM am_integrations
UNION SELECT COUNT(*), uid, 'integration' FROM am_integrations GROUP BY uid
UNION SELECT COUNT(*), 'enable', 'work status' FROM am_integrations WHERE status IS TRUE GROUP BY status
UNION SELECT MAX(count_by_company.\"count\"), 'max', 'count by company' FROM (SELECT COUNT(*) AS \"count\" FROM am_integrations GROUP BY company_id) AS count_by_company
UNION SELECT AVG(count_by_company.\"count\")::INTEGER, 'avg', 'count by company' FROM (SELECT COUNT(*) AS \"count\" FROM am_integrations GROUP BY company_id) AS count_by_company
ORDER BY \"parameter name\", \"count\" DESC;

-- Number of entries in the grid - Networks
SELECT COUNT(*) networks_count
FROM am_networks;

-- Hierarchy level counts (max/avr)
WITH RECURSIVE grid_hierarchy AS (
    SELECT id, 0 AS parent_id, 0 AS level
    FROM am_networks
    WHERE NOT EXISTS(
            SELECT asset2_id FROM am_relations WHERE asset2_type_id = 6 AND asset2_id = am_networks.id
        )
    UNION
    SELECT r.asset2_id AS id, r.asset1_id AS parent_id, grid_hierarchy.level + 1 AS level
    FROM am_relations r
             JOIN grid_hierarchy
                  ON grid_hierarchy.id = r.asset1_id AND r.asset1_type_id = 6 AND r.relation_type_id = 2
)
SELECT MAX(level) AS am_networks_hierarchy_depth, AVG(level) AS am_networks_hierarchy_depth_avg
FROM grid_hierarchy;

-- Grouped by mask counts
SELECT n.mask,
       COUNT(n.id) rows_count
FROM am_networks n
GROUP BY n.mask;


-- GIT relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS assets_relations_count_max,
       AVG(tbl.relations_count) AS assets_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'networks')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'assets')
         GROUP BY r.asset1_id
     ) tbl;

-- Device relation counts  (max/avr)
SELECT MAX(tbl.devices_count) devices_count_max, AVG(tbl.devices_count) devices_count_avg
FROM (
         SELECT COUNT(ips.id) devices_count
         FROM am_devices_ifs_ips ips
                  JOIN am_networks an ON ips.networks_id = an.id
         GROUP BY an.id
     ) tbl;

-- Division relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS orgs_relations_count_max,
       AVG(tbl.relations_count) AS orgs_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'networks')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'organization')
         GROUP BY r.asset1_id
     ) tbl;

-- User assets relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS custom_assets_relations_count_max,
       AVG(tbl.relations_count) AS custom_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'networks')
           AND r.asset2_type_id IN (SELECT id FROM am_asset_types WHERE type_id IS NULL)
         GROUP BY r.asset1_id
     ) tbl;

-- Documents relation counts (max/avr)
SELECT MAX(tbl.inc_count) docs_count, AVG(tbl.inc_count) docs_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM doc_networks t
         GROUP BY t.networks_id
     ) tbl;

-- Number of entries in the grid - office
SELECT COUNT(*) offices_count
FROM am_offices;


-- Hierarchy level counts (max/avr)
WITH RECURSIVE grid_hierarchy AS (
    SELECT id, 0 AS parent_id, 0 AS level
    FROM am_processes
    WHERE NOT EXISTS(
            SELECT asset2_id FROM am_relations WHERE asset2_type_id = 4 AND asset2_id = am_processes.id
        )
    UNION
    SELECT r.asset2_id AS id, r.asset1_id AS parent_id, grid_hierarchy.level + 1 AS level
    FROM am_relations r
             JOIN grid_hierarchy
                  ON grid_hierarchy.id = r.asset1_id AND r.asset1_type_id = 4 AND r.relation_type_id = 2
)
SELECT MAX(level) AS am_offices_hierarchy_depth, AVG(level) AS am_offices_hierarchy_depth_avg
FROM grid_hierarchy;

-- Device relation counts (max/avr)
--- only one office can be related to one device
SELECT COUNT(*) devices_relations_count
FROM am_devices
WHERE offices_id IS NOT NULL;

-- Division relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS orgs_relations_count_max,
       AVG(tbl.relations_count) AS orgs_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'office')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'organization')
         GROUP BY r.asset1_id
     ) tbl;

-- Tasks relation counts (max/avr)
SELECT MAX(tbl.rows_count) tasks_count_max, AVG(tbl.rows_count) tasks_count_avg
FROM (
         SELECT COUNT(t.id) rows_count
         FROM tm_task_offices t
         GROUP BY t.offices_id
     ) tbl;

-- User assets relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS custom_assets_relations_count_max,
       AVG(tbl.relations_count) AS custom_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'office')
           AND r.asset2_type_id IN (SELECT id FROM am_asset_types WHERE type_id IS NULL)
         GROUP BY r.asset1_id
     ) tbl;

-- Documents relation counts (max/avr)
SELECT MAX(tbl.rows_count) docs_count_max, AVG(tbl.rows_count) docs_count_avg
FROM (
         SELECT COUNT(t.id) rows_count
         FROM doc_offices t
         GROUP BY t.offices_id
     ) tbl;

-- Audit relation counts (max/avr)
-- summaries
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_summary_audit t
         GROUP BY t.offices_id
     ) tbl;
-- evaluations
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_evaluations_offices t
         GROUP BY t.offices_id
     ) tbl;
-- issues
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_remark_offices t
         GROUP BY t.offices_id
     ) tbl;
-- remediation plans
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_remediation_plans_offices t
         GROUP BY t.offices_id
     ) tbl;

-- Number of entries in the grid - division
SELECT COUNT(*)
FROM am_organization;


-- Hierarchy level counts (max/avr)
WITH RECURSIVE grid_hierarchy AS (
    SELECT id, 0 AS parent_id, 0 AS level
    FROM am_processes
    WHERE NOT EXISTS(
            SELECT asset2_id FROM am_relations WHERE asset2_type_id = 3 AND asset2_id = am_processes.id
        )
    UNION
    SELECT r.asset2_id AS id, r.asset1_id AS parent_id, grid_hierarchy.level + 1 AS level
    FROM am_relations r
             JOIN grid_hierarchy
                  ON grid_hierarchy.id = r.asset1_id AND r.asset1_type_id = 3 AND r.relation_type_id = 2
)
SELECT MAX(level) AS am_organization_hierarchy_depth, AVG(level) AS am_organization_hierarchy_depth_avg
FROM grid_hierarchy;

-- GIT relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS assets_relations_count_max,
       AVG(tbl.relations_count) AS assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'organization')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'assets')
         GROUP BY r.asset1_id
     ) tbl;

-- Process relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS bp_relations_count_max,
       AVG(tbl.relations_count) AS bp_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'organization')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'processes')
         GROUP BY r.asset1_id
     ) tbl;

-- Office relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS offices_relations_count_max,
       AVG(tbl.relations_count) AS offices_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'organization')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'office')
         GROUP BY r.asset1_id
     ) tbl;

-- Information relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS info_relations_count_max,
       AVG(tbl.relations_count) AS info_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'organization')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'info')
         GROUP BY r.asset1_id
     ) tbl;

-- Device relation counts (max/avr)
--- only one division can re related to one device
SELECT COUNT(*) devices_relations_count
FROM am_devices
WHERE organization_id is NOT NULL;

-- User relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS users_relations_count_max,
       AVG(tbl.relations_count) AS users_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'organization')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'users')
         GROUP BY r.asset1_id
     ) tbl;

-- Incidents relation counts (max/avr)
SELECT MAX(tbl.rows_count) incidents_count_max, AVG(tbl.rows_count) incidents_count_avg
FROM (
         SELECT COUNT(inc.id) rows_count
         FROM im_incidents_organizations inc
         GROUP BY inc.organization_id
     ) tbl;

-- Tasks relation counts (max/avr)
SELECT MAX(tbl.rows_count) tasks_count_max, AVG(tbl.rows_count) tasks_count_avg
FROM (
         SELECT COUNT(t.id) rows_count
         FROM tm_task_organizations t
         GROUP BY t.organizations_id
     ) tbl;

-- Documents relation counts (max/avr)
SELECT MAX(tbl.rows_count) docs_count_max, AVG(tbl.rows_count) docs_count_avg
FROM (
         SELECT COUNT(t.id) rows_count
         FROM doc_offices t
         GROUP BY t.offices_id
     ) tbl;

-- Audit relation counts (max/avr)
-- summaries
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_summary_audit t
         GROUP BY t.organization_id
     ) tbl;
-- evaluations
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_evaluations_organization t
         GROUP BY t.organization_id
     ) tbl;
-- issues
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_remark_organization t
         GROUP BY t.organization_id
     ) tbl;
-- remediation plans
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_remediation_plans_organization t
         GROUP BY t.organization_id
     ) tbl;

-- User assets relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS custom_assets_relations_count_max,
       AVG(tbl.relations_count) AS custom_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'organization')
           AND r.asset2_type_id IN (SELECT id FROM am_asset_types WHERE type_id IS NULL)
         GROUP BY r.asset1_id
     ) tbl;

-- Number of entries in the grid - bussines-process
SELECT COUNT(*) bp_count
FROM am_processes;


-- Hierarchy level counts (max/avr)
WITH RECURSIVE grid_hierarchy AS (
    SELECT id, 0 AS parent_id, 0 AS level
    FROM am_processes
    WHERE NOT EXISTS(
            SELECT asset2_id FROM am_relations WHERE asset2_type_id = 1 AND asset2_id = am_processes.id
        )
    UNION
    SELECT r.asset2_id AS id, r.asset1_id AS parent_id, grid_hierarchy.level + 1 AS level
    FROM am_relations r
             JOIN grid_hierarchy
                  ON grid_hierarchy.id = r.asset1_id AND r.asset1_type_id = 1 AND r.relation_type_id = 2
)
SELECT MAX(level) AS am_processes_hierarchy_depth, AVG(level) AS am_processes_hierarchy_depth_avg
FROM grid_hierarchy;

-- GIT relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS assets_relations_count_max,
       AVG(tbl.relations_count) AS assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'processes')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'assets')
         GROUP BY r.asset1_id
     ) tbl;

-- Division relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS orgs_relations_count_max,
       AVG(tbl.relations_count) AS orgs_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'processes')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'organization')
         GROUP BY r.asset1_id
     ) tbl;

-- Information relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS info_relations_count_max,
       AVG(tbl.relations_count) AS info_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'processes')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'info')
         GROUP BY r.asset1_id
     ) tbl;

-- Incidents relation counts (max/avr)
SELECT MAX(tbl.rows_count) incidents_count, AVG(tbl.rows_count) incidents_count_avg
FROM (
         SELECT COUNT(inc.id) rows_count
         FROM im_incident_processes inc
         GROUP BY inc.process_id
     ) tbl;

-- Tasks relation counts (max/avr)
SELECT MAX(tbl.rows_count) tasks_count_max, AVG(tbl.rows_count) tasks_count_avg
FROM (
         SELECT COUNT(t.id) rows_count
         FROM tm_task_processes t
         GROUP BY t.processes_id
     ) tbl;

-- User assets relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS custom_assets_relations_count_max,
       AVG(tbl.relations_count) AS custom_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'processes')
           AND r.asset2_type_id IN (SELECT id FROM am_asset_types WHERE type_id IS NULL)
         GROUP BY r.asset1_id
     ) tbl;

-- Documents relation counts (max/avr)
SELECT MAX(tbl.inc_count) docs_count_max, AVG(tbl.inc_count) docs_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM doc_processes t
         GROUP BY t.processes_id
     ) tbl;

-- Audit relation counts (max/avr)
-- summaries
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_summary_audit t
         GROUP BY t.processes_id
     ) tbl;
-- evaluations
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_evaluations_process t
         GROUP BY t.process_id
     ) tbl;
-- issues
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_remark_processes t
         GROUP BY t.processes_id
     ) tbl;
-- remediation plans
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_remediation_plans_processes t
         GROUP BY t.processes_id
     ) tbl;

-- Scan poolitics - all
SELECT count(*) AS \"count\", '' AS \"parameter value\", 'all count' AS \"parameter name\" FROM am_scans
-- grouped by scan profiles
UNION SELECT COUNT(*), scan, 'scan' FROM am_scans GROUP BY scan
-- grouped by scan area
UNION SELECT COUNT(*), type, 'type' FROM am_scans GROUP BY type
-- disabled
UNION SELECT COUNT(*), '', 'active scans' FROM am_scans WHERE disabled IS NOT TRUE
-- Scanned device counts (max, avg)
UNION SELECT AVG(targets_count), '', 'avg count' FROM am_scans
UNION SELECT MAX(targets_count), '', 'max count' FROM am_scans
ORDER BY \"parameter name\", \"count\" DESC;


-- Number of entries in the grid - collectors
SELECT COUNT(*) AS \"collectos count\" FROM am_collectors;

-- Number of entries in the grid - personal
SELECT COUNT(*) users_count
FROM am_users;

-- Hidden local user counts
SELECT COUNT(*) users_count
FROM am_users
WHERE local = TRUE;

-- Number of entries in the grid. Grouped by source
SELECT us.name, COUNT(*) rows_count
FROM am_users_data_sources
         LEFT JOIN am_users_sources us ON us.uid = am_users_data_sources.source_uid
GROUP BY us.id;


-- GIT relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS assets_relations_count_max,
       AVG(tbl.relations_count) AS assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND
                                         r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'assets')
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'users')
         GROUP BY a.id
     ) tbl;

-- Division relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS orgs_relations_count_max,
       AVG(tbl.relations_count) AS orgs_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'users')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'organization')
         GROUP BY r.asset1_id
     ) tbl;

-- Office relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS offices_relations_count_max,
       AVG(tbl.relations_count) AS offices_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'users')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'office')
         GROUP BY r.asset1_id
     ) tbl;


-- Device relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS devices_relations_count_max,
       AVG(tbl.relations_count) AS devices_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'users')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'devices')
         GROUP BY r.asset1_id
     ) tbl;

-- User assets relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS custom_assets_relations_count_max,
       AVG(tbl.relations_count) AS custom_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'users')
           AND r.asset2_type_id IN (SELECT id FROM am_asset_types WHERE type_id IS NULL)
         GROUP BY r.asset1_id
     ) tbl;

-- Documents relation counts (max/avr)
SELECT MAX(tbl.rows_count) docs_count_max, AVG(tbl.rows_count) docs_count_avg
FROM (
         SELECT COUNT(t.id) rows_count
         FROM doc_am_users t
         GROUP BY t.am_user_id
     ) tbl;

     -- Number of entries in the grid
SELECT COUNT(*) assign_policies_count
FROM am_device_assign_politic;

-- Number of entries in the grid grouped by assets type
SELECT p.asset_type, COUNT(*) assign_policies_count
FROM am_device_assign_politic p
GROUP BY p.asset_type;

-- Number of entries in the grid grouped by company (max/avr)
SELECT MAX(tbl.assign_policies_count) assign_policies_count_by_company_max,
       AVG(tbl.assign_policies_count) assign_policies_count_by_company_avg
FROM (
         SELECT COUNT(*) assign_policies_count
         FROM am_device_assign_politic p
         GROUP BY p.company_id
     ) tbl;

-- Politics criteria counts (max/avr)
SELECT MAX(tbl.rules_count) rules_count_max,
       AVG(tbl.rules_count) rules_count_avg
FROM (
         SELECT COUNT(r.id) rules_count
         FROM am_device_assign_politic_rule r
         GROUP BY r.device_assign_politic_id
     ) tbl;

-- Policy launch schedule - how often it runs
-- (the schedule applies to all policies, excluding the organization)
-- so we are collecting information about the launch schedule settings
SELECT JSON_AGG(ROW_TO_JSON(s)) policies_run_schedule
FROM am_device_assign_policies_schedule s;

-- Number of entries in the grid - automation scripts
SELECT COUNT(*) AS \"automation scripts count\", 'all count' AS \"group\" FROM am_automation_scripts
UNION SELECT COUNT(*) AS \"automation scripts count\", 'crated date - ' || \"createdAt\"::TEXT
FROM am_automation_scripts
GROUP BY \"createdAt\"
ORDER BY \"group\";

-- Number of entries in the grid
SELECT COUNT(*)
FROM am_catalogs;

-- Security attributes
SELECT COUNT(*) security_attrs_count
FROM risks_security_attribute;

-- Bussiness process categories
SELECT COUNT(*) bp_categories_count
FROM am_processes_categories;

-- Software groups
SELECT COUNT(*) softwaregroups_count
FROM am_softwaresgroups;

-- Information assets
SELECT COUNT(*) informationassets_count
FROM am_informationassets;

-- Assets classification
SELECT COUNT(*) assets_classification_count
FROM am_classification;

-- User priviliges grouped by type
SELECT p.privileges_group_id privileges_group_id, COUNT(p.id) priveleges_count
FROM am_user_privileges p
GROUP BY p.privileges_group_id;

-- Assets status grouped by assets type 
SELECT aat.name, COUNT(s.id) statuses_count
FROM am_statuses s
         JOIN am_asset_types aat ON s.asset_type_id = aat.id
GROUP BY aat.id;

-- Tags
SELECT COUNT(*) tags_count
FROM am_tags;

-- Git group types
SELECT COUNT(*) asset_group_type_count
FROM am_asset_group_type;

-- Device types (grouped by default/custom)
SELECT (SELECT COUNT(*)
        FROM am_nodes
        WHERE key IN
              ('videocamera', 'ip_telephony', 'smp-server', 'smp-collector', 'firewall-server', 'unknown', 'network',
               'group',
               'other', 'router', 'scan', 'printer', 'mobile_device', 'server_dc', 'server_mail', 'proxy-server',
               'talk-server', 'print-server', 'remote-access-server', 'terminal-server', 'server_db',
               'application-server',
               'file-server', 'notebook', 'server_windows', 'server_linux', 'workstation_windows', 'workstation_osx',
               'workstation_linux', 'web-server-linux', 'web-server-windows', 'ftp-server-linux', 'ftp-server-windows',
               'mkt',
               'firewall', 'external-device')) nodes_default_count,
       (SELECT COUNT(*)
        FROM am_nodes
        WHERE key NOT IN
              ('videocamera', 'ip_telephony', 'smp-server', 'smp-collector', 'firewall-server', 'unknown', 'network',
               'group',
               'other', 'router', 'scan', 'printer', 'mobile_device', 'server_dc', 'server_mail', 'proxy-server',
               'talk-server', 'print-server', 'remote-access-server', 'terminal-server', 'server_db',
               'application-server',
               'file-server', 'notebook', 'server_windows', 'server_linux', 'workstation_windows', 'workstation_osx',
               'workstation_linux', 'web-server-linux', 'web-server-windows', 'ftp-server-linux', 'ftp-server-windows',
               'mkt',
               'firewall', 'external-device')) nodes_custom_count;

-- Division types
SELECT COUNT(*) org_types_count
FROM am_organization_type;

-- AM_states count
SELECT COUNT(*) states_count
FROM am_states;

-- Number of entries in the grid - collectors
SELECT COUNT(*) AS \"collectos count\" FROM am_collectors;

-- Custom assets types counts
SELECT COUNT(id) custom_types_count
FROM am_asset_types
WHERE type_id IS NULL;

-- Number of entries in the grid (max/avr) in every type
SELECT MAX(rows_count) custom_assets_rows_max, AVG(rows_count) custom_assets_rows_avg
FROM (
         SELECT COUNT(id) rows_count
         FROM am_custom_assets
         GROUP BY asset_type_id
     ) tbl;



-- Bussines process relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS bp_relations_count_max, AVG(tbl.relations_count) AS bp_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_custom_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND r.asset1_type_id = a.asset_type_id
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'processes')
         GROUP BY a.id
     ) tbl;

-- Division relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS orgs_relations_count_max, AVG(tbl.relations_count) AS orgs_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_custom_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND r.asset1_type_id = a.asset_type_id
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'organization')
         GROUP BY a.id
     ) tbl;

-- Information relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS info_relations_count_max, AVG(tbl.relations_count) AS info_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_custom_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND r.asset1_type_id = a.asset_type_id
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'info')
         GROUP BY a.id
     ) tbl;

-- User relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS staff_relations_count_max, AVG(tbl.relations_count) AS staff_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_custom_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND r.asset1_type_id = a.asset_type_id
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'users')
         GROUP BY a.id
     ) tbl;

-- Networks relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS networks_relations_count_max,
       AVG(tbl.relations_count) AS networks_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_custom_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND r.asset1_type_id = a.asset_type_id
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'networks')
         GROUP BY a.id
     ) tbl;

-- Device relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS devices_relations_count_max,
       AVG(tbl.relations_count) AS devices_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_custom_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND r.asset1_type_id = a.asset_type_id
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'devices')
         GROUP BY a.id
     ) tbl;

-- Software relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS software_relations_count_max,
       AVG(tbl.relations_count) AS software_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_custom_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND r.asset1_type_id = a.asset_type_id
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'software')
         GROUP BY a.id
     ) tbl;

-- Office relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS office_relations_count_max,
       AVG(tbl.relations_count) AS office_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_custom_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND r.asset1_type_id = a.asset_type_id
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'office')
         GROUP BY a.id
     ) tbl;

-- GIT relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS assets_relations_count_max,
       AVG(tbl.relations_count) AS assets_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_custom_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND r.asset1_type_id = a.asset_type_id
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'assets')
         GROUP BY a.id
     ) tbl;

-- Tasks relation counts (max/avr)
SELECT MAX(tbl.rows_count) tasks_count_max, AVG(tbl.rows_count) tasks_count_avg
FROM (
         SELECT COUNT(t.id) rows_count
         FROM tm_task_custom t
         GROUP BY t.custom_asset_id
     ) tbl;

-- User assets relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS custom_assets_relations_count_max,
       AVG(tbl.relations_count) AS custom_assets_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_custom_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND r.asset1_type_id = a.asset_type_id
             AND r.asset2_type_id IN (SELECT id FROM am_asset_types WHERE type_id IS NULL)
         GROUP BY a.id
     ) tbl;

-- Documents relation counts (max/avr)
SELECT MAX(tbl.rows_count) docs_count_max, AVG(tbl.rows_count) docs_count_avg
FROM (
         SELECT COUNT(t.id) rows_count
         FROM doc_custom_assets t
         GROUP BY t.custom_asset_id
     ) tbl;

-- Number of entries in the grid - Software detect policies
SELECT COUNT(*) AS \"detects policy count\" FROM am_detects;

-- assets life cycle settings (just checked marks)
SELECT ROW_TO_JSON(am_asset_life_cycle) life_cycle_settings
FROM am_asset_life_cycle;

-- Number of entries in the grid - Software
SELECT COUNT(id) software_count
FROM am_software;

-- Device relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS devices_relations_count_max,
       AVG(tbl.relations_count) AS devices_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'software')
           AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'devices')
         GROUP BY r.asset1_id
     ) tbl;

-- Tasks relation counts  (max/avr)
SELECT MAX(tbl.rows_count) tasks_count_max, AVG(tbl.rows_count) tasks_count_avg
FROM (
         SELECT COUNT(t.id) rows_count
         FROM tm_task_software t
         GROUP BY t.software_id
     ) tbl;


-- User assets relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS custom_assets_relations_count_max,
       AVG(tbl.relations_count) AS custom_assets_relations_count_avg
FROM (
         SELECT COUNT(r.id) relations_count
         FROM am_relations r
         WHERE r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'software')
           AND r.asset2_type_id IN (SELECT id FROM am_asset_types WHERE type_id IS NULL)
         GROUP BY r.asset1_id
     ) tbl;

-- Documents relation counts (max/avr)
SELECT MAX(tbl.inc_count) docs_count_max, AVG(tbl.inc_count) docs_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM doc_software t
         GROUP BY t.software_id
     ) tbl;

-- Number of entries in the grid
select count(*) from am_updates;

-- Device relation counts (max/avr)
select max(up_count),
       avg(up_count)
from (select count(*) as up_count
      from am_updates,
           am_devices_updates
      where am_updates.id = am_devices_updates.updates_id
      group by devices_id) as foo;

-- Number of entries in the grid
select count(*) vulnerabilities_count from am_vulnerabilities;

-- Unique vulnerabilities count
select count(distinct name) uniq_vulnerabilities_count from am_vulnerabilities;

-- Device-vulnerability relations count  (max/avr)
select max(count_device),
       avg(count_device)
from (select count(*) as count_device
      from am_vulnerabilities,
           am_devices_vulnerabilities
      where am_vulnerabilities.id = am_devices_vulnerabilities.vulnerabilities_id
      group by am_devices_vulnerabilities.vulnerabilities_id) as foo;


-- Number of entries in the grid. Grouped by source;
select \"from\", count(*) from am_vulnerabilities group by \"from\";

-- Incidents relation counts (max/avr)
select max(incindent_count),
       avg(incindent_count)
from (select sum(incident_count) incindent_count from am_devices_vulnerabilities group by devices_id) as foo;

-- Tasks relation counts (max/avr)
select max(task_count),
       avg(task_count)
from (select sum(task_count) task_count from am_devices_vulnerabilities group by devices_id) as foo;


-- Software relation counts (vulnerable software) (max/avr)
select max(soft_count),
       avg(soft_count)
from (select count(*) soft_count from am_devices_vulnerabilities_software group by device_vulnerability_id) foo;

-- GIT relation counts (max/avr)
select max(soft_count),
       avg(soft_count)
from (select count(*) soft_count from am_devices_vulnerabilities_software group by device_vulnerability_id) foo;

-- Vulnerabilities link counts (max/avr)
select max(ref_count),
       avg(ref_count)
from (select count(*) ref_count from am_vulnerabilities_references group by vulnerabilities_id) foo;

-- Comments counts
select max(comment_count),
       avg(comment_count)
from (select count(*) comment_count from am_devices_vulnerabilities_comments group by am_devices_vulnerabilities_id) foo;

-- Number of entries in the grid
select count(*) from am_assets;


-- Hierarchy level counts (max/avr)
WITH RECURSIVE am_assets_hierarchy AS (
    SELECT id, 0 AS parent_id, 0 AS level
    FROM am_assets
    WHERE NOT EXISTS(
            SELECT asset2_id FROM am_relations WHERE asset2_type_id = 9 AND asset2_id = am_assets.id
        )
    UNION
    SELECT r.asset2_id AS id, r.asset1_id AS parent_id, am_assets_hierarchy.level + 1 AS level
    FROM am_relations r
             JOIN am_assets_hierarchy
                  ON am_assets_hierarchy.id = r.asset1_id AND r.asset1_type_id = 9 AND r.relation_type_id = 2
)
SELECT MAX(level) AS am_assets_hierarchy_depth, AVG(level) AS am_assets_hierarchy_depth_avg
FROM am_assets_hierarchy;

-- Bussines process relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS bp_relations_count, AVG(tbl.relations_count) AS bp_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND
                                         r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'assets')
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'processes')
         GROUP BY a.id
     ) tbl;

-- Division relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS org_relations_count, AVG(tbl.relations_count) AS org_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND
                                         r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'assets')
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'organization')
         GROUP BY a.id
     ) tbl;

-- Information relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS info_relations_count, AVG(tbl.relations_count) AS info_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND
                                         r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'assets')
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'info')
         GROUP BY a.id
     ) tbl;


-- User relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS staff_relations_count, AVG(tbl.relations_count) AS staff_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND
                                         r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'assets')
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'users')
         GROUP BY a.id
     ) tbl;

-- Networks relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS networks_relations_count,
       AVG(tbl.relations_count) AS networks_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND
                                         r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'assets')
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'networks')
         GROUP BY a.id
     ) tbl;


-- Device relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS devices_relations_count, AVG(tbl.relations_count) AS devices_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND
                                         r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'assets')
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'devices')
         GROUP BY a.id
     ) tbl;


-- Incidents relation counts (max/avr)
SELECT MAX(tbl.inc_count) incidents_count, AVG(tbl.inc_count) incidents_count_avg
FROM (
         SELECT inc.asset_id,
                COUNT(inc.id) inc_count
         FROM im_incidents_assets inc
         GROUP BY inc.asset_id
     ) tbl;

-- GIT relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS assets_relations_count,
       AVG(tbl.relations_count) AS assets_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND
                                         r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'assets')
             AND r.asset2_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'assets')
             AND r.relation_type_id = 1
         GROUP BY a.id
     ) tbl;

-- Tasks relation counts (max/avr)
SELECT MAX(tbl.inc_count) tasks_count, AVG(tbl.inc_count) tasks_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM tm_task_assets t
         GROUP BY t.assets_id
     ) tbl;

-- User assets relation counts (max/avr)
SELECT MAX(tbl.relations_count) AS custom_assets_relations_count,
       AVG(tbl.relations_count) AS custom_assets_relations_count_avg
FROM (
         SELECT a.id, COUNT(r.id) relations_count
         FROM am_assets a
                  JOIN am_relations r ON r.asset1_id = a.id AND
                                         r.asset1_type_id = (SELECT id FROM am_asset_types WHERE type_id = 'assets')
             AND r.asset2_type_id IN (SELECT id FROM am_asset_types WHERE type_id IS NULL)
         GROUP BY a.id
     ) tbl;

-- Documents relation counts (max/avr)
SELECT MAX(tbl.inc_count) docs_count, AVG(tbl.inc_count) docs_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM doc_assets t
         GROUP BY t.assets_id
     ) tbl;

-- Audit relation counts (max/avr)
-- summaries
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_summary_audit t
         GROUP BY t.asset_id
     ) tbl;
-- evaluations
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_evaluations_assets t
         GROUP BY t.assets_id
     ) tbl;
-- issues
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_remark_assets t
         GROUP BY t.asset_id
     ) tbl;
-- remediation plans
SELECT MAX(tbl.inc_count) audit_summary_count_max, AVG(tbl.inc_count) audit_summary_count_avg
FROM (
         SELECT COUNT(t.id) inc_count
         FROM cm_remediation_plans_assets t
         GROUP BY t.asset_id
     ) tbl;

select mode, add, delete, count(*)
from (select access_rules -> 'assets' -> 'mode'                    as mode,
             access_rules -> 'assets' -> 'permissions' -> 'add'    as add,
             access_rules -> 'assets' -> 'permissions' -> 'delete' as delete
      from roles
      where exists(select 1 from roles_asset_groups_types where role_id = roles.id)) as prepared_roles
group by prepared_roles.mode, prepared_roles.add, prepared_roles.delete;

EOF" > stat.log

$CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp -a $PG_ATTR  <<EOF

-- Companies:
-- Companies count
SELECT count(*) FROM companies;

-- Companies count with different sublevel
SELECT level, count(*)
FROM (SELECT id, nlevel(path) AS level FROM companies) AS sq
GROUP BY level
ORDER BY level;

-- ************************* --

-- Journal:
-- All logs counts
SELECT count(*) FROM logs;

-- Every module logs count
SELECT module, count(*)
FROM logs
GROUP BY module
ORDER BY 2 DESC;

-- Every table logs count
SELECT reference_table, count(*)
FROM logs
GROUP BY reference_table
ORDER BY 2 DESC
LIMIT 50;

-- ************************* --

-- API:
-- users with public api access
SELECT count(*) FROM users_tokens;

-- ************************* --

-- System dictionaries:
-- Regexps counts
SELECT count(*) FROM directory_regexps;

-- ************************* --

-- Incidents categories:
-- Categories count
SELECT count(*) FROM im_categories;

-- Actual categories count
SELECT count(*)
FROM im_categories
WHERE disable_category = FALSE
AND deleted = FALSE;

-- Fields for category counts
SELECT category_id, count(im_categories_fields.*)
FROM im_categories_fields
INNER JOIN im_categories ON im_categories_fields.category_id = im_categories.id
WHERE disable_category = FALSE
AND deleted = FALSE
GROUP BY category_id
ORDER BY 2 DESC
LIMIT 50;

-- Types for category counts
SELECT category_id, count(im_categories.*)
FROM im_categories_types
INNER JOIN im_categories ON im_categories_types.category_id = im_categories.id
WHERE disable_category = FALSE
AND deleted = FALSE
GROUP BY category_id
ORDER BY 2 DESC
LIMIT 50;

-- ************************* --

-- Incidents types:
-- Types counts
SELECT count(*) FROM im_catalog_types;

-- Actual types counts
SELECT count(*)
FROM im_catalog_types
WHERE hidden = FALSE;

-- Types groups counts
SELECT count(*) FROM im_catalog_types_groups;

-- Types in Group count
SELECT group_id, count(*)
FROM im_catalog_types
GROUP BY group_id
ORDER BY 2 DESC;

-- Fields in type count
SELECT type_id, count(im_catalog_types_fields.*)
FROM im_catalog_types_fields
INNER JOIN im_catalog_types ON im_catalog_types_fields.type_id = im_catalog_types.id
WHERE im_catalog_types.hidden = FALSE
GROUP BY type_id
ORDER BY 2 DESC
LIMIT 50;

-- categories in type count
SELECT type_id, count(im_categories_types.*)
FROM im_categories_types
INNER JOIN im_catalog_types ON im_categories_types.type_id = im_catalog_types.id
WHERE im_catalog_types.hidden = FALSE
GROUP BY type_id
ORDER BY 2 DESC
LIMIT 50;

-- ************************* --

-- Incident processing cycles:
-- Cycles count
SELECT count(*) FROM im_catalog_status_groups;

-- Cycles with advanced settings count
SELECT count(*) FROM im_catalog_status_groups WHERE advanced = true;

-- Catalog statuses count
SELECT count(*) FROM im_catalog_status;

-- Statuses in cycle count
SELECT group_id, count(*)
FROM im_catalog_status
GROUP BY group_id
ORDER BY 2 DESC
LIMIT 50;

-- Cycles with transition rules count
SELECT count(DISTINCT group_id)
FROM im_status_transitions
WHERE transition_rules IS NOT NULL;

-- ************************* --

-- Incident fields:
-- im_fields counts
SELECT count(*) FROM im_fields;

-- im_fields with tags count
SELECT count(*)
FROM im_fields
WHERE tag IS NOT NULL
AND tag <> '';

-- Fileds grouped by types
SELECT type, count(*)
FROM im_fields
GROUP BY type
ORDER BY 2 DESC;

-- Tags with dot in custom fileds
SELECT count(*)
FROM im_fields
WHERE system = false
AND tag LIKE ('%.%');

-- List of fields with dot in tag
SELECT tag, type
FROM im_fields
WHERE system = false
AND tag LIKE ('%.%')
ORDER BY tag, type;

-- Max columns in array fields
SELECT max(jsonb_array_length(params->'config'))
FROM im_fields
WHERE type = 'grid';

-- im_fields group counts
SELECT count(*) FROM im_fields_groups;

-- Fields in every group counts
SELECT group_id, count(*)
FROM im_fields
GROUP BY group_id
ORDER BY 2 DESC
LIMIT 50;


-- Incident templates:
-- Total number of templates
SELECT count(*) FROM im_template;

-- ************************* --

-- Criticality levels:
-- Total number of levels
SELECT count(*) FROM im_catalog_levels;

-- ************************* --

-- Response scenarios:
-- Total number of current scenarios
SELECT count(*)
FROM im_playbooks
WHERE unit = 'playbook'
AND outdated = false
AND deleted = false;

-- Total number of scenario groups
SELECT count(*)
FROM im_playbooks
WHERE unit = 'group';

-- Number of current scenarios per group
SELECT parent_id, count(*)
FROM im_playbooks
WHERE unit = 'playbook'
AND outdated = false
AND deleted = false
GROUP BY parent_id
ORDER BY 2 DESC
LIMIT 50;

-- Total number of actions of different types
SELECT type, count(*)
FROM im_playbooks
WHERE unit = 'action'
AND outdated = false
AND deleted = false
GROUP BY type
ORDER BY 2 DESC;

-- Number of actual actions per scenario
SELECT parent_id, count(*)
FROM im_playbooks
WHERE unit = 'action'
AND outdated = false
AND deleted = false
GROUP BY parent_id
ORDER BY 2 DESC
LIMIT 50;

-- Number of versions of one script
SELECT uuid, count(*)
FROM im_playbooks
WHERE unit = 'playbook'
GROUP BY uuid
ORDER BY 2 DESC
LIMIT 50;

-- Number of criteria per scenario
SELECT im_playbooks.id, count(im_playbooks_criteria.*)
FROM im_playbooks
INNER JOIN im_playbooks_criteria ON im_playbooks_criteria.unit_id = im_playbooks.id
WHERE im_playbooks.unit = 'playbook'
AND outdated = false
AND deleted = false
GROUP BY im_playbooks.id
ORDER BY 2 DESC
LIMIT 50;

-- Number of criteria of different types per scenario
SELECT im_playbooks_criteria.type, count(im_playbooks_criteria.*)
FROM im_playbooks
INNER JOIN im_playbooks_criteria ON im_playbooks_criteria.unit_id = im_playbooks.id
WHERE im_playbooks.unit = 'playbook'
AND outdated = false
AND deleted = false
GROUP BY im_playbooks_criteria.type
ORDER BY 2 DESC;

-- Number of criteria per action
SELECT im_playbooks.id, im_playbooks.type, count(im_playbooks_criteria.*)
FROM im_playbooks
INNER JOIN im_playbooks_criteria ON im_playbooks_criteria.unit_id = im_playbooks.id
WHERE im_playbooks.unit = 'action'
AND outdated = false
AND deleted = false
GROUP BY im_playbooks.id
ORDER BY 2 DESC
LIMIT 50;

-- Number of criteria of different types for actions
SELECT im_playbooks_criteria.type, count(im_playbooks_criteria.*)
FROM im_playbooks
INNER JOIN im_playbooks_criteria ON im_playbooks_criteria.unit_id = im_playbooks.id
WHERE im_playbooks.unit = 'action'
AND outdated = false
AND deleted = false
GROUP BY im_playbooks_criteria.type
ORDER BY 2 DESC;

-- Number of actions launched by hands outside the script
SELECT count(*)
FROM im_playbooks
WHERE unit = 'action'
AND parent_id IS NULL;

-- Number of runs of current versions of scripts on incidents
SELECT im_playbooks.id, count(im_playbooks_launches.*)
FROM im_playbooks
INNER JOIN im_playbooks_launches ON im_playbooks.id = im_playbooks_launches.unit_id
WHERE im_playbooks.unit = 'playbook'
AND im_playbooks.outdated = false
AND im_playbooks.deleted = false
GROUP BY im_playbooks.id
ORDER BY 2 DESC;

-- Number of runs of outdated versions of scripts on incidents
SELECT im_playbooks.id, count(im_playbooks_launches.*)
FROM im_playbooks
INNER JOIN im_playbooks_launches ON im_playbooks.id = im_playbooks_launches.unit_id
WHERE im_playbooks.unit = 'playbook'
AND im_playbooks.outdated = true
AND im_playbooks.deleted = false
GROUP BY im_playbooks.id
ORDER BY 2 DESC
LIMIT 50;

-- Number of runs of remote versions of scripts on incidents
SELECT im_playbooks.id, count(im_playbooks_launches.*)
FROM im_playbooks
INNER JOIN im_playbooks_launches ON im_playbooks.id = im_playbooks_launches.unit_id
WHERE im_playbooks.unit = 'playbook'
AND im_playbooks.deleted = true
GROUP BY im_playbooks.id
ORDER BY 2 DESC
LIMIT 50;

-- ************************* --

-- Correlation rules:
-- Total number of rules
SELECT count(*) FROM im_correlation_rules;

-- ************************* --

-- Integration with external systems:
-- Total number of integrations
SELECT count(*)
FROM am_integrations
WHERE module = 'im';

-- Number of integrations of different types
SELECT uid, count(*)
FROM am_integrations
WHERE module = 'im'
GROUP BY uid
ORDER BY 2 DESC;

-- Number of incidents received from integrations of different types
SELECT am_integrations.uid, count(im_incident.*)
FROM am_integrations
INNER JOIN im_incident ON am_integrations.id = im_incident.integration_id
WHERE am_integrations.module = 'im'
GROUP BY am_integrations.uid
ORDER BY 2 DESC;

-- ************************* --

-- Connectors:
-- Total number of connectors
SELECT count(*) FROM connectors;

-- Number of connectors of each type
SELECT type, count(*)
FROM connectors
GROUP BY type
ORDER BY 2;

-- Number of connectors of each type used in scripts
SELECT type, count(*)
FROM connectors
WHERE EXISTS(
    SELECT * FROM im_playbooks_relations WHERE collectors_id = connectors.id
)
GROUP BY type
ORDER BY 2;

-- ************************* --

-- Total number of directories
SELECT count(*) FROM im_catalogs;

-- Total number of user directories
SELECT count(*) FROM im_catalogs WHERE system = false;

-- Number of entries per user directory
SELECT catalog_id, count(*)
FROM im_catalog_usercatalog
WHERE system = false OR system is NULL
GROUP BY catalog_id
ORDER BY 2;

-- ************************* --

-- Incidents
-- Total number of incidents
SELECT count(*) FROM im_incident;

-- Number of incidents deleted
SELECT count(*)
FROM im_incident
WHERE deleted = true;

-- Number of archived incidents
SELECT count(*)
FROM im_incident
WHERE archived = true;

-- Number of closed incidents
SELECT count(*)
FROM im_incident
INNER JOIN im_catalog_status ON im_incident.status_id = im_catalog_status.id
WHERE im_catalog_status.type = 'closed';

-- Total number of records about custom fields by incident
SELECT count(*) FROM im_fields_values;

-- Number of non-empty records about custom fields by incident
SELECT count(*)
FROM im_fields_values
WHERE value IS NOT NULL
AND value <> '';

-- Number of custom field values ​​per incident
SELECT incident_id, count(*)
FROM im_fields_values
WHERE value IS NOT NULL
AND value <> ''
GROUP BY incident_id
ORDER BY 2 DESC
LIMIT 50;

-- Number of records about linked devices
SELECT count(*) FROM im_incident_device;

-- Number of devices per incident
SELECT incident_id, count(*)
FROM im_incident_device
GROUP BY incident_id
ORDER BY 2 DESC
LIMIT 50;

-- Number of records about linked GIT
SELECT count(*) FROM im_incidents_assets;

-- Number of GIT per incident
SELECT incident_id, count(*)
FROM im_incidents_assets
GROUP BY incident_id
ORDER BY 2 DESC
LIMIT 50;

-- Number of records about linked business processes
SELECT count(*) FROM im_incident_processes;

-- Number of business processes per incident
SELECT incident_id, count(*)
FROM im_incident_processes
GROUP BY incident_id
ORDER BY 2 DESC
LIMIT 50;

-- Number of records about linked business units
SELECT count(*) FROM im_incidents_organizations;

-- Number of business processes per incident
SELECT incident_id, count(*)
FROM im_incidents_organizations
GROUP BY incident_id
ORDER BY 2 DESC
LIMIT 50;

-- Number of records about linked information assets
SELECT count(*) FROM im_incidents_information;

-- Number of information assets per incident
SELECT incident_id, count(*)
FROM im_incidents_information
GROUP BY incident_id
ORDER BY 2 DESC
LIMIT 50;

-- Number of records about linked incident participants
SELECT count(*) FROM im_incident_disturber;

-- Number of incident participants per incident
SELECT incident_id, count(*)
FROM im_incident_disturber
GROUP BY incident_id
ORDER BY 2 DESC
LIMIT 50;

-- Number of records about linked custom assets
SELECT count(*) FROM im_incidents_assets_customs;

-- Number of custom assets per incident
SELECT incident_id, count(*)
FROM im_incidents_assets_customs
GROUP BY incident_id
ORDER BY 2 DESC
LIMIT 50;

-- Number of records about linked certificates
SELECT count(*) FROM im_incidents_files;

-- Number of evidence per incident
SELECT incident_id, count(*)
FROM im_incidents_files
GROUP BY incident_id
ORDER BY 2 DESC
LIMIT 50;

-- Number of records about associated causes
SELECT count(*) FROM im_incidents_reasons;

-- Number of causes per incident
SELECT incident_id, count(*)
FROM im_incidents_reasons
GROUP BY incident_id
ORDER BY 2 DESC
LIMIT 50;

-- Number of records about the workgroup (users)
SELECT count(*) FROM im_incidents_workgroup;

-- Number of incidents with the working group (users), excluding those responsible for the incident
SELECT count(*) FROM im_incidents_workgroup WHERE level <> 3;

-- Number of working group members (users) per incident
SELECT incident_id, count(*)
FROM im_incidents_workgroup
GROUP BY incident_id
ORDER BY 2 DESC
LIMIT 50;

-- Number of records about the workgroup (user group)
SELECT count(*) FROM im_incidents_workgroup_user_groups;

-- Number of members of the working group (group of users) per incident
SELECT incident_id, count(*)
FROM im_incidents_workgroup_user_groups
GROUP BY incident_id
ORDER BY 2 DESC
LIMIT 50;

-- Number of comment entries
SELECT count(*) FROM im_incidents_comments;

-- Number of comments per incident
SELECT incident_id, count(*)
FROM im_incidents_comments
GROUP BY incident_id
ORDER BY 2 DESC
LIMIT 50;

-- Number of incident-related task records
SELECT count(*)
FROM im_playbooks_relations
WHERE task_id IS NOT NULL;

-- Number of tasks per incident
SELECT im_playbooks_launches.incident_id, count(im_playbooks_relations.*)
FROM im_playbooks_launches
INNER JOIN im_playbooks_relations
    ON im_playbooks_launches.id = im_playbooks_relations.launch_id
           AND im_playbooks_relations.task_id IS NOT NULL
GROUP BY im_playbooks_launches.incident_id
ORDER BY 2 DESC
LIMIT 50;

-- Total number of tabs in the incident grid
SELECT count(*)
FROM saved_filters
WHERE module = 'incidents'
AND fixed_tab = false
AND is_my_filter = false;

-- Number of tabs in the incident grid per user
SELECT user_id, count(*)
FROM saved_filters
WHERE module = 'incidents'
AND fixed_tab = false
AND is_my_filter = false
GROUP BY user_id
ORDER BY 2 DESC
LIMIT 50;

-- Tabs with a large number of customized filters
SELECT
json_array_length(data::json->'filters') as count
FROM saved_filters
WHERE module = 'incidents'
AND fixed_tab = false
AND is_my_filter = false
ORDER BY 1 DESC
LIMIT 50;

-- Total number of saved incident filters
SELECT count(*)
FROM saved_filters
WHERE module = 'incidents'
AND fixed_tab = false
AND is_my_filter = true;

-- Number of saved filters per user
SELECT user_id, count(*)
FROM saved_filters
WHERE module = 'incidents'
AND fixed_tab = false
AND is_my_filter = true
GROUP BY user_id
ORDER BY 2 DESC
LIMIT 50;

-- Saved filters with more filters
SELECT
json_array_length(data::json->'filters') as count
FROM saved_filters
WHERE module = 'incidents'
AND fixed_tab = false
AND is_my_filter = true
ORDER BY 1 DESC
LIMIT 50;

-- ************************* --

-- Charts
-- Total number of custom graphs for incidents
SELECT count(charts.*)
FROM charts
INNER JOIN chart_types ON charts.type_id = chart_types.id
WHERE chart_types.object_type = 'incidents';

-- Number of custom graphs for incidents per graph type
SELECT chart_types.chart_type, count(charts.*)
FROM chart_types
INNER JOIN charts ON charts.type_id = chart_types.id
WHERE chart_types.object_type = 'incidents'
GROUP BY chart_types.chart_type
ORDER BY 2 DESC;

-- Total number of template graphs for incidents
SELECT count(charts.*)
FROM charts
WHERE type IN (8, 9, 10, 11, 23, 24, 25, 26, 27, 32, 33, 34, 35, 36);

-- Number of template graphs for incidents per type
WITH
     chart_templates AS (
        SELECT *
        FROM (
            VALUES (8), (9), (10), (11), (23), (24), (25), (26), (27), (32), (33), (34), (35), (36)
        ) AS chart_templates (template_id)
     )
SELECT
    chart_templates.template_id,
    (SELECT count(*) FROM charts WHERE type = chart_templates.template_id)
FROM chart_templates
ORDER BY 1;

EOF" > sz_soar_stat.log



$CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp -a $PG_ATTR  <<EOF

-- Unique vulnerabilities (name, unique vulnerability identifier):
SELECT name, identifier
FROM am_vulnerabilities;

-- Number of unique vulnerabilities:
SELECT COUNT(DISTINCT vulnerabilities_id)
FROM am_devices_vulnerabilities;

-- Number of unique open vulnerabilities:
SELECT COUNT(DISTINCT vulnerabilities_id)
FROM am_devices_vulnerabilities
WHERE status != 'closed';

-- Total number of vulnerabilities:
SELECT COUNT(*)
FROM am_devices_vulnerabilities;

-- Total number of open vulnerabilities:
SELECT COUNT(*)
FROM am_devices_vulnerabilities
WHERE status != 'closed';

-- Number of vulnerabilities found within a unique vulnerability (unique vulnerability ID, count):
SELECT (SELECT identifier FROM am_vulnerabilities WHERE id = am_devices_vulnerabilities.vulnerabilities_id), COUNT(*)
FROM am_devices_vulnerabilities
WHERE status != 'closed'
GROUP BY vulnerabilities_id;

-- Number of open vulnerabilities found in Pentest mode:
SELECT count(*)
FROM am_devices_vulnerabilities
WHERE scan_profiles && ARRAY(SELECT name FROM vm_policy.profile WHERE type_of_profile = 'TYPE_OF_PROFILE_PENTEST')
AND status != 'closed';

-- Number of vulnerabilities found within a unique vulnerability in Pentest mode (unique vulnerability identifier, number):
SELECT (SELECT identifier FROM am_vulnerabilities WHERE id = am_devices_vulnerabilities.vulnerabilities_id), COUNT(*)
FROM am_devices_vulnerabilities
WHERE status != 'closed'
AND scan_profiles && ARRAY(SELECT name FROM vm_policy.profile WHERE type_of_profile = 'TYPE_OF_PROFILE_PENTEST')
GROUP BY vulnerabilities_id;

-- Number of open vulnerabilities found in Audit mode:
SELECT count(*)
FROM am_devices_vulnerabilities
WHERE scan_profiles && ARRAY(SELECT name FROM vm_policy.profile WHERE type_of_profile = 'TYPE_OF_PROFILE_VULNER')
AND status != 'closed';

-- Number of vulnerabilities found within a unique vulnerability in Audit mode (unique vulnerability identifier, number):
SELECT (SELECT identifier FROM am_vulnerabilities WHERE id = am_devices_vulnerabilities.vulnerabilities_id), COUNT(*)
FROM am_devices_vulnerabilities
WHERE status != 'closed'
AND scan_profiles && ARRAY(SELECT name FROM vm_policy.profile WHERE type_of_profile = 'TYPE_OF_PROFILE_VULNER')
GROUP BY vulnerabilities_id;


-- Infrastructure
-- OS
-- List of unique OS in the system:
SELECT DISTINCT os FROM am_devices
WHERE os is NOT NULL;

-- Number of unique OS in the system - the name and version of the OS are taken into account:
SELECT count(DISTINCT os) FROM am_devices
WHERE os is NOT NULL;

-- Number of instances of each unique OS (name of OS, number of instances):
SELECT os, count(*) FROM am_devices
WHERE os is NOT NULL
GROUP BY os;

-- Number of instances for each unique OS family (family name, number of instances):
SELECT os_type, count(*) FROM am_devices WHERE os_type is NOT NULL
GROUP BY os_type;

-- Software
-- List of unique software (by name only) in the system:
SELECT DISTINCT name FROM am_software;

-- List of unique software (name + version) in the system:
SELECT DISTINCT ON (name, version) name, version FROM am_software;

-- Number of unique software (by name only) in the system:
SELECT count(DISTINCT name) FROM am_software;


-- Number of unique software (name + version) in the system:
SELECT count(DISTINCT (name, version)) FROM am_software;


-- Number of unique software instances (by name only) in the system (software name, number of instances):
SELECT name, version, COUNT((name, version))
FROM am_software
LEFT JOIN am_relations ON am_software.id = am_relations.asset1_id AND am_relations.asset1_type_id = 8 AND
am_relations.asset2_type_id = 5
GROUP BY (name, version);

-- Number of unique software instances (name + version) in the system (software name, version, number of instances):
SELECT name, version, COUNT((name, version))
FROM am_software
LEFT JOIN am_relations ON am_software.id = am_relations.asset1_id AND am_relations.asset1_type_id = 8 AND
am_relations.asset2_type_id = 5
GROUP BY (name, version);

-- Ports
-- List of unique ports in the system:
SELECT DISTINCT port FROM am_devices_ports;
-- List of unique services in the system:
SELECT DISTINCT service FROM am_devices_ports;
-- List of unique ports + protocols + services in the system:
SELECT DISTINCT ON (port, protocol, service) port, protocol, service FROM am_devices_ports;

-- Number of uses of each port in the system (port, count):
SELECT port, count(*) FROM am_devices_ports
GROUP BY port;

-- Number of uses of each port + protocol in the system (port, protocol, count):
SELECT port, protocol, count(*) FROM am_devices_ports
GROUP BY (port,protocol);

-- Number of uses of each port + protocol + service (if specified) in the system (port, protocol, service, count):
SELECT port, protocol, service, count(*) FROM am_devices_ports
GROUP BY (port,protocol,service);

-- Number of uses of each service in the system (service, quantity):
SELECT service, count(*) FROM am_devices_ports
WHERE service != ''
GROUP BY service;

EOF" > vm_stat.log

  }

collect_db_dump() {
  cd "$LOG_PATH"/sql/config || exit_on_error "Directory $LOG_PATH/sql/config not available, exit script"
  if [[ $NO_DB_ACCESS == 1 ]]; then return 0;fi

  echo "Gathering db schema info"
  # Tables structure
  $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH pg_dump $PG_ATTR -s" > config_sql_dump.txt

}

collect_db_config() {
  cd "$LOG_PATH"/sql/config || exit_on_error "Directory $LOG_PATH/sql/config not available, exit script"
  if [[ $NO_DB_ACCESS == 1 ]]; then return 0;fi

  echo "Gathering db config info" |& tee -a "$LOG_PATH"/script_errors.log
  # Last 15000 lines of logs
  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    SELECT
        \"id\",
        \"createdAt\",
        reference_table,
        object_name,
        message
    FROM logs
    ORDER BY
        \"createdAt\" DESC
    LIMIT 25000
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >config_logs.csv

  # Collectors config
  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    SELECT id, name,__v, address, port, https, status,\"createdAt\", \"updatedAt\" FROM public.am_collectors
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >config_sql_am_collectors.csv

  # Intergations config
  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    SELECT
      id, status, uid, name, username, host, port,
      tls, database, domain, enabled, cron, time,
      collectors_id, \"createdAt\", \"updatedAt\", \"module\",  email,
      error, protocol, last_run, company_id, group_id,options
    FROM
      public.am_integrations
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >config_sql_am_integrations.csv

  # Connectors config
  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
    SELECT
      id, name, status, error, type, collectors_id, description, address,
      username, port, timeout, is_test_mode, regexp, result, auth_type,
      parent_id, \"createdAt\", \"updatedAt\", options
    FROM
      public.connectors
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >config_sql_connectors.csv

  # Users config
  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
  SELECT
    id, lang, last_logon, fields, disabled, hidden, fails, settings,
    interface_group_id, use_preset_interface, start_section, all_companies,
    blocked_until, password_creation_date, disabled_at, service_account,
    need_to_change_password, fails_count
  FROM
    users
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >config_sql_users.csv


  {
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR <<EOF
COPY (
  SELECT
    *
  FROM
    im_playbooks_relations
  WHERE
    unit_id IS NOT NULL
)
TO STDOUT WITH CSV HEADER;
EOF"
  } >config_sql_im_playbooks_relations.csv


  # Tables for download
  table_for_export=(

    "am_asset_life_cycle"
    "am_assets_assign_policies_rules_information"
    "am_assets_assign_policies_rules_organizations"
    "am_assets_assign_policies_rules_processes"
    "am_detects"
    "am_device_assign_policies_schedule"
    "am_device_assign_politic"
    "am_device_assign_politic_admin"
    "am_device_assign_politic_asset"
    "am_device_assign_politic_rule"
    "am_device_assign_politic_standard"
    "am_device_assign_politic_tag"
    "am_fields"
    "am_scans"
    "am_scans_assets"
    "am_scans_collectors"
    "am_scans_devices"
    "am_scans_groups"
    "am_scans_networks"
    "am_automation_scripts"
    "am_scripts_policies"
    "am_scripts_policies_automation_scripts"
    "am_scripts_policies_devices"
    "am_scripts_policies_networks"
    "am_scripts_policies_node_types"
    "im_correlation_rule_groups"
    "im_correlation_rules"
    "im_correlation_rules_incident_count"
    "im_correlation_rules_rule"
    "report_auto_generation_policies"
    "report_auto_generation_policies_companies"
    "im_playbooks"
    "im_playbooks_companies"
    "im_playbooks_criteria"
    "im_playbooks_transitions"
    "im_playbooks_relations"
    "tm_integrations"
    "im_fields"
    "im_fields_groups"
    "im_categories"
    "im_categories_fields"
    "im_categories_types"
    "im_catalog_types"
    "im_catalog_types_fields"
    "im_catalog_types_groups"
    "im_views"
    "im_views_criteria"
    "im_views_fields"
    "roles"
    "roles_asset_groups_types"
    "roles_incidents_categories_types"
    "roles_incidents_criteria"
    "roles_user_groups"
    "roles_users"
    "user_columns"
    "user_dashboard_filters"
    "user_groups"
    "user_groups_companies"
    "users_companies"
    "users_user_groups"
    "mail_gateways"
  )
  for table in ${table_for_export[*]}; do
    {
      $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql --set=table=\"$table\" -Fp $PG_ATTR <<EOF
COPY (
    SELECT
      *
    FROM
      :table
)
TO STDOUT WITH CSV HEADER;
EOF"
    } >config_"$table".csv
  done


echo -e "Gathering tuples info (may take a long time(3x100 tables))" |& tee -a "$LOG_PATH"/script_errors.log
$CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -q -Fp $PG_ATTR -c 'CREATE EXTENSION IF NOT EXISTS pgstattuple'"

tables_tup=($($CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp -qt $PG_ATTR -c 'select relname from pg_stat_user_tables order by n_dead_tup desc limit 100;'"))
tables_tup_count=${#tables_tup[@]}
for table2 in ${tables_tup[*]}; do
tables_tup_count=$(($tables_tup_count - 1))
echo -ne "$tables_tup_count\033[0K\r " &>/dev/tty
echo "Table: $table2" >> pgstattuple_by_dead_tuples.log
$CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR -c '\gx' -c \"select * from pgstattuple('$table2')\"" >> pgstattuple_by_dead_tuples.log
done
echo -e "\033[0K\r"

tables2_tup=($($CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp -qt $PG_ATTR -c 'select relname from pg_stat_user_tables order by seq_tup_read desc limit 100;'"))
tables2_tup_count=${#tables2_tup[@]}
for table3 in ${tables2_tup[*]}; do
tables2_tup_count=$(($tables2_tup_count - 1))
echo -ne "$tables2_tup_count\033[0K\r " &>/dev/tty
echo "Table: $table3" >> pgstattuple_by_seq_tup_read.log
$CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR -c '\gx' -c \"select * from pgstattuple('$table3')\"" >> pgstattuple_by_seq_tup_read.log
done
echo -e "\033[0K\r"


tables3_tup=($(cat $LOG_PATH/sql/stats/sql_pg_class_size.csv | awk -F, 'NR==2, NR==101 {print $1}'))
tables3_tup_count=${#tables3_tup[@]}
for table4 in ${tables3_tup[*]}; do
tables3_tup_count=$(($tables3_tup_count - 1))
echo -ne "$tables3_tup_count\033[0K\r " &>/dev/tty
echo "Table: $table4" >> pgstattuple_by_table_size.log
$CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR -c '\gx' -c \"select * from pgstattuple('$table4')\"" >> pgstattuple_by_table_size.log
done
echo -e "\033[0K\r"





echo -e  "Gathering index info (may take a long time)" |& tee -a "$LOG_PATH"/script_errors.log
index_stat=($($CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp -qt $PG_ATTR -c \"select indexrelname  from pg_stat_all_indexes where schemaname not like 'pg_%' order by idx_scan desc limit 100;\""))
index_stat_count=${#index_stat[@]}
for index in ${index_stat[*]}; do
index_stat_count=$(($index_stat_count - 1))
echo -ne "$index_stat_count\033[0K\r " &>/dev/tty
echo "Index: $index" >> pgstatindex.log
$CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR -c '\gx' -c \"select * from pgstatindex('$index')\"" >> pgstatindex.log
done
echo -e "\033[0K\r"


#gett params from mail_service_db

if [[ "$SYS_VERSION" =~ 5.2.* ]]; then
  {
      $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR_MAIL <<EOF
  COPY (
    SELECT
      uuid, config, host, user, \"lastError\", \"authMethod\", type, state, \"createdAt\"
    FROM
      mail_config
    )
  TO STDOUT WITH CSV HEADER;
EOF"
    } >config_mail_service_db_mail_config.csv
fi

if [[ "$SYS_VERSION" =~ 5.3.* ]]; then
    coll_tables=$($CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR_COLL -c '\dt' | sed '1,3d' | cut -d\" \" -f 4")
    for table in ${coll_tables[*]}; do
    echo "Table: $table" >> collector_db.log
    $CONTAINER_EXEC bash -c "PGPASSFILE=$PASSFILEPATH psql -Fp $PG_ATTR_COLL -c '\gx' -c \"select * from pgstattuple('$table')\"" >> collector_db.log
    done
fi

}

check_iops(){

cd "$LOG_PATH"/diagnostic || exit_on_error "Directory $LOG_PATH/diagnostic not available, exit script"

echo "Checking disk iops, may take a while" |& tee -a "$LOG_PATH"/script_errors.log
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=fiotest --filename=fiotest --bs=4k --iodepth=64 --size=4G --readwrite=randrw --rwmixread=75 >fio_disk_iops.txt
rm -f fiotest
}

check_db(){
local isdb
isdb=$($CONTAINER_EXEC bash -c "PGPASSFILE='$PASSFILEPATH' psql $PG_ATTR -lqt | cut -d \| -f 1 | grep -o rvision")
if [[ "$SKIP_DB_CHECK" ]];then
  echo "Manual DB check ignore, continue to collecting" |& tee -a $LOG_FILE_NAME
  echo -e "\nCredentials:\nHost: $DB_HOST_CONFIG \nUser: $DB_USER_CONFIG \nDatabase: $DB_NAME_CONFIG \nPort $DB_PORT_CONFIG" >&2
elif [[ -z $NO_DB_ACCESS ]] && [[ "$isdb" == "rvision" ]]; then
  echo "Connection to DB successfull" |& tee -a $LOG_FILE_NAME
  echo -e "\nCredentials:\nHost: $DB_HOST_CONFIG \nUser: $DB_USER_CONFIG \nDatabase: $DB_NAME_CONFIG \nPort $DB_PORT_CONFIG" >&2
elif [[ $NO_DB_ACCESS == 1 ]];then
  echo "No DB" |& tee -a $LOG_FILE_NAME
else
  echo "Cannot connect to DB, Maybe incorrect parsing of credentials to DB, check it" |& tee -a $LOG_FILE_NAME
  NO_DB_ACCESS=1
  echo -e "\nCredentials:\nHost: $DB_HOST_CONFIG \nUser: $DB_USER_CONFIG \nPassword: $DB_PASS_CONFIG \nDatabase: $DB_NAME_CONFIG \nPort $DB_PORT_CONFIG"
  echo -e "If credentials is correct, then check pg_hba.conf for $DB_USER_CONFIG access rights.\nIf credentials incorrect check your linux user rights to access config file "${PRODUCT_BASE_PATH}"/data/smp/volumes/common/config \n\n Press [Enter] to continue without DB logs, or CTRL + C to cancel script"
  echo -e "And use SKIP_DB_CHECK=yes parameter ${CGREEN}sudo SKIP_DB_CHECK=yes bash support_info.sh -a 123-456789${CNORM} for skipping DB check if you shure that credentials is correct"
  read -e -s
  echo -e "No DB access, checking error - manual choice to continue without db logs" |& tee -a $LOG_FILE_NAME
fi

}

manual_db_input(){

echo "Enter url or ip address for database:"
read DB_HOST_CONFIG
echo "Enter port for database url $DB_HOST_CONFIG [5432]"
read -i "5432" DB_PORT_CONFIG
DB_PORT_CONFIG=${DB_PORT_CONFIG:-5432}
echo "Enter database name for $DB_HOST_CONFIG:$DB_PORT_CONFIG [rvision]"
read  -i "rvision" DB_NAME_CONFIG
DB_NAME_CONFIG=${DB_NAME_CONFIG:-rvision}
echo "Enter user name for $DB_NAME_CONFIG database [rvision]"
read  -i "rvision" DB_USER_CONFIG
DB_USER_CONFIG=${DB_USER_CONFIG:-rvision}
echo "Enter password for user $DB_USER_CONFIG "
read -s  DB_PASS_CONFIG

printf "\n\nCheck connection paramaters:\nDB_HOST: $DB_HOST_CONFIG \nDB_PORT: $DB_PORT_CONFIG \nDB_NAME: $DB_NAME_CONFIG \nDB_USER: $DB_USER_CONFIG \n"
echo "Enter "Y" if correct, "N" for input again"
read REPEAT
case $REPEAT in
   Y | y)
     echo "Parameters accepted"
     ;;
  N | n)
     detect_db
     ;;
 esac

}

detect_db() {
echo "Detecting database parameters and checking database connection" |& tee -a "$LOG_PATH"/script_errors.log
get_installation_type

if [[ -n $CONFIG_FILE ]] && [[ $CONFIG_5_3 ]];then
  eval "$(cat $CONFIG_FILE | grep -Pzao "\[db\](.|\n)*?(user\s*=\N*)" | grep -a "^user *= *" | sed -e 's/user\s*=\s*/DB_USER_CONFIG=/g' | grep -a DB_USER_CONFIG)"
  DB_PASS_CONFIG="$(cat $CONFIG_FILE  | grep -Pzao "\[db\](.|\n)*?(pass\s*=\N*)" | grep -a "^pass *= *" | sed -e 's/pass\s*=\s*//g' | sed 's/\"//g' | sed s/\'//g)"
# eval "$(cat $CONFIG_FILE | grep -Pzo "\[db\](.|\n)*?(pass\s*=\N*)" | grep "^pass *= *" | sed -e 's/pass\s*=\s*/DB_PASS_CONFIG=/g' | grep DB_PASS_CONFIG)"
  eval "$(cat $CONFIG_FILE | grep -Pzao "\[db\](.|\n)*?(host\s*=\N*)" | grep -a "^host *= *" | sed -e 's/host\s*=\s*/DB_HOST_CONFIG=/g' | grep -a DB_HOST_CONFIG)"
  eval "$(cat $CONFIG_FILE | grep -Pzao "\[db\](.|\n)*?(name\s*=\N*)" | grep -a "^name *= *" | sed -e 's/name\s*=\s*/DB_NAME_CONFIG=/g' | grep -a DB_NAME_CONFIG)"
  eval "$(cat $CONFIG_FILE | grep -Pzao "\[db\](.|\n)*?(port\s*=\N*)" | grep -a "^port *= *" | sed -e 's/port\s*=\s*/DB_PORT_CONFIG=/g' | grep -a DB_PORT_CONFIG)"
  if [ "$DB_HOST_CONFIG" = "postgresql" ]; then
    DB_HOST_CONFIG="localhost"
  fi
#echo $DB_HOST_CONFIG:$DB_PORT_CONFIG:$DB_NAME_CONFIG:$DB_USER_CONFIG:$DB_PASS_CONFIG >&2
elif [[ -n $CONFIG_FILE ]] && [[ $CONFIG_5_4 ]];then
  DB_USER_CONFIG="$(cat $CONFIG_FILE | grep -a smp_db__user | sed -e 's/smp_db__user\s*=\s*//g')"
  DB_PASS_CONFIG="$(cat $CONFIG_FILE  | grep -a smp_db__pass | sed -e 's/smp_db__pass\s*=\s*//g')"
  DB_HOST_CONFIG="$(cat $CONFIG_FILE | grep -a smp_db__host | sed -e 's/smp_db__host\s*=\s*//g')"
  DB_NAME_CONFIG="$(cat $CONFIG_FILE | grep -a smp_db__name | sed -e 's/smp_db__name\s*=\s*//g')"
  DB_PORT_CONFIG="$(cat $CONFIG_FILE | grep -a smp_db__port | sed -e 's/smp_db__port\s*=\s*//g')"
  if [ "$DB_HOST_CONFIG" = "postgresql" ]; then
    DB_HOST_CONFIG="localhost"
  fi
elif [[ -z $CONFIG_FILE ]] && [[ $collect_type != "logs" ]]; then
echo "No config file for db parameters, manual input request" |& tee -a $LOG_FILE_NAME
echo "Do you want to manually enter DataBase credentials? (Y/N)"  |& tee -a $LOG_FILE_NAME
read MANUAL
case $MANUAL in
   Y | y)
     manual_db_input
     ;;
  N | n)
     NO_DB_ACCESS=1
     break
     ;;
 esac
elif [[ $collect_type != "logs" ]] && { [[ -z $DB_USER_CONFIG ]] || [[ -z $DB_PASS_CONFIG ]] || [[ -z $DB_HOST_CONFIG ]] || [[ -z $DB_NAME_CONFIG ]] || [[ -z $DB_PORT_CONFIG ]]; };then
echo "One of DB parameters missing, manual input request"  |& tee -a $LOG_FILE_NAME
echo "Do you want to manually enter DataBase credentials? (Y/N)"  |& tee -a $LOG_FILE_NAME
read MANUAL
case $MANUAL in
   Y | y)
     manual_db_input
     ;;
  N | n)
     NO_DB_ACCESS=1
     break
     ;;
 esac
fi

PG_ATTR="-h $DB_HOST_CONFIG -U $DB_USER_CONFIG -d $DB_NAME_CONFIG -p $DB_PORT_CONFIG"
#if version >= 5.2
PG_ATTR_MAIL="-h $DB_HOST_CONFIG -U $DB_USER_CONFIG -d mail_service_db -p $DB_PORT_CONFIG"
#if version >= 5.3
PG_ATTR_COLL="-h $DB_HOST_CONFIG -U $DB_USER_CONFIG -d collmanager -p $DB_PORT_CONFIG"

for _cname in "postgresql[_-]" "[_-]smp[_-]"; do
  PGCONTAINER="$(docker ps --filter "Name=$_cname\d+" --format '{{.Names}}' 2> /dev/null || true)"
  if [ $PGCONTAINER ]; then
    echo "PostgreSQL client tools container: $PGCONTAINER"
    break
  fi
done

#PASSFILE - where to put file
#PASSFILEPATH - from where read config to execute queries
if [[ $PGCONTAINER =~ smp[-_]1 ]]; then
  PASSFILE="${PRODUCT_BASE_PATH}"/data/smp/volumes/custom_scripts/pgpass
  PASSFILEPATH=/app/custom_scripts/pgpass
  touch $PASSFILE
  chown 10001 "$PASSFILE"
  chmod 0600 "$PASSFILE"
elif [[ $PGCONTAINER =~ postgresql[-_]1 ]]; then
  PASSFILE="${PRODUCT_BASE_PATH}"/data/db/cfg/pgpass
  PASSFILEPATH=/custom-cfg/pgpass
  touch $PASSFILE
  chmod 0600 "$PASSFILE"
else
  PASSFILE=/tmp/pgpass
  PASSFILEPATH=/tmp/pgpass
  touch $PASSFILE
  chmod 0600 "$PASSFILE"
fi
DB_PASS_CONFIG=$(echo $DB_PASS_CONFIG | sed "s/'//g")
echo "$DB_HOST_CONFIG"":$DB_PORT_CONFIG":"$DB_NAME_CONFIG":"$DB_USER_CONFIG":"$DB_PASS_CONFIG" > "$PASSFILE"
echo $PASSFILE > "$LOGPATH"/passfileplace
CONTAINER_EXEC="${PGCONTAINER:+"docker exec $PGCONTAINER"}"
check_db
}






create_archive() {
  cd "$LOG_PATH"/../ || exit_on_error "Cannot determine and archive $LOG_PATH directory, exiting"
  echo "Deleting trash files and directories" >&2
  find "$LOG_PATH" -type f -empty -print -delete >&2
  find "$LOG_PATH" -type d -empty -print -delete >&2

  if [ "$archiver" == zip ]; then
    if [[ "$PASS" ]]; then
      zip -P 'qb3rH6qAtKxP' -rq -6 "$LOG_PATH".zip "${LOG_PATH}" "${LOG_PATH}"_old
    fi
    zip -rq -6 "${LOG_PATH}".zip "${LOG_PATH}" "${LOG_PATH}"_old
  elif [ "$archiver" == tar ]; then
    tar -czf "${LOG_PATH}".tar.gz "${LOG_PATH}" "${LOG_PATH}_old"
  else
    echo "Cannot create archive" >&2
  fi
}

clean_dir() {
PASSFILEDEL=$(cat "$LOGPATH"/passfileplace)
if [[ $DEBUG ]]; then echo -e "$PASSFILEDEL"; fi
rm -f "$PASSFILEDEL"
rm -rf "$LOG_PATH"
}


check_index() {
if [[ $NO_DB_ACCESS == 1 ]]; then return 0;fi

echo "Checking DB indexes for error "

declare -A QUERIES=(
  ["am_devices_codes"]="FROM am_devices_codes WHERE id IN (SELECT MIN(id) FROM am_devices_codes GROUP BY devices_id, name, value HAVING COUNT(*) > 1);"
  ["am_devices_disks"]="FROM am_devices_disks WHERE id IN (SELECT MIN(id) FROM am_devices_disks GROUP BY devices_id, name HAVING COUNT(*) > 1);"
  ["am_devices_vulnerabilities_software"]="FROM am_devices_vulnerabilities_software WHERE id IN (SELECT MIN(id) FROM am_devices_vulnerabilities_software GROUP BY device_vulnerability_id, name, COALESCE(version, ''::character varying) HAVING COUNT(*) > 1);"
  ["am_software"]="FROM am_software WHERE id IN (select min(id) FROM am_software GROUP BY name, version, company_id HAVING count(*) > 1);"
  ["am_users_emails"]="FROM am_users_emails WHERE id IN (SELECT MIN(id) FROM am_users_emails GROUP BY am_user_id, LOWER(email::text) HAVING COUNT(*) > 1);"
  ["am_users-login-domain-company"]="FROM am_users WHERE id IN (SELECT MIN(id) FROM am_users WHERE domains_id IS NOT NULL AND login IS NOT NULL AND local = FALSE GROUP BY login, domains_id, company_id HAVING COUNT(*) > 1);"
  ["am_users-sid-device"]="FROM am_users WHERE id IN (SELECT MIN(id) FROM am_users WHERE device IS NOT NULL AND sid IS NOT NULL AND local = TRUE GROUP BY sid, device HAVING COUNT(*) > 1);"
  ["am_users"]="FROM am_users WHERE id IN (select min(id) FROM am_users WHERE ((device IS NOT NULL) AND (local = true)) GROUP BY login, device HAVING count(*) > 1);"
  ["am_vulnerabilities_references"]="FROM am_vulnerabilities_references WHERE id IN (select min(id) FROM am_vulnerabilities_references GROUP BY name, vulnerabilities_id having count(*) > 1);"
  ["am_vulnerabilities_software"]="FROM am_vulnerabilities_software WHERE id IN (select min(id) FROM am_vulnerabilities_software WHERE operator IS NOT null GROUP BY vulnerabilities_id, name, COALESCE(version, ''::character varying), operator HAVING count(*) > 1);"
)

CUSTOM_QUERY_SCRIPT="${CUSTOM_QUERY_SCRIPT:-"${PRODUCT_BASE_PATH}"/utils/db/custom-query.sh}"

printf "%36s | %10s | %s\n" "TABLE" "DUP_COUNT" "RESULT"

if [ ! -f "$CUSTOM_QUERY_SCRIPT" ]; then
  echo "[ERROR] script not found: $CUSTOM_QUERY_SCRIPT"
  echo "Set path to 'custom-query.sh' script by variable CUSTOM_QUERY_SCRIPT"
fi

REPORT=
FIXES=

for _query_id in "${!QUERIES[@]}"; do
  DUPLICATES_COUNT=0
  _query="${QUERIES[$_query_id]}"
  DUPLICATES_COUNT="$($CUSTOM_QUERY_SCRIPT "select count(*) $_query" 2>/dev/null || true)"

  printf "%36s | %10d | " "$_query_id" "$DUPLICATES_COUNT"
  if [ "${DUPLICATES_COUNT:-0}" -eq 0 ]; then
    echo "OK"
  else
    echo "WARN duplicates found"
    REPORT="${REPORT}--> $_query_id\n$($CUSTOM_QUERY_SCRIPT "select * $_query" 2>/dev/null)\n"
    FIXES="${FIXES}--> $_query_id, to delete duplicated rows:
    $CUSTOM_QUERY_SCRIPT \"DELETE $_query\"\n"
  fi
done

if [ "$REPORT" ]; then
  echo -e "\nReport:\n$REPORT"
fi

if [ "$FIXES" ]; then
  echo -e "\nFixes (WARN: LOST DATA):\n$FIXES"
fi

}

check_right(){
  if [ $(id -u) -gt 0 ]; then
    echo -e "${CRED}
  Elevated system privileges are required.
  Start again using command \"sudo\" or from behalf of user \"root\".${CNORM}"
    exit 1
  fi
}

check_cluster(){
  if [[ -f /opt/healthcheck/nodestate ]]; then
    echo "Cluster installation, requesting credentials for access db nodes"
    echo "It is better to gather logs from db nodes too. You need "
    echo "Enter url or ip address for database node 1:"
    read DB_NODE1_URL
    echo "Enter user with rights to docker commands for database node 1:"
    read DB_NODE1_USER
    echo "Enter url or ip address for database node 2:"
    read DB_NODE1_URL
    echo "Enter user with rights to docker commands for database node 2:"
    read DB_NODE1_USER


  elif [[ "$ext_db_cont" == 1 ]];then
    echo "External DB in container. Trying to gather logs"
  else
    echo "Not cluster installation, skipping another nodes checking"
  fi

}


help() {
  printf <<EOF "
  ##########################################################################################################
  ##########################################################################################################
  Incorrect parameters: Usage example: bash support_info.sh -a <archive name> <optional_log_parameters>

  Parameters:
  -a <archive name> - we recommend using the application number for example 123-456789

  with no -t equal to all parameters, except silly (system, logs, db, db_dev)

  <optional_log_parameters>

  1. -t key can take only one parameter from <logs, db, system, db_dev, silly>, two -t keys will take parameter from last key.

  system - only system info, no logs and no db requests

  logs - system info and logs, no db requests

  db - system info and db request, no system logs

  db_dev - collecting usage statistics for developers

  silly - extended collector log, 3-step process.
    1-enabling silly log mode for collector, and recreating collector container.
    2-repeat your steps to get the error.
    3-collecting extended log, disabling silly log mode for collector, recreating collector container again.

  2. -d key for date/time from which collect container logs, standart format for docker logs --since key. Show logs since timestamp (e.g. 2023-12-31T13:23:37Z) or relative (e.g. 42m for 42 minutes).
  If -d is empty then collecting last 15000 lines from container logs. Usable only with \"-t logs and silly\" type or with no -t key.

  3. -c key, for running only diagnostic checks (doubled index and disk iops)

  4. -n key, for create password protected ZIP file. Works only if you have zip on your host. Ask support for password.

  EXAMPLES:
  sudo bash support_info.sh -a 123-456789                          -> for collecting all available logs in archive /tmp/123-456789.<zip/tar.gz>
  sudo bash support_info.sh -a 123-456789 -t db                    -> for collecting only system info and db request_stats
  sudo bash support_info.sh -a 123-456789 -d 2023-12-31            -> for collecting all available logs in archive since 2023-16-31T00:00:00Z
  sudo bash support_info.sh -a 123-456789 -t logs -d 2023-12-31    -> for collecting only system info and docker logs since 2023-12-31T00:00:00Z
  sudo bash support_info.sh -a 123-456789 -t logs -d 60m           -> for collecting only system info and docker logs for last hour
  sudo bash support_info.sh -a 123-456789 -c                       -> for collecting only diagnostic info in archive /tmp/123-456789.<zip/tar.gz>
  sudo bash support_info.sh -a 123-456789 -n                       -> for collecting all available logs in archive /tmp/123-456789.<zip/tar.gz> with password, if it zip.
  sudo SKIP_DB_CHECK=yes bash support_info.sh -a 123-456789        -> for skipping DB check in a case of checking errors

  "
EOF
}



system() {
  if [[ $DEBUG ]]; then echo "[DEBUG] system function var arch dir is $arch_dir"; fi
  local START_TIME=$(date +%s)
  init_dir "$arch_dir"
  echo "Checking installation type"
  get_installation_type
  echo "Checking system version"
  get_installed_version "$arch_dir"
  echo "Collecting system info"
  collect_system_info
  echo "Collecting config files"
  collect_file_config
  execution_time $START_TIME "System info collect"
}

db() {
  local START_TIME=$(date +%s)
  #Get DB config from smp config file
  detect_db
  collect_db_stats
  collect_db_dump
  collect_db_config
  check_index > "$LOG_PATH"/index_check.log
  execution_time $START_TIME "Main DB info collect"
}

db_dev() {
  local START_TIME=$(date +%s)
  detect_db
  collect_db_dev_stats
  execution_time $START_TIME "Dev DB info collect"
}


logs(){
  local START_TIME=$(date +%s)
  echo "Collecting logs"
  collect_logs_info

  if command -v pcs &>/dev/null; then
    echo "Collecting cluster info"
    collect_cluster_info
  fi

  if command -v docker &>/dev/null; then
    echo "Collecting docker info"
    collect_docker_info
  fi
  if command -v pm2 &>/dev/null; then
    echo "Collecting PM2 info (if available)"
    collect_pm2_info
  fi

  if command -v patronictl &>/dev/null; then
    echo "Collecting DB cluster info"
    collect_db_cluster_info
  fi

  if [[ -d /opt/healthcheck ]]; then
    echo "Collecting APP cluster info"
    collect_app_cluster_info
  fi

  cd "$LOG_PATH" || exit_on_error "Directory $LOG_PATH not available, exit script"
  agg_host_data &> "$AGG_HOST_LOG"
  agg_app_data &> "$AGG_APP_LOG"

  execution_time $START_TIME "Logs info collect"
}


silly_off(){
echo "Disabling extended collector log"
sed -i '/LOG_LEVEL=silly\|DEF_SANDBOX=yes\|trace=silly/d' "${PRODUCT_BASE_PATH}"/data/collectors/collectorjs/.env

echo "Recreating collector container"
cd "${PRODUCT_BASE_PATH}"/app/collectors/collectorjs/ && ./stop.sh  && ./up.sh

}

silly_on(){

echo "Checking collector log mode"

if grep -o LOG_LEVEL=silly "${PRODUCT_BASE_PATH}"/data/collectors/collectorjs/.env && grep -o DEF_SANDBOX=yes "${PRODUCT_BASE_PATH}"/data/collectors/collectorjs/.env && grep -o trace=silly "${PRODUCT_BASE_PATH}"/data/collectors/collectorjs/.env; then
  echo "Extended log already enabled"
else
  echo "Enabling extended log"
  echo -e "LOG_LEVEL=silly\nDEF_SANDBOX=yes\ntrace=silly"  >> "${PRODUCT_BASE_PATH}"/data/collectors/collectorjs/.env
fi
trap 'silly_off; exit' SIGTERM SIGINT

echo "Recreating collector container"
cd "${PRODUCT_BASE_PATH}"/app/collectors/collectorjs/ && ./stop.sh  && ./up.sh

echo "Now you need to repeat steps to reproduce your problem. After reproducing it you need to press Enter for start collecting logs"
read -e -s -p "Press [Enter] to continue, press [Ctrl]+[C] to cancel..."
}

silly_attention(){
echo -e "ATTENTION! You launching silly mode. In this mode you will enable extended collector log, but all collector processes will be killed and changes made inside collector container will be removed during container being recreated!\nIf you agree press Enter, otherwise press CTRL+C to cancel launch"
read -e -s -p "Press [Enter] to continue, press [Ctrl]+[C] to cancel..."

}

archive(){
  echo -e "Archiving..."
  execution_time $START_TIME Script total time
  create_archive
  echo "Deleting temporary files"
  clean_dir
  if [[ "$archiver" = "zip" ]]; then
  echo "Collected info packed in archive $LOG_PATH.zip"
  elif [[ "$archiver" = "tar" ]]; then
  echo "Collected info packed in archive $LOG_PATH.tar.gz"
  fi
}

diagnostic(){

cd "$LOG_PATH"/diagnostic || exit_on_error "Directory $LOG_PATH/diagnostic not available, exit script"

check_iops &> "$LOG_PATH"/diagnostic/iops_check.log
check_index &> "$LOG_PATH"/diagnostic/index_check.log

}

execution_time(){
  local MSG=${2:-" execution time"}
  local END=$(date +%s)
  local DIFF=$(date -d @$((END-$1)) -u +%T)
  echo "$MSG $DIFF"
}

agg_host_data()
{
echo -e "OS information\n======================================================= ======================"
cat "$LOG_PATH"/system/sys_release.txt
echo -e "========================================================================= ================"
echo -e "\nInformation about the processor(s)\n====================================== ========================="
echo -e "Number of processors: $(cat /proc/cpuinfo | grep proc --count)"
echo -e "Number of processor cores: $(cat /proc/cpuinfo | grep "cpu co" -m1 | awk '{print$4}')"
echo -e "CPU model: $(cat /proc/cpuinfo | grep "model name" -m1 | cut -f 2 -d :)"
echo -e "CPU frequency: $(cat /proc/cpuinfo | grep "cpu MHz" -m1 |cut -f 2 -d :)"
echo -e "CPU flags: $(cat /proc/cpuinfo | grep "flags" -m1 |cut -f 2 -d :)"
echo -e "========================================================================= ================"
echo -e "\nInformation about RAM (in megabytes)\n================================================ ==========================="
free -m
echo -e "========================================================================= ================"
echo -e "\nInformation about free disk space\n====================================== ========================="
df -h | grep -v tmpfs | grep -v overlay
echo -e "========================================================================= ================"
echo -e "\nInformation about host network addresses\n====================================================== ========================"
ip -br a | grep -v
echo -e "========================================================================= ================"
echo -e "\nInformation about DNS addresses\n====================================================== ======================="
cat "$LOG_PATH"/system/ip_dns.txt
echo -e "========================================================================= ================"
echo -e "\nInformation about the system load (Load Average)\n================================================ ==========================="
cat /proc/loadavg
echo -e "========================================================================= ================"
echo -e "\nServer time information\n====================================================== ======================="
cat "$LOG_PATH"/system/sys_timedatectl.txt
echo -e "========================================================================= ================"
echo -e "\nServer name information\n====================================================== ======================="
cat "$LOG_PATH"/system/sys_uname.txt
echo -e "========================================================================= ================"
echo -e "\nInformation about server uptime\n====================================== ========================="
cat "$LOG_PATH"/system/sys_uptime.txt
echo -e "========================================================================= ================"
}


agg_app_data()
{
echo -e "========================================================================= ================"
echo -e "\nApplication version information (Version file and configuration file, values ​​must match)\n============== ===================================="
cat "${PRODUCT_BASE_PATH}"/app/smp/packageVersion
grep -a "version" "${PRODUCT_BASE_PATH}"/data/smp/volumes/common/config
echo -e "========================================================================= ================"
echo -e "\nLicense information\n===================================================================== ======================"
cat "$LOG_PATH"/docker/license.txt
echo -e "========================================================================= ================"
echo -e "\nInformation about the version of the collector(s) (local file and data from the database)\n========================================== ===================================="
cat "${PRODUCT_BASE_PATH}"/app/collectors/version
"${PRODUCT_BASE_PATH}"/utils/db/custom-query.sh "select id, name, https, status, error, \"__v\", node from am_collectors" 2>/dev/null
echo -e "========================================================================= ================"
echo -e "\nInformation about the database version\n====================================================== ======================="
if [[ -f "${PRODUCT_BASE_PATH}"/app/db/packageVersion ]]; then
 echo -e "Container version"
 cat "${PRODUCT_BASE_PATH}"/app/db/packageVersion
fi
echo -e "DBMS version"
"${PRODUCT_BASE_PATH}"/utils/db/custom-query.sh "select version()" 2>/dev/null
echo -e "========================================================================= ================"
echo -e "\nSystem configuration file\n====================================================== ======================"
cat "$LOG_PATH"/config/config_smp.txt
echo -e "========================================================================= ================"
if [[ -f "$LOG_PATH"/config/config_postgresql_custom.txt ]]; then
 echo -e "\nDatabase configuration file in container (custom.conf) !! FOR FULL PG SETTINGS VIEW sql_pg_settings.csv file in \"sql/stats\" or \"config\" directory\n================================================ ============================="
 cat "$LOG_PATH"/config/config_postgresql_custom.txt
 echo -e "========================================================================= ================"
fi
if [[ -f "$LOG_PATH"/config/host_env_port_open.txt ]]; then
 echo -e "\nEnvironment variables for opening ports to the outside (/etc/environment)\n============================================= ============================================="
 cat "$LOG_PATH"/config/host_env_port_open.txt
 echo -e "========================================================================= ================"
fi
if [[ -f "$LOG_PATH"/config/smp_default_envs.log ]]; then
 echo -e "\nEnvironment variables for the smp(defaults.env) service\n================================================ ============================="
 cat "$LOG_PATH"/config/smp_default_envs.log
 echo -e "========================================================================= ================"
fi
if [[ -f "$LOG_PATH"/config/smp_envs.log ]]; then
 echo -e "\nEnvironment variables for the smp(.env) service\n================================================ ============================"
 cat "$LOG_PATH"/config/smp_envs.log
 echo -e "========================================================================= ================"
fi
if [[ -f "$LOG_PATH"/config/smp_envs-s3.log ]]; then
 echo -e "\nEnvironment variables for the smp(.env-s3) service\n================================ ============================================="
 cat "$LOG_PATH"/config/smp_envs-s3.log
 echo -e "========================================================================= ================"
fi
if [[ -f "$LOG_PATH"/config/collector_envs.log ]]; then
 echo -e "\nEnvironment variables for the collector(.env) service\n================================================ ============================"
 cat "$LOG_PATH"/config/collector_envs.log
 echo -e "========================================================================= ================"
fi

}


exit_on_error(){

echo -e "${CRED}${1:-"Attention! An error occurred while changing directory"}${CNORM}"
exit 1

}



##################
##################
###Starting script
##################
START_TIME=$(date +%s)
check_right

##TODO
#check_cluster

if [ "$#" -lt 1 ]; then
  help
  exit 2
fi


date_arc=
collect_type=

while getopts ":a:d:t:cnf" opt; do
        case "${opt}" in
        a)
        arch_dir=$OPTARG
        ;;

        d)
        echo "Date for archive set '--since $OPTARG'"
        date_arc=$OPTARG
        ;;

        t)
        echo "Type of collected info '$OPTARG'"
        collect_type=$OPTARG
        ;;

        c)
        echo "Gathering only diagnostic info"
        collect_type=diagnostic
        ;;

        n)
        echo "Password for archive - active"
        PASS=yes
        ;;

        f)
        echo "Limited info collection mode"
        LIMIT=true
        ;;

        :)
        help
        exit 3
        ;;

        \?)
        help
        exit 4
        ;;

        *)
        help
        exit 5
        ;;
        esac
done

if [ $OPTIND -eq 1 ]; then
  echo "Wrong argument - read help"
  help
  exit 6
fi

if [ -z "$arch_dir" ]; then
  echo "No -a key provided, using default archive name \"${PRODUCT_NAME_LC}_logs\""
  arch_dir=${PRODUCT_NAME_LC}_logs
  if [ -f "$LOG_PATH.zip" ] || [ -f "$LOG_PATH.tar.gz" ]; then
    echo "$LOG_PATH archive already available, rename it to ${PRODUCT_NAME_LC}_logs_old"
    mv -f "$LOG_PATH".zip /tmp/${PRODUCT_NAME_LC}_logs_old.zip 2>/dev/null
    mv -f "$LOG_PATH".tar.gz /tmp/${PRODUCT_NAME_LC}_logs_old.tar.gz 2>/dev/null
  elif [[ -d "$LOG_PATH" ]]; then
    echo "$LOG_PATH directory already available, rename it to ${PRODUCT_NAME_LC}_logs_old"
    rm -fr /tmp/${PRODUCT_NAME_LC}_logs_old
    mv -f "$LOG_PATH" /tmp/${PRODUCT_NAME_LC}_logs_old
  fi
fi

if [[ $arch_dir =~ "./" ]];then
	arch_dir=${arch_dir/.\//$(pwd)/}
fi

if [[ $arch_dir =~ "/" ]];then
	if [[ $arch_dir =~ ".zip" ]];then
		arch_dir=${arch_dir//.zip/}
		LOG_PATH=$arch_dir
		arch_dir=$(echo $arch_dir | awk -F/ '{print $NF}')
	elif [[ $arch_dir =~ ".tar.gz" ]];then
		arch_dir=${arch_dir//.tar.gz/}
		LOG_PATH=$arch_dir
		arch_dir=$(echo $arch_dir | awk -F/ '{print $NF}')
	else
		LOG_PATH=$arch_dir
		arch_dir=$(echo $arch_dir | awk -F/ '{print $NF}')
  fi
elif [[ $arch_dir =~ ".zip" ]];then
	arch_dir=${arch_dir//.zip/}
	LOG_PATH=/tmp/$arch_dir
elif [[ $arch_dir =~ ".tar.gz" ]];then
	arch_dir=${arch_dir//.tar.gz/}
	LOG_PATH=/tmp/$arch_dir
else
  LOG_PATH=/tmp/$arch_dir
fi


if [[ -d $LOG_PATH ]]; then
  echo "Directory $LOG_PATH already exists, moving to ${LOG_PATH}_old"
  rm -rf "${LOG_PATH}"_old
  mv "$LOG_PATH" "${LOG_PATH}"_old
fi
mkdir -p "$LOG_PATH"
exec 2>"$LOG_PATH"/script_errors.log
touch "$LOG_PATH"/script_errors.log
LOG_FILE_NAME="$LOG_PATH"/collection.log
touch "$LOG_FILE_NAME"
ps aux |& grep support_info  &>> "$LOG_PATH"/script_launch.log
echo -e "If no more lines then no errors" &>> "$LOG_PATH"/script_errors.log

if [ -x "$(command -v zip)" ]; then
  archiver=zip
elif [ -x "$(command -v tar)" ]; then
  archiver=tar
fi

if [[ $DEBUG ]]; then echo "[DEBUG] collect type is $collect_type"; fi


case "$collect_type" in
  "")
    system | tee -a $LOG_FILE_NAME
    logs | tee -a $LOG_FILE_NAME
    db | tee -a $LOG_FILE_NAME
    archive | tee -a $LOG_FILE_NAME
  ;;
  "system")
    system | tee -a $LOG_FILE_NAME
    archive | tee -a $LOG_FILE_NAME
  ;;
  "db")
    system | tee -a $LOG_FILE_NAME
    db | tee -a $LOG_FILE_NAME
    archive | tee -a $LOG_FILE_NAME
  ;;
  "db_dev")
    system | tee -a $LOG_FILE_NAME
    db_dev | tee -a $LOG_FILE_NAME
    archive | tee -a $LOG_FILE_NAME
  ;;
  "logs")
    system | tee -a $LOG_FILE_NAME
    collect_db_config_file | tee -a $LOG_FILE_NAME
    logs | tee -a $LOG_FILE_NAME
    archive | tee -a $LOG_FILE_NAME
  ;;
  "silly")
    silly_attention | tee -a $LOG_FILE_NAME
    init_dir | tee -a $LOG_FILE_NAME
    silly_on | tee -a $LOG_FILE_NAME
    logs | tee -a $LOG_FILE_NAME
    silly_off | tee -a $LOG_FILE_NAME
    archive | tee -a $LOG_FILE_NAME
  ;;
  "diagnostic")
    init_dir | tee -a $LOG_FILE_NAME
    diagnostic | tee -a $LOG_FILE_NAME
    archive | tee -a $LOG_FILE_NAME
  ;;
  *)
    help
    exit 7
  ;;
esac
