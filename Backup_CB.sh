#! /bin/bash

. ./common/common.sh
. ./backup/common.sh
. ./backup/backup_master.sh
. ./backup/backup_slave.sh

parse_input $@
validate_input

LOCAL_BACKUP_DIR=$LOCAL_BACKUP_DIR_BASE/$DATE/$REMOTE_HOST
LOG_DIR=$( dirname $LOCAL_BACKUP_DIR)
LOG_FILE="$LOG_DIR/backup.log"
mkdir -p $LOCAL_BACKUP_DIR
exec > >(tee >(sed -u -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g' > $LOG_FILE))
exec 2>&1

color_echo "Backup folder: $LOCAL_BACKUP_DIR/" "1;33"
color_echo "Log File: $LOG_FILE" "1;33"
echo

if [ -z "$MASTER_HOST" ];
then
    # ************************************************************************************************#
    # **************************** Connect to the remote host ****************************************#
    # **************************** It's either master or slave with no master info provided **********#
    # ************************************************************************************************#
    color_echo "--------------------------------------------------------------------------------------"
    color_echo "Retrieving information from the remote server"
    color_echo "--------------------------------------------------------------------------------------"
    get_remote_config
fi


if [ -z "$MASTER_HOST" ] && [ $ClusterMembership != "Slave" ];
then
    # ************************************************************************************************#
    # **************************** Master Configuration is found *************************************#
    # ************************************************************************************************#
    color_echo "--------------------------------------------------------------------------------------"
    color_echo "$ClusterMembership configuration is found on the remote server"
    color_echo "--------------------------------------------------------------------------------------"

    # ************************************************************************************************#
    # **************************** Stopping CB Server on the remote server ***************************#
    # ************************************************************************************************#
    echo
    color_echo "--------------------------------------------------------------------------------------"
    color_echo "Backing up \e[0mMASTER\e[1;32m"
    color_echo "--------------------------------------------------------------------------------------"
    if [ "$SKIP_MASTER_STOP" != "1" ]
    then
        color_echo "-------- Stopping cb-enterprise on the master"
        stop_start_cb_server $remote_conn "stop"
    fi
    # ************************************************************************************************#
    # **************************** Backing up master *************************************************#
    # ************************************************************************************************#
    backup_node $remote_conn $ClusterMembership $LOCAL_BACKUP_DIR $REMOTE_USER

    color_echo "--------------------------------------------------------------------------------------"
    color_echo "Backup of the MASTER is done"
    color_echo "--------------------------------------------------------------------------------------"

    # ************************************************************************************************#
    # **************************** Backing up all slaves if it's requested in command args ***********#
    # ************************************************************************************************#
    if [ $ClusterMembership == "Master" ] && [ "$MASTER_ALL" == "1" ];
    then
        echo
        color_echo "--------------------------------------------------------------------------------------"
        color_echo "Backing up \e[0mALL SLAVES\e[1;32m"
        color_echo "--------------------------------------------------------------------------------------"
        # ************************************************************************************************#
        # **************************** Getting cb_ssh key from the master to access all slaves ***********#
        # ************************************************************************************************#
        get_key_from_master $remote_conn
        # ************************************************************************************************#
        # **************************** Backing up all slaves *********************************************#
        # ************************************************************************************************#
        backup_all_slaves $remote_conn $LOCAL_BACKUP_DIR $slave_ssh_key
        color_echo "--------------------------------------------------------------------------------------"
        color_echo "Backup of ALL SLAVES is done"
        color_echo "--------------------------------------------------------------------------------------"
    fi

    # ************************************************************************************************#
    # **************************** Starting CB Server on the remote server ***************************#
    # ************************************************************************************************#
    if [ "$SKIP_MASTER_STOP" != "1" ]
    then
        echo
        color_echo "-------- Starting cb-enterprise on the master"
        stop_start_cb_server $remote_conn "start"
        color_echo "--- Done"
    fi
    echo
else
    # ************************************************************************************************#
    # **************************** Slave Configuration is found *************************************#
    # ************************************************************************************************#
    echo
    color_echo "--------------------------------------------------------------------------------------"
    color_echo "Slave configuration is found on the remote server"
    color_echo "--------------------------------------------------------------------------------------"

    # ************************************************************************************************#
    # **************************** Connecting to master node *****************************************#
    # ************************************************************************************************#
    echo
    color_echo "--------------------------------------------------------------------------------------"
    color_echo "Establishing connection to the master"
    color_echo "--------------------------------------------------------------------------------------"
    if [ -z "$MASTER_HOST" ];
    then
        # ************************************************************************************************#
        # **************************** No master info was provided in command args ***********************#
        # **************************** Copy cluster.conf from slave to parse it **************************#
        # ************************************************************************************************#
        color_echo "-------- Master inforamation was not provided. Getting cluster.conf from the remote server"
        get_master_info_from_remote
    fi
    color_echo "-------- Connecting to the master server"
    if [ -z "$MASTER_USER" ];
    then
        MASTER_USER=root
    fi
    open_ssh_tunnel $MASTER_USER $MASTER_HOST $MASTER_SSH_KEY
    exit_if_error $? "-------- Could not connect to the master ---------------------------------------------"
    master_conn=$last_conn
    color_echo "--- Done"

    # ************************************************************************************************#
    # **************************** No connection to slave was made yet *******************************#
    # **************************** We can try to connect to the remote with provided key *************#
    # **************************** Or obtain cn_ssh key from the master ******************************#
    # ************************************************************************************************#
    if [ -z "$remote_conn" ];
    then
        echo
        color_echo "--------------------------------------------------------------------------------------"
        color_echo "Establishing connection to the remote server"
        color_echo "--------------------------------------------------------------------------------------"

        # ************************************************************************************************#
        # **************************** Trying to connect to the remote with provided key *****************#
        # ************************************************************************************************#
        if [ ! -z "$SSH_KEY" ]
        then
            test_ssh_key $REMOTE_USER $REMOTE_HOST $SSH_KEY
            key_valid=$?
        else
            color_echo "-------- SSH key to the slave was not provided"
            key_valid=0
        fi

        # ************************************************************************************************#
        # **************************** Trying to obtain cb_shh key from the master ***********************#
        # ************************************************************************************************#
        if [ "$key_valid" == "0" ];
        then
            get_slave_ssh_key_from_master $master_conn
        fi
        color_echo "-------- Connecting to the slave node"
        # ************************************************************************************************#
        # **************************** Connecting to the remote server ***********************************#
        # ************************************************************************************************#
        get_remote_connection
        get_remote_config
        color_echo "--- Done"
    fi

    # ************************************************************************************************#
    # **************************** Stopping CB Server on the remote server ***************************#
    # ************************************************************************************************#
    echo
    echo
    color_echo "--------------------------------------------------------------------------------------"
    color_echo "Backing up SLAVE [\e[0m$REMOTE_HOST\e[1;32m]"
    color_echo "--------------------------------------------------------------------------------------"
    if [ "$SKIP_MASTER_STOP" != "1" ]
    then
        color_echo "-------- Stopping cb-enterprise on the master"
        stop_start_cb_server $master_conn "stop"
    fi

    # ************************************************************************************************#
    # **************************** Backing up salve **************************************************#
    # ************************************************************************************************#
    backup_node $remote_conn $ClusterMembership $LOCAL_BACKUP_DIR $REMOTE_USER

    color_echo "--------------------------------------------------------------------------------------"
    color_echo "Backup of the SLAVE is done"
    color_echo "--------------------------------------------------------------------------------------"

    # ************************************************************************************************#
    # **************************** Starting CB Server on the remote server ***************************#
    # ************************************************************************************************#
    if [ "$SKIP_MASTER_STOP" != "1" ]
    then
        echo
        color_echo "-------- Starting cb-enterprise on the master"
        stop_start_cb_server $master_conn "start"
        color_echo "--- Done"
    fi
    echo
    close_ssh_tunnel $master_conn
fi

close_ssh_tunnel $remote_conn
cleanup_tmp_files

echo
color_echo "--------------------------------------------------------------------------------------"
color_echo "Backup is successful"
color_echo "--------------------------------------------------------------------------------------"

echo
color_echo "Log File: $LOG_DIR/backup.log" "1;33"

