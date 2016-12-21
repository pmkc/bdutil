# Copyright 2014 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS-IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# finalize the cluster configuration

source hadoop_helpers.sh

# initialize hdfs dirs
loginfo "Set up HDFS /tmp and /user dirs"
initialize_hdfs_dirs admin

AMBARI_CLUSTER=$(get_ambari_cluster_name)

# update hadoop configuration
# Add GCS connector to HADOOP_CLASSPATH
TEMPFILE=$(mktemp)
/var/lib/ambari-server/resources/scripts/configs.sh \
    get localhost ${AMBARI_CLUSTER} hadoop-env ${TEMPFILE}
sed -i 's#\(^"content.*\)",$#\1\\nHADOOP_CLASSPATH=${HADOOP_CLASSPATH}:/usr/local/lib/hadoop/lib/*",#' ${TEMPFILE}
/var/lib/ambari-server/resources/scripts/configs.sh \
    set localhost ${AMBARI_CLUSTER} hadoop-env ${TEMPFILE}

# Misc configuration
cat << EOF | xargs -n 3 /var/lib/ambari-server/resources/scripts/configs.sh \
    set localhost ${AMBARI_CLUSTER}
core-site fs.gs.impl  com.google.cloud.hadoop.fs.gcs.GoogleHadoopFileSystem
core-site fs.AbstractFileSystem.gs.impl com.google.cloud.hadoop.fs.gcs.GoogleHadoopFS
core-site fs.gs.project.id ${PROJECT}
core-site fs.gs.system.bucket ${CONFIGBUCKET}
core-site fs.gs.working.dir /
capacity-scheduler yarn.scheduler.capacity.node-locality-delay -1
EOF

sleep 10
loginfo "Restarting services, because Ambari usually requires it."
SERVICE='ALL'
ambari_service_stop
ambari_wait_requests_completed
ambari_service_start
ambari_wait_requests_completed

# Check GCS connectivity
check_filesystem_accessibility
